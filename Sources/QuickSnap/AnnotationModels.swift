import AppKit
import Foundation
import SwiftUI

enum CaptureFilter: String, CaseIterable, Identifiable {
    case all
    case fullScreen
    case window
    case selection
    case imported
    case missing

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: return "All"
        case .fullScreen: return "Full"
        case .window: return "Window"
        case .selection: return "Selection"
        case .imported: return "Imported"
        case .missing: return "Missing"
        }
    }
}

enum AnnotationTool: String, CaseIterable, Identifiable {
    case pen = "Pen"
    case rectangle = "Rectangle"
    case arrow = "Arrow"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .pen: return "pencil.tip"
        case .rectangle: return "rectangle"
        case .arrow: return "arrow.up.right"
        }
    }
}

struct Stroke: Identifiable {
    let id = UUID()
    var points: [CGPoint]
    var color: NSColor
    var lineWidth: CGFloat
}

enum ShapeKind {
    case rectangle
    case arrow
}

struct ShapeAnnotation: Identifiable {
    let id = UUID()
    var kind: ShapeKind
    var start: CGPoint
    var end: CGPoint
    var color: NSColor
    var lineWidth: CGFloat
}

enum SelectedAnnotation: Equatable {
    case stroke(UUID)
    case shape(UUID)
}

