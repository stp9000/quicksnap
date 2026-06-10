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
    var markdownSiteName: String = ""
    var markdownWordCount: Int = 0
    var sourceHTMLCharacterCount: Int = 0
    var filteredHTMLCharacterCount: Int = 0
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

    init() {}

    fileprivate enum CodingKeys: String, CodingKey {
        case urlString
        case canonicalURL
        case browser
        case viewport
        case userAgent
        case referrerURL
        case scriptSources
        case failedResources
        case visibleErrors
        case consoleSummary
        case errorMessage
        case stackTrace
        case pageTitle
        case clippedMarkdownContent
        case markdownClipStatus
        case markdownExtractionEngine
        case markdownExtractionError
        case markdownClipExcerpt
        case markdownFilePath
        case markdownAuthor
        case markdownPublishedDate
        case markdownSiteName
        case markdownWordCount
        case sourceHTMLCharacterCount
        case filteredHTMLCharacterCount
        case wikiEntities
        case wikiConcepts
        case wikiIngestStatus
        case wikiPagesAffected
        case wikiIngestError
        case wikiCapturePagePath
        case preferredImageName
        case researchSummary
        case sourceURL
        case tableColumns
        case tableRows
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        urlString = container.decodeString(forKey: .urlString)
        canonicalURL = container.decodeString(forKey: .canonicalURL)
        browser = container.decodeString(forKey: .browser)
        viewport = container.decodeString(forKey: .viewport)
        userAgent = container.decodeString(forKey: .userAgent)
        referrerURL = container.decodeString(forKey: .referrerURL)
        scriptSources = container.decodeStringArray(forKey: .scriptSources)
        failedResources = container.decodeStringArray(forKey: .failedResources)
        visibleErrors = container.decodeStringArray(forKey: .visibleErrors)
        consoleSummary = container.decodeString(forKey: .consoleSummary)
        errorMessage = container.decodeString(forKey: .errorMessage)
        stackTrace = container.decodeString(forKey: .stackTrace)
        pageTitle = container.decodeString(forKey: .pageTitle)
        clippedMarkdownContent = container.decodeString(forKey: .clippedMarkdownContent)
        markdownClipStatus = container.decodeString(forKey: .markdownClipStatus)
        markdownExtractionEngine = container.decodeString(forKey: .markdownExtractionEngine)
        markdownExtractionError = container.decodeString(forKey: .markdownExtractionError)
        markdownClipExcerpt = container.decodeString(forKey: .markdownClipExcerpt)
        markdownFilePath = container.decodeString(forKey: .markdownFilePath)
        markdownAuthor = container.decodeString(forKey: .markdownAuthor)
        markdownPublishedDate = container.decodeString(forKey: .markdownPublishedDate)
        markdownSiteName = container.decodeString(forKey: .markdownSiteName)
        markdownWordCount = container.decodeInt(forKey: .markdownWordCount)
        sourceHTMLCharacterCount = container.decodeInt(forKey: .sourceHTMLCharacterCount)
        filteredHTMLCharacterCount = container.decodeInt(forKey: .filteredHTMLCharacterCount)
        wikiEntities = container.decodeStringArray(forKey: .wikiEntities)
        wikiConcepts = container.decodeStringArray(forKey: .wikiConcepts)
        wikiIngestStatus = container.decodeString(forKey: .wikiIngestStatus)
        wikiPagesAffected = container.decodeStringArray(forKey: .wikiPagesAffected)
        wikiIngestError = container.decodeString(forKey: .wikiIngestError)
        wikiCapturePagePath = container.decodeString(forKey: .wikiCapturePagePath)
        preferredImageName = container.decodeString(forKey: .preferredImageName)
        researchSummary = container.decodeString(forKey: .researchSummary)
        sourceURL = container.decodeString(forKey: .sourceURL)
        tableColumns = container.decodeStringArray(forKey: .tableColumns)
        tableRows = (try? container.decode([[String]].self, forKey: .tableRows)) ?? []
    }
}

private extension KeyedDecodingContainer where Key == CapturePresetPayload.CodingKeys {
    func decodeString(forKey key: Key) -> String {
        (try? decodeIfPresent(String.self, forKey: key)) ?? ""
    }

    func decodeStringArray(forKey key: Key) -> [String] {
        (try? decodeIfPresent([String].self, forKey: key)) ?? []
    }

    func decodeInt(forKey key: Key) -> Int {
        (try? decodeIfPresent(Int.self, forKey: key)) ?? 0
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
