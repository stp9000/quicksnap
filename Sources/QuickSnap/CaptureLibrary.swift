import AppKit
import CoreGraphics
import Foundation
import SQLite3
import Vision

enum CaptureSourceKind: String, Codable, CaseIterable {
    case fullScreen = "full_screen"
    case selection = "selection"
    case window = "window"
    case imported = "imported"

    var displayName: String {
        switch self {
        case .fullScreen:
            return "Full Screen"
        case .selection:
            return "Selection"
        case .window:
            return "Window"
        case .imported:
            return "Imported"
        }
    }
}

enum CaptureOCRStatus: String, Codable, CaseIterable {
    case pending
    case complete
    case unavailable

    var displayName: String {
        switch self {
        case .pending:
            return "OCR pending"
        case .complete:
            return "OCR indexed"
        case .unavailable:
            return "No OCR text"
        }
    }
}

struct CaptureRecord: Identifiable, Hashable {
    let id: String
    let displaySequence: Int
    let imagePath: String
    let createdAt: Date
    let sourceApp: String
    let windowTitle: String
    let urlString: String?
    let ocrText: String
    let tags: [String]
    let pixelWidth: Int
    let pixelHeight: Int
    let sourceKind: CaptureSourceKind
    let showsSelectionBorder: Bool
    let ocrStatus: CaptureOCRStatus
    let presetID: String
    let presetPayload: CapturePresetPayload
    let analysis: CaptureAnalysisResult
    let chatMessages: [CaptureChatMessage]

    var imageURL: URL {
        URL(fileURLWithPath: imagePath)
    }

    var sourceDisplayName: String {
        if !sourceApp.isEmpty {
            return sourceApp
        }
        return sourceKind.displayName
    }

    var displayIdentifier: String {
        String(format: "QS%05d", max(displaySequence, 0))
    }

    var sourceDisplayLabel: String {
        "\(sourceDisplayName) - \(displayIdentifier)"
    }

    var displayTitle: String {
        if !windowTitle.isEmpty {
            return windowTitle
        }
        if !sourceApp.isEmpty {
            return sourceApp
        }
        return sourceKind.displayName
    }

    var displaySubtitle: String {
        let presetName = presetDefinition.name
        if sourceApp.isEmpty {
            return "\(sourceKind.displayName) · \(presetName)"
        }
        return "\(sourceApp) · \(presetName)"
    }

    var searchSummary: String {
        let fallback = presetSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        if !fallback.isEmpty {
            return fallback
        }

        return windowTitle.isEmpty ? ocrStatus.displayName : windowTitle
    }

    var presetDefinition: CapturePresetDefinition {
        CapturePresetCatalog.definition(for: normalizedPresetID)
    }

    var normalizedPresetID: String {
        switch presetID {
        case "ui_issue":
            return "bug_report"
        default:
            return presetID
        }
    }

    var presetSummary: String {
        switch normalizedPresetID {
        case "bug_report":
            return presetPayload.consoleSummary
        default:
            return ""
        }
    }

    var dimensionsText: String {
        "\(pixelWidth) x \(pixelHeight)"
    }

