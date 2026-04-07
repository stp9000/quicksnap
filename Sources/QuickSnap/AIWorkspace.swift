import Foundation

enum CaptureAnalysisStatus: String, Codable, CaseIterable {
    case idle
    case pending
    case complete
    case failed

    var displayName: String {
        switch self {
        case .idle: return "Not analyzed"
        case .pending: return "Analyzing"
        case .complete: return "Analysis ready"
        case .failed: return "Analysis failed"
        }
    }
}

enum WorkspacePanelMode: String, CaseIterable, Identifiable {
    case analyze = "Analyze"
    case send = "Send"

    var id: String { rawValue }
}

enum SubmissionTarget: String, Codable, CaseIterable, Identifiable {
    case github
    case jira

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .github: return "GitHub"
        case .jira: return "Jira"
        }
    }
}

enum BugReportScreenshotHandlingMode: String, Codable, CaseIterable {
    case clipboard
    case localFileReference

    var displayName: String {
        switch self {
        case .clipboard: return "Clipboard"
        case .localFileReference: return "Local File Reference"
        }
    }
}

struct BugReportDraft: Codable, Hashable {
    var captureID: String = ""
    var captureDisplayLabel: String = ""
    var title: String = ""
    var body: String = ""
    var labels: [String] = []
    var target: SubmissionTarget = .github
    var screenshotHandlingMode: BugReportScreenshotHandlingMode = .clipboard

    var hasContent: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func githubIssueURL(owner: String, repo: String) -> URL? {
        let trimmedOwner = owner.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedRepo = repo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedOwner.isEmpty, !trimmedRepo.isEmpty else { return nil }

        var components = URLComponents(string: "https://github.com/\(trimmedOwner)/\(trimmedRepo)/issues/new")
        var queryItems = [
            URLQueryItem(name: "title", value: title),
            URLQueryItem(name: "body", value: body)
        ]
        if !labels.isEmpty {
            queryItems.append(URLQueryItem(name: "labels", value: labels.joined(separator: ",")))
        }
        components?.queryItems = queryItems
        return components?.url
    }
}

enum CaptureChatRole: String, Codable, CaseIterable {
    case user
    case assistant
}

struct CaptureChatMessage: Identifiable, Codable, Hashable {
    let id: String
    let captureID: String
    let role: CaptureChatRole
    let body: String
    let createdAt: Date
}

enum SendPreviewKind: String, CaseIterable, Identifiable {
    case filePath
    case markdownSnippet
    case markdownDocument
    case issueDraft
    case githubIssueURL

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .filePath: return "File Path"
        case .markdownSnippet: return "Markdown Snippet"
        case .markdownDocument: return "Markdown Document"
        case .issueDraft: return "Issue Draft"
        case .githubIssueURL: return "GitHub Issue URL"
        }
    }

    var usesMonospace: Bool {
        switch self {
        case .markdownSnippet, .markdownDocument:
            return false
        case .filePath, .issueDraft, .githubIssueURL:
            return true
        }
    }
}

struct CaptureAnalysisResult: Codable, Hashable {
    var status: CaptureAnalysisStatus = .idle
    var presetID: String = ""
    var updatedAt: Date?
    var summary: String = ""
    var tags: [String] = []
    var recommendedActions: [String] = []
    var issueTitle: String = ""
    var issueBody: String = ""
    var severity: String = ""
    var rawJSON: String = ""

    var hasContent: Bool {
        !summary.isEmpty || !tags.isEmpty || !recommendedActions.isEmpty || !issueTitle.isEmpty || !issueBody.isEmpty
    }
}

struct CaptureAnalysisRequest: Codable {
    let captureID: String
    let presetID: String
    let imagePath: String
    let ocrText: String
    let sourceApp: String
    let windowTitle: String
    let urlString: String?
    let presetPayload: CapturePresetPayload
}

struct OpenAIAnalysisConfiguration: Equatable {
    let apiKey: String
    let model: String
}

enum OpenAIModelNormalizer {
    static func normalize(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "gpt-4o-mini"
        }

