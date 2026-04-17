import Foundation

struct CapturePresetPayload: Codable, Hashable {
    var urlString: String = ""
    var canonicalURL: String = ""
    var browser: String = ""
    var viewport: String = ""
    var userAgent: String = ""
    var referrerURL: String = ""
    var scriptSources: [String] = []
    var failedResources: [String] = []
    var visibleErrors: [String] = []
    var consoleSummary: String = ""
    var errorMessage: String = ""
    var stackTrace: String = ""
    var pageTitle: String = ""
    var clippedMarkdownContent: String = ""
    var markdownClipStatus: String = ""
    var markdownExtractionEngine: String = ""
    var markdownExtractionError: String = ""
    var markdownClipExcerpt: String = ""
    var markdownFilePath: String = ""
    var markdownAuthor: String = ""
    var markdownPublishedDate: String = ""
    var wikiEntities: [String] = []
    var wikiConcepts: [String] = []
    var wikiIngestStatus: String = ""
    var wikiPagesAffected: [String] = []
    var wikiIngestError: String = ""
    var wikiCapturePagePath: String = ""
    var preferredImageName: String = ""
    var researchSummary: String = ""
    var sourceURL: String = ""
    var tableColumns: [String] = []
    var tableRows: [[String]] = []

    var primaryURL: String? {
        let candidates = [canonicalURL, urlString, sourceURL]
        return candidates.first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
    }
}

struct CapturePresetDefinition: Identifiable, Hashable {
    enum ExportMode: String, Hashable {
        case markdown
        case githubIssueURL
    }

    let id: String
    let name: String
    let description: String
    let expectedFields: [String]
    let exportModes: [ExportMode]
    let supportsAIEnrichment: Bool

    static let general = CapturePresetDefinition(
        id: "general",
        name: "General",
        description: "Default structured screenshot capture.",
        expectedFields: [],
        exportModes: [.markdown],
        supportsAIEnrichment: true
    )

    static let uiIssue = CapturePresetDefinition(
        id: "bug_report",
        name: "Bug Report",
        description: "Capture a bug report with reproduction context.",
        expectedFields: ["URL", "Browser", "Viewport", "Console Summary"],
        exportModes: [.markdown, .githubIssueURL],
        supportsAIEnrichment: true
    )

    static let markdown = CapturePresetDefinition(
        id: "markdown",
        name: "Markdown",
        description: "Capture a web page into a reusable Markdown document.",
        expectedFields: ["URL", "Page Title", "Clip Status"],
        exportModes: [.markdown],
        supportsAIEnrichment: true
    )

    static let builtin: [CapturePresetDefinition] = [
        .general,
        .markdown,
        .uiIssue
    ]
}
