import Foundation

struct WikiAnnotationSummary {
    let textAnnotations: [String]
    let rectangleCount: Int
    let arrowCount: Int
    let strokeCount: Int

    var promptSummary: String {
        var lines: [String] = []
        if !textAnnotations.isEmpty {
            lines.append("Text annotations: \(textAnnotations.joined(separator: " | "))")
        }
        lines.append("Rectangle annotations: \(rectangleCount)")
        lines.append("Arrow annotations: \(arrowCount)")
        lines.append("Freehand annotations: \(strokeCount)")
        return lines.joined(separator: "\n")
    }
}

struct WikiIngestResult {
    let entities: [String]
    let concepts: [String]
    let capturePagePath: String
    let affectedPaths: [String]
}

private struct WikiTopicExtraction: Decodable {
    let entities: [String]
    let concepts: [String]
    let capture_summary: String
    let key_points: [String]?
}

private struct WikiPageSynthesisPayload: Decodable {
    let pages: [WikiSynthesizedPage]
}

private struct WikiSynthesizedPage: Decodable {
    let title: String
    let kind: String
    let markdown: String
}

private struct WikiExistingPageContext {
    let title: String
    let kind: WikiPageKind
    let relativePath: String
    let content: String
}

enum WikiOperationService {
    static func annotationSummary(from annotations: PersistedCaptureAnnotations) -> WikiAnnotationSummary {
        WikiAnnotationSummary(
            textAnnotations: annotations.texts.map(\.text).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty },
            rectangleCount: annotations.shapes.filter { $0.kind == .rectangle }.count,
            arrowCount: annotations.shapes.filter { $0.kind == .arrow }.count,
            strokeCount: annotations.strokes.count
        )
    }

    static func ingest(
        capture: CaptureRecord,
        annotationSummary: WikiAnnotationSummary,
        repository: WikiRepository,
        configuration: OpenAIAnalysisConfiguration
    ) async throws -> WikiIngestResult {
        try repository.ensureStructure()
        let schema = try repository.loadSchema()
        let extraction = try await WikiOpenAIClient.extractTopics(
            capture: capture,
            annotationSummary: annotationSummary,
            schema: schema,
            configuration: configuration
        )

        let normalizedEntities = uniqueNonEmpty(extraction.entities)
        let normalizedConcepts = uniqueNonEmpty(extraction.concepts)
        let existingPages = loadExistingPages(
            entities: normalizedEntities,
            concepts: normalizedConcepts,
            repository: repository
        )

        let synthesis = try await WikiOpenAIClient.synthesizePages(
            capture: capture,
            annotationSummary: annotationSummary,
            schema: schema,
            extraction: extraction,
            existingPages: existingPages,
            configuration: configuration
        )

        let capturePagePath = repository.relativePathForCapture(id: capture.id)
        let capturePageMarkdown = buildCapturePage(
            capture: capture,
            extraction: extraction,
            entities: normalizedEntities,
            concepts: normalizedConcepts,
            pageDrafts: synthesis.pages
        )
        try repository.writePage(relativePath: capturePagePath, content: capturePageMarkdown)

        var affectedPaths: [String] = [capturePagePath]
        for page in synthesis.pages {
            guard let kind = pageKind(from: page.kind) else { continue }
            let relativePath = repository.relativePath(for: page.title, kind: kind)
            try repository.writePage(relativePath: relativePath, content: normalizedMarkdown(page.markdown, fallbackTitle: page.title))
            affectedPaths.append(relativePath)
        }

        _ = try repository.refreshIndex()
        try repository.appendLogEntry(action: "ingest", capture: capture, affectedPaths: affectedPaths)

        return WikiIngestResult(
            entities: normalizedEntities,
            concepts: normalizedConcepts,
            capturePagePath: capturePagePath,
            affectedPaths: uniqueNonEmpty(affectedPaths)
        )
    }

    private static func buildCapturePage(
        capture: CaptureRecord,
        extraction: WikiTopicExtraction,
        entities: [String],
        concepts: [String],
        pageDrafts: [WikiSynthesizedPage]
    ) -> String {
        let title = capture.presetPayload.pageTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? capture.displayTitle
            : capture.presetPayload.pageTitle
        let summary = extraction.capture_summary.trimmingCharacters(in: .whitespacesAndNewlines)
        let points = (extraction.key_points ?? []).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let relatedDrafts = pageDrafts.compactMap { draft -> String? in
            guard let kind = pageKind(from: draft.kind) else { return nil }
            let folder = kind.directoryName
            let slug = WikiRepository.slug(from: draft.title)
            return "- [\(draft.title)](../\(folder)/\(slug).md)"
        }

        var lines: [String] = [
            "# \(title)",
            "",
            "## Summary",
            summary.isEmpty ? "No summary was generated for this capture yet." : summary,
            "",
            "## Capture",
            "- Capture ID: `\(capture.id)`",
            "- Source: \(capture.displaySubtitle)",
            "- Captured: \(CaptureRecord.markdownTimestampFormatter.string(from: capture.createdAt))",
            "- Screenshot: `\(capture.imagePath)`"
        ]

        if let primaryURL = capture.primaryURL, !primaryURL.isEmpty {
            lines.append("- URL: \(primaryURL)")
        }
        if !entities.isEmpty {
            lines.append("- Entities: \(entities.joined(separator: ", "))")
        }
        if !concepts.isEmpty {
            lines.append("- Concepts: \(concepts.joined(separator: ", "))")
        }

        if !points.isEmpty {
            lines.append("")
            lines.append("## Key Points")
            lines.append(contentsOf: points.map { "- \($0)" })
        }

        if !relatedDrafts.isEmpty {
            lines.append("")
            lines.append("## Related Wiki Pages")
            lines.append(contentsOf: relatedDrafts)
        }

        let sourceText = capture.presetPayload.clippedMarkdownContent.trimmingCharacters(in: .whitespacesAndNewlines)
        if !sourceText.isEmpty {
            lines.append("")
            lines.append("## Source Excerpt")
            lines.append("")
            lines.append(sourceText)
        } else if !capture.ocrText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append("")
            lines.append("## OCR Text")
            lines.append("")
            lines.append(capture.ocrText.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return lines.joined(separator: "\n")
    }

    private static func loadExistingPages(
        entities: [String],
        concepts: [String],
        repository: WikiRepository
    ) -> [WikiExistingPageContext] {
        var pages: [WikiExistingPageContext] = []
        for entity in entities {
            let relativePath = repository.relativePath(for: entity, kind: .entity)
            if let content = repository.loadPage(relativePath: relativePath) {
                pages.append(WikiExistingPageContext(title: entity, kind: .entity, relativePath: relativePath, content: content))
            }
        }
        for concept in concepts {
            let relativePath = repository.relativePath(for: concept, kind: .concept)
            if let content = repository.loadPage(relativePath: relativePath) {
                pages.append(WikiExistingPageContext(title: concept, kind: .concept, relativePath: relativePath, content: content))
            }
        }
        return pages
    }

    private static func pageKind(from rawValue: String) -> WikiPageKind? {
        switch rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "entity", "entities":
            return .entity
        case "concept", "concepts":
            return .concept
        default:
            return nil
        }
    }

    private static func normalizedMarkdown(_ markdown: String, fallbackTitle: String) -> String {
        let trimmed = markdown.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "# \(fallbackTitle)\n"
        }
        if trimmed.hasPrefix("#") {
            return trimmed
        }
        return "# \(fallbackTitle)\n\n" + trimmed
    }

    private static func uniqueNonEmpty(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        var ordered: [String] = []
        for value in values {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = trimmed.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            if seen.insert(key).inserted {
                ordered.append(trimmed)
            }
        }
        return ordered
    }
}