        let lowered = trimmed.lowercased()
        switch lowered {
        case "4.0 mini", "4o mini", "gpt 4o mini", "gpt-4.0-mini", "gpt4o-mini":
            return "gpt-4o-mini"
        case "4.1 mini", "gpt 4.1 mini":
            return "gpt-4.1-mini"
        default:
            return trimmed
        }
    }
}

enum CaptureAnalysisError: Error {
    case invalidImageData
    case badResponse
    case emptyResponse
    case apiError(String)
}

enum CaptureAnalysisService {
    static func analyzeWithAI(capture: CaptureRecord, configuration: OpenAIAnalysisConfiguration) async throws -> CaptureAnalysisResult {
        try await OpenAIAnalysisClient.analyze(capture: capture, configuration: configuration)
    }

    static func generateMarkdown(prompt: String, imageURL: URL, configuration: OpenAIAnalysisConfiguration) async throws -> String {
        try await OpenAIAnalysisClient.generateMarkdown(prompt: prompt, imageURL: imageURL, configuration: configuration)
    }

    static func analyzeLocally(capture: CaptureRecord) -> CaptureAnalysisResult {
        heuristicAnalysis(for: capture)
    }

    static func testConnection(configuration: OpenAIAnalysisConfiguration) async throws {
        try await OpenAIAnalysisClient.testConnection(configuration: configuration)
    }

    static func respondToChat(capture: CaptureRecord, messages: [CaptureChatMessage], question: String, configuration: OpenAIAnalysisConfiguration?) async throws -> String {
        if let configuration {
            return try await OpenAIAnalysisClient.chat(capture: capture, messages: messages, question: question, configuration: configuration)
        }
        return heuristicChatResponse(for: capture, messages: messages, question: question)
    }

    private static func heuristicAnalysis(for capture: CaptureRecord) -> CaptureAnalysisResult {
        let request = CaptureAnalysisRequest(
            captureID: capture.id,
            presetID: capture.presetID,
            imagePath: capture.imagePath,
            ocrText: capture.ocrText,
            sourceApp: capture.sourceApp,
            windowTitle: capture.windowTitle,
            urlString: capture.primaryURL,
            presetPayload: capture.presetPayload
        )

        let summary = heuristicSummary(for: capture)
        let tags = heuristicTags(for: capture)
        let actions = recommendedActions(for: capture)
        let issueTitle = suggestedIssueTitle(for: capture, summary: summary)
        let issueBody = suggestedIssueBody(for: capture, summary: summary)
        let severity = severityForCapture(capture)

        let rawObject: [String: Any] = [
            "request": [
                "capture_id": request.captureID,
                "preset_id": request.presetID,
                "image_path": request.imagePath,
                "source_app": request.sourceApp,
                "window_title": request.windowTitle,
                "url": request.urlString ?? "",
                "ocr_text": request.ocrText
            ],
            "response": [
                "mode": "local_fallback",
                "summary": summary,
                "tags": tags,
                "recommended_actions": actions,
                "issue_title": issueTitle,
                "issue_body": issueBody,
                "severity": severity
            ]
        ]

        let rawJSON = prettyJSONString(from: rawObject)
        return CaptureAnalysisResult(
            status: .complete,
            presetID: capture.presetID,
            updatedAt: Date(),
            summary: summary,
            tags: tags,
            recommendedActions: actions,
            issueTitle: issueTitle,
            issueBody: issueBody,
            severity: severity,
            rawJSON: rawJSON
        )
    }

    private static func heuristicSummary(for capture: CaptureRecord) -> String {
        let context = firstNonEmpty([
            capture.windowTitle,
            capture.presetPayload.pageTitle,
            capture.presetPayload.researchSummary,
            capture.searchSummary
        ]) ?? capture.displayTitle

        switch capture.normalizedPresetID {
        case "bug_report":
            let console = capture.presetPayload.consoleSummary
            if !console.isEmpty {
                return "Potential bug report in \(context) with visible console/error signal: \(console)"
            }
            return "Potential bug report captured in \(context). Review the interface state, URL, metadata, and annotations for reproduction details."
        default:
            return "General capture of \(context) with reusable OCR, metadata, and export artifacts."
        }
    }

