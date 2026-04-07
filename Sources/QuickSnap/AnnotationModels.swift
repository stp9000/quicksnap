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
    case text = "Text"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .pen: return "pencil.tip"
        case .rectangle: return "rectangle"
        case .arrow: return "arrow.up.right"
        case .text: return "textformat"
        }
    }
}

struct Stroke: Identifiable {
    var id = UUID()
    var points: [CGPoint]
    var color: NSColor
    var lineWidth: CGFloat
}

enum ShapeKind: String, Codable {
    case rectangle
    case arrow
}

struct ShapeAnnotation: Identifiable {
    var id = UUID()
    var kind: ShapeKind
    var start: CGPoint
    var end: CGPoint
    var color: NSColor
    var lineWidth: CGFloat
}

struct TextAnnotation: Identifiable {
    var id = UUID()
    var text: String
    var position: CGPoint
    var color: NSColor
    var fontSize: CGFloat
}

struct PersistedCaptureAnnotations: Codable, Hashable {
    var strokes: [PersistedStroke] = []
    var shapes: [PersistedShape] = []
    var texts: [PersistedTextAnnotation] = []

    var isEmpty: Bool {
        strokes.isEmpty && shapes.isEmpty && texts.isEmpty
    }
}

struct PersistedPoint: Codable, Hashable {
    var x: Double
    var y: Double
}

struct PersistedStroke: Codable, Hashable {
    var id: String
    var points: [PersistedPoint]
    var colorHex: String
    var lineWidth: Double
}

struct PersistedShape: Codable, Hashable {
    var id: String
    var kind: ShapeKind
    var start: PersistedPoint
    var end: PersistedPoint
    var colorHex: String
    var lineWidth: Double
}

struct PersistedTextAnnotation: Codable, Hashable {
    var id: String
    var text: String
    var position: PersistedPoint
    var colorHex: String
    var fontSize: Double
}

enum SelectedAnnotation: Equatable {
    case stroke(UUID)
    case shape(UUID)
    case text(UUID)
}

@MainActor
final class AnnotationDocument: ObservableObject {
    private static let annotationColorDefaultsKey = "quicksnap.annotationColorHex"
    private static let captureStoragePathDefaultsKey = "quicksnap.captureStorageRootPath"
    private static let markdownStoragePathDefaultsKey = "quicksnap.markdownStorageRootPath"
    private static let selectedPresetDefaultsKey = "quicksnap.selectedPresetID"
    private static let aiFeaturesEnabledDefaultsKey = "quicksnap.ai.enabled"
    private static let aiUsesPersonalKeyDefaultsKey = "quicksnap.ai.usesPersonalKey"
    private static let autoComposeBugReportsDefaultsKey = "quicksnap.ai.autoComposeBugReports"
    private static let openAIModelDefaultsKey = "quicksnap.ai.openaiModel"
    private static let githubOwnerDefaultsKey = "quicksnap.github.owner"
    private static let githubRepoDefaultsKey = "quicksnap.github.repo"
    private static let githubLabelsDefaultsKey = "quicksnap.github.labels"
    private static let jiraDomainDefaultsKey = "quicksnap.jira.domain"
    private static let jiraEmailDefaultsKey = "quicksnap.jira.email"
    private static let jiraProjectKeyDefaultsKey = "quicksnap.jira.projectKey"
    private static let jiraIssueTypeDefaultsKey = "quicksnap.jira.issueType"

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
    @Published var textAnnotations: [TextAnnotation] = []
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
    @Published var selectedSubmissionTarget: SubmissionTarget = .github {
        didSet {
            bugReportDraft.target = selectedSubmissionTarget
        }
    }
    @Published var bugReportDraft = BugReportDraft()
    @Published var isBugReportSubmissionSheetPresented = false
    @Published var isSubmittingBugReport = false
    @Published var submissionErrorMessage: String?
    @Published var lastSubmittedIssueURL: String?
    @Published var analysisErrorMessage: String?
    @Published var chatErrorMessage: String?
    @Published var chatInputText = ""
    @Published var isSendingChatMessage = false
    @Published private(set) var selectedCaptureChatMessages: [CaptureChatMessage] = []
    @Published var aiSettingsStatusMessage: String?
    @Published var isTestingOpenAIConnection = false
    @Published var aiFeaturesEnabled = true {
        didSet {
            UserDefaults.standard.set(aiFeaturesEnabled, forKey: Self.aiFeaturesEnabledDefaultsKey)
        }
    }
    @Published var aiUsesPersonalKey = false {
        didSet {
            UserDefaults.standard.set(aiUsesPersonalKey, forKey: Self.aiUsesPersonalKeyDefaultsKey)
        }
    }
    @Published var autoComposeBugReports = false {
        didSet {
            UserDefaults.standard.set(autoComposeBugReports, forKey: Self.autoComposeBugReportsDefaultsKey)
        }
    }
    @Published var openAIModel = "gpt-4o-mini" {
        didSet {
            UserDefaults.standard.set(openAIModel, forKey: Self.openAIModelDefaultsKey)
        }
    }
    @Published var openAIKeyDraft = ""
    @Published private(set) var hasSavedOpenAIKey = false
    @Published var githubPATDraft = ""
    @Published private(set) var hasSavedGitHubPAT = false
    @Published var githubOwner = "" {
        didSet { UserDefaults.standard.set(githubOwner, forKey: Self.githubOwnerDefaultsKey) }
    }
    @Published var githubRepo = "" {
        didSet { UserDefaults.standard.set(githubRepo, forKey: Self.githubRepoDefaultsKey) }
    }
    @Published var githubLabels = "" {
        didSet { UserDefaults.standard.set(githubLabels, forKey: Self.githubLabelsDefaultsKey) }
    }
    @Published var jiraDomain = "" {
        didSet { UserDefaults.standard.set(jiraDomain, forKey: Self.jiraDomainDefaultsKey) }
    }
    @Published var jiraEmail = "" {
        didSet { UserDefaults.standard.set(jiraEmail, forKey: Self.jiraEmailDefaultsKey) }
    }
    @Published var jiraProjectKey = "" {
        didSet { UserDefaults.standard.set(jiraProjectKey, forKey: Self.jiraProjectKeyDefaultsKey) }
    }
    @Published var jiraIssueType = "Bug" {
        didSet { UserDefaults.standard.set(jiraIssueType, forKey: Self.jiraIssueTypeDefaultsKey) }
    }
    @Published var jiraTokenDraft = ""
    @Published private(set) var hasSavedJiraToken = false
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
    private var pendingAutoOpenSubmissionCaptureID: String?
    private let defaultExportDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Pictures", isDirectory: true)
        .appendingPathComponent("QuickSnap", isDirectory: true)
    private var captureRepository: CaptureRepository?