private enum WikiOpenAIClient {
    private struct RequestBody: Encodable {
        let model: String
        let input: [RequestMessage]
        let text: RequestText

        struct RequestText: Encodable {
            let format: ResponseFormat
        }

        struct ResponseFormat: Encodable {
            let type: String
        }
    }

    private struct RequestMessage: Encodable {
        let role: String
        let content: [RequestContent]
    }

    private struct RequestContent: Encodable {
        let type: String
        let text: String?
    }

    private struct ResponseEnvelope: Decodable {
        let output: [OutputItem]?
    }

    private struct OutputItem: Decodable {
        let content: [OutputContent]?
    }

    private struct OutputContent: Decodable {
        let type: String
        let text: String?
    }

    private struct ErrorEnvelope: Decodable {
        let error: APIErrorPayload
    }

    private struct APIErrorPayload: Decodable {
        let message: String
    }

    static func extractTopics(
        capture: CaptureRecord,
        annotationSummary: WikiAnnotationSummary,
        schema: String,
        configuration: OpenAIAnalysisConfiguration
    ) async throws -> WikiTopicExtraction {
        let prompt = """
        You are extracting wiki topics from a QuickSnap capture. Return only a JSON object with these keys:
        entities (array of strings),
        concepts (array of strings),
        capture_summary (string),
        key_points (array of strings).

        Prefer high-signal entities and concepts only. Keep each list under 8 items.

        Wiki schema:
        \(schema)

        Capture metadata:
        Preset: \(capture.presetDefinition.name)
        Source App: \(capture.sourceApp)
        Window Title: \(capture.windowTitle)
        URL: \(capture.primaryURL ?? "Unavailable")
        Page Title: \(capture.presetPayload.pageTitle)
        Tags: \(capture.tags.joined(separator: ", "))

        Annotation guidance:
        \(annotationSummary.promptSummary)

        Clipped Markdown:
        \(capture.presetPayload.clippedMarkdownContent)

        OCR Text:
        \(capture.ocrText)
        """

        let output = try await performJSONRequest(prompt: prompt, configuration: configuration)
        return try JSONDecoder().decode(WikiTopicExtraction.self, from: Data(output.utf8))
    }