    private static func heuristicTags(for capture: CaptureRecord) -> [String] {
        var tags = capture.tags
        let presetTag = capture.presetDefinition.name.lowercased().replacingOccurrences(of: " ", with: "-")
        if !tags.contains(presetTag) { tags.append(presetTag) }
        if !capture.sourceApp.isEmpty { tags.append(capture.sourceApp.lowercased()) }
        if capture.primaryURL != nil { tags.append("has-url") }
        if !capture.ocrText.isEmpty { tags.append("ocr-indexed") }
        if capture.normalizedPresetID == "bug_report", !capture.presetPayload.consoleSummary.isEmpty { tags.append("console-signal") }
        return Array(NSOrderedSet(array: tags.filter { !$0.isEmpty })) as? [String] ?? tags
    }

    fileprivate static func recommendedActions(for capture: CaptureRecord) -> [String] {
        switch capture.normalizedPresetID {
        case "bug_report":
            return ["Review issue draft", "Open GitHub issue", "Verify reproduction context"]
        default:
            return ["Preview Markdown document", "Copy file path", "Add tags for retrieval"]
        }
    }

    fileprivate static func suggestedIssueTitle(for capture: CaptureRecord, summary: String) -> String {
        switch capture.normalizedPresetID {
        case "bug_report":
            if !capture.issueDraftTitle.isEmpty { return capture.issueDraftTitle }
            return summary
        default:
            return ""
        }
    }

    fileprivate static func suggestedIssueBody(for capture: CaptureRecord, summary: String) -> String {
        switch capture.normalizedPresetID {
        case "bug_report":
            if !capture.issueDraftBody.isEmpty { return capture.issueDraftBody }
            return summary
        default:
            return ""
        }
    }

    fileprivate static func severityForCapture(_ capture: CaptureRecord) -> String {
        let searchable = [capture.presetPayload.consoleSummary, capture.presetPayload.errorMessage, capture.ocrText]
            .joined(separator: " ")
            .lowercased()
        if searchable.contains("fatal") || searchable.contains("uncaught") || searchable.contains("crash") { return "high" }
        if searchable.contains("error") || searchable.contains("failed") { return "medium" }
        if capture.normalizedPresetID == "bug_report" { return "medium" }
        return "low"
    }

    fileprivate static func firstNonEmpty(_ values: [String]) -> String? {
        values.first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
    }

    fileprivate static func prettyJSONString(from object: Any) -> String {
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted]),
              let string = String(data: data, encoding: .utf8) else {
            return ""
        }
        return string
    }

    private static func heuristicChatResponse(for capture: CaptureRecord, messages: [CaptureChatMessage], question: String) -> String {
        let lowerQuestion = question.lowercased()

        if lowerQuestion.contains("summary") || lowerQuestion.contains("what is the issue") {
            return capture.analysis.summary.isEmpty ? heuristicSummary(for: capture) : capture.analysis.summary
        }

        if lowerQuestion.contains("tag") {
            let tags = capture.analysis.tags.isEmpty ? heuristicTags(for: capture) : capture.analysis.tags
            return tags.isEmpty ? "I don't have any strong tags for this capture yet." : "Suggested tags: \(tags.joined(separator: ", "))."
        }

        if lowerQuestion.contains("severity") {
            let severity = capture.analysis.severity.isEmpty ? severityForCapture(capture) : capture.analysis.severity
            return "This looks \(severity)."
        }

        if lowerQuestion.contains("issue") || lowerQuestion.contains("draft") {
            let issueTitle = capture.analysis.issueTitle.isEmpty ? suggestedIssueTitle(for: capture, summary: capture.analysis.summary) : capture.analysis.issueTitle
            let issueBody = capture.analysis.issueBody.isEmpty ? suggestedIssueBody(for: capture, summary: capture.analysis.summary) : capture.analysis.issueBody
            return [issueTitle, issueBody].filter { !$0.isEmpty }.joined(separator: "\n\n")
        }

        if lowerQuestion.contains("next") || lowerQuestion.contains("action") {
            let actions = capture.analysis.recommendedActions.isEmpty ? recommendedActions(for: capture) : capture.analysis.recommendedActions
            return actions.isEmpty ? "No follow-up actions are available yet." : "Recommended next steps:\n- " + actions.joined(separator: "\n- ")
        }

        let historyHint = messages.last(where: { $0.role == .assistant })?.body ?? capture.analysis.summary
        if !historyHint.isEmpty {
            return "\(historyHint)\n\nBased on your question, I would next review the capture details, OCR text, and preset metadata for more context."
        }

        return "I can answer follow-up questions about this capture using its screenshot context, OCR text, preset metadata, and current analysis."
    }
}

