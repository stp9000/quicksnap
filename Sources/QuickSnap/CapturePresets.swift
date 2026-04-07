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
    var generatedMarkdown: String = ""
    var clippedMarkdownContent: String = ""
    var markdownClipStatus: String = ""
    var markdownClipExcerpt: String = ""
    var markdownFilePath: String = ""
    var preferredImageName: String = ""
    var researchSummary: String = ""
    var sourceURL: String = ""
    var tableColumns: [String] = []
    var tableRows: [[String]] = []
    var customFields: [String: String] = [:]

    var primaryURL: String? {
        let candidates = [canonicalURL, urlString, sourceURL]
        return candidates.first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
    }
}

struct CustomCapturePresetDefinition: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var fieldNames: [String]
    var exportTemplate: String
}

struct CapturePresetDefinition: Identifiable, Hashable {
    enum ExportMode: String, Hashable {
        case markdown
        case issueDraft
        case githubIssueURL
    }

    let id: String
    let name: String
    let description: String
    let expectedFields: [String]
    let exportModes: [ExportMode]
    let supportsAIEnrichment: Bool
    let isCustom: Bool
    let customDefinition: CustomCapturePresetDefinition?

    static let general = CapturePresetDefinition(
        id: "general",
        name: "General",
        description: "Default structured screenshot capture.",
        expectedFields: [],
        exportModes: [.markdown],
        supportsAIEnrichment: true,
        isCustom: false,
        customDefinition: nil
    )

    static let uiIssue = CapturePresetDefinition(
        id: "bug_report",
        name: "Bug Report",
        description: "Capture a bug report with reproduction context.",
        expectedFields: ["URL", "Browser", "Viewport", "Console Summary"],
        exportModes: [.markdown, .issueDraft, .githubIssueURL],
        supportsAIEnrichment: true,
        isCustom: false,
        customDefinition: nil
    )

    static let markdown = CapturePresetDefinition(
        id: "markdown",
        name: "Markdown",
        description: "Capture a web page into a reusable Markdown document.",
        expectedFields: ["URL", "Page Title", "Clip Status"],
        exportModes: [.markdown],
        supportsAIEnrichment: true,
        isCustom: false,
        customDefinition: nil
    )

    static let builtin: [CapturePresetDefinition] = [
        .general,
        .markdown,
        .uiIssue
    ]

    static func from(custom definition: CustomCapturePresetDefinition) -> CapturePresetDefinition {
        CapturePresetDefinition(
            id: definition.id,
            name: definition.name,
            description: "Custom preset",
            expectedFields: definition.fieldNames,
            exportModes: [.markdown],
            supportsAIEnrichment: false,
            isCustom: true,
            customDefinition: definition
        )
    }
}