    var exportBaseName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return "QuickSnap-\(formatter.string(from: createdAt))"
    }

    var markdownSnippet: String {
        let altText = markdownTitle.isEmpty ? displayTitle : markdownTitle
        return "![\(altText)](\(imageURL.absoluteString))"
    }

    var markdownTitle: String {
        displayTitle
    }

    var markdownDocument: String {
        if let customDefinition = presetDefinition.customDefinition {
            return renderCustomMarkdown(using: customDefinition)
        }

        switch normalizedPresetID {
        case "bug_report":
            return issueDraftMarkdown
        default:
            return genericMarkdown
        }
    }

    var issueDraftTitle: String {
        switch normalizedPresetID {
        case "bug_report":
            if !presetPayload.consoleSummary.isEmpty {
                return "Bug report: \(presetPayload.consoleSummary)"
            }
            return "Bug report for \(displayTitle)"
        default:
            return "QuickSnap capture: \(displayTitle)"
        }
    }

    var issueDraftBody: String {
        var lines: [String] = [
            "## Summary",
            searchSummary,
            "",
            "## Capture",
            markdownSnippet,
            "",
            "- Preset: \(presetDefinition.name)",
            "- Capture ID: `\(sourceDisplayLabel)`",
            "- Source: \(displaySubtitle)",
            "- Captured: \(Self.markdownTimestampFormatter.string(from: createdAt))",
            "- Dimensions: \(dimensionsText)"
        ]

        if let primaryURL = primaryURL {
            lines.append("- URL: \(primaryURL)")
        }

        switch normalizedPresetID {
        case "bug_report":
            if !presetPayload.browser.isEmpty {
                lines.append("- Browser: \(presetPayload.browser)")
            }
            if !presetPayload.viewport.isEmpty {
                lines.append("- Viewport: \(presetPayload.viewport)")
            }
            lines.append("- File: `\(imagePath)`")
            if !tags.isEmpty {
                lines.append("- Tags: \(tags.joined(separator: ", "))")
            }
            if !presetPayload.consoleSummary.isEmpty {
                lines.append("")
                lines.append("## Console Summary")
                lines.append(presetPayload.consoleSummary)
            }
            if !presetPayload.errorMessage.isEmpty {
                lines.append("")
                lines.append("## Error Message")
                lines.append(presetPayload.errorMessage)
            }
            if !presetPayload.stackTrace.isEmpty {
                lines.append("")
                lines.append("## Stack Trace")
                lines.append("```text")
                lines.append(presetPayload.stackTrace)
                lines.append("```")
            }
        default:
            break
        }

        return lines.joined(separator: "\n")
    }

    var jsonExportText: String? {
        return nil
    }

    var csvExportText: String? {
        nil
    }

    var fileExists: Bool {
        FileManager.default.fileExists(atPath: imagePath)
    }

    var primaryURL: String? {
        presetPayload.primaryURL ?? urlString
    }

    var hasAnalysis: Bool {
        analysis.status == .complete && analysis.hasContent
    }

    var isAnalysisStale: Bool {
        !analysis.presetID.isEmpty && analysis.presetID != presetID
    }

    func previewText(for kind: SendPreviewKind) -> String? {
        switch kind {
        case .filePath:
            return imagePath
        case .markdownSnippet:
            return markdownSnippet
        case .markdownDocument:
            return markdownDocument
        case .issueDraft:
            guard presetDefinition.exportModes.contains(.issueDraft) else { return nil }
            return "# \(issueDraftTitle)\n\n\(issueDraftBody)"
        case .githubIssueURL:
            return githubIssueURLString
        }
    }

    var githubIssueBody: String {
        issueDraftBody
    }

    func githubIssueURL(owner: String, repo: String, labels: String = "") -> URL? {
        let trimmedOwner = owner.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedRepo = repo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedOwner.isEmpty, !trimmedRepo.isEmpty else { return nil }

        var components = URLComponents(string: "https://github.com/\(trimmedOwner)/\(trimmedRepo)/issues/new")
        var queryItems = [
            URLQueryItem(name: "title", value: issueDraftTitle),
            URLQueryItem(name: "body", value: githubIssueBody)
        ]
        let trimmedLabels = labels.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedLabels.isEmpty {
            queryItems.append(URLQueryItem(name: "labels", value: trimmedLabels))
        }
        components?.queryItems = queryItems
        return components?.url
    }

    var githubIssueURLString: String? {
        nil
    }

    static let markdownTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private var genericMarkdown: String {
        var lines: [String] = [
            "# \(displayTitle)",
            "",
            markdownSnippet,
            "",
            "- Preset: \(presetDefinition.name)",
            "- Capture ID: `\(sourceDisplayLabel)`",
            "- Source: \(displaySubtitle)",
            "- Captured: \(Self.markdownTimestampFormatter.string(from: createdAt))",
            "- Dimensions: \(dimensionsText)",
            "- OCR Status: \(ocrStatus.displayName)",
            "- File: `\(imagePath)`"
        ]

        if !tags.isEmpty {
            lines.append("- Tags: \(tags.joined(separator: ", "))")
        }
        if let primaryURL {
            lines.append("- URL: \(primaryURL)")
        }
        if !ocrText.isEmpty {
            lines.append("")
            lines.append("## OCR Text")
            lines.append("")
            lines.append("```text")
            lines.append(ocrText)
            lines.append("```")
        }
        return lines.joined(separator: "\n")
    }

    private var documentationMarkdown: String {
        let title = presetPayload.pageTitle.isEmpty ? displayTitle : presetPayload.pageTitle
        let imageName = presetPayload.preferredImageName.isEmpty ? exportBaseName : presetPayload.preferredImageName
        let body = presetPayload.generatedMarkdown.isEmpty ? "This capture is ready for documentation workflows." : presetPayload.generatedMarkdown
        return [
            "## \(title)",
            "",
            body,
            "",
            markdownSnippet,
            "",
            "- Suggested image name: `\(imageName)`",
            primaryURL.map { "- URL: \($0)" },
            !ocrText.isEmpty ? "" : nil,
            !ocrText.isEmpty ? "### OCR Text" : nil,
            !ocrText.isEmpty ? ocrText : nil
        ].compactMap { $0 }.joined(separator: "\n")
    }

    private var issueDraftMarkdown: String {
        [
            "# \(issueDraftTitle)",
            "",
            issueDraftBody
        ].joined(separator: "\n")
    }

    private func renderCustomMarkdown(using definition: CustomCapturePresetDefinition) -> String {
        var text = definition.exportTemplate
        let replacements: [String: String] = [
            "capture_id": id,
            "title": displayTitle,
            "image_markdown": markdownSnippet,
            "source": displaySubtitle,
            "captured_at": Self.markdownTimestampFormatter.string(from: createdAt),
            "dimensions": dimensionsText,
            "ocr_text": ocrText,
            "tags": tags.joined(separator: ", ")
        ].merging(presetPayload.customFields) { _, new in new }

        for (key, value) in replacements {
            text = text.replacingOccurrences(of: "{{\(key)}}", with: value)
        }
        return text
    }

}

