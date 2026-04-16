import Foundation

enum WikiPageKind: String, Codable, CaseIterable {
    case entity
    case concept
    case capture

    var directoryName: String {
        switch self {
        case .entity:
            return "entities"
        case .concept:
            return "concepts"
        case .capture:
            return "captures"
        }
    }

    var displayName: String {
        switch self {
        case .entity:
            return "Entities"
        case .concept:
            return "Concepts"
        case .capture:
            return "Captures"
        }
    }
}

struct WikiPageRecord {
    let kind: WikiPageKind
    let title: String
    let relativePath: String
    let summary: String
    let content: String
    let url: URL
}

final class WikiRepository {
    let markdownRootDirectory: URL
    let rootDirectory: URL

    var schemaURL: URL { rootDirectory.appendingPathComponent("wiki-schema.md") }
    var indexURL: URL { rootDirectory.appendingPathComponent("index.md") }
    var logURL: URL { rootDirectory.appendingPathComponent("log.md") }

    init(markdownRootDirectory: URL) {
        self.markdownRootDirectory = markdownRootDirectory
        self.rootDirectory = markdownRootDirectory.appendingPathComponent("wiki", isDirectory: true)
    }

    func ensureStructure() throws {
        try FileManager.default.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
        for kind in WikiPageKind.allCases {
            try FileManager.default.createDirectory(at: directoryURL(for: kind), withIntermediateDirectories: true)
        }

        if !FileManager.default.fileExists(atPath: schemaURL.path) {
            try Self.defaultSchema.write(to: schemaURL, atomically: true, encoding: .utf8)
        }
        if !FileManager.default.fileExists(atPath: indexURL.path) {
            try initialIndexDocument().write(to: indexURL, atomically: true, encoding: .utf8)
        }
        if !FileManager.default.fileExists(atPath: logURL.path) {
            try initialLogDocument().write(to: logURL, atomically: true, encoding: .utf8)
        }
    }

    func loadSchema() throws -> String {
        try ensureStructure()
        return try String(contentsOf: schemaURL, encoding: .utf8)
    }

    func relativePath(for title: String, kind: WikiPageKind) -> String {
        switch kind {
        case .capture:
            return "captures/\(Self.slug(from: title)).md"
        case .entity:
            return "entities/\(Self.slug(from: title)).md"
        case .concept:
            return "concepts/\(Self.slug(from: title)).md"
        }
    }

    func relativePathForCapture(id: String) -> String {
        "captures/\(Self.slug(from: id)).md"
    }

    func pageURL(for relativePath: String) -> URL {
        rootDirectory.appendingPathComponent(relativePath)
    }

    func loadPage(relativePath: String) -> String? {
        let url = pageURL(for: relativePath)
        return try? String(contentsOf: url, encoding: .utf8)
    }

    func loadPage(title: String, kind: WikiPageKind) -> String? {
        loadPage(relativePath: relativePath(for: title, kind: kind))
    }