private enum OpenAIAnalysisClient {
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
        let image_url: String?

        init(type: String, text: String? = nil, imageURL: String? = nil) {
            self.type = type
            self.text = text
            self.image_url = imageURL
        }
    }

    private struct ResponseEnvelope: Decodable {
        let output: [OutputItem]?
    }

    private struct OutputItem: Decodable {
        let type: String
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

    private struct ModelPayload: Decodable {
        let summary: String
        let tags: [String]
        let recommended_actions: [String]
        let issue_title: String?
        let issue_body: String?
        let severity: String?
    }

    private struct ChatPayload: Decodable {
        let answer: String
    }

    static func analyze(capture: CaptureRecord, configuration: OpenAIAnalysisConfiguration) async throws -> CaptureAnalysisResult {
        let imageDataURL = try imageDataURL(for: capture.imageURL)
        let prompt = promptForCapture(capture)
        let body = RequestBody(
            model: configuration.model,
            input: [
                RequestMessage(
                    role: "user",
                    content: [
                        RequestContent(type: "input_text", text: prompt),
                        RequestContent(type: "input_image", imageURL: imageDataURL)
                    ]
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
        guard let outputText = extractedOutputText(from: envelope), !outputText.isEmpty else {
            throw CaptureAnalysisError.emptyResponse
        }

        let payload = try JSONDecoder().decode(ModelPayload.self, from: Data(outputText.utf8))
        return CaptureAnalysisResult(
            status: .complete,
            presetID: capture.presetID,
            updatedAt: Date(),
            summary: payload.summary,
            tags: payload.tags,
            recommendedActions: payload.recommended_actions,
            issueTitle: payload.issue_title ?? CaptureAnalysisService.suggestedIssueTitle(for: capture, summary: payload.summary),
            issueBody: payload.issue_body ?? CaptureAnalysisService.suggestedIssueBody(for: capture, summary: payload.summary),
            severity: payload.severity ?? CaptureAnalysisService.severityForCapture(capture),
            rawJSON: outputText
        )
    }

    static func testConnection(configuration: OpenAIAnalysisConfiguration) async throws {
        let body = RequestBody(
            model: configuration.model,
            input: [
                RequestMessage(
                    role: "user",
                    content: [
                        RequestContent(type: "input_text", text: "Return a JSON object with a summary field equal to 'ok'.")
                    ]
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
        if !(200..<300).contains(http.statusCode) {
            throw apiError(from: data) ?? CaptureAnalysisError.apiError("OpenAI request failed with status \(http.statusCode).")
        }
    }

    static func chat(capture: CaptureRecord, messages: [CaptureChatMessage], question: String, configuration: OpenAIAnalysisConfiguration) async throws -> String {
        let historyText = messages.suffix(8).map { "\($0.role.rawValue.capitalized): \($0.body)" }.joined(separator: "\n\n")
        let prompt = """
        You are continuing a conversation about a QuickSnap capture. Answer in plain text only.

        Capture preset: \(capture.presetDefinition.name)
        Source app: \(capture.sourceApp)
        Window title: \(capture.windowTitle)
        URL: \(capture.primaryURL ?? "Unavailable")
        OCR text:
        \(capture.ocrText)

        Existing analysis summary:
        \(capture.analysis.summary)

        Existing analysis tags:
        \(capture.analysis.tags.joined(separator: ", "))

        Existing issue draft:
        \(capture.analysis.issueBody)

        Prior chat:
        \(historyText)

        User question:
        \(question)
        """

        let body = RequestBody(
            model: configuration.model,
            input: [
                RequestMessage(
                    role: "user",
                    content: [
                        RequestContent(type: "input_text", text: prompt)
                    ]
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
        guard let outputText = extractedOutputText(from: envelope), !outputText.isEmpty else {
            throw CaptureAnalysisError.emptyResponse
        }

        if let payload = try? JSONDecoder().decode(ChatPayload.self, from: Data(outputText.utf8)) {
            return payload.answer
        }
        return outputText
    }

    static func generateMarkdown(prompt: String, imageURL: URL, configuration: OpenAIAnalysisConfiguration) async throws -> String {
        let imageDataURL = try imageDataURL(for: imageURL)
        let body = RequestBody(
            model: configuration.model,
            input: [
                RequestMessage(
                    role: "user",
                    content: [
                        RequestContent(type: "input_text", text: prompt),
                        RequestContent(type: "input_image", imageURL: imageDataURL)
                    ]
                )
            ],
            text: .init(format: .init(type: "text"))
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
        guard let outputText = extractedOutputText(from: envelope), !outputText.isEmpty else {
            throw CaptureAnalysisError.emptyResponse
        }
        return outputText
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

    private static func imageDataURL(for imageURL: URL) throws -> String {
        let data = try Data(contentsOf: imageURL)
        guard !data.isEmpty else {
            throw CaptureAnalysisError.invalidImageData
        }
        return "data:image/png;base64,\(data.base64EncodedString())"
    }

    private static func promptForCapture(_ capture: CaptureRecord) -> String {
        let urlLine = capture.primaryURL.map { "URL: \($0)" } ?? "URL: unavailable"
        let issueHint = capture.normalizedPresetID == "bug_report"
            ? "This is a bug-report workflow. Prefer a concrete, actionable issue_title and an issue_body ready for GitHub. If the screenshot suggests a broken or incorrect state, say so plainly."
            : "Issue fields may be empty strings when not relevant."

        return """
        You are analyzing a QuickSnap capture. Return only a JSON object with these keys:
        summary (string),
        tags (array of strings),
        recommended_actions (array of strings),
        issue_title (string),
        issue_body (string),
        severity (string).

        Preset: \(capture.presetDefinition.name)
        Source App: \(capture.sourceApp)
        Window Title: \(capture.windowTitle)
        \(urlLine)
        Page Title: \(capture.presetPayload.pageTitle)
        Browser: \(capture.presetPayload.browser)
        Viewport: \(capture.presetPayload.viewport)
        User Agent: \(capture.presetPayload.userAgent)
        Referrer: \(capture.presetPayload.referrerURL)
        Visible Errors: \(capture.presetPayload.visibleErrors.joined(separator: " | "))
        Failed Resources: \(capture.presetPayload.failedResources.joined(separator: " | "))
        Script Sources: \(capture.presetPayload.scriptSources.joined(separator: " | "))
        Console Summary: \(capture.presetPayload.consoleSummary)
        Error Message: \(capture.presetPayload.errorMessage)
        Stack Trace:
        \(capture.presetPayload.stackTrace)
        OCR Text:
        \(capture.ocrText)

        Preset Payload:
        \(String(describing: capture.presetPayload))

        Keep tags concise. Recommended actions should be short imperative phrases.
        For bug reports, bias toward:
        - a specific title that names the broken page, feature, or state
        - an issue body with sections for summary, observed behavior, reproduction context, and evidence
        - severity that matches the visible impact and error signals
        - a full replacement of any previous analysis rather than an appended update
        \(issueHint)
        """
    }
}