struct CaptureDraft {
    let id: String
    let displaySequence: Int
    let createdAt: Date
    let sourceApp: String
    let windowTitle: String
    let urlString: String?
    let pixelWidth: Int
    let pixelHeight: Int
    let sourceKind: CaptureSourceKind
    let showsSelectionBorder: Bool
    let image: NSImage
    let tags: [String]
    let ocrStatus: CaptureOCRStatus
    let presetID: String
    let presetPayload: CapturePresetPayload
}

struct FrontmostCaptureContext {
    let sourceApp: String
    let bundleIdentifier: String?
    let windowTitle: String
    let windowID: CGWindowID?
}

struct BrowserDebugMetadata {
    let pageTitle: String
    let viewport: String
}

struct WindowCaptureOption: Identifiable, Hashable {
    let id: CGWindowID
    let sourceApp: String
    let windowTitle: String
    let bundleIdentifier: String?
    let width: Int
    let height: Int

    var displayTitle: String {
        sourceApp.isEmpty ? "Window" : sourceApp
    }

    var displaySubtitle: String {
        let title = windowTitle.isEmpty ? "Untitled Window" : windowTitle
        return "\(title) · \(width)x\(height)"
    }

    var captureContext: FrontmostCaptureContext {
        FrontmostCaptureContext(
            sourceApp: sourceApp,
            bundleIdentifier: bundleIdentifier,
            windowTitle: windowTitle,
            windowID: id
        )
    }
}

enum CaptureRepositoryError: Error {
    case databaseOpenFailed
    case prepareFailed(String)
    case executeFailed(String)
    case imageEncodingFailed
}

final class CaptureRepository {
    let rootDirectory: URL
    let captureDirectory: URL
    let databaseURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(rootDirectory: URL? = nil) throws {
        let baseDirectory = rootDirectory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("QuickSnap", isDirectory: true)
        self.rootDirectory = baseDirectory
        self.captureDirectory = baseDirectory.appendingPathComponent("Captures", isDirectory: true)
        self.databaseURL = baseDirectory.appendingPathComponent("captures.sqlite3")

        try FileManager.default.createDirectory(at: captureDirectory, withIntermediateDirectories: true)
        try initializeDatabase()
    }