    func writePage(relativePath: String, content: String) throws {
        try ensureStructure()
        let url = pageURL(for: relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    func appendLogEntry(action: String, capture: CaptureRecord, affectedPaths: [String]) throws {
        try ensureStructure()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let timestamp = formatter.string(from: Date())
        let title = capture.presetPayload.pageTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? capture.displayTitle
            : capture.presetPayload.pageTitle
        var lines: [String] = []
        lines.append("## [\(timestamp)] \(action)")
        lines.append("")
        lines.append("- Capture: `\(capture.id)`")
        lines.append("- Title: \(title)")
        if let primaryURL = capture.primaryURL, !primaryURL.isEmpty {
            lines.append("- URL: \(primaryURL)")
        }
        if !affectedPaths.isEmpty {
            lines.append("- Affected Pages:")
            lines.append(contentsOf: affectedPaths.map { "  - \($0)" })
        }
        lines.append("")

        let existing = (try? String(contentsOf: logURL, encoding: .utf8)) ?? initialLogDocument()
        let updated = existing.trimmingCharacters(in: .whitespacesAndNewlines) + "\n\n" + lines.joined(separator: "\n")
        try updated.write(to: logURL, atomically: true, encoding: .utf8)
    }

    @discardableResult
    func refreshIndex() throws -> String {
        try ensureStructure()
        let pageGroups = try Dictionary(grouping: pageRecords(), by: \.kind)
        var lines: [String] = [
            "# QuickSnap Wiki Index",
            "",
            "Auto-generated catalog of wiki pages managed by QuickSnap.",
            ""
        ]

        for kind in [WikiPageKind.entity, .concept, .capture] {
            lines.append("## \(kind.displayName)")
            lines.append("")
            let records = (pageGroups[kind] ?? []).sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            if records.isEmpty {
                lines.append("_No pages yet._")
                lines.append("")
                continue
            }

            for record in records {
                let summary = record.summary.isEmpty ? "No summary yet." : record.summary
                lines.append("- [\(record.title)](\(record.relativePath)) - \(summary)")
            }
            lines.append("")
        }

        let text = lines.joined(separator: "\n")
        try text.write(to: indexURL, atomically: true, encoding: .utf8)
        return text
    }

    func pageRecords() throws -> [WikiPageRecord] {
        try ensureStructure()
        var records: [WikiPageRecord] = []
        for kind in WikiPageKind.allCases {
            let directory = directoryURL(for: kind)
            let urls = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
            for url in urls where url.pathExtension.lowercased() == "md" {
                guard let content = try? String(contentsOf: url, encoding: .utf8) else { continue }
                let relativePath = url.path.replacingOccurrences(of: rootDirectory.path + "/", with: "")
                records.append(
                    WikiPageRecord(
                        kind: kind,
                        title: Self.title(from: content, fallback: url.deletingPathExtension().lastPathComponent),
                        relativePath: relativePath,
                        summary: Self.summary(from: content),
                        content: content,
                        url: url
                    )
                )
            }
        }
        return records
    }

    private func directoryURL(for kind: WikiPageKind) -> URL {
        rootDirectory.appendingPathComponent(kind.directoryName, isDirectory: true)
    }

    private func initialIndexDocument() -> String {
        [
            "# QuickSnap Wiki Index",
            "",
            "Auto-generated catalog of wiki pages managed by QuickSnap.",
            "",
            "## Entities",
            "",
            "_No pages yet._",
            "",
            "## Concepts",
            "",
            "_No pages yet._",
            "",
            "## Captures",
            "",
            "_No pages yet._"
        ].joined(separator: "\n")
    }

    private func initialLogDocument() -> String {
        [
            "# QuickSnap Wiki Log",
            "",
            "Chronological record of wiki ingest operations."
        ].joined(separator: "\n")
    }

    private static func title(from markdown: String, fallback: String) -> String {
        for line in markdown.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("# ") {
                return String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return fallback.replacingOccurrences(of: "-", with: " ")
    }

    private static func summary(from markdown: String) -> String {
        for line in markdown.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if trimmed.hasPrefix("#") || trimmed == "---" || trimmed.hasPrefix("title:") || trimmed.hasPrefix("capture_id:") {
                continue
            }
            return trimmed
        }
        return ""
    }

    static func slug(from value: String) -> String {
        let lowered = value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).lowercased()
        let scalars = lowered.unicodeScalars.map { scalar -> Character in
            if CharacterSet.alphanumerics.contains(scalar) {
                return Character(String(scalar))
            }
            return "-"
        }
        let raw = String(scalars)
        let collapsed = raw.replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
        let trimmed = collapsed.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return trimmed.isEmpty ? "untitled" : trimmed
    }

    static let defaultSchema = """
# QuickSnap Wiki Schema

This wiki is maintained from QuickSnap captures.

Authoring rules:
- Prefer concise, factual Markdown.
- Preserve existing useful information when updating pages.
- Link back to capture pages when citing a source capture.
- Entity pages are for named tools, products, people, companies, APIs, libraries, and services.
- Concept pages are for ideas, techniques, patterns, workflows, and comparisons.
- Capture pages summarize one capture and list why it matters.
- When uncertain, be explicit about uncertainty instead of inventing claims.
"""
}