@MainActor
final class AnnotationDocument: ObservableObject {
    private static let annotationColorDefaultsKey = "quicksnap.annotationColorHex"
    private static let captureStoragePathDefaultsKey = "quicksnap.captureStorageRootPath"
    private static let selectedPresetDefaultsKey = "quicksnap.selectedPresetID"
    private static let aiUsesPersonalKeyDefaultsKey = "quicksnap.ai.usesPersonalKey"
    private static let openAIModelDefaultsKey = "quicksnap.ai.openaiModel"
    private static let githubOwnerDefaultsKey = "quicksnap.github.owner"
    private static let githubRepoDefaultsKey = "quicksnap.github.repo"
    private static let githubLabelsDefaultsKey = "quicksnap.github.labels"

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter
    }()

    private static let sidebarTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    @Published var backgroundImage: NSImage?
    @Published var showsSelectionBorder = false
    @Published var canvasSize = CGSize(width: 1280, height: 800)
    @Published var selectedTool: AnnotationTool = .pen
    @Published var selectedAnnotation: SelectedAnnotation?
    @Published var color: NSColor = .systemRed {
        didSet { persistSelectedColor() }
    }
    @Published var lineWidth: CGFloat = 4
    @Published var strokes: [Stroke] = []
    @Published var shapes: [ShapeAnnotation] = []
    @Published private(set) var captures: [CaptureRecord] = []
    @Published private(set) var presetDefinitions: [CapturePresetDefinition] = []
    @Published var selectedCaptureID: String?
    @Published var searchText = "" {
        didSet { refreshCaptureLibrary(preserving: selectedCaptureID) }
    }
    @Published var activeFilter: CaptureFilter = .all {
        didSet { applyCaptureFilter(preserving: selectedCaptureID) }
    }
    @Published var selectedCaptureTagsText = ""
    @Published var selectedPresetID: String = "general" {
        didSet {
            UserDefaults.standard.set(selectedPresetID, forKey: Self.selectedPresetDefaultsKey)
        }
    }
    @Published var availableWindowOptions: [WindowCaptureOption] = []
    @Published var isWindowPickerPresented = false
    @Published var selectedCapturePayload = CapturePresetPayload()
    @Published var isRightPanelVisible = false
    @Published var rightPanelMode: WorkspacePanelMode = .analyze
    @Published var selectedSendPreviewKind: SendPreviewKind = .markdownDocument
    @Published var analysisErrorMessage: String?
    @Published var chatErrorMessage: String?
    @Published var chatInputText = ""
    @Published var isSendingChatMessage = false
    @Published private(set) var selectedCaptureChatMessages: [CaptureChatMessage] = []
    @Published var aiSettingsStatusMessage: String?
    @Published var isTestingOpenAIConnection = false
    @Published var aiUsesPersonalKey = false {
        didSet {
            UserDefaults.standard.set(aiUsesPersonalKey, forKey: Self.aiUsesPersonalKeyDefaultsKey)
        }
    }
    @Published var openAIModel = "gpt-4o-mini" {
        didSet {
            UserDefaults.standard.set(openAIModel, forKey: Self.openAIModelDefaultsKey)
        }
    }
    @Published var openAIKeyDraft = ""
    @Published private(set) var hasSavedOpenAIKey = false
    @Published var githubOwner = "" {
        didSet { UserDefaults.standard.set(githubOwner, forKey: Self.githubOwnerDefaultsKey) }
    }
    @Published var githubRepo = "" {
        didSet { UserDefaults.standard.set(githubRepo, forKey: Self.githubRepoDefaultsKey) }
    }
    @Published var githubLabels = "" {
        didSet { UserDefaults.standard.set(githubLabels, forKey: Self.githubLabelsDefaultsKey) }
    }
    @Published var customPresetNameDraft = ""
    @Published var customPresetFieldsDraft = ""
    @Published var customPresetTemplateDraft = """
# {{title}}

{{image_markdown}}
"""
    @Published var statusMessage = "Ready"
    @Published var libraryErrorMessage: String?

    private var annotationHistory: [SelectedAnnotation] = []
    private var allCaptures: [CaptureRecord] = []
    private let defaultExportDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Pictures", isDirectory: true)
        .appendingPathComponent("QuickSnap", isDirectory: true)
    private var captureRepository: CaptureRepository?

    init() {
        captureRepository = buildCaptureRepository()
        selectedPresetID = UserDefaults.standard.string(forKey: Self.selectedPresetDefaultsKey) ?? "general"
        aiUsesPersonalKey = UserDefaults.standard.bool(forKey: Self.aiUsesPersonalKeyDefaultsKey)
        openAIModel = UserDefaults.standard.string(forKey: Self.openAIModelDefaultsKey) ?? "gpt-4o-mini"
        hasSavedOpenAIKey = KeychainStore.loadOpenAIKey() != nil
        githubOwner = UserDefaults.standard.string(forKey: Self.githubOwnerDefaultsKey) ?? ""
        githubRepo = UserDefaults.standard.string(forKey: Self.githubRepoDefaultsKey) ?? ""
        githubLabels = UserDefaults.standard.string(forKey: Self.githubLabelsDefaultsKey) ?? ""

        if let savedHex = UserDefaults.standard.string(forKey: Self.annotationColorDefaultsKey) {
            color = NSColor(hex: savedHex)
        }

        reloadPresetDefinitions()

        if captureRepository == nil {
            libraryErrorMessage = "QuickSnap could not initialize its local capture library."
        }

        refreshCaptureLibrary()
        if backgroundImage == nil, let firstCapture = captures.first {
            openCapture(firstCapture)
        }
    }

    var selectedCapture: CaptureRecord? {
        captures.first(where: { $0.id == selectedCaptureID })
    }

    var selectedPresetDefinition: CapturePresetDefinition {
        presetDefinitions.first(where: { $0.id == selectedPresetID }) ?? .general
    }

    var selectedCapturePresetDefinition: CapturePresetDefinition {
        selectedCapture.map { CapturePresetCatalog.definition(for: $0.presetID) } ?? selectedPresetDefinition
    }

    var captureCountSummary: String {
        if allCaptures.isEmpty {
            return "No captures stored"
        }
        if activeFilter == .all {
            return "\(captures.count) capture\(captures.count == 1 ? "" : "s")"
        }
        return "\(captures.count) of \(allCaptures.count) visible"
    }

    var defaultExportFilename: String {
        if let selectedCapture {
            return "\(selectedCapture.exportBaseName).png"
        }
        return "\(makeTimestampedBaseName()).png"
    }

    var currentResolutionText: String {
        selectedCapture?.dimensionsText ?? "\(Int(canvasSize.width)) x \(Int(canvasSize.height))"
    }

    var currentCaptureSubtitle: String {
        selectedCapture?.displaySubtitle ?? "Unsaved workspace"
    }

    var currentCaptureTimestampText: String {
        guard let selectedCapture else { return "" }
        return Self.sidebarTimestampFormatter.string(from: selectedCapture.createdAt)
    }

    var canCopyCaptureOutputs: Bool { selectedCapture != nil }
    var canCopyImage: Bool { backgroundImage != nil }
    var canAnalyzeSelectedCapture: Bool { selectedCapture != nil }
    var canExportIssueDraft: Bool {
        guard let selectedCapture else { return false }
        return selectedCapture.presetDefinition.exportModes.contains(.issueDraft)
    }
    var canSendToGitHub: Bool {
        guard let selectedCapture else { return false }
        return selectedCapture.presetDefinition.exportModes.contains(.githubIssueURL)
            && !githubOwner.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !githubRepo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var captureLibraryPathText: String {
        captureRepository?.rootDirectory.path ?? "Unavailable"
    }

    var isUsingDefaultStorageLocation: Bool {
        UserDefaults.standard.string(forKey: Self.captureStoragePathDefaultsKey) == nil
    }

    var storageLocationSummaryText: String {
        isUsingDefaultStorageLocation ? "Default Application Support location" : "Custom storage location"
    }

    var currentPresetDescription: String {
        selectedPresetDefinition.description
    }

    var selectedCapturePrimaryURLText: String {
        selectedCapture?.primaryURL ?? ""
    }

    var selectedPreviewText: String? {
        guard let selectedCapture else { return nil }
        if selectedSendPreviewKind == .githubIssueURL {
            return selectedCapture.githubIssueURL(owner: githubOwner, repo: githubRepo, labels: githubLabels)?.absoluteString
        }
        return selectedCapture.previewText(for: selectedSendPreviewKind)
    }

    var selectedPreviewTitle: String {
        selectedSendPreviewKind.displayName
    }

    var savedOpenAIKeySummary: String {
        hasSavedOpenAIKey ? "Personal OpenAI key saved in Keychain" : "No OpenAI API key saved"
    }

    func clearAnnotations() {
        strokes.removeAll()
        shapes.removeAll()
        selectedAnnotation = nil
        annotationHistory.removeAll()
    }

    func loadImage(_ image: NSImage, capture: CaptureRecord? = nil, showsSelectionBorder: Bool = false) {
        backgroundImage = image
        selectedCaptureID = capture?.id
        selectedCaptureTagsText = capture?.tags.joined(separator: ", ") ?? ""
        selectedCapturePayload = capture?.presetPayload ?? CapturePresetPayload()
        selectedCaptureChatMessages = capture?.chatMessages ?? []
        self.showsSelectionBorder = showsSelectionBorder
        let size = image.size
        if size.width > 0, size.height > 0 {
            canvasSize = size
        }
        clearAnnotations()
    }

    func refreshCaptureLibrary(preserving captureID: String? = nil) {
        guard let captureRepository else {
            captures = []
            return
        }

        do {
            allCaptures = try captureRepository.listCaptures(matching: searchText)
            libraryErrorMessage = nil
            applyCaptureFilter(preserving: captureID ?? selectedCaptureID)
        } catch {
            libraryErrorMessage = "QuickSnap could not read its capture history."
        }
    }

    func openCapture(_ capture: CaptureRecord) {
        selectedCaptureID = capture.id
        selectedCaptureTagsText = capture.tags.joined(separator: ", ")
        selectedCapturePayload = capture.presetPayload
        selectedCaptureChatMessages = capture.chatMessages
        chatInputText = ""
        chatErrorMessage = nil

        guard capture.fileExists, let image = NSImage(contentsOf: capture.imageURL) else {
            backgroundImage = nil
            canvasSize = CGSize(width: 1280, height: 800)
            showsSelectionBorder = capture.showsSelectionBorder
            clearAnnotations()
            statusMessage = "The image for this capture is missing."
            return
        }

        loadImage(image, capture: capture, showsSelectionBorder: capture.showsSelectionBorder)
        statusMessage = "Loaded \(capture.displayTitle)"
    }

    func openWorkspacePanel(mode: WorkspacePanelMode = .analyze) {
        rightPanelMode = mode
        isRightPanelVisible = true
    }

    func showAnalyzePanel() {
        rightPanelMode = .analyze
        isRightPanelVisible = true
    }

    func openSendPreview(_ kind: SendPreviewKind) {
        guard selectedCapture != nil else { return }
        selectedSendPreviewKind = kind
        rightPanelMode = .send
        isRightPanelVisible = true
    }

    func closeRightPanel() {
        isRightPanelVisible = false
    }

    func runAIAnalysisForSelectedCapture() {
        runAnalysisForSelectedCapture(useAI: true)
    }

    func runLocalAnalysisForSelectedCapture() {
        runAnalysisForSelectedCapture(useAI: false)
    }

    func sendChatMessageForSelectedCapture() {
        guard let captureRepository, let selectedCapture else { return }
        let trimmed = chatInputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSendingChatMessage else { return }

        let userMessage = CaptureChatMessage(
            id: "msg_\(UUID().uuidString.lowercased())",
            captureID: selectedCapture.id,
            role: .user,
            body: trimmed,
            createdAt: Date()
        )

        do {
            try captureRepository.appendChatMessage(userMessage)
            selectedCaptureChatMessages.append(userMessage)
            chatInputText = ""
            chatErrorMessage = nil
            isSendingChatMessage = true
            refreshCaptureLibrary(preserving: selectedCapture.id)
        } catch {
            chatErrorMessage = "QuickSnap could not save your question."
            return
        }

        Task.detached(priority: .userInitiated) { [captureRepository] in
            do {
                let configuration = await MainActor.run { self.openAIConfiguration }
                let reply = try await CaptureAnalysisService.respondToChat(
                    capture: selectedCapture,
                    messages: selectedCapture.chatMessages + [userMessage],
                    question: trimmed,
                    configuration: configuration
                )
                let assistantMessage = CaptureChatMessage(
                    id: "msg_\(UUID().uuidString.lowercased())",
                    captureID: selectedCapture.id,
                    role: .assistant,
                    body: reply,
                    createdAt: Date()
                )
                try captureRepository.appendChatMessage(assistantMessage)
                await MainActor.run {
                    self.isSendingChatMessage = false
                    self.chatErrorMessage = nil
                    self.selectedCaptureChatMessages.append(assistantMessage)
                    self.refreshCaptureLibrary(preserving: selectedCapture.id)
                }
            } catch {
                await MainActor.run {
                    self.isSendingChatMessage = false
                    self.chatErrorMessage = self.readableAnalysisError(error)
                }
            }
        }
    }

    func saveOpenAIKey() {
        let trimmed = openAIKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        do {
            try KeychainStore.saveOpenAIKey(trimmed)
            hasSavedOpenAIKey = true
            openAIKeyDraft = ""
            analysisErrorMessage = nil
            aiSettingsStatusMessage = "OpenAI API key saved."
            statusMessage = "Saved OpenAI API key"
        } catch {
            analysisErrorMessage = "QuickSnap could not save the OpenAI key."
            aiSettingsStatusMessage = "QuickSnap could not save the OpenAI key."
            statusMessage = "QuickSnap could not save the OpenAI key."
        }
    }

    func removeOpenAIKey() {
        KeychainStore.deleteOpenAIKey()
        hasSavedOpenAIKey = false
        openAIKeyDraft = ""
        analysisErrorMessage = nil
        aiSettingsStatusMessage = "OpenAI API key removed."
        statusMessage = "Removed OpenAI API key"
    }

    func testOpenAIConnection() {
        guard let configuration = openAIConfiguration else {
            analysisErrorMessage = "Save an OpenAI API key first."
            aiSettingsStatusMessage = "Save an OpenAI API key first."
            return
        }

        isTestingOpenAIConnection = true
        aiSettingsStatusMessage = "Testing OpenAI connection..."
        Task.detached(priority: .userInitiated) {
            do {
                try await CaptureAnalysisService.testConnection(configuration: configuration)
                await MainActor.run {
                    self.isTestingOpenAIConnection = false
                    self.analysisErrorMessage = nil
                    self.aiSettingsStatusMessage = "OpenAI connection verified."
                    self.statusMessage = "OpenAI connection verified"
                }
            } catch {
                await MainActor.run {
                    self.isTestingOpenAIConnection = false
                    self.analysisErrorMessage = self.readableAnalysisError(error)
                    self.aiSettingsStatusMessage = self.readableAnalysisError(error)
                    self.statusMessage = "OpenAI connection failed"
                }
            }
        }
    }

    func captureMainDisplay() {
        captureWithPersistence(kind: .fullScreen, showsSelectionBorder: false) {
            guard let cgImage = CGDisplayCreateImage(CGMainDisplayID()) else { return nil }
            return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        }
    }

    func captureSelectionFromScreen() {
        captureWithPersistence(kind: .selection, showsSelectionBorder: true) {
            let outputURL = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("quicksnap-selection-\(UUID().uuidString).png")
            defer { try? FileManager.default.removeItem(at: outputURL) }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            process.arguments = ["-i", "-x", outputURL.path]

            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                return nil
            }

            guard process.terminationStatus == 0 else { return nil }
            return NSImage(contentsOf: outputURL)
        }
    }

    func presentWindowPicker() {
        let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "QuickSnap"
        availableWindowOptions = FrontmostWindowInspector.availableCaptureWindows(excluding: appName)

        guard !availableWindowOptions.isEmpty else {
            NSSound.beep()
            statusMessage = "QuickSnap could not find any other windows to capture."
            return
        }

        isWindowPickerPresented = true
    }

    func dismissWindowPicker() {
        isWindowPickerPresented = false
    }

    func captureWindow(_ option: WindowCaptureOption) {
        isWindowPickerPresented = false

        captureWithPersistence(kind: .window, showsSelectionBorder: false, context: option.captureContext) {
            let outputURL = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("quicksnap-window-\(UUID().uuidString).png")
            defer { try? FileManager.default.removeItem(at: outputURL) }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            process.arguments = ["-l", "\(option.id)", "-x", outputURL.path]

            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                return nil
            }

            guard process.terminationStatus == 0 else { return nil }
            return NSImage(contentsOf: outputURL)
        }
    }

    func openImageFromDisk() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .tiff, .gif, .bmp, .heic, .webP]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url, let image = NSImage(contentsOf: url) else { return }

        loadImage(image, capture: nil, showsSelectionBorder: false)
        statusMessage = "Importing image..."

        let importedContext = FrontmostCaptureContext(
            sourceApp: "Imported",
            bundleIdentifier: nil,
            windowTitle: url.deletingPathExtension().lastPathComponent,
            windowID: nil
        )
        ingestCapture(image, kind: .imported, showsSelectionBorder: false, context: importedContext)
        statusMessage = "Imported image using \(selectedPresetDefinition.name)"
    }

    func saveAnnotatedImage() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = defaultExportFilename

        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let pngData = renderPNGDataForExport() else { return }

        do {
            try pngData.write(to: url)
            statusMessage = "Exported PNG"
        } catch {
            NSSound.beep()
        }
    }

    func renderPNGDataForExport() -> Data? {
        renderPNGData()
    }

    func writeExportPNGToTemporaryFile() -> URL? {
        guard let pngData = renderPNGDataForExport() else { return nil }
        let fileName = defaultExportFilename
        let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let tempURL = tempDirectory.appendingPathComponent("\(UUID().uuidString)-\(fileName)")

        do {
            try pngData.write(to: tempURL, options: .atomic)
            archiveExportPNGInBackground(pngData: pngData, fileName: fileName)
            return tempURL
        } catch {
            NSSound.beep()
            return nil
        }
    }

    func copyRenderedImageToPasteboard() {
        guard let renderedImage = renderAnnotatedImage().tiffRepresentation else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(renderedImage, forType: .tiff)
        statusMessage = "Copied image to clipboard"
    }

    func copyCurrentCaptureFilePath() {
        guard let selectedCapture else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(selectedCapture.imagePath, forType: .string)
        statusMessage = "Copied capture file path"
    }

    func copySelectedPreviewArtifact() {
        guard let previewText = selectedPreviewText else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(previewText, forType: .string)
        statusMessage = "Copied \(selectedSendPreviewKind.displayName)"
    }

    func copyCurrentCaptureMarkdown() {
        guard let selectedCapture else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(selectedCapture.markdownSnippet, forType: .string)
        statusMessage = "Copied Markdown snippet"
    }

    func copyCurrentCaptureMarkdownDocument() {
        guard let selectedCapture else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(selectedCapture.markdownDocument, forType: .string)
        statusMessage = "Copied Markdown document"
    }

    func exportCurrentCaptureMarkdownDocument() {
        guard let selectedCapture else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "\(selectedCapture.exportBaseName).md"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try selectedCapture.markdownDocument.write(to: url, atomically: true, encoding: .utf8)
            statusMessage = "Exported Markdown file"
        } catch {
            NSSound.beep()
            statusMessage = "QuickSnap could not write the Markdown file."
        }
    }

    func exportSelectedPreviewArtifactIfAvailable() {
        guard selectedSendPreviewKind == .markdownDocument else { return }
        exportCurrentCaptureMarkdownDocument()
    }

    func openSelectedCaptureGitHubIssue() {
        guard let selectedCapture,
              let url = selectedCapture.githubIssueURL(owner: githubOwner, repo: githubRepo, labels: githubLabels) else {
            statusMessage = "Configure a GitHub owner and repo first."
            return
        }

        NSWorkspace.shared.open(url)
        statusMessage = "Opened GitHub issue draft"
    }

    func copyIssueDraftToPasteboard() {
        guard let selectedCapture else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString("# \(selectedCapture.issueDraftTitle)\n\n\(selectedCapture.issueDraftBody)", forType: .string)
        statusMessage = "Copied issue draft"
    }

    func copyTableJSONToPasteboard() {
        guard let json = selectedCapture?.jsonExportText else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(json, forType: .string)
        statusMessage = "Copied table JSON"
    }

    func copyTableCSVToPasteboard() {
        guard let csv = selectedCapture?.csvExportText else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(csv, forType: .string)
        statusMessage = "Copied table CSV"
    }

    func revealCurrentCaptureInFinder() {
        guard let selectedCapture else { return }
        NSWorkspace.shared.activateFileViewerSelecting([selectedCapture.imageURL])
        statusMessage = "Revealed capture in Finder"
    }

    func revealCaptureLibraryInFinder() {
        guard let captureRepository else { return }
        NSWorkspace.shared.activateFileViewerSelecting([captureRepository.rootDirectory])
        statusMessage = "Revealed capture library"
    }

    func chooseStorageLocation() {
        let panel = NSOpenPanel()
        panel.prompt = "Choose"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose where QuickSnap should store captures and its SQLite library."

        if let captureRepository {
            panel.directoryURL = captureRepository.rootDirectory.deletingLastPathComponent()
        }

        guard panel.runModal() == .OK, let url = panel.url else { return }
        UserDefaults.standard.set(url.path, forKey: Self.captureStoragePathDefaultsKey)
        reloadCaptureRepository()
        statusMessage = "Updated capture storage location"
    }

    func resetStorageLocationToDefault() {
        UserDefaults.standard.removeObject(forKey: Self.captureStoragePathDefaultsKey)
        reloadCaptureRepository()
        statusMessage = "Reset capture storage to the default location"
    }

    func saveSelectedCaptureTags() {
        guard let captureRepository, let selectedCapture else { return }
        let normalizedTags = selectedCaptureTagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        do {
            try captureRepository.updateTags(for: selectedCapture.id, tags: normalizedTags)
            if let index = allCaptures.firstIndex(where: { $0.id == selectedCapture.id }) {
                let existing = allCaptures[index]
                allCaptures[index] = CaptureRecord(
                    id: existing.id,
                    displaySequence: existing.displaySequence,
                    imagePath: existing.imagePath,
                    createdAt: existing.createdAt,
                    sourceApp: existing.sourceApp,
                    windowTitle: existing.windowTitle,
                    urlString: existing.urlString,
                    ocrText: existing.ocrText,
                    tags: normalizedTags,
                    pixelWidth: existing.pixelWidth,
                    pixelHeight: existing.pixelHeight,
                    sourceKind: existing.sourceKind,
                    showsSelectionBorder: existing.showsSelectionBorder,
                    ocrStatus: existing.ocrStatus,
                    presetID: existing.presetID,
                    presetPayload: existing.presetPayload,
                    analysis: existing.analysis,
                    chatMessages: existing.chatMessages
                )
            }
            if let index = captures.firstIndex(where: { $0.id == selectedCapture.id }) {
                let existing = captures[index]
                captures[index] = CaptureRecord(
                    id: existing.id,
                    displaySequence: existing.displaySequence,
                    imagePath: existing.imagePath,
                    createdAt: existing.createdAt,
                    sourceApp: existing.sourceApp,
                    windowTitle: existing.windowTitle,
                    urlString: existing.urlString,
                    ocrText: existing.ocrText,
                    tags: normalizedTags,
                    pixelWidth: existing.pixelWidth,
                    pixelHeight: existing.pixelHeight,
                    sourceKind: existing.sourceKind,
                    showsSelectionBorder: existing.showsSelectionBorder,
                    ocrStatus: existing.ocrStatus,
                    presetID: existing.presetID,
                    presetPayload: existing.presetPayload,
                    analysis: existing.analysis,
                    chatMessages: existing.chatMessages
                )
            }
            selectedCaptureTagsText = normalizedTags.joined(separator: ", ")
            refreshCaptureLibrary(preserving: selectedCapture.id)
            statusMessage = normalizedTags.isEmpty ? "Cleared capture tags" : "Saved capture tags"
        } catch {
            libraryErrorMessage = "QuickSnap could not save capture tags."
        }
    }

    func saveSelectedCapturePresetPayload() {
        guard let captureRepository, let selectedCapture else { return }
        do {
            try captureRepository.updatePresetPayload(for: selectedCapture.id, payload: selectedCapturePayload)
            refreshCaptureLibrary(preserving: selectedCapture.id)
            statusMessage = "Updated preset fields"
        } catch {
            libraryErrorMessage = "QuickSnap could not save preset details."
        }
    }

    func applySelectedPresetToCurrentCapture() {
        guard let captureRepository, let selectedCapture else { return }
        do {
            try captureRepository.updatePreset(for: selectedCapture.id, presetID: selectedPresetID)
            selectedCapturePayload = payloadAdjustedForSelectedPreset(from: selectedCapturePayload)
            try captureRepository.updatePresetPayload(for: selectedCapture.id, payload: selectedCapturePayload)
            refreshCaptureLibrary(preserving: selectedCapture.id)
            statusMessage = "Updated capture preset"
        } catch {
            libraryErrorMessage = "QuickSnap could not update the capture preset."
        }
    }

    func addCustomPreset() {
        let trimmedName = customPresetNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let fields = parsedCustomPresetFields()

        var existing = CapturePresetCatalog.loadCustomDefinitions()
        let template = generatedCustomTemplate(baseTemplate: customPresetTemplateDraft, fieldNames: fields)
        let definition = CustomCapturePresetDefinition(
            id: "custom_\(UUID().uuidString.lowercased())",
            name: trimmedName,
            fieldNames: fields,
            exportTemplate: template
        )
        existing.append(definition)
        CapturePresetCatalog.saveCustomDefinitions(existing)
        reloadPresetDefinitions()
        selectedPresetID = definition.id
        customPresetNameDraft = ""
        customPresetFieldsDraft = ""
        customPresetTemplateDraft = "# {{title}}\n\n{{image_markdown}}"
        statusMessage = "Added custom preset"
    }

    func syncCustomPresetTemplateWithFields() {
        customPresetTemplateDraft = generatedCustomTemplate(
            baseTemplate: customPresetTemplateDraft,
            fieldNames: parsedCustomPresetFields()
        )
    }

    func removeCustomPreset(_ definition: CustomCapturePresetDefinition) {
        let updated = CapturePresetCatalog.loadCustomDefinitions().filter { $0.id != definition.id }
        CapturePresetCatalog.saveCustomDefinitions(updated)
        reloadPresetDefinitions()
        if selectedPresetID == definition.id {
            selectedPresetID = "general"
        }
        statusMessage = "Removed custom preset"
    }

    func payloadBinding(for keyPath: WritableKeyPath<CapturePresetPayload, String>) -> Binding<String> {
        Binding(
            get: { self.selectedCapturePayload[keyPath: keyPath] },
            set: { self.selectedCapturePayload[keyPath: keyPath] = $0 }
        )
    }

    func customFieldBinding(named fieldName: String) -> Binding<String> {
        Binding(
            get: { self.selectedCapturePayload.customFields[fieldName, default: ""] },
            set: { self.selectedCapturePayload.customFields[fieldName] = $0 }
        )
    }

    func undoLastAnnotation() {
        guard let last = annotationHistory.popLast() else { return }
        switch last {
        case .stroke(let id):
            strokes.removeAll { $0.id == id }
        case .shape(let id):
            shapes.removeAll { $0.id == id }
        }
        selectedAnnotation = nil
    }

    func deleteSelectedAnnotation() {
        guard let selected = selectedAnnotation else { return }
        switch selected {
        case .stroke(let id):
            strokes.removeAll { $0.id == id }
            annotationHistory.removeAll { $0 == .stroke(id) }
        case .shape(let id):
            shapes.removeAll { $0.id == id }
            annotationHistory.removeAll { $0 == .shape(id) }
        }
        selectedAnnotation = nil
    }

    func selectAnnotation(at point: CGPoint) {
        if let stroke = strokes.last(where: { pointHitsStroke(point, stroke: $0) }) {
            selectedAnnotation = .stroke(stroke.id)
            return
        }
        if let shape = shapes.last(where: { pointHitsShape(point, shape: $0) }) {
            selectedAnnotation = .shape(shape.id)
            return
        }
        selectedAnnotation = nil
    }

    func timelineTimestamp(for capture: CaptureRecord) -> String {
        Self.sidebarTimestampFormatter.string(from: capture.createdAt)
    }

    private func captureWithPersistence(kind: CaptureSourceKind, showsSelectionBorder: Bool, context: FrontmostCaptureContext? = nil, work: @escaping () -> NSImage?) {
        let context = context ?? FrontmostWindowInspector.captureContext()
        let app = NSApplication.shared
        let wasActive = app.isActive
        app.hide(nil)

        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.25) {
            let capturedImage = work()
            DispatchQueue.main.async {
                if let capturedImage {
                    self.ingestCapture(capturedImage, kind: kind, showsSelectionBorder: showsSelectionBorder, context: context)
                }
                app.unhide(nil)
                if wasActive {
                    app.activate(ignoringOtherApps: true)
                }
            }
        }
    }

    private func ingestCapture(_ image: NSImage, kind: CaptureSourceKind, showsSelectionBorder: Bool, context: FrontmostCaptureContext) {
        guard let captureRepository else {
            loadImage(image, capture: nil, showsSelectionBorder: showsSelectionBorder)
            return
        }

        let createdAt = Date()
        let captureID = "cap_\(UUID().uuidString.lowercased())"
        let capturedURL = BrowserURLResolver.resolveURL(for: context)
        let browserMetadata = BrowserDebugMetadataResolver.resolve(for: context)
        let presetPayload = payloadAdjustedForSelectedPreset(
            from: initialPayload(for: selectedPresetID, capturedURL: capturedURL, browserMetadata: browserMetadata)
        )
        let draft = CaptureDraft(
            id: captureID,
            displaySequence: 0,
            createdAt: createdAt,
            sourceApp: context.sourceApp,
            windowTitle: context.windowTitle,
            urlString: capturedURL,
            pixelWidth: Int(image.size.width),
            pixelHeight: Int(image.size.height),
            sourceKind: kind,
            showsSelectionBorder: showsSelectionBorder,
            image: image,
            tags: [],
            ocrStatus: .pending,
            presetID: selectedPresetID,
            presetPayload: presetPayload
        )

        do {
            let record = try captureRepository.createCapture(from: draft)
            refreshCaptureLibrary(preserving: record.id)
            openCapture(record)
            statusMessage = "Saved \(record.presetDefinition.name) capture"
            scheduleOCR(for: record)
        } catch {
            libraryErrorMessage = "QuickSnap could not save the captured image."
            loadImage(image, capture: nil, showsSelectionBorder: showsSelectionBorder)
        }
    }

    private func scheduleOCR(for capture: CaptureRecord) {
        guard let captureRepository else { return }
        Task.detached(priority: .utility) { [captureRepository] in
            let recognizedText = OCRTextRecognizer.recognizeText(at: capture.imageURL)
            let status: CaptureOCRStatus = recognizedText.isEmpty ? .unavailable : .complete
            try? captureRepository.updateOCRResult(for: capture.id, ocrText: recognizedText, status: status)
            if let enrichedPayload = enrichedPayload(for: capture, recognizedText: recognizedText) {
                try? captureRepository.updatePresetPayload(for: capture.id, payload: enrichedPayload)
            }
            await MainActor.run {
                self.refreshCaptureLibrary(preserving: capture.id)
            }
        }
    }

    private func runAnalysisForSelectedCapture(useAI: Bool) {
        guard let captureRepository, let selectedCapture else {
            analysisErrorMessage = nil
            return
        }

        analysisErrorMessage = nil
        let pending = CaptureAnalysisResult(status: .pending, presetID: selectedCapture.presetID, updatedAt: Date())
        try? captureRepository.updateAnalysis(for: selectedCapture.id, analysis: pending)
        refreshCaptureLibrary(preserving: selectedCapture.id)

        Task.detached(priority: .userInitiated) { [captureRepository] in
            do {
                try await Task.sleep(nanoseconds: 200_000_000)
                let configuration = await MainActor.run { self.openAIConfiguration }
                let analysisResult: CaptureAnalysisResult
                if useAI, let configuration {
                    analysisResult = try await CaptureAnalysisService.analyzeWithAI(capture: selectedCapture, configuration: configuration)
                } else {
                    analysisResult = CaptureAnalysisService.analyzeLocally(capture: selectedCapture)
                }
                var result = analysisResult
                result.status = .complete
                result.presetID = selectedCapture.normalizedPresetID
                result.updatedAt = Date()
                try captureRepository.updateAnalysis(for: selectedCapture.id, analysis: result)
                await MainActor.run {
                    self.refreshCaptureLibrary(preserving: selectedCapture.id)
                    self.statusMessage = useAI && configuration != nil ? "AI analysis ready" : "Local analysis ready"
                }
            } catch {
                let failed = CaptureAnalysisResult(
                    status: .failed,
                    presetID: selectedCapture.normalizedPresetID,
                    updatedAt: Date(),
                    summary: "",
                    tags: [],
                    recommendedActions: [],
                    issueTitle: "",
                    issueBody: "",
                    severity: "",
                    rawJSON: ""
                )
                try? captureRepository.updateAnalysis(for: selectedCapture.id, analysis: failed)
                await MainActor.run {
                    self.analysisErrorMessage = self.readableAnalysisError(error)
                    self.statusMessage = "Analysis failed"
                    self.refreshCaptureLibrary(preserving: selectedCapture.id)
                }
            }
        }
    }

    private func readableAnalysisError(_ error: Error) -> String {
        if case let CaptureAnalysisError.apiError(message) = error {
            return message
        }
        return "QuickSnap could not analyze this capture."
    }


    private func applyCaptureFilter(preserving captureID: String?) {
        captures = allCaptures.filter(matchesActiveFilter)

        if let captureID, captures.contains(where: { $0.id == captureID }) {
            selectedCaptureID = captureID
        } else if let selectedCaptureID, captures.contains(where: { $0.id == selectedCaptureID }) {
            self.selectedCaptureID = selectedCaptureID
        } else {
            selectedCaptureID = captures.first?.id
        }

        if let selectedCapture {
            selectedCaptureTagsText = selectedCapture.tags.joined(separator: ", ")
            selectedCapturePayload = selectedCapture.presetPayload
            selectedCaptureChatMessages = selectedCapture.chatMessages
        } else {
            selectedCaptureTagsText = ""
            selectedCapturePayload = CapturePresetPayload()
            selectedCaptureChatMessages = []
        }
    }

    private func reloadCaptureRepository() {
        captureRepository = buildCaptureRepository()
        if captureRepository == nil {
            libraryErrorMessage = "QuickSnap could not initialize its local capture library."
            captures = []
            allCaptures = []
            selectedCaptureID = nil
            return
        }

        libraryErrorMessage = nil
        refreshCaptureLibrary(preserving: nil)
        if let firstCapture = captures.first {
            openCapture(firstCapture)
        } else {
            backgroundImage = nil
            canvasSize = CGSize(width: 1280, height: 800)
            clearAnnotations()
        }
    }

    private func buildCaptureRepository() -> CaptureRepository? {
        let customPath = UserDefaults.standard.string(forKey: Self.captureStoragePathDefaultsKey)
        let rootURL = customPath.map { URL(fileURLWithPath: $0, isDirectory: true) }
        return try? CaptureRepository(rootDirectory: rootURL)
    }

    private var openAIConfiguration: OpenAIAnalysisConfiguration? {
        guard aiUsesPersonalKey,
              let key = KeychainStore.loadOpenAIKey(),
              !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        let normalizedModel = openAIModel.trimmingCharacters(in: .whitespacesAndNewlines)
        return OpenAIAnalysisConfiguration(
            apiKey: key,
            model: OpenAIModelNormalizer.normalize(normalizedModel)
        )
    }

    private func reloadPresetDefinitions() {
        presetDefinitions = CapturePresetCatalog.allDefinitions()
        if !presetDefinitions.contains(where: { $0.id == selectedPresetID || (selectedPresetID == "ui_issue" && $0.id == "bug_report") }) {
            selectedPresetID = "general"
        } else if selectedPresetID == "ui_issue" {
            selectedPresetID = "bug_report"
        }
    }

    private func payloadAdjustedForSelectedPreset(from payload: CapturePresetPayload) -> CapturePresetPayload {
        var payload = payload
        if !selectedPresetDefinition.isCustom {
            payload.customFields = [:]
        }
        return payload
    }

    private func initialPayload(for presetID: String, capturedURL: String?, browserMetadata: BrowserDebugMetadata?) -> CapturePresetPayload {
        var payload = CapturePresetPayload()
        if let capturedURL {
            switch presetID {
            case "bug_report", "ui_issue":
                payload.urlString = capturedURL
            default:
                break
            }
        }
        if let browserMetadata {
            if payload.pageTitle.isEmpty {
                payload.pageTitle = browserMetadata.pageTitle
            }
            if payload.viewport.isEmpty {
                payload.viewport = browserMetadata.viewport
            }
        }
        return payload
    }

    private func generatedCustomTemplate(baseTemplate: String, fieldNames: [String]) -> String {
        let trimmedBase = baseTemplate.trimmingCharacters(in: .whitespacesAndNewlines)
        var template = trimmedBase.isEmpty ? "# {{title}}\n\n{{image_markdown}}" : trimmedBase

        for fieldName in fieldNames {
            let placeholder = "{{\(fieldName)}}"
            if !template.contains(placeholder) {
                template.append("\n\n**\(fieldName):** \(placeholder)")
            }
        }

        return template
    }

    private func parsedCustomPresetFields() -> [String] {
        customPresetFieldsDraft
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func matchesActiveFilter(_ capture: CaptureRecord) -> Bool {
        switch activeFilter {
        case .all: return true
        case .fullScreen: return capture.sourceKind == .fullScreen
        case .window: return capture.sourceKind == .window
        case .selection: return capture.sourceKind == .selection
        case .imported: return capture.sourceKind == .imported
        case .missing: return !capture.fileExists
        }
    }

    private func renderPNGData() -> Data? {
        let outputImage = renderAnnotatedImage()
        guard let tiffData = outputImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }
        return pngData
    }

    private func renderAnnotatedImage() -> NSImage {
        let output = NSImage(size: canvasSize)
        output.lockFocus()

        NSColor.white.setFill()
        NSRect(origin: .zero, size: canvasSize).fill()
        backgroundImage?.draw(in: NSRect(origin: .zero, size: canvasSize), from: .zero, operation: .sourceOver, fraction: 1)
        if showsSelectionBorder {
            drawSelectionBorder(in: NSRect(origin: .zero, size: canvasSize))
        }
        for stroke in strokes { drawStroke(stroke, highlighted: false) }
        for shape in shapes { drawShape(shape, highlighted: false) }
        output.unlockFocus()
        return output
    }

    private func drawStroke(_ stroke: Stroke, highlighted: Bool) {
        guard let first = stroke.points.first else { return }
        let path = NSBezierPath()
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.lineWidth = stroke.lineWidth + (highlighted ? 2 : 0)
        path.move(to: renderPoint(first))
        for point in stroke.points.dropFirst() {
            path.line(to: renderPoint(point))
        }
        (highlighted ? NSColor.systemBlue : stroke.color).setStroke()
        path.stroke()
    }

    private func drawShape(_ shape: ShapeAnnotation, highlighted: Bool) {
        (highlighted ? NSColor.systemBlue : shape.color).setStroke()
        switch shape.kind {
        case .rectangle:
            let convertedStart = renderPoint(shape.start)
            let convertedEnd = renderPoint(shape.end)
            let rect = CGRect(
                x: min(convertedStart.x, convertedEnd.x),
                y: min(convertedStart.y, convertedEnd.y),
                width: abs(convertedEnd.x - convertedStart.x),
                height: abs(convertedEnd.y - convertedStart.y)
            )
            let path = NSBezierPath(rect: rect)
            path.lineWidth = shape.lineWidth + (highlighted ? 2 : 0)
            path.stroke()
        case .arrow:
            let start = renderPoint(shape.start)
            let end = renderPoint(shape.end)
            let path = NSBezierPath()
            path.lineWidth = shape.lineWidth + (highlighted ? 2 : 0)
            path.lineCapStyle = .round
            path.move(to: start)
            path.line(to: end)
            path.stroke()

            let angle = atan2(end.y - start.y, end.x - start.x)
            let headLength = max(10, shape.lineWidth * 4)
            let left = CGPoint(x: end.x - headLength * cos(angle - .pi / 6), y: end.y - headLength * sin(angle - .pi / 6))
            let right = CGPoint(x: end.x - headLength * cos(angle + .pi / 6), y: end.y - headLength * sin(angle + .pi / 6))
            let head = NSBezierPath()
            head.lineWidth = shape.lineWidth + (highlighted ? 2 : 0)
            head.lineCapStyle = .round
            head.move(to: end)
            head.line(to: left)
            head.move(to: end)
            head.line(to: right)
            head.stroke()
        }
    }

    private func pointHitsStroke(_ point: CGPoint, stroke: Stroke) -> Bool {
        guard stroke.points.count > 1 else { return false }
        let threshold = max(8, stroke.lineWidth + 4)
        for index in 0..<(stroke.points.count - 1) {
            if distanceFromPoint(point, toSegmentStart: stroke.points[index], end: stroke.points[index + 1]) <= threshold {
                return true
            }
        }
        return false
    }

    private func pointHitsShape(_ point: CGPoint, shape: ShapeAnnotation) -> Bool {
        switch shape.kind {
        case .rectangle:
            let rect = CGRect(
                x: min(shape.start.x, shape.end.x),
                y: min(shape.start.y, shape.end.y),
                width: abs(shape.end.x - shape.start.x),
                height: abs(shape.end.y - shape.start.y)
            )
            let inset = max(6, shape.lineWidth + 3)
            let outer = rect.insetBy(dx: -inset, dy: -inset)
            let inner = rect.insetBy(dx: inset, dy: inset)
            return outer.contains(point) && !inner.contains(point)
        case .arrow:
            return distanceFromPoint(point, toSegmentStart: shape.start, end: shape.end) <= max(10, shape.lineWidth + 4)
        }
    }

    private func distanceFromPoint(_ point: CGPoint, toSegmentStart a: CGPoint, end b: CGPoint) -> CGFloat {
        let ab = CGPoint(x: b.x - a.x, y: b.y - a.y)
        let ap = CGPoint(x: point.x - a.x, y: point.y - a.y)
        let abLengthSquared = ab.x * ab.x + ab.y * ab.y
        if abLengthSquared == 0 {
            return hypot(ap.x, ap.y)
        }
        let t = max(0, min(1, (ap.x * ab.x + ap.y * ab.y) / abLengthSquared))
        let projection = CGPoint(x: a.x + ab.x * t, y: a.y + ab.y * t)
        return hypot(point.x - projection.x, point.y - projection.y)
    }

    private func renderPoint(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x, y: canvasSize.height - point.y)
    }

    private func drawSelectionBorder(in rect: NSRect) {
        NSColor.separatorColor.setStroke()
        let border = NSBezierPath(rect: rect.insetBy(dx: 1.5, dy: 1.5))
        border.lineWidth = 3
        border.stroke()
    }

    private func persistSelectedColor() {
        guard let rgbHex = rgbHexString(for: color) else { return }
        UserDefaults.standard.set(rgbHex, forKey: Self.annotationColorDefaultsKey)
    }

    private func rgbHexString(for color: NSColor) -> String? {
        guard let rgbColor = color.usingColorSpace(.deviceRGB) else { return nil }
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        rgbColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return String(format: "%02X%02X%02X", Int(round(red * 255)), Int(round(green * 255)), Int(round(blue * 255)))
    }

    private func makeTimestampedBaseName(now: Date = Date()) -> String {
        let formatter = Self.timestampFormatter
        formatter.timeZone = .autoupdatingCurrent
        return "QuickSnap-\(formatter.string(from: now))"
    }

    private func archiveExportPNGInBackground(pngData: Data, fileName: String) {
        let destinationDirectory = defaultExportDirectory
        DispatchQueue.global(qos: .utility).async {
            let destinationURL = destinationDirectory.appendingPathComponent(fileName)
            do {
                try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
                try pngData.write(to: destinationURL, options: .atomic)
            } catch {
                return
            }
        }
    }

    func addStroke(points: [CGPoint]) {
        guard points.count > 1 else { return }
        let stroke = Stroke(points: points, color: color, lineWidth: lineWidth)
        strokes.append(stroke)
        annotationHistory.append(.stroke(stroke.id))
        selectedAnnotation = nil
    }

    func addShape(kind: ShapeKind, start: CGPoint, end: CGPoint) {
        let shape = ShapeAnnotation(kind: kind, start: start, end: end, color: color, lineWidth: lineWidth)
        shapes.append(shape)
        annotationHistory.append(.shape(shape.id))
        selectedAnnotation = nil
    }
}

private func enrichedPayload(for capture: CaptureRecord, recognizedText: String) -> CapturePresetPayload? {
    var payload = capture.presetPayload
    var didChange = false

    if payload.browser.isEmpty, BrowserURLResolver.isSupportedBrowserApp(capture.sourceApp) {
        payload.browser = capture.sourceApp
        didChange = true
    }

    if capture.normalizedPresetID == "bug_report",
       payload.consoleSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
       let consoleSummary = ConsoleSignalExtractor.extractSummary(from: recognizedText) {
        payload.consoleSummary = consoleSummary
        didChange = true
    }

    return didChange ? payload : nil
}

private enum ConsoleSignalExtractor {
    private static let keywordSignals = [
        "uncaught",
        "typeerror",
        "referenceerror",
        "syntaxerror",
        "error",
        "exception",
        "failed",
        "cannot ",
        "undefined",
        "warning"
    ]

    static func extractSummary(from text: String) -> String? {
        let lines = text
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else { return nil }

        let matches = lines.filter { line in
            let folded = line.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            return keywordSignals.contains(where: { folded.contains($0) })
        }

        guard !matches.isEmpty else { return nil }
        return matches.prefix(3).joined(separator: "\n")
    }
}