    func createCapture(from draft: CaptureDraft) throws -> CaptureRecord {
        let displaySequence = draft.displaySequence > 0 ? draft.displaySequence : (try nextDisplaySequence())
        let destinationURL = captureDirectory.appendingPathComponent("\(draft.id).png")
        guard let pngData = draft.image.pngData else {
            throw CaptureRepositoryError.imageEncodingFailed
        }

        try pngData.write(to: destinationURL, options: .atomic)

        let record = CaptureRecord(
            id: draft.id,
            displaySequence: displaySequence,
            imagePath: destinationURL.path,
            createdAt: draft.createdAt,
            sourceApp: draft.sourceApp,
            windowTitle: draft.windowTitle,
            urlString: draft.urlString ?? draft.presetPayload.primaryURL,
            ocrText: "",
            tags: draft.tags,
            pixelWidth: draft.pixelWidth,
            pixelHeight: draft.pixelHeight,
            sourceKind: draft.sourceKind,
            showsSelectionBorder: draft.showsSelectionBorder,
            ocrStatus: draft.ocrStatus,
            presetID: draft.presetID,
            presetPayload: draft.presetPayload,
            analysis: CaptureAnalysisResult(),
            chatMessages: []
        )

        try withDatabase { db in
            let sql = """
            INSERT OR REPLACE INTO captures
            (id, display_sequence, image_path, created_at, source_app, window_title, url_string, ocr_text, tags, pixel_width, pixel_height, source_kind, shows_selection_border, ocr_status, preset_id, payload_json, analysis_status, analysis_preset_id, analysis_updated_at, analysis_summary, analysis_tags, analysis_recommended_actions, analysis_issue_title, analysis_issue_body, analysis_severity, analysis_raw_json)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw CaptureRepositoryError.prepareFailed(lastErrorMessage(db))
            }
            defer { sqlite3_finalize(statement) }

            bindText(record.id, to: 1, in: statement)
            sqlite3_bind_int(statement, 2, Int32(record.displaySequence))
            bindText(record.imagePath, to: 3, in: statement)
            bindText(Self.iso8601Formatter.string(from: record.createdAt), to: 4, in: statement)
            bindText(record.sourceApp, to: 5, in: statement)
            bindText(record.windowTitle, to: 6, in: statement)
            bindOptionalText(record.urlString, to: 7, in: statement)
            bindText(record.ocrText, to: 8, in: statement)
            bindText(record.tags.joined(separator: "\n"), to: 9, in: statement)
            sqlite3_bind_int(statement, 10, Int32(record.pixelWidth))
            sqlite3_bind_int(statement, 11, Int32(record.pixelHeight))
            bindText(record.sourceKind.rawValue, to: 12, in: statement)
            sqlite3_bind_int(statement, 13, record.showsSelectionBorder ? 1 : 0)
            bindText(record.ocrStatus.rawValue, to: 14, in: statement)
            bindText(record.normalizedPresetID, to: 15, in: statement)
            bindText(encodedPayloadString(for: record.presetPayload), to: 16, in: statement)
            bindText(record.analysis.status.rawValue, to: 17, in: statement)
            bindText(record.analysis.presetID, to: 18, in: statement)
            bindOptionalText(record.analysis.updatedAt.map(Self.iso8601Formatter.string(from:)), to: 19, in: statement)
            bindText(record.analysis.summary, to: 20, in: statement)
            bindText(record.analysis.tags.joined(separator: "\n"), to: 21, in: statement)
            bindText(record.analysis.recommendedActions.joined(separator: "\n"), to: 22, in: statement)
            bindText(record.analysis.issueTitle, to: 23, in: statement)
            bindText(record.analysis.issueBody, to: 24, in: statement)
            bindText(record.analysis.severity, to: 25, in: statement)
            bindText(record.analysis.rawJSON, to: 26, in: statement)

            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw CaptureRepositoryError.executeFailed(lastErrorMessage(db))
            }
        }

        return record
    }

    func listCaptures(matching query: String) throws -> [CaptureRecord] {
        try withDatabase { db in
            let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
            let sql: String
            if trimmedQuery.isEmpty {
                sql = """
                SELECT id, display_sequence, image_path, created_at, source_app, window_title, url_string, ocr_text, tags, pixel_width, pixel_height, source_kind, shows_selection_border, ocr_status, preset_id, payload_json, analysis_status, analysis_preset_id, analysis_updated_at, analysis_summary, analysis_tags, analysis_recommended_actions, analysis_issue_title, analysis_issue_body, analysis_severity, analysis_raw_json
                FROM captures
                ORDER BY datetime(created_at) DESC;
                """
            } else {
                sql = """
                SELECT id, display_sequence, image_path, created_at, source_app, window_title, url_string, ocr_text, tags, pixel_width, pixel_height, source_kind, shows_selection_border, ocr_status, preset_id, payload_json, analysis_status, analysis_preset_id, analysis_updated_at, analysis_summary, analysis_tags, analysis_recommended_actions, analysis_issue_title, analysis_issue_body, analysis_severity, analysis_raw_json
                FROM captures
                WHERE lower(id) LIKE lower(?)
                   OR lower(source_app) LIKE lower(?)
                   OR lower(window_title) LIKE lower(?)
                   OR lower(url_string) LIKE lower(?)
                   OR lower(ocr_text) LIKE lower(?)
                   OR lower(tags) LIKE lower(?)
                   OR lower(source_kind) LIKE lower(?)
                   OR lower(created_at) LIKE lower(?)
                   OR lower(preset_id) LIKE lower(?)
                   OR lower(payload_json) LIKE lower(?)
                ORDER BY datetime(created_at) DESC;
                """
            }

            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw CaptureRepositoryError.prepareFailed(lastErrorMessage(db))
            }
            defer { sqlite3_finalize(statement) }

            if !trimmedQuery.isEmpty {
                let likeQuery = "%\(trimmedQuery)%"
                for index in 1...10 {
                    bindText(likeQuery, to: Int32(index), in: statement)
                }
            }

            var records: [CaptureRecord] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                let payloadJSON = stringValue(at: 15, in: statement)
                records.append(
                    CaptureRecord(
                        id: stringValue(at: 0, in: statement),
                        displaySequence: Int(sqlite3_column_int(statement, 1)),
                        imagePath: stringValue(at: 2, in: statement),
                        createdAt: Self.iso8601Formatter.date(from: stringValue(at: 3, in: statement)) ?? Date(),
                        sourceApp: stringValue(at: 4, in: statement),
                        windowTitle: stringValue(at: 5, in: statement),
                        urlString: optionalStringValue(at: 6, in: statement),
                        ocrText: stringValue(at: 7, in: statement),
                        tags: stringValue(at: 8, in: statement).split(separator: "\n").map(String.init).filter { !$0.isEmpty },
                        pixelWidth: Int(sqlite3_column_int(statement, 9)),
                        pixelHeight: Int(sqlite3_column_int(statement, 10)),
                        sourceKind: CaptureSourceKind(rawValue: stringValue(at: 11, in: statement)) ?? .fullScreen,
                        showsSelectionBorder: sqlite3_column_int(statement, 12) != 0,
                        ocrStatus: CaptureOCRStatus(rawValue: stringValue(at: 13, in: statement)) ?? .pending,
                        presetID: stringValue(at: 14, in: statement).isEmpty ? "general" : stringValue(at: 14, in: statement),
                        presetPayload: decodedPayload(from: payloadJSON),
                        analysis: decodedAnalysis(
                            status: stringValue(at: 16, in: statement),
                            presetID: stringValue(at: 17, in: statement),
                            updatedAt: optionalStringValue(at: 18, in: statement),
                            summary: stringValue(at: 19, in: statement),
                            tags: stringValue(at: 20, in: statement),
                            recommendedActions: stringValue(at: 21, in: statement),
                            issueTitle: stringValue(at: 22, in: statement),
                            issueBody: stringValue(at: 23, in: statement),
                            severity: stringValue(at: 24, in: statement),
                            rawJSON: stringValue(at: 25, in: statement)
                        ),
                        chatMessages: (try? listChatMessages(for: stringValue(at: 0, in: statement))) ?? []
                    )
                )
            }

            return records
        }
    }

    func updateOCRResult(for captureID: String, ocrText: String, status: CaptureOCRStatus) throws {
        try withDatabase { db in
            let sql = "UPDATE captures SET ocr_text = ?, ocr_status = ? WHERE id = ?;"
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw CaptureRepositoryError.prepareFailed(lastErrorMessage(db))
            }
            defer { sqlite3_finalize(statement) }

            bindText(ocrText, to: 1, in: statement)
            bindText(status.rawValue, to: 2, in: statement)
            bindText(captureID, to: 3, in: statement)

            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw CaptureRepositoryError.executeFailed(lastErrorMessage(db))
            }
        }
    }

    func updateTags(for captureID: String, tags: [String]) throws {
        try withDatabase { db in
            let sql = "UPDATE captures SET tags = ? WHERE id = ?;"
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw CaptureRepositoryError.prepareFailed(lastErrorMessage(db))
            }
            defer { sqlite3_finalize(statement) }

            bindText(tags.joined(separator: "\n"), to: 1, in: statement)
            bindText(captureID, to: 2, in: statement)

            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw CaptureRepositoryError.executeFailed(lastErrorMessage(db))
            }
        }
    }

    func updatePreset(for captureID: String, presetID: String) throws {
        try withDatabase { db in
            let sql = "UPDATE captures SET preset_id = ? WHERE id = ?;"
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw CaptureRepositoryError.prepareFailed(lastErrorMessage(db))
            }
            defer { sqlite3_finalize(statement) }

            bindText(presetID, to: 1, in: statement)
            bindText(captureID, to: 2, in: statement)

            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw CaptureRepositoryError.executeFailed(lastErrorMessage(db))
            }
        }
    }

    func updatePresetPayload(for captureID: String, payload: CapturePresetPayload) throws {
        try withDatabase { db in
            let sql = "UPDATE captures SET payload_json = ?, url_string = ? WHERE id = ?;"
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw CaptureRepositoryError.prepareFailed(lastErrorMessage(db))
            }
            defer { sqlite3_finalize(statement) }

            bindText(encodedPayloadString(for: payload), to: 1, in: statement)
            bindOptionalText(payload.primaryURL, to: 2, in: statement)
            bindText(captureID, to: 3, in: statement)

            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw CaptureRepositoryError.executeFailed(lastErrorMessage(db))
            }
        }
    }

    func updateAnalysis(for captureID: String, analysis: CaptureAnalysisResult) throws {
        try withDatabase { db in
            let sql = """
            UPDATE captures
            SET analysis_status = ?, analysis_preset_id = ?, analysis_updated_at = ?, analysis_summary = ?, analysis_tags = ?, analysis_recommended_actions = ?, analysis_issue_title = ?, analysis_issue_body = ?, analysis_severity = ?, analysis_raw_json = ?
            WHERE id = ?;
            """
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw CaptureRepositoryError.prepareFailed(lastErrorMessage(db))
            }
            defer { sqlite3_finalize(statement) }

            bindText(analysis.status.rawValue, to: 1, in: statement)
            bindText(analysis.presetID, to: 2, in: statement)
            bindOptionalText(analysis.updatedAt.map(Self.iso8601Formatter.string(from:)), to: 3, in: statement)
            bindText(analysis.summary, to: 4, in: statement)
            bindText(analysis.tags.joined(separator: "\n"), to: 5, in: statement)
            bindText(analysis.recommendedActions.joined(separator: "\n"), to: 6, in: statement)
            bindText(analysis.issueTitle, to: 7, in: statement)
            bindText(analysis.issueBody, to: 8, in: statement)
            bindText(analysis.severity, to: 9, in: statement)
            bindText(analysis.rawJSON, to: 10, in: statement)
            bindText(captureID, to: 11, in: statement)

            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw CaptureRepositoryError.executeFailed(lastErrorMessage(db))
            }
        }
    }

    func listChatMessages(for captureID: String) throws -> [CaptureChatMessage] {
        try withDatabase { db in
            let sql = """
            SELECT id, capture_id, role, body, created_at
            FROM capture_chat_messages
            WHERE capture_id = ?
            ORDER BY datetime(created_at) ASC;
            """
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw CaptureRepositoryError.prepareFailed(lastErrorMessage(db))
            }
            defer { sqlite3_finalize(statement) }

            bindText(captureID, to: 1, in: statement)

            var messages: [CaptureChatMessage] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                messages.append(
                    CaptureChatMessage(
                        id: stringValue(at: 0, in: statement),
                        captureID: stringValue(at: 1, in: statement),
                        role: CaptureChatRole(rawValue: stringValue(at: 2, in: statement)) ?? .assistant,
                        body: stringValue(at: 3, in: statement),
                        createdAt: Self.iso8601Formatter.date(from: stringValue(at: 4, in: statement)) ?? Date()
                    )
                )
            }
            return messages
        }
    }

    func appendChatMessage(_ message: CaptureChatMessage) throws {
        try withDatabase { db in
            let sql = """
            INSERT INTO capture_chat_messages (id, capture_id, role, body, created_at)
            VALUES (?, ?, ?, ?, ?);
            """
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw CaptureRepositoryError.prepareFailed(lastErrorMessage(db))
            }
            defer { sqlite3_finalize(statement) }

            bindText(message.id, to: 1, in: statement)
            bindText(message.captureID, to: 2, in: statement)
            bindText(message.role.rawValue, to: 3, in: statement)
            bindText(message.body, to: 4, in: statement)
            bindText(Self.iso8601Formatter.string(from: message.createdAt), to: 5, in: statement)

            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw CaptureRepositoryError.executeFailed(lastErrorMessage(db))
            }
        }
    }

    private func initializeDatabase() throws {
        try withDatabase { db in
            let sql = """
            CREATE TABLE IF NOT EXISTS captures (
                id TEXT PRIMARY KEY,
                display_sequence INTEGER NOT NULL DEFAULT 0,
                image_path TEXT NOT NULL,
                created_at TEXT NOT NULL,
                source_app TEXT NOT NULL,
                window_title TEXT NOT NULL,
                url_string TEXT,
                ocr_text TEXT NOT NULL DEFAULT '',
                tags TEXT NOT NULL DEFAULT '',
                pixel_width INTEGER NOT NULL,
                pixel_height INTEGER NOT NULL,
                source_kind TEXT NOT NULL,
                shows_selection_border INTEGER NOT NULL DEFAULT 0,
                ocr_status TEXT NOT NULL DEFAULT 'pending',
                preset_id TEXT NOT NULL DEFAULT 'general',
                payload_json TEXT NOT NULL DEFAULT '{}',
                analysis_status TEXT NOT NULL DEFAULT 'idle',
                analysis_preset_id TEXT NOT NULL DEFAULT '',
                analysis_updated_at TEXT,
                analysis_summary TEXT NOT NULL DEFAULT '',
                analysis_tags TEXT NOT NULL DEFAULT '',
                analysis_recommended_actions TEXT NOT NULL DEFAULT '',
                analysis_issue_title TEXT NOT NULL DEFAULT '',
                analysis_issue_body TEXT NOT NULL DEFAULT '',
                analysis_severity TEXT NOT NULL DEFAULT '',
                analysis_raw_json TEXT NOT NULL DEFAULT ''
            );
            """
            guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
                throw CaptureRepositoryError.executeFailed(lastErrorMessage(db))
            }

            let chatSQL = """
            CREATE TABLE IF NOT EXISTS capture_chat_messages (
                id TEXT PRIMARY KEY,
                capture_id TEXT NOT NULL,
                role TEXT NOT NULL,
                body TEXT NOT NULL,
                created_at TEXT NOT NULL
            );
            """
            guard sqlite3_exec(db, chatSQL, nil, nil, nil) == SQLITE_OK else {
                throw CaptureRepositoryError.executeFailed(lastErrorMessage(db))
            }

            let migrationSQL = [
                "ALTER TABLE captures ADD COLUMN ocr_status TEXT NOT NULL DEFAULT 'pending';",
                "ALTER TABLE captures ADD COLUMN preset_id TEXT NOT NULL DEFAULT 'general';",
                "ALTER TABLE captures ADD COLUMN payload_json TEXT NOT NULL DEFAULT '{}';",
                "ALTER TABLE captures ADD COLUMN analysis_status TEXT NOT NULL DEFAULT 'idle';",
                "ALTER TABLE captures ADD COLUMN analysis_preset_id TEXT NOT NULL DEFAULT '';",
                "ALTER TABLE captures ADD COLUMN analysis_updated_at TEXT;",
                "ALTER TABLE captures ADD COLUMN analysis_summary TEXT NOT NULL DEFAULT '';",
                "ALTER TABLE captures ADD COLUMN analysis_tags TEXT NOT NULL DEFAULT '';",
                "ALTER TABLE captures ADD COLUMN analysis_recommended_actions TEXT NOT NULL DEFAULT '';",
                "ALTER TABLE captures ADD COLUMN analysis_issue_title TEXT NOT NULL DEFAULT '';",
                "ALTER TABLE captures ADD COLUMN analysis_issue_body TEXT NOT NULL DEFAULT '';",
                "ALTER TABLE captures ADD COLUMN analysis_severity TEXT NOT NULL DEFAULT '';",
                "ALTER TABLE captures ADD COLUMN analysis_raw_json TEXT NOT NULL DEFAULT '';",
                "ALTER TABLE captures ADD COLUMN display_sequence INTEGER NOT NULL DEFAULT 0;"
            ]
            for statement in migrationSQL {
                sqlite3_exec(db, statement, nil, nil, nil)
            }
        }
    }

    private func withDatabase<T>(_ body: (OpaquePointer?) throws -> T) throws -> T {
        var db: OpaquePointer?
        guard sqlite3_open(databaseURL.path, &db) == SQLITE_OK else {
            sqlite3_close(db)
            throw CaptureRepositoryError.databaseOpenFailed
        }
        defer { sqlite3_close(db) }
        return try body(db)
    }

    private func bindText(_ string: String, to index: Int32, in statement: OpaquePointer?) {
        sqlite3_bind_text(statement, index, string, -1, SQLITE_TRANSIENT)
    }

    private func bindOptionalText(_ string: String?, to index: Int32, in statement: OpaquePointer?) {
        if let string {
            bindText(string, to: index, in: statement)
        } else {
            sqlite3_bind_null(statement, index)
        }
    }

    private func stringValue(at index: Int32, in statement: OpaquePointer?) -> String {
        guard let value = sqlite3_column_text(statement, index) else {
            return ""
        }
        return String(cString: value)
    }

    private func optionalStringValue(at index: Int32, in statement: OpaquePointer?) -> String? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else {
            return nil
        }
        return stringValue(at: index, in: statement)
    }

    private func encodedPayloadString(for payload: CapturePresetPayload) -> String {
        guard let data = try? encoder.encode(payload),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }

    private func decodedPayload(from string: String) -> CapturePresetPayload {
        guard let data = string.data(using: .utf8),
              let payload = try? decoder.decode(CapturePresetPayload.self, from: data) else {
            return CapturePresetPayload()
        }
        return payload
    }

    private func decodedAnalysis(status: String, presetID: String, updatedAt: String?, summary: String, tags: String, recommendedActions: String, issueTitle: String, issueBody: String, severity: String, rawJSON: String) -> CaptureAnalysisResult {
        CaptureAnalysisResult(
            status: CaptureAnalysisStatus(rawValue: status) ?? .idle,
            presetID: presetID,
            updatedAt: updatedAt.flatMap(Self.iso8601Formatter.date(from:)),
            summary: summary,
            tags: tags.split(separator: "\n").map(String.init).filter { !$0.isEmpty },
            recommendedActions: recommendedActions.split(separator: "\n").map(String.init).filter { !$0.isEmpty },
            issueTitle: issueTitle,
            issueBody: issueBody,
            severity: severity,
            rawJSON: rawJSON
        )
    }

    private func nextDisplaySequence() throws -> Int {
        try withDatabase { db in
            let sql = "SELECT MAX(display_sequence) FROM captures;"
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw CaptureRepositoryError.prepareFailed(lastErrorMessage(db))
            }
            defer { sqlite3_finalize(statement) }

            if sqlite3_step(statement) == SQLITE_ROW {
                return Int(sqlite3_column_int(statement, 0)) + 1
            }
            return 1
        }
    }

    private func lastErrorMessage(_ db: OpaquePointer?) -> String {
        guard let message = sqlite3_errmsg(db) else {
            return "Unknown SQLite error"
        }
        return String(cString: message)
    }

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

enum CapturePresetCatalog {
    private static let customDefaultsKey = "quicksnap.customCapturePresets"

    static func allDefinitions() -> [CapturePresetDefinition] {
        CapturePresetDefinition.builtin + loadCustomDefinitions().map(CapturePresetDefinition.from)
    }

    static func definition(for id: String) -> CapturePresetDefinition {
        let resolvedID = id == "ui_issue" ? "bug_report" : id
        return allDefinitions().first(where: { $0.id == resolvedID }) ?? .general
    }

    static func loadCustomDefinitions() -> [CustomCapturePresetDefinition] {
        guard let data = UserDefaults.standard.data(forKey: customDefaultsKey),
              let definitions = try? JSONDecoder().decode([CustomCapturePresetDefinition].self, from: data) else {
            return []
        }
        return definitions
    }

    static func saveCustomDefinitions(_ definitions: [CustomCapturePresetDefinition]) {
        guard let data = try? JSONEncoder().encode(definitions) else {
            return
        }
        UserDefaults.standard.set(data, forKey: customDefaultsKey)
    }
}

enum OCRTextRecognizer {
    static func recognizeText(at imageURL: URL) -> String {
        let requestHandler = VNImageRequestHandler(url: imageURL)
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        do {
            try requestHandler.perform([request])
        } catch {
            return ""
        }

        return (request.results ?? [])
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum FrontmostWindowInspector {
    static func captureContext() -> FrontmostCaptureContext {
        let frontmostApplication = NSWorkspace.shared.frontmostApplication
        let frontmostApp = frontmostApplication?.localizedName ?? "Unknown App"
        let bundleIdentifier = frontmostApplication?.bundleIdentifier
        guard let windowInfo = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return FrontmostCaptureContext(sourceApp: frontmostApp, bundleIdentifier: bundleIdentifier, windowTitle: "", windowID: nil)
        }

        for entry in windowInfo {
            let ownerName = entry[kCGWindowOwnerName as String] as? String ?? ""
            let layer = entry[kCGWindowLayer as String] as? Int ?? 0
            let alpha = entry[kCGWindowAlpha as String] as? Double ?? 1
            let bounds = entry[kCGWindowBounds as String] as? [String: CGFloat] ?? [:]
            let width = bounds["Width"] ?? 0
            let height = bounds["Height"] ?? 0

            guard ownerName == frontmostApp, layer == 0, alpha > 0, width > 20, height > 20 else {
                continue
            }

            let windowTitle = entry[kCGWindowName as String] as? String ?? ""
            let windowNumber = entry[kCGWindowNumber as String] as? UInt32
            return FrontmostCaptureContext(sourceApp: frontmostApp, bundleIdentifier: bundleIdentifier, windowTitle: windowTitle, windowID: windowNumber)
        }

        return FrontmostCaptureContext(sourceApp: frontmostApp, bundleIdentifier: bundleIdentifier, windowTitle: "", windowID: nil)
    }

    static func availableCaptureWindows(excluding appName: String) -> [WindowCaptureOption] {
        guard let windowInfo = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        let runningAppsByName = Dictionary(
            NSWorkspace.shared.runningApplications.compactMap { application -> (String, String?)? in
                guard let name = application.localizedName else { return nil }
                return (name, application.bundleIdentifier)
            },
            uniquingKeysWith: { first, _ in first }
        )

        return windowInfo.compactMap { entry in
            let ownerName = entry[kCGWindowOwnerName as String] as? String ?? ""
            let layer = entry[kCGWindowLayer as String] as? Int ?? 0
            let alpha = entry[kCGWindowAlpha as String] as? Double ?? 1
            let bounds = entry[kCGWindowBounds as String] as? [String: CGFloat] ?? [:]
            let width = Int(bounds["Width"] ?? 0)
            let height = Int(bounds["Height"] ?? 0)
            let windowNumber = entry[kCGWindowNumber as String] as? CGWindowID

            guard let windowNumber else { return nil }
            guard layer == 0, alpha > 0, width > 120, height > 120 else { return nil }
            guard ownerName != appName else { return nil }

            let windowTitle = (entry[kCGWindowName as String] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return WindowCaptureOption(
                id: windowNumber,
                sourceApp: ownerName,
                windowTitle: windowTitle,
                bundleIdentifier: runningAppsByName[ownerName] ?? nil,
                width: width,
                height: height
            )
        }
    }
}

enum BrowserURLResolver {
    private struct BrowserDefinition {
        let bundleIdentifier: String
        let appName: String
        let script: String
    }

    private static let supportedBrowsers: [BrowserDefinition] = [
        BrowserDefinition(
            bundleIdentifier: "com.apple.Safari",
            appName: "Safari",
            script: """
            tell application "Safari"
                if (count of windows) is 0 then return ""
                return URL of current tab of front window
            end tell
            """
        ),
        BrowserDefinition(
            bundleIdentifier: "com.google.Chrome",
            appName: "Google Chrome",
            script: """
            tell application "Google Chrome"
                if (count of windows) is 0 then return ""
                return URL of active tab of front window
            end tell
            """
        ),
        BrowserDefinition(
            bundleIdentifier: "company.thebrowser.Browser",
            appName: "Arc",
            script: """
            tell application "Arc"
                if (count of windows) is 0 then return ""
                return URL of active tab of front window
            end tell
            """
        ),
        BrowserDefinition(
            bundleIdentifier: "com.brave.Browser",
            appName: "Brave Browser",
            script: """
            tell application "Brave Browser"
                if (count of windows) is 0 then return ""
                return URL of active tab of front window
            end tell
            """
        ),
        BrowserDefinition(
            bundleIdentifier: "com.microsoft.edgemac",
            appName: "Microsoft Edge",
            script: """
            tell application "Microsoft Edge"
                if (count of windows) is 0 then return ""
                return URL of active tab of front window
            end tell
            """
        )
    ]

    static func resolveURL(for context: FrontmostCaptureContext) -> String? {
        guard let browser = matchingBrowser(for: context) else {
            return nil
        }

        guard let script = NSAppleScript(source: browser.script) else {
            return nil
        }

        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        if error != nil {
            return nil
        }

        let value = result.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? nil : value
    }

    static func isSupportedBrowserApp(_ appName: String) -> Bool {
        supportedBrowsers.contains(where: { $0.appName == appName })
    }

    private static func matchingBrowser(for context: FrontmostCaptureContext) -> BrowserDefinition? {
        if let bundleIdentifier = context.bundleIdentifier {
            if let browser = supportedBrowsers.first(where: { $0.bundleIdentifier == bundleIdentifier }) {
                return browser
            }
        }

        return supportedBrowsers.first(where: { $0.appName == context.sourceApp })
    }
}

enum BrowserDebugMetadataResolver {
    private static let chromiumAppNames = ["Google Chrome", "Arc", "Brave Browser", "Microsoft Edge"]

    static func resolve(for context: FrontmostCaptureContext) -> BrowserDebugMetadata? {
        if context.bundleIdentifier == "com.apple.Safari" || context.sourceApp == "Safari" {
            let script = """
            tell application "Safari"
                if (count of windows) is 0 then return ""
                set pageTitle to name of current tab of front window
                set viewportSize to do JavaScript "window.innerWidth + 'x' + window.innerHeight" in current tab of front window
                return pageTitle & "||" & viewportSize
            end tell
            """
            return run(script: script)
        }

        guard chromiumAppNames.contains(context.sourceApp) else {
            return nil
        }

        let script = """
        tell application "\(context.sourceApp)"
            if (count of windows) is 0 then return ""
            set pageTitle to title of active tab of front window
            set viewportSize to execute active tab of front window javascript "window.innerWidth + 'x' + window.innerHeight"
            return pageTitle & "||" & viewportSize
        end tell
        """
        return run(script: script)
    }

    private static func run(script source: String) -> BrowserDebugMetadata? {
        guard let script = NSAppleScript(source: source) else { return nil }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        if error != nil {
            return nil
        }
        let value = result.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !value.isEmpty else { return nil }
        let parts = value.components(separatedBy: "||")
        let title = parts.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let viewport = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespacesAndNewlines) : ""
        return BrowserDebugMetadata(pageTitle: title, viewport: viewport)
    }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

private extension NSImage {
    var pngData: Data? {
        guard let tiffData = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
    }
}