    init() {
        captureRepository = buildCaptureRepository()
        selectedPresetID = UserDefaults.standard.string(forKey: Self.selectedPresetDefaultsKey) ?? "general"
        if UserDefaults.standard.object(forKey: Self.aiFeaturesEnabledDefaultsKey) == nil {
            aiFeaturesEnabled = true
        } else {
            aiFeaturesEnabled = UserDefaults.standard.bool(forKey: Self.aiFeaturesEnabledDefaultsKey)
        }
        aiUsesPersonalKey = UserDefaults.standard.bool(forKey: Self.aiUsesPersonalKeyDefaultsKey)
        autoComposeBugReports = UserDefaults.standard.bool(forKey: Self.autoComposeBugReportsDefaultsKey)
        openAIModel = UserDefaults.standard.string(forKey: Self.openAIModelDefaultsKey) ?? "gpt-4o-mini"
        hasSavedOpenAIKey = KeychainStore.loadOpenAIKey() != nil
        hasSavedGitHubPAT = KeychainStore.loadGitHubPAT() != nil
        githubOwner = UserDefaults.standard.string(forKey: Self.githubOwnerDefaultsKey) ?? ""
        githubRepo = UserDefaults.standard.string(forKey: Self.githubRepoDefaultsKey) ?? ""
        githubLabels = UserDefaults.standard.string(forKey: Self.githubLabelsDefaultsKey) ?? ""
        jiraDomain = UserDefaults.standard.string(forKey: Self.jiraDomainDefaultsKey) ?? ""
        jiraEmail = UserDefaults.standard.string(forKey: Self.jiraEmailDefaultsKey) ?? ""
        jiraProjectKey = UserDefaults.standard.string(forKey: Self.jiraProjectKeyDefaultsKey) ?? ""
        jiraIssueType = UserDefaults.standard.string(forKey: Self.jiraIssueTypeDefaultsKey) ?? "Bug"
        hasSavedJiraToken = KeychainStore.loadJiraToken() != nil

        if let savedHex = UserDefaults.standard.string(forKey: Self.annotationColorDefaultsKey) {
            color = NSColor(hex: savedHex)
        }

        reloadPresetDefinitions()
        resetBugReportDraft()

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
    var canRunAIAnalysis: Bool { aiFeaturesEnabled && selectedCapture != nil }
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

    var canSubmitToJira: Bool {
        selectedCapture != nil &&
            !jiraDomain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !jiraEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !jiraProjectKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !jiraIssueType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            hasSavedJiraToken
    }

    var canSubmitCurrentBugReport: Bool {
        switch selectedSubmissionTarget {
        case .github:
            return canSendToGitHub
        case .jira:
            return canSubmitToJira
        }
    }

    var captureLibraryPathText: String {
        captureRepository?.rootDirectory.path ?? "Unavailable"
    }

    var markdownStoragePathText: String {
        markdownStorageDirectory.path
    }

    var isUsingDefaultStorageLocation: Bool {
        UserDefaults.standard.string(forKey: Self.captureStoragePathDefaultsKey) == nil
    }

    var isUsingDefaultMarkdownStorageLocation: Bool {
        UserDefaults.standard.string(forKey: Self.markdownStoragePathDefaultsKey) == nil
    }

    var storageLocationSummaryText: String {
        isUsingDefaultStorageLocation ? "Default Application Support location" : "Custom storage location"
    }

    var markdownStorageSummaryText: String {
        isUsingDefaultMarkdownStorageLocation ? "Default folder under capture storage" : "Custom Markdown output location"
    }

    var currentPresetDescription: String {
        selectedPresetDefinition.description
    }

    var selectedCapturePrimaryURLText: String {
        selectedCapture?.primaryURL ?? ""
    }

    var selectedPreviewText: String? {
        if selectedSendPreviewKind == .githubIssueURL {
            return bugReportDraft.githubIssueURL(owner: githubOwner, repo: githubRepo)?.absoluteString
        }
        guard let selectedCapture else { return nil }
        return selectedCapture.previewText(for: selectedSendPreviewKind)
    }

    var selectedPreviewTitle: String {
        selectedSendPreviewKind.displayName
    }

    var savedOpenAIKeySummary: String {
        if !aiFeaturesEnabled {
            return "AI features are disabled. QuickSnap stays local-only."
        }
        return hasSavedOpenAIKey ? "Personal OpenAI key saved in Keychain" : "No OpenAI API key saved"
    }

    var savedGitHubPATSummary: String {
        hasSavedGitHubPAT ? "GitHub PAT saved in Keychain for future API mode" : "No GitHub PAT saved"
    }

    var savedJiraTokenSummary: String {
        hasSavedJiraToken ? "Jira API token saved in Keychain" : "No Jira API token saved"
    }

    func clearAnnotations(persist: Bool = true) {
        strokes.removeAll()
        shapes.removeAll()
        textAnnotations.removeAll()
        selectedAnnotation = nil
        annotationHistory.removeAll()
        if persist {
            persistAnnotationsForSelectedCapture()
        }
    }

    func loadImage(_ image: NSImage, capture: CaptureRecord? = nil, showsSelectionBorder: Bool = false) {
        backgroundImage = image
        selectedCaptureID = capture?.id
        selectedCaptureTagsText = capture?.tags.joined(separator: ", ") ?? ""
        selectedCapturePayload = capture?.presetPayload ?? CapturePresetPayload()
        selectedCaptureChatMessages = capture?.chatMessages ?? []
        seedBugReportDraft(from: capture)
        self.showsSelectionBorder = showsSelectionBorder
        let size = image.size
        if size.width > 0, size.height > 0 {
            canvasSize = size
        }
        applyPersistedAnnotations(capture?.annotations)
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
        seedBugReportDraft(from: capture)
        chatInputText = ""
        chatErrorMessage = nil

        guard capture.fileExists, let image = NSImage(contentsOf: capture.imageURL) else {
            backgroundImage = nil
            canvasSize = CGSize(width: 1280, height: 800)
            showsSelectionBorder = capture.showsSelectionBorder
            clearAnnotations(persist: false)
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

    func prepareBugReportDraftForSelectedCapture() {
        seedBugReportDraft(from: selectedCapture)
    }

    func openBugReportSubmissionSheet() {
        guard selectedCapture != nil else { return }
        prepareBugReportDraftForSelectedCapture()
        submissionErrorMessage = nil
        isBugReportSubmissionSheetPresented = true
    }

    func showAnalyzePanel() {
        rightPanelMode = .analyze
        isRightPanelVisible = true
    }

    func openSendPreview(_ kind: SendPreviewKind) {
        guard selectedCapture != nil else { return }
        if kind == .githubIssueURL {
            prepareBugReportDraftForSelectedCapture()
        }
        selectedSendPreviewKind = kind
        rightPanelMode = .send
        isRightPanelVisible = true
    }

    func closeRightPanel() {
        isRightPanelVisible = false
    }

    func runAIAnalysisForSelectedCapture() {
        guard aiFeaturesEnabled else {
            analysisErrorMessage = "AI features are disabled in Settings."
            statusMessage = "AI features are disabled"
            return
        }
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

    func saveGitHubPAT() {
        let trimmed = githubPATDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        do {
            try KeychainStore.saveGitHubPAT(trimmed)
            hasSavedGitHubPAT = true
            githubPATDraft = ""
            statusMessage = "Saved GitHub PAT"
        } catch {
            statusMessage = "QuickSnap could not save the GitHub PAT."
        }
    }

    func removeGitHubPAT() {
        KeychainStore.deleteGitHubPAT()
        hasSavedGitHubPAT = false
        githubPATDraft = ""
        statusMessage = "Removed GitHub PAT"
    }

    func saveJiraToken() {
        let trimmed = jiraTokenDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        do {
            try KeychainStore.saveJiraToken(trimmed)
            hasSavedJiraToken = true
            jiraTokenDraft = ""
            statusMessage = "Saved Jira API token"
        } catch {
            statusMessage = "QuickSnap could not save the Jira API token."
        }
    }

    func removeJiraToken() {
        KeychainStore.deleteJiraToken()
        hasSavedJiraToken = false
        jiraTokenDraft = ""
        statusMessage = "Removed Jira API token"
    }

    func testOpenAIConnection() {
        guard aiFeaturesEnabled else {
            analysisErrorMessage = "Enable AI features first."
            aiSettingsStatusMessage = "Enable AI features first."
            return
        }
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

    func copyRenderedImageToPasteboard(statusText: String = "Copied image to clipboard") {
        guard let renderedImage = renderAnnotatedImage().tiffRepresentation else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(renderedImage, forType: .tiff)
        statusMessage = statusText
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
            try markdownDocumentText(for: selectedCapture).write(to: url, atomically: true, encoding: .utf8)
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
        prepareBugReportDraftForSelectedCapture()
        submitCurrentBugReportDraftToGitHub()
    }

    func submitCurrentBugReportDraftToGitHub() {
        guard let url = bugReportDraft.githubIssueURL(owner: githubOwner, repo: githubRepo) else {
            statusMessage = "Configure a GitHub owner and repo first."
            submissionErrorMessage = statusMessage
            return
        }

        isSubmittingBugReport = true
        copyRenderedImageToPasteboard(statusText: "Copied screenshot for GitHub")
        NSWorkspace.shared.open(url)
        isSubmittingBugReport = false
        lastSubmittedIssueURL = url.absoluteString
        submissionErrorMessage = nil
        statusMessage = "Copied screenshot and opened GitHub issue draft"
    }

    func copyLastSubmittedIssueURL() {
        guard let lastSubmittedIssueURL, !lastSubmittedIssueURL.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(lastSubmittedIssueURL, forType: .string)
        statusMessage = "Copied submitted issue URL"
    }

    func openLastSubmittedIssueURL() {
        guard let lastSubmittedIssueURL, let url = URL(string: lastSubmittedIssueURL) else { return }
        NSWorkspace.shared.open(url)
        statusMessage = "Opened submitted issue"
    }

    func submitCurrentBugReport() {
        switch selectedSubmissionTarget {
        case .github:
            submitCurrentBugReportDraftToGitHub()
        case .jira:
            submitCurrentBugReportToJira()
        }
    }

    func submitCurrentBugReportToJira() {
        guard canSubmitToJira else {
            submissionErrorMessage = "Complete Jira settings and save a Jira API token first."
            statusMessage = "Jira settings are incomplete"
            return
        }
        guard let token = KeychainStore.loadJiraToken() else {
            submissionErrorMessage = "Save a Jira API token first."
            statusMessage = "No Jira API token saved"
            return
        }

        let title = bugReportDraft.title
        let body = bugReportDraft.body
        let domain = jiraDomain
        let email = jiraEmail
        let projectKey = jiraProjectKey
        let issueType = jiraIssueType
        let screenshotData = renderPNGDataForExport()
        let screenshotName = defaultExportFilename

        isSubmittingBugReport = true
        submissionErrorMessage = nil

        Task.detached(priority: .userInitiated) {
            do {
                let issue = try await JiraClient.createIssue(
                    domain: domain,
                    email: email,
                    token: token,
                    projectKey: projectKey,
                    issueType: issueType,
                    summary: title,
                    description: body
                )

                if let screenshotData {
                    try await JiraClient.attachFile(
                        domain: domain,
                        email: email,
                        token: token,
                        issueKey: issue.key,
                        imageData: screenshotData,
                        filename: screenshotName
                    )
                }

                await MainActor.run {
                    self.isSubmittingBugReport = false
                    self.lastSubmittedIssueURL = issue.browseURL.absoluteString
                    self.submissionErrorMessage = nil
                    self.statusMessage = "Created Jira issue \(issue.key)"
                    NSWorkspace.shared.open(issue.browseURL)
                }
            } catch {
                await MainActor.run {
                    self.isSubmittingBugReport = false
                    self.submissionErrorMessage = self.readableSubmissionError(error)
                    self.statusMessage = "Jira submission failed"
                }
            }
        }
    }

    func copySelectedCaptureImageForGitHub() {
        guard selectedCapture != nil else { return }
        copyRenderedImageToPasteboard(statusText: "Copied screenshot for GitHub")
    }

    func updateBugReportDraftLabels(from value: String) {
        bugReportDraft.labels = value
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var bugReportDraftLabelsText: String {
        bugReportDraft.labels.joined(separator: ", ")
    }

    func copyIssueDraftToPasteboard() {
        guard let selectedCapture else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString("# \(selectedCapture.preferredBugReportTitle)\n\n\(selectedCapture.preferredBugReportBody)", forType: .string)
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

    func revealMarkdownStorageInFinder() {
        let directory = markdownStorageDirectory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        NSWorkspace.shared.activateFileViewerSelecting([directory])
        statusMessage = "Revealed Markdown storage"
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

    func chooseMarkdownStorageLocation() {
        let panel = NSOpenPanel()
        panel.prompt = "Choose"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose where QuickSnap should store generated Markdown files for the Markdown preset."
        panel.directoryURL = markdownStorageDirectory.deletingLastPathComponent()

        guard panel.runModal() == .OK, let url = panel.url else { return }
        UserDefaults.standard.set(url.path, forKey: Self.markdownStoragePathDefaultsKey)
        statusMessage = "Updated Markdown storage location"
        refreshCaptureLibrary(preserving: selectedCaptureID)
    }

    func resetStorageLocationToDefault() {
        UserDefaults.standard.removeObject(forKey: Self.captureStoragePathDefaultsKey)
        reloadCaptureRepository()
        statusMessage = "Reset capture storage to the default location"
    }

    func resetMarkdownStorageLocationToDefault() {
        UserDefaults.standard.removeObject(forKey: Self.markdownStoragePathDefaultsKey)
        statusMessage = "Reset Markdown storage to the default location"
        refreshCaptureLibrary(preserving: selectedCaptureID)
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
                    annotations: existing.annotations,
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
                    annotations: existing.annotations,
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
        case .text(let id):
            textAnnotations.removeAll { $0.id == id }
        }
        selectedAnnotation = nil
        persistAnnotationsForSelectedCapture()
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
        case .text(let id):
            textAnnotations.removeAll { $0.id == id }
            annotationHistory.removeAll { $0 == .text(id) }
        }
        selectedAnnotation = nil
        persistAnnotationsForSelectedCapture()
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
        if let text = textAnnotations.last(where: { pointHitsText(point, textAnnotation: $0) }) {
            selectedAnnotation = .text(text.id)
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
        let pageClip = selectedPresetID == "markdown" ? BrowserPageClipper.clip(for: context) : nil
        let presetPayload = payloadAdjustedForSelectedPreset(
            from: initialPayload(for: selectedPresetID, capturedURL: capturedURL, browserMetadata: browserMetadata, pageClip: pageClip)
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
            var record = try captureRepository.createCapture(from: draft)
            if record.normalizedPresetID == "markdown" {
                let enrichedMarkdownPayload = createMarkdownPayload(for: record, context: context, pageClip: pageClip)
                try? captureRepository.updatePresetPayload(for: record.id, payload: enrichedMarkdownPayload)
                record = record.withPresetPayload(enrichedMarkdownPayload)
            }
            refreshCaptureLibrary(preserving: record.id)
            openCapture(record)
            statusMessage = "Saved \(record.presetDefinition.name) capture"
            if record.normalizedPresetID == "bug_report", autoComposeBugReports, aiFeaturesEnabled {
                pendingAutoOpenSubmissionCaptureID = record.id
                runAIAnalysisForSelectedCapture()
            }
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
            if capture.normalizedPresetID == "markdown" {
                let configuration = await MainActor.run { self.openAIConfiguration }
                if let configuration,
                   let aiPayload = try? await self.aiEnhancedMarkdownPayload(for: capture, recognizedText: recognizedText, configuration: configuration) {
                    try? captureRepository.updatePresetPayload(for: capture.id, payload: aiPayload)
                }
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
                    if self.pendingAutoOpenSubmissionCaptureID == selectedCapture.id {
                        self.pendingAutoOpenSubmissionCaptureID = nil
                        self.prepareBugReportDraftForSelectedCapture()
                        self.isBugReportSubmissionSheetPresented = true
                    }
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
                    if self.pendingAutoOpenSubmissionCaptureID == selectedCapture.id {
                        self.pendingAutoOpenSubmissionCaptureID = nil
                        self.prepareBugReportDraftForSelectedCapture()
                        self.isBugReportSubmissionSheetPresented = true
                    }
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
            seedBugReportDraft(from: selectedCapture)
        } else {
            selectedCaptureTagsText = ""
            selectedCapturePayload = CapturePresetPayload()
            selectedCaptureChatMessages = []
            resetBugReportDraft()
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
            clearAnnotations(persist: false)
        }
    }

    private func buildCaptureRepository() -> CaptureRepository? {
        let customPath = UserDefaults.standard.string(forKey: Self.captureStoragePathDefaultsKey)
        let rootURL = customPath.map { URL(fileURLWithPath: $0, isDirectory: true) }
        return try? CaptureRepository(rootDirectory: rootURL)
    }

    private var openAIConfiguration: OpenAIAnalysisConfiguration? {
        guard aiFeaturesEnabled,
              aiUsesPersonalKey,
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

    private func initialPayload(for presetID: String, capturedURL: String?, browserMetadata: BrowserDebugMetadata?, pageClip: BrowserPageClipPayload?) -> CapturePresetPayload {
        var payload = CapturePresetPayload()
        if let capturedURL {
            switch presetID {
            case "bug_report", "ui_issue", "markdown":
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
            if payload.userAgent.isEmpty {
                payload.userAgent = browserMetadata.userAgent
            }
            if payload.referrerURL.isEmpty {
                payload.referrerURL = browserMetadata.referrerURL
            }
            if payload.scriptSources.isEmpty {
                payload.scriptSources = browserMetadata.scriptSources
            }
            if payload.failedResources.isEmpty {
                payload.failedResources = browserMetadata.failedResources
            }
            if payload.visibleErrors.isEmpty {
                payload.visibleErrors = browserMetadata.visibleErrors
            }
        }
        if let pageClip {
            if payload.pageTitle.isEmpty {
                payload.pageTitle = pageClip.pageTitle
            }
            if payload.canonicalURL.isEmpty {
                payload.canonicalURL = pageClip.canonicalURL
            }
            if payload.markdownClipExcerpt.isEmpty {
                payload.markdownClipExcerpt = pageClip.excerpt
            }
            if payload.clippedMarkdownContent.isEmpty {
                payload.clippedMarkdownContent = pageClip.markdown
            }
            if payload.markdownClipStatus.isEmpty {
                payload.markdownClipStatus = pageClip.markdown.isEmpty ? MarkdownClipStatus.failed.rawValue : MarkdownClipStatus.dom.rawValue
            }
        }
        return payload
    }

    private var markdownStorageDirectory: URL {
        if let customPath = UserDefaults.standard.string(forKey: Self.markdownStoragePathDefaultsKey),
           !customPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return URL(fileURLWithPath: customPath, isDirectory: true)
        }

        if let captureRepository {
            return captureRepository.rootDirectory.appendingPathComponent("Markdown", isDirectory: true)
        }

        let defaultRoot = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("QuickSnap", isDirectory: true)
        return defaultRoot.appendingPathComponent("Markdown", isDirectory: true)
    }

    private func markdownDocumentText(for capture: CaptureRecord) -> String {
        if capture.normalizedPresetID != "markdown" {
            return capture.markdownDocument
        }

        let path = capture.presetPayload.markdownFilePath.trimmingCharacters(in: .whitespacesAndNewlines)
        if !path.isEmpty,
           FileManager.default.fileExists(atPath: path),
           let text = try? String(contentsOfFile: path, encoding: .utf8),
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return text
        }

        return capture.markdownDocument
    }

    private func createMarkdownPayload(for capture: CaptureRecord, context: FrontmostCaptureContext, pageClip: BrowserPageClipPayload?) -> CapturePresetPayload {
        var payload = capture.presetPayload
        if payload.browser.isEmpty, BrowserURLResolver.isSupportedBrowserApp(capture.sourceApp) {
            payload.browser = capture.sourceApp
        }

        let domMarkdown = pageClip?.markdown.trimmingCharacters(in: .whitespacesAndNewlines) ?? payload.clippedMarkdownContent.trimmingCharacters(in: .whitespacesAndNewlines)
        if !domMarkdown.isEmpty {
            payload.clippedMarkdownContent = domMarkdown
            payload.markdownClipStatus = MarkdownClipStatus.dom.rawValue
        } else {
            payload.clippedMarkdownContent = fallbackMarkdownBody(for: capture, pageClip: pageClip)
            payload.markdownClipStatus = BrowserURLResolver.isSupportedBrowserApp(capture.sourceApp) ? MarkdownClipStatus.ocrFallback.rawValue : MarkdownClipStatus.unavailable.rawValue
        }

        if payload.pageTitle.isEmpty {
            payload.pageTitle = pageClip?.pageTitle ?? capture.displayTitle
        }
        if payload.canonicalURL.isEmpty {
            payload.canonicalURL = pageClip?.canonicalURL ?? payload.urlString
        }
        if payload.markdownClipExcerpt.isEmpty {
            payload.markdownClipExcerpt = pageClip?.excerpt ?? firstMeaningfulExcerpt(from: payload.clippedMarkdownContent)
        }

        do {
            let markdownURL = try ensureMarkdownFile(for: capture.withPresetPayload(payload))
            payload.markdownFilePath = markdownURL.path
        } catch {
            payload.markdownFilePath = ""
            libraryErrorMessage = "QuickSnap saved the capture, but could not write the Markdown file."
        }

        return payload
    }

    private func ensureMarkdownFile(for capture: CaptureRecord) throws -> URL {
        let directory = markdownStorageDirectory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileName = "\(capture.exportBaseName)-\(capture.id).md"
        let url = directory.appendingPathComponent(fileName)
        try capture.markdownDocument.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func fallbackMarkdownBody(for capture: CaptureRecord, pageClip: BrowserPageClipPayload?) -> String {
        var lines: [String] = []
        if let excerpt = pageClip?.excerpt, !excerpt.isEmpty {
            lines.append(excerpt)
        }
        if !capture.ocrText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if !lines.isEmpty {
                lines.append("")
            }
            lines.append(capture.ocrText.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        if lines.isEmpty {
            lines.append("No structured page text was available from this capture.")
        }
        return lines.joined(separator: "\n\n")
    }

    private func firstMeaningfulExcerpt(from markdown: String) -> String {
        markdown
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty && !$0.hasPrefix("#") && !$0.hasPrefix("- ") }) ?? ""
    }

    private func aiEnhancedMarkdownPayload(for capture: CaptureRecord, recognizedText: String, configuration: OpenAIAnalysisConfiguration) async throws -> CapturePresetPayload {
        guard capture.presetPayload.markdownClipStatus != MarkdownClipStatus.dom.rawValue else {
            return capture.presetPayload
        }

        let prompt = """
        Convert this web capture into clean Markdown. Return only Markdown.

        Source App: \(capture.sourceApp)
        Window Title: \(capture.windowTitle)
        URL: \(capture.primaryURL ?? "Unavailable")
        Page Title: \(capture.presetPayload.pageTitle)
        Existing Markdown:
        \(capture.presetPayload.clippedMarkdownContent)

        OCR Text:
        \(recognizedText)
        """

        let markdown = try await CaptureAnalysisService.generateMarkdown(
            prompt: prompt,
            imageURL: capture.imageURL,
            configuration: configuration
        ).trimmingCharacters(in: .whitespacesAndNewlines)

        guard !markdown.isEmpty else {
            return capture.presetPayload
        }

        var payload = capture.presetPayload
        payload.clippedMarkdownContent = markdown
        payload.markdownClipStatus = MarkdownClipStatus.aiFallback.rawValue
        if payload.markdownClipExcerpt.isEmpty {
            payload.markdownClipExcerpt = firstMeaningfulExcerpt(from: markdown)
        }
        if payload.pageTitle.isEmpty {
            payload.pageTitle = capture.displayTitle
        }
        if let url = try? ensureMarkdownFile(for: capture.withPresetPayload(payload)) {
            payload.markdownFilePath = url.path
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

    private func seedBugReportDraft(from capture: CaptureRecord?) {
        guard let capture else {
            resetBugReportDraft()
            return
        }

        bugReportDraft = capture.bugReportDraft(
            defaultLabels: githubLabels,
            target: selectedSubmissionTarget,
            screenshotHandlingMode: .clipboard
        )
    }

    private func resetBugReportDraft() {
        bugReportDraft = BugReportDraft(target: selectedSubmissionTarget)
    }

    private func readableSubmissionError(_ error: Error) -> String {
        if let jiraError = error as? JiraClientError {
            switch jiraError {
            case .invalidDomain:
                return "QuickSnap could not build the Jira API URL from the configured domain."
            case .badResponse:
                return "Jira returned an unexpected response."
            case .apiError(let message):
                return message
            }
        }
        return error.localizedDescription
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
        for text in textAnnotations { drawTextAnnotation(text, highlighted: false) }
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

    private func drawTextAnnotation(_ annotation: TextAnnotation, highlighted: Bool) {
        let point = renderPoint(annotation.position)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: annotation.fontSize, weight: .semibold),
            .foregroundColor: highlighted ? NSColor.systemBlue : annotation.color
        ]
        NSString(string: annotation.text).draw(at: point, withAttributes: attributes)
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

    private func pointHitsText(_ point: CGPoint, textAnnotation: TextAnnotation) -> Bool {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: textAnnotation.fontSize, weight: .semibold)
        ]
        let size = NSString(string: textAnnotation.text).size(withAttributes: attributes)
        let rect = CGRect(x: textAnnotation.position.x, y: textAnnotation.position.y, width: size.width, height: size.height)
            .insetBy(dx: -8, dy: -6)
        return rect.contains(point)
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
        persistAnnotationsForSelectedCapture()
    }

    func addShape(kind: ShapeKind, start: CGPoint, end: CGPoint) {
        let shape = ShapeAnnotation(kind: kind, start: start, end: end, color: color, lineWidth: lineWidth)
        shapes.append(shape)
        annotationHistory.append(.shape(shape.id))
        selectedAnnotation = nil
        persistAnnotationsForSelectedCapture()
    }

    func addTextAnnotation(_ text: String, at position: CGPoint) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let annotation = TextAnnotation(
            text: trimmed,
            position: position,
            color: color,
            fontSize: max(14, lineWidth * 5)
        )
        textAnnotations.append(annotation)
        annotationHistory.append(.text(annotation.id))
        selectedAnnotation = nil
        persistAnnotationsForSelectedCapture()
    }

    func moveSelectedTextAnnotation(to position: CGPoint) {
        guard case .text(let id) = selectedAnnotation,
              let index = textAnnotations.firstIndex(where: { $0.id == id }) else {
            return
        }
        textAnnotations[index].position = position
        persistAnnotationsForSelectedCapture()
    }

    func updateSelectedTextAnnotation(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              case .text(let id) = selectedAnnotation,
              let index = textAnnotations.firstIndex(where: { $0.id == id }) else {
            return
        }
        textAnnotations[index].text = trimmed
        persistAnnotationsForSelectedCapture()
    }

    func selectedTextAnnotation() -> TextAnnotation? {
        guard case .text(let id) = selectedAnnotation else { return nil }
        return textAnnotations.first(where: { $0.id == id })
    }

    private func applyPersistedAnnotations(_ persisted: PersistedCaptureAnnotations?) {
        guard let persisted else {
            clearAnnotations(persist: false)
            return
        }

        strokes = persisted.strokes.map { stroke in
            Stroke(
                id: UUID(uuidString: stroke.id) ?? UUID(),
                points: stroke.points.map { CGPoint(x: $0.x, y: $0.y) },
                color: NSColor(hex: stroke.colorHex),
                lineWidth: CGFloat(stroke.lineWidth)
            )
        }
        shapes = persisted.shapes.map { shape in
            ShapeAnnotation(
                id: UUID(uuidString: shape.id) ?? UUID(),
                kind: shape.kind,
                start: CGPoint(x: shape.start.x, y: shape.start.y),
                end: CGPoint(x: shape.end.x, y: shape.end.y),
                color: NSColor(hex: shape.colorHex),
                lineWidth: CGFloat(shape.lineWidth)
            )
        }
        textAnnotations = persisted.texts.map { text in
            TextAnnotation(
                id: UUID(uuidString: text.id) ?? UUID(),
                text: text.text,
                position: CGPoint(x: text.position.x, y: text.position.y),
                color: NSColor(hex: text.colorHex),
                fontSize: CGFloat(text.fontSize)
            )
        }
        selectedAnnotation = nil
        annotationHistory.removeAll()
    }

    private func persistAnnotationsForSelectedCapture() {
        guard let captureRepository, let selectedCaptureID else { return }
        do {
            try captureRepository.updateAnnotations(
                for: selectedCaptureID,
                annotations: currentPersistedAnnotations()
            )
            updateCachedCaptureAnnotations(for: selectedCaptureID, annotations: currentPersistedAnnotations())
        } catch {
            libraryErrorMessage = "QuickSnap could not save annotations for this capture."
        }
    }

    private func currentPersistedAnnotations() -> PersistedCaptureAnnotations {
        PersistedCaptureAnnotations(
            strokes: strokes.compactMap { stroke in
                guard let colorHex = rgbHexString(for: stroke.color) else { return nil }
                return PersistedStroke(
                    id: stroke.id.uuidString,
                    points: stroke.points.map { PersistedPoint(x: $0.x, y: $0.y) },
                    colorHex: colorHex,
                    lineWidth: Double(stroke.lineWidth)
                )
            },
            shapes: shapes.compactMap { shape in
                guard let colorHex = rgbHexString(for: shape.color) else { return nil }
                return PersistedShape(
                    id: shape.id.uuidString,
                    kind: shape.kind,
                    start: PersistedPoint(x: shape.start.x, y: shape.start.y),
                    end: PersistedPoint(x: shape.end.x, y: shape.end.y),
                    colorHex: colorHex,
                    lineWidth: Double(shape.lineWidth)
                )
            },
            texts: textAnnotations.compactMap { text in
                guard let colorHex = rgbHexString(for: text.color) else { return nil }
                return PersistedTextAnnotation(
                    id: text.id.uuidString,
                    text: text.text,
                    position: PersistedPoint(x: text.position.x, y: text.position.y),
                    colorHex: colorHex,
                    fontSize: Double(text.fontSize)
                )
            }
        )
    }

    private func updateCachedCaptureAnnotations(for captureID: String, annotations: PersistedCaptureAnnotations) {
        allCaptures = allCaptures.map { record in
            guard record.id == captureID else { return record }
            return record.withAnnotations(annotations)
        }
        captures = captures.map { record in
            guard record.id == captureID else { return record }
            return record.withAnnotations(annotations)
        }
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

    if capture.normalizedPresetID == "bug_report",
       payload.visibleErrors.isEmpty {
        let visibleErrors = VisibleErrorExtractor.extract(from: recognizedText)
        if !visibleErrors.isEmpty {
            payload.visibleErrors = visibleErrors
            didChange = true
        }
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

private enum VisibleErrorExtractor {
    private static let keywordSignals = [
        "error",
        "warning",
        "failed",
        "unable",
        "invalid",
        "exception",
        "denied",
        "not found"
    ]

    static func extract(from text: String) -> [String] {
        Array(text
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { line in
                let lowered = line.lowercased()
                return keywordSignals.contains(where: { lowered.contains($0) })
            }
            .prefix(5))
    }
}