    static func synthesizePages(
        capture: CaptureRecord,
        annotationSummary: WikiAnnotationSummary,
        schema: String,
        extraction: WikiTopicExtraction,
        existingPages: [WikiExistingPageContext],
        configuration: OpenAIAnalysisConfiguration
    ) async throws -> WikiPageSynthesisPayload {
        let targetList = (
            extraction.entities.map { "entity: \($0)" } +
            extraction.concepts.map { "concept: \($0)" }
        ).joined(separator: "\n")

        let existingText = existingPages.isEmpty
            ? "No existing pages for these targets."
            : existingPages.map { context in
                """
                ### \(context.kind.rawValue.capitalized): \(context.title)
                Relative Path: \(context.relativePath)
                \(context.content)
                """
            }.joined(separator: "\n\n")

        let prompt = """
        You are updating a QuickSnap knowledge wiki. Return only a JSON object with one key:
        pages (array of objects with keys title, kind, markdown).

        Rules:
        - kind must be either "entity" or "concept"
        - return one page object for each requested target below
        - preserve useful existing information when a current page already exists
        - write concise Markdown with a top-level # heading
        - include links back to the capture page using `../captures/\(WikiRepository.slug(from: capture.id)).md` when helpful

        Wiki schema:
        \(schema)

        Requested targets:
        \(targetList)

        Existing pages:
        \(existingText)

        Capture summary:
        \(extraction.capture_summary)

        Key points:
        \((extraction.key_points ?? []).joined(separator: " | "))

        Annotation guidance:
        \(annotationSummary.promptSummary)

        Source Markdown:
        \(capture.presetPayload.clippedMarkdownContent)

        OCR Text:
        \(capture.ocrText)
        """

        let output = try await performJSONRequest(prompt: prompt, configuration: configuration)
        return try JSONDecoder().decode(WikiPageSynthesisPayload.self, from: Data(output.utf8))
    }

    private static func performJSONRequest(prompt: String, configuration: OpenAIAnalysisConfiguration) async throws -> String {
        let body = RequestBody(
            model: configuration.model,
            input: [
                RequestMessage(
                    role: "user",
                    content: [RequestContent(type: "input_text", text: prompt)]
                )
            ],
            text: .init(format: .init(type: "json_object"))
        )

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw CaptureAnalysisError.badResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw apiError(from: data) ?? CaptureAnalysisError.badResponse
        }

        let envelope = try JSONDecoder().decode(ResponseEnvelope.self, from: data)
        guard let output = extractedOutputText(from: envelope), !output.isEmpty else {
            throw CaptureAnalysisError.emptyResponse
        }
        return output
    }

    private static func extractedOutputText(from envelope: ResponseEnvelope) -> String? {
        envelope.output?
            .flatMap { $0.content ?? [] }
            .first(where: { $0.type == "output_text" })?
            .text
    }

    private static func apiError(from data: Data) -> CaptureAnalysisError? {
        guard let payload = try? JSONDecoder().decode(ErrorEnvelope.self, from: data) else {
            return nil
        }
        return .apiError(payload.error.message)
    }
}
