import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var document: AnnotationDocument
    @EnvironmentObject var skinManager: SkinManager
    @StateObject private var colorPanel = ColorPanelCoordinator()
    @State private var inspectorShowsAllFields = false
    @State private var isHistorySidebarVisible = true

    private var skin: AppSkin { skinManager.current }
    private var toolbarIconColor: Color { Color.white.opacity(skin.isGlass ? 0.82 : 0.9) }

    var body: some View {
        HSplitView {
            if isHistorySidebarVisible {
                historySidebar
                    .frame(minWidth: 240, idealWidth: 290, maxWidth: 420)
            }

            VStack(spacing: 0) {
                toolBar

                Rectangle()
                    .fill(skin.isModern ? skin.border : skin.separator)
                    .frame(height: 1)

                canvasViewport
                    .background(canvasBackground)

                Rectangle()
                    .fill(skin.isModern ? skin.border : skin.separator)
                    .frame(height: 1)

                exportFooter
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(windowBackground)

            if document.isRightPanelVisible {
                workspacePanel
                    .frame(minWidth: 280, idealWidth: 360, maxWidth: 520)
            }
        }
        .background(windowBackground)
        .background(WindowTransparencyHelper(isGlass: skin.isGlass))
        .sheet(isPresented: $document.isWindowPickerPresented) {
            WindowPickerSheet(document: document, skin: skin)
        }
        .sheet(isPresented: $document.isBugReportSubmissionSheetPresented) {
            BugReportSubmissionSheet(document: document, skin: skin)
        }
        .onDeleteCommand {
            document.deleteSelectedAnnotation()
        }
    }

    private var historySidebar: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Capture Library")
                    .font(skin.primaryFont(size: 13))
                    .foregroundColor(skin.accent)

                TextField("Search OCR, preset, app, title, tags", text: $document.searchText)
                    .textFieldStyle(.roundedBorder)

                filterStrip

                Text(document.captureCountSummary)
                    .font(.caption)
                    .foregroundColor(skin.textSecondary)

                if let libraryErrorMessage = document.libraryErrorMessage {
                    Text(libraryErrorMessage)
                        .font(.caption)
                        .foregroundColor(.red.opacity(0.9))
                }
            }
            .padding(16)
            .background(toolbarBackground)

            VSplitView {
                Group {
                    if document.captures.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 24))
                                .foregroundColor(skin.accentDim)
                            Text("No captures yet")
                                .font(skin.primaryFont(size: 13))
                            Text(document.searchText.isEmpty ? "Take a screen capture to start building searchable history." : "Try a different search or filter to reveal more saved captures.")
                                .font(.caption)
                                .foregroundColor(skin.textSecondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 220)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(sidebarBackground)
                    } else {
                        List(document.captures) { capture in
                            Button {
                                document.openCapture(capture)
                            } label: {
                                CaptureRowView(capture: capture, isSelected: document.selectedCaptureID == capture.id, timestamp: document.timelineTimestamp(for: capture), skin: skin)
                            }
                            .buttonStyle(.plain)
                            .listRowInsets(EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10))
                            .listRowBackground(Color.clear)
                        }
                        .listStyle(.sidebar)
                        .scrollContentBackground(.hidden)
                        .background(sidebarBackground)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .frame(minHeight: 260, idealHeight: 360)

                ScrollView {
                    selectedCaptureInspector
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minHeight: 180, idealHeight: 280)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(toolbarBackground)
            }
            .animation(nil, value: document.searchText)
            .animation(nil, value: document.captureCountSummary)
        }
        .background(sidebarBackground)
    }

    private var filterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(CaptureFilter.allCases) { filter in
                    Button {
                        document.activeFilter = filter
                    } label: {
                        Text(filter.displayName)
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(filter == document.activeFilter ? skin.accentOverlay : Color.white.opacity(0.04))
                            .foregroundColor(filter == document.activeFilter ? skin.accent : skin.textSecondary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var selectedCaptureInspector: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let capture = document.selectedCapture {
                Text("Selected Capture")
                    .font(skin.primaryFont(size: 12))
                    .foregroundColor(skin.accent)

                ForEach(displayedInspectorFields(for: capture), id: \.label) { field in
                    if field.isLink {
                        metadataLinkRow(label: field.label, value: field.value)
                    } else {
                        metadataRow(label: field.label, value: field.value)
                    }
                }

                if shouldShowInspectorToggle(for: capture) {
                    Button(inspectorShowsAllFields ? "Show Default Fields" : "View All Fields") {
                        inspectorShowsAllFields.toggle()
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(skin.accent)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Tags")
                        .font(.caption)
                        .foregroundColor(skin.textSecondary)
                    TextField("comma, separated, tags", text: $document.selectedCaptureTagsText)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            document.saveSelectedCaptureTags()
                        }
                    Button("Save Tags") {
                        document.saveSelectedCaptureTags()
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(skin.accent)
                }

                Button("Reveal Library in Finder") {
                    document.revealCaptureLibraryInFinder()
                }
                .buttonStyle(.borderless)
                .foregroundColor(skin.accent)
            } else {
                Text("Selected Capture")
                    .font(skin.primaryFont(size: 12))
                    .foregroundColor(skin.accent)
                Text("Choose a stored capture to inspect metadata and tags.")
                    .font(.caption)
                    .foregroundColor(skin.textSecondary)
            }
        }
        .padding(16)
        .onChange(of: document.selectedCaptureID) { _ in
            inspectorShowsAllFields = false
        }
    }

    private func metadataRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(skin.textSecondary)
            Text(value.isEmpty ? "Unavailable" : value)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(2)
        }
    }

    private func metadataLinkRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(skin.textSecondary)

            if let url = URL(string: value), !value.isEmpty {
                Link(value, destination: url)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(2)
            } else {
                Text(value.isEmpty ? "Unavailable" : value)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(2)
            }
        }
    }

    private func displayedInspectorFields(for capture: CaptureRecord) -> [InspectorField] {
        let allFields = inspectorFields(for: capture)
        if inspectorShowsAllFields {
            return allFields
        }
        return Array(allFields.prefix(6))
    }

    private func shouldShowInspectorToggle(for capture: CaptureRecord) -> Bool {
        inspectorFields(for: capture).count > 6
    }

    private func inspectorFields(for capture: CaptureRecord) -> [InspectorField] {
        let baseFields: [InspectorField] = [
            InspectorField(label: "Preset", value: capture.presetDefinition.name),
            InspectorField(label: "Capture ID", value: capture.sourceDisplayLabel),
            InspectorField(label: "Title", value: capture.displayTitle),
            InspectorField(label: "Source", value: capture.displaySubtitle),
            InspectorField(label: "URL", value: document.selectedCapturePrimaryURLText, isLink: true),
            InspectorField(label: "Browser", value: capture.presetPayload.browser),
            InspectorField(label: "OCR", value: capture.ocrStatus.displayName),
            InspectorField(label: "Status", value: capture.fileExists ? "Available locally" : "Image file missing")
        ]

        let detailFields: [InspectorField]
        switch capture.normalizedPresetID {
        case "markdown":
            detailFields = [
                InspectorField(label: "Page Title", value: capture.presetPayload.pageTitle),
                InspectorField(label: "Viewport", value: capture.presetPayload.viewport),
                InspectorField(label: "Referrer", value: capture.presetPayload.referrerURL, isLink: true),
                InspectorField(label: "Clip Status", value: capture.presetPayload.markdownClipStatus),
                InspectorField(label: "Markdown File", value: capture.presetPayload.markdownFilePath),
                InspectorField(label: "Excerpt", value: capture.presetPayload.markdownClipExcerpt)
            ]
        case "bug_report":
            detailFields = [
                InspectorField(label: "Viewport", value: capture.presetPayload.viewport),
                InspectorField(label: "Page Title", value: capture.presetPayload.pageTitle),
                InspectorField(label: "Referrer", value: capture.presetPayload.referrerURL, isLink: true),
                InspectorField(label: "Console Summary", value: capture.presetPayload.consoleSummary),
                InspectorField(label: "Error Message", value: capture.presetPayload.errorMessage),
                InspectorField(label: "Stack Trace", value: capture.presetPayload.stackTrace),
                InspectorField(label: "Visible Errors", value: capture.presetPayload.visibleErrors.joined(separator: "\n")),
                InspectorField(label: "Failed Resources", value: capture.presetPayload.failedResources.joined(separator: "\n")),
                InspectorField(label: "Script Sources", value: capture.presetPayload.scriptSources.joined(separator: "\n"))
            ]
        default:
            if let custom = capture.presetDefinition.customDefinition {
                detailFields = custom.fieldNames.map { field in
                    InspectorField(label: field, value: capture.presetPayload.customFields[field, default: ""])
                }
            } else {
                detailFields = []
            }
        }

        let fields = inspectorShowsAllFields ? baseFields + detailFields : baseFields
        return fields.filter { !$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    @ViewBuilder
    private var windowBackground: some View {
        if skin.isGlass {
            Rectangle().fill(.ultraThinMaterial)
        } else {
            skin.panelBg
        }
    }

    @ViewBuilder
    private var canvasBackground: some View {
        if skin.isGlass {
            Color.clear
        } else {
            skin.panelBg
        }
    }

    @ViewBuilder
    private var sidebarBackground: some View {
        if skin.isGlass {
            Rectangle().fill(.regularMaterial)
        } else if skin.isModern {
            skin.surface
        } else {
            skin.panelBg
        }
    }

    private var emptyCanvas: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(.system(size: 28))
                .foregroundColor(skin.accentDim)
            Text("Capture, search, and annotate")
                .font(skin.primaryFont(size: 16))
                .foregroundColor(skin.accent)
            Text("Use the capture buttons above to create a stored screenshot you can search, reopen, export, and annotate.")
                .font(.caption)
                .foregroundColor(skin.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity, minHeight: 420)
        .padding(32)
    }

    private var workspacePanel: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Picker("Workspace", selection: $document.rightPanelMode) {
                    ForEach(WorkspacePanelMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Button {
                    document.closeRightPanel()
                } label: {
                    Image(systemName: "xmark")
                        .foregroundColor(toolbarIconColor)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(currentButtonStyle())
                .help("Close Workspace Panel")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(sidebarBackground)

            Rectangle()
                .fill(skin.isModern ? skin.border : skin.separator)
                .frame(height: 1)

            Group {
                if document.rightPanelMode == .analyze {
                    analysisPanelContent
                } else {
                    sendPanelContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(sidebarBackground)
        }
        .background(sidebarBackground)
    }

    private var analysisPanelContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Analyze")
                    .font(skin.primaryFont(size: 13))
                    .foregroundColor(skin.accent)

                if let capture = document.selectedCapture {
                    HStack(spacing: 12) {
                        Button("Run Local Analysis") {
                            document.runLocalAnalysisForSelectedCapture()
                        }
                        .buttonStyle(currentButtonStyle())

                        Button("Run AI Analysis") {
                            document.runAIAnalysisForSelectedCapture()
                        }
                        .buttonStyle(currentButtonStyle())
                        .disabled(!document.canRunAIAnalysis)
                    }

                    if capture.isAnalysisStale {
                        Text("Stored analysis was created for a different preset and may be stale.")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }

                    switch capture.analysis.status {
                    case .idle:
                        Text("No analysis yet for this capture.")
                            .font(.caption)
                            .foregroundColor(skin.textSecondary)
                    case .pending:
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Analyzing selected capture...")
                                .font(.caption)
                                .foregroundColor(skin.textSecondary)
                        }
                    case .failed:
                        Text(document.analysisErrorMessage ?? "Analysis failed for this capture.")
                            .font(.caption)
                            .foregroundColor(.red.opacity(0.9))
                    case .complete:
                        HStack(spacing: 10) {
                            if !capture.analysis.severity.isEmpty {
                                analysisBadge(capture.analysis.severity.capitalized, tint: Color.orange.opacity(0.18), textColor: Color.orange)
                            }
                            analysisBadge(capture.presetDefinition.name, tint: skin.accent.opacity(0.14), textColor: skin.accent)
                        }
                        if !capture.analysis.issueTitle.isEmpty {
                            analysisHeadlineBlock(label: "Issue Title", value: capture.analysis.issueTitle)
                        }
                        analysisHeadlineBlock(label: "Summary", value: capture.analysis.summary)
                        if !capture.analysis.tags.isEmpty {
                            analysisTagsBlock(capture.analysis.tags)
                        }
                        if !capture.analysis.recommendedActions.isEmpty {
                            analysisRecommendedActionsBlock(capture.analysis.recommendedActions)
                        }
                    }
                } else {
                    Text("Select a stored capture to analyze.")
                        .font(.caption)
                        .foregroundColor(skin.textSecondary)
                }
            }
            .padding(16)
        }
    }

    private func analysisHeadlineBlock(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundColor(skin.textSecondary)
            Text(value.isEmpty ? "Unavailable" : value)
                .font(.system(size: label == "Issue Title" ? 13 : 12, weight: label == "Issue Title" ? .semibold : .medium))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
    }

    private func analysisBadge(_ text: String, tint: Color, textColor: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(textColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(tint)
            .clipShape(Capsule())
    }

    private func analysisTagsBlock(_ tags: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tags")
                .font(.caption2)
                .foregroundColor(skin.textSecondary)
            FlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(skin.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(skin.isGlass ? 0.08 : 0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
    }

    private func analysisRecommendedActionsBlock(_ actions: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recommended Actions")
                .font(.caption2)
                .foregroundColor(skin.textSecondary)
            ForEach(actions, id: \.self) { action in
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(skin.accent.opacity(0.7), lineWidth: 1.5)
                        .frame(width: 18, height: 18)
                    Text(action)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(Color.white.opacity(skin.isGlass ? 0.08 : 0.04))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private var sendPanelContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(document.selectedPreviewTitle)
                    .font(skin.primaryFont(size: 13))
                    .foregroundColor(skin.accent)
                Spacer()
                if document.selectedPreviewText != nil {
                    Button("Copy") {
                        document.copySelectedPreviewArtifact()
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(skin.accent)

                    if document.selectedSendPreviewKind == .markdownDocument {
                        Button("Export") {
                            document.exportSelectedPreviewArtifactIfAvailable()
                        }
                        .buttonStyle(.borderless)
                        .foregroundColor(skin.accent)
                    }

                    if document.selectedSendPreviewKind == .githubIssueURL && document.canSendToGitHub {
                        Button("Review") {
                            document.openBugReportSubmissionSheet()
                        }
                        .buttonStyle(.borderless)
                        .foregroundColor(skin.accent)

                        Button("Copy Screenshot") {
                            document.copySelectedCaptureImageForGitHub()
                        }
                        .buttonStyle(.borderless)
                        .foregroundColor(skin.accent)

                        Button("Send to GitHub") {
                            document.openSelectedCaptureGitHubIssue()
                        }
                        .buttonStyle(.borderless)
                        .foregroundColor(skin.accent)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            if let capture = document.selectedCapture {
                workspaceCaptureHeader(capture: capture)
                    .padding(.horizontal, 16)
            }

            Picker("Artifact", selection: $document.selectedSendPreviewKind) {
                Text("File Path").tag(SendPreviewKind.filePath)
                Text("Markdown Snippet").tag(SendPreviewKind.markdownSnippet)
                Text("Markdown Document").tag(SendPreviewKind.markdownDocument)
                if document.canExportIssueDraft {
                    Text("Issue Draft").tag(SendPreviewKind.issueDraft)
                }
                if document.canSendToGitHub {
                    Text("GitHub Issue URL").tag(SendPreviewKind.githubIssueURL)
                }
            }
            .pickerStyle(.menu)
            .padding(.horizontal, 16)

            Group {
                if let previewText = document.selectedPreviewText {
                    VStack(alignment: .leading, spacing: 10) {
                        if document.selectedSendPreviewKind == .githubIssueURL {
                            Text("QuickSnap will copy the current screenshot to your clipboard and open a prefilled GitHub new-issue page with the draft title, body, and labels.")
                                .font(.caption)
                                .foregroundColor(skin.textSecondary)

                            if let lastSubmittedIssueURL = document.lastSubmittedIssueURL, !lastSubmittedIssueURL.isEmpty {
                                Text("Last opened issue URL")
                                    .font(.caption2)
                                    .foregroundColor(skin.textSecondary)
                                Text(lastSubmittedIssueURL)
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundColor(.primary)
                                    .textSelection(.enabled)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            if let submissionErrorMessage = document.submissionErrorMessage, !submissionErrorMessage.isEmpty {
                                Text(submissionErrorMessage)
                                    .font(.caption)
                                    .foregroundColor(.red.opacity(0.9))
                            }
                        }

                        ScrollView {
                            Text(previewText)
                                .font(.system(size: 11, weight: .medium, design: document.selectedSendPreviewKind.usesMonospace ? .monospaced : .default))
                                .foregroundColor(.primary)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                        }
                        .background(Color.white.opacity(skin.isGlass ? 0.08 : 0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                } else if document.selectedCapture == nil {
                    Text("Select a stored capture to preview send artifacts.")
                        .font(.caption)
                        .foregroundColor(skin.textSecondary)
                        .padding(16)
                } else {
                    Text("This send artifact is unavailable for the selected capture.")
                        .font(.caption)
                        .foregroundColor(skin.textSecondary)
                        .padding(16)
                }
            }

            Spacer(minLength: 0)
        }
    }

    private func workspaceCaptureHeader(capture: CaptureRecord) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(capture.sourceDisplayLabel)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.primary)
            Text(document.timelineTimestamp(for: capture))
                .font(.caption2)
                .foregroundColor(skin.textSecondary)
            if let primaryURL = capture.primaryURL, !primaryURL.isEmpty, let url = URL(string: primaryURL) {
                Link(primaryURL, destination: url)
                    .font(.caption)
                    .lineLimit(1)
            } else {
                Text(capture.displaySubtitle)
                    .font(.caption)
                    .foregroundColor(skin.textSecondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(skin.isGlass ? 0.08 : 0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var canvasViewport: some View {
        GeometryReader { geometry in
            Group {
                if document.backgroundImage == nil {
                    emptyCanvas
                } else if skin.isModern {
                    modernCanvas(in: geometry.size)
                } else {
                    winAmpCanvas(in: geometry.size)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Canvas Variants

    private func modernCanvas(in availableSize: CGSize) -> some View {
        fittedCanvas(in: availableSize, padding: 24) {
            AnnotationCanvas(document: document)
                .frame(width: document.canvasSize.width, height: document.canvasSize.height)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(skin.border, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.25), radius: 16, x: 0, y: 4)
        }
    }

    private func winAmpCanvas(in availableSize: CGSize) -> some View {
        fittedCanvas(in: availableSize, padding: 20) {
            AnnotationCanvas(document: document)
                .frame(width: document.canvasSize.width, height: document.canvasSize.height)
                .background(Color.white)
                .overlay(
                    Rectangle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [skin.canvasFrameStart, skin.canvasFrameEnd],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(color: Color.black.opacity(0.7), radius: 8, x: 0, y: 2)
        }
    }

    private func fittedCanvas<CanvasView: View>(in availableSize: CGSize, padding: CGFloat, @ViewBuilder content: () -> CanvasView) -> some View {
        let rawWidth = max(document.canvasSize.width, 1)
        let rawHeight = max(document.canvasSize.height, 1)
        let usableWidth = max(availableSize.width - (padding * 2), 160)
        let usableHeight = max(availableSize.height - (padding * 2), 160)
        let scale = min(usableWidth / rawWidth, usableHeight / rawHeight, 1)
        let fittedSize = CGSize(width: rawWidth * scale, height: rawHeight * scale)

        return ZStack {
            content()
                .scaleEffect(scale)
                .frame(width: fittedSize.width, height: fittedSize.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(padding)
    }

    // MARK: - Toolbar

    private var toolBar: some View {
        HStack(spacing: skin.isModern ? 10 : 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isHistorySidebarVisible.toggle()
                }
            } label: {
                Image(systemName: "sidebar.left")
                    .foregroundColor(toolbarIconColor)
                    .frame(width: skin.isModern ? 32 : 28, height: skin.isModern ? 32 : 28)
            }
            .buttonStyle(currentButtonStyle())
            .help(isHistorySidebarVisible ? "Hide Sidebar" : "Show Sidebar")

            presetPicker

            Spacer(minLength: 0)

            iconButton(symbol: "macwindow.on.rectangle", helpText: "Capture Front Window") {
                document.presentWindowPicker()
            }

            iconButton(symbol: "selection.pin.in.out", helpText: "Capture Selection") {
                document.captureSelectionFromScreen()
            }

            ForEach(AnnotationTool.allCases) { tool in
                Button {
                    document.selectedTool = tool
                } label: {
                    Image(systemName: tool.symbolName)
                        .foregroundColor(toolbarIconColor)
                        .frame(width: skin.isModern ? 32 : 28, height: skin.isModern ? 32 : 28)
                }
                .buttonStyle(currentButtonStyle(isActive: document.selectedTool == tool))
                .help(tool.rawValue)
            }

            colorPickerButton
            lineWidthMenu

            iconButton(symbol: "arrow.uturn.backward", helpText: "Undo Last Annotation") {
                document.undoLastAnnotation()
            }
            .disabled(document.strokes.isEmpty && document.shapes.isEmpty && document.textAnnotations.isEmpty)

            iconButton(symbol: "trash", helpText: "Delete Selected Annotation") {
                document.deleteSelectedAnnotation()
            }
            .disabled(document.selectedAnnotation == nil)

            iconButton(symbol: "trash.slash", helpText: "Clear All Annotations") {
                document.clearAnnotations()
            }

            skinPicker
            outputMenu

            Spacer(minLength: 0)

            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    if document.isRightPanelVisible {
                        document.closeRightPanel()
                    } else {
                        document.openWorkspacePanel()
                    }
                }
            } label: {
                Image(systemName: "sidebar.right")
                    .foregroundColor(toolbarIconColor)
                    .frame(width: skin.isModern ? 32 : 28, height: skin.isModern ? 32 : 28)
            }
            .buttonStyle(currentButtonStyle())
            .help(document.isRightPanelVisible ? "Hide Workspace Panel" : "Show Workspace Panel")
        }
        .padding(.horizontal, skin.isModern ? 16 : 10)
        .padding(.vertical, skin.isModern ? 12 : 8)
        .background(toolbarBackground)
    }

    // MARK: - Toolbar Background

    @ViewBuilder
    private var toolbarBackground: some View {
        if skin.isGlass {
            Rectangle().fill(.ultraThinMaterial)
        } else if skin.isModern {
            skin.surface
        } else {
            LinearGradient(
                colors: [skin.toolbarGradientTop, skin.panelBg],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    @ViewBuilder
    private var footerBackground: some View {
        if skin.isGlass {
            Rectangle().fill(.ultraThinMaterial)
        } else if skin.isModern {
            skin.surface
        } else {
            skin.panelBg
        }
    }

    // MARK: - Skin Picker

    private var presetPicker: some View {
        Menu {
            ForEach(document.presetDefinitions) { preset in
                Button {
                    document.selectedPresetID = preset.id
                } label: {
                    if document.selectedPresetID == preset.id {
                        Label(preset.name, systemImage: "checkmark")
                    } else {
                        Text(preset.name)
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "shippingbox")
                Text(document.selectedPresetDefinition.name)
                    .font(.system(size: skin.isModern ? 11 : 10, weight: .medium))
                    .lineLimit(1)
            }
            .frame(height: skin.isModern ? 32 : 28)
            .padding(.horizontal, 10)
            .foregroundColor(toolbarIconColor)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 132, height: skin.isModern ? 32 : 28)
        .background(skinPickerBackground)
        .overlay(skinPickerOverlay)
        .help("Select Capture Preset")
    }

    private var skinPicker: some View {
        Menu {
            Section("Modern") {
                ForEach(SkinManager.all.filter { $0.isModern }) { s in
                    Button {
                        skinManager.select(s)
                    } label: {
                        if skin.id == s.id {
                            Label(s.name, systemImage: "checkmark")
                        } else {
                            Text(s.name)
                        }
                    }
                }
            }
            Section("Classic") {
                ForEach(SkinManager.all.filter { !$0.isModern }) { s in
                    Button {
                        skinManager.select(s)
                    } label: {
                        if skin.id == s.id {
                            Label(s.name, systemImage: "checkmark")
                        } else {
                            Text(s.name)
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "paintpalette")
                .frame(width: skin.isModern ? 32 : 28, height: skin.isModern ? 32 : 28)
                .foregroundColor(toolbarIconColor)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: skin.isModern ? 32 : 28, height: skin.isModern ? 32 : 28)
        .background(skinPickerBackground)
        .overlay(skinPickerOverlay)
        .help("Change Theme")
    }

    private var lineWidthMenu: some View {
        Menu {
            ForEach([1, 2, 4, 6, 8, 12, 16, 20], id: \.self) { width in
                Button {
                    document.lineWidth = CGFloat(width)
                } label: {
                    if Int(document.lineWidth.rounded()) == width {
                        Label("\(width) px", systemImage: "checkmark")
                    } else {
                        Text("\(width) px")
                    }
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .frame(width: skin.isModern ? 32 : 28, height: skin.isModern ? 32 : 28)
                .foregroundColor(toolbarIconColor)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: skin.isModern ? 32 : 28, height: skin.isModern ? 32 : 28)
        .background(skinPickerBackground)
        .overlay(skinPickerOverlay)
        .help("Line Width")
    }

    private var outputMenu: some View {
        Menu {
            Button("Copy Rendered Image") {
                document.copyRenderedImageToPasteboard()
            }
            .disabled(!document.canCopyImage)

            if document.canExportIssueDraft {
                Button("Review Bug Report") {
                    document.openBugReportSubmissionSheet()
                }
                .keyboardShortcut("B", modifiers: [.command, .shift])
            }

            Divider()

            Button("Export Markdown File") {
                document.exportCurrentCaptureMarkdownDocument()
            }
            .disabled(!document.canCopyCaptureOutputs)

            Button("Reveal Capture in Finder") {
                document.revealCurrentCaptureInFinder()
            }
            .disabled(!document.canCopyCaptureOutputs)
        } label: {
            Image(systemName: "square.and.arrow.up")
                .frame(width: skin.isModern ? 32 : 28, height: skin.isModern ? 32 : 28)
                .foregroundColor(toolbarIconColor)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: skin.isModern ? 32 : 28, height: skin.isModern ? 32 : 28)
        .background(skinPickerBackground)
        .overlay(skinPickerOverlay)
        .help("Share Outputs")
    }

    @ViewBuilder
    private var skinPickerBackground: some View {
        if skin.isModern {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(skin.buttonFace)
                .allowsHitTesting(false)
        } else {
            LinearGradient(
                colors: [skin.buttonGradTop, skin.buttonGradBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var skinPickerOverlay: some View {
        if !skin.isModern {
            BevelBorder(hi: skin.bevelHi, shadow: skin.bevelShadow, cornerRadius: 3, pressed: false)
                .allowsHitTesting(false)
        }
    }

    // MARK: - Dividers

    private func themeDivider() -> some View {
        Group {
            if skin.isModern {
                modernDivider()
            } else {
                winAmpDivider()
            }
        }
    }

    private func modernDivider() -> some View {
        Rectangle()
            .fill(Color.white.opacity(0.06))
            .frame(width: 1, height: 20)
            .padding(.horizontal, 3)
    }

    private func winAmpDivider() -> some View {
        ZStack(alignment: .leading) {
            Rectangle()
                .fill(skin.separator)
                .frame(width: 1, height: 22)
            Rectangle()
                .fill(skin.bevelHi.opacity(0.3))
                .frame(width: 1, height: 22)
                .offset(x: 1)
        }
    }

    // MARK: - Helpers

    private func currentButtonStyle(isActive: Bool = false) -> AnyButtonStyle {
        if skin.isModern {
            return AnyButtonStyle(ModernButtonStyle(skin: skin, isActive: isActive))
        } else {
            return AnyButtonStyle(WinAmpButtonStyle(skin: skin, isActive: isActive))
        }
    }

    private func iconButton(symbol: String, helpText: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .foregroundColor(toolbarIconColor)
                .frame(width: skin.isModern ? 32 : 28, height: skin.isModern ? 32 : 28)
        }
        .buttonStyle(currentButtonStyle())
        .help(helpText)
    }

    // MARK: - Color Picker

    private var colorPickerButton: some View {
        Button {
            colorPanel.onColorChange = { newColor in
                document.color = newColor
            }
            colorPanel.present(initial: document.color)
        } label: {
            RoundedRectangle(cornerRadius: skin.isModern ? 4 : 2, style: .continuous)
                .fill(Color(nsColor: document.color))
                .overlay(
                    RoundedRectangle(cornerRadius: skin.isModern ? 4 : 2, style: .continuous)
                        .strokeBorder(
                            skin.isModern ? skin.border : skin.bevelShadow.opacity(0.8),
                            lineWidth: 1
                        )
                )
                .frame(width: skin.isModern ? 18 : 16, height: skin.isModern ? 18 : 16)
                .frame(width: skin.isModern ? 32 : 28, height: skin.isModern ? 32 : 28)
        }
        .buttonStyle(currentButtonStyle())
        .help("Annotation Color")
    }

    // MARK: - Footer

    private var exportFooter: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(document.defaultExportFilename)
                    .font(skin.isModern ? skin.primaryFont(size: 11) : skin.lcdFont(size: 10))
                    .foregroundColor(skin.accentDim)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(document.currentCaptureSubtitle)
                    .font(.caption2)
                    .foregroundColor(skin.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            DragExportNotch(document: document, skin: skin)
                .frame(width: 88, height: 28)
                .disabled(document.backgroundImage == nil)
                .opacity(document.backgroundImage == nil ? 0.55 : 1)

            VStack(alignment: .trailing, spacing: 2) {
                Text(document.currentResolutionText)
                    .font(skin.isModern ? skin.monoFont(size: 11) : skin.lcdFont(size: 10))
                    .foregroundColor(skin.accent)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                Text(document.currentCaptureTimestampText.isEmpty ? document.statusMessage : document.currentCaptureTimestampText)
                    .font(.caption2)
                    .foregroundColor(skin.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, skin.isModern ? 16 : 12)
        .frame(height: skin.isModern ? 44 : 40)
        .background(footerBackground)
        .overlay(
            Rectangle()
                .fill(skin.isModern ? skin.border : skin.separator)
                .frame(height: 1),
            alignment: .top
        )
    }
}

private struct InspectorField {
    let label: String
    let value: String
    var isLink: Bool = false
}

private struct CaptureRowView: View {
    let capture: CaptureRecord
    let isSelected: Bool
    let timestamp: String
    let skin: AppSkin

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(capture.sourceDisplayLabel)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(isSelected ? .white : .primary)
                        .lineLimit(1)
                    Text(rowSubtitle)
                        .font(.system(size: 11))
                        .foregroundColor(isSelected ? Color.white.opacity(0.85) : skin.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                if !capture.fileExists {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                }
            }
            HStack {
                Text(timestamp)
                Spacer()
                Text(capture.presetDefinition.name)
                Spacer()
                Text(capture.dimensionsText)
            }
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundColor(isSelected ? Color.white.opacity(0.78) : skin.accentDim)
        }
        .padding(10)
        .background(rowBackground)
        .overlay(rowOverlay)
    }

    @ViewBuilder
    private var rowBackground: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(skin.accentOverlay.opacity(0.95))
        } else if skin.isModern {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.02))
        } else {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.black.opacity(0.12))
        }
    }

    @ViewBuilder
    private var rowOverlay: some View {
        if skin.isModern {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(isSelected ? skin.accent.opacity(0.6) : skin.border, lineWidth: 1)
        }
    }

    private var rowSubtitle: String {
        let detailTitle = capture.windowTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let presetName = capture.presetDefinition.name
        if !detailTitle.isEmpty && detailTitle != capture.sourceDisplayLabel {
            return "\(detailTitle) · \(presetName)"
        }
        return "\(capture.sourceKind.displayName) · \(presetName)"
    }
}

private struct WindowPickerSheet: View {
    @ObservedObject var document: AnnotationDocument
    let skin: AppSkin

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose Window")
                .font(skin.primaryFont(size: 16))
                .foregroundColor(skin.accent)

            Text("Select the window QuickSnap should capture.")
                .font(.caption)
                .foregroundColor(skin.textSecondary)

            List(document.availableWindowOptions) { option in
                Button {
                    document.captureWindow(option)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(option.displayTitle)
                            .font(.system(size: 13, weight: .semibold))
                        Text(option.displaySubtitle)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
            .listStyle(.inset)

            HStack {
                Spacer()

                Button("Cancel") {
                    document.dismissWindowPicker()
                }
            }
        }
        .padding(20)
        .frame(minWidth: 420, minHeight: 360)
        .background(skin.isGlass ? AnyView(Rectangle().fill(.thinMaterial)) : AnyView(skin.panelBg))
    }
}

private struct BugReportSubmissionSheet: View {
    @ObservedObject var document: AnnotationDocument
    let skin: AppSkin
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Review Bug Report")
                        .font(skin.primaryFont(size: 16))
                        .foregroundColor(skin.accent)
                    if let capture = document.selectedCapture {
                        Text(capture.sourceDisplayLabel)
                            .font(.caption)
                            .foregroundColor(skin.textSecondary)
                    }
                }

                Spacer()

                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.borderless)
                .foregroundColor(skin.accent)
            }

            if let capture = document.selectedCapture {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Capture Context")
                        .font(.caption)
                        .foregroundColor(skin.textSecondary)
                    if let image = document.backgroundImage {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .frame(height: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(skin.isModern ? skin.border : skin.separator, lineWidth: 1)
                            )
                    }
                    Text(capture.displaySubtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.primary)
                    Text(document.timelineTimestamp(for: capture))
                        .font(.caption2)
                        .foregroundColor(skin.textSecondary)
                    if let primaryURL = capture.primaryURL, !primaryURL.isEmpty, let url = URL(string: primaryURL) {
                        Link(primaryURL, destination: url)
                            .font(.caption)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(skin.isGlass ? 0.08 : 0.04))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            Picker("Target", selection: $document.selectedSubmissionTarget) {
                ForEach(SubmissionTarget.allCases) { target in
                    Text(target.displayName).tag(target)
                }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 6) {
                Text("Title")
                    .font(.caption)
                    .foregroundColor(skin.textSecondary)
                TextField(
                    "Issue title",
                    text: Binding(
                        get: { document.bugReportDraft.title },
                        set: { document.bugReportDraft.title = $0 }
                    )
                )
                .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Labels")
                    .font(.caption)
                    .foregroundColor(skin.textSecondary)
                TextField(
                    "bug, ui, regression",
                    text: Binding(
                        get: { document.bugReportDraftLabelsText },
                        set: { document.updateBugReportDraftLabels(from: $0) }
                    )
                )
                .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Body")
                    .font(.caption)
                    .foregroundColor(skin.textSecondary)
                TextEditor(
                    text: Binding(
                        get: { document.bugReportDraft.body },
                        set: { document.bugReportDraft.body = $0 }
                    )
                )
                .font(.system(size: 12, design: .monospaced))
                .frame(minHeight: 280)
                .padding(8)
                .background(Color.white.opacity(skin.isGlass ? 0.08 : 0.04))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            if let submissionErrorMessage = document.submissionErrorMessage, !submissionErrorMessage.isEmpty {
                Text(submissionErrorMessage)
                    .font(.caption)
                    .foregroundColor(.red.opacity(0.9))
            }

            if let lastSubmittedIssueURL = document.lastSubmittedIssueURL, !lastSubmittedIssueURL.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Last Submitted Issue")
                        .font(.caption)
                        .foregroundColor(skin.textSecondary)
                    Text(lastSubmittedIssueURL)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.primary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 10) {
                        Button("Copy URL") {
                            document.copyLastSubmittedIssueURL()
                        }
                        .buttonStyle(.borderless)
                        .foregroundColor(skin.accent)

                        Button("Open URL") {
                            document.openLastSubmittedIssueURL()
                        }
                        .buttonStyle(.borderless)
                        .foregroundColor(skin.accent)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(skin.isGlass ? 0.08 : 0.04))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            HStack {
                Button("Copy Screenshot") {
                    document.copySelectedCaptureImageForGitHub()
                }
                .buttonStyle(.borderless)
                .foregroundColor(skin.accent)

                Button("Copy Issue Body") {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(document.bugReportDraft.body, forType: .string)
                    document.statusMessage = "Copied bug report body"
                }
                .buttonStyle(.borderless)
                .foregroundColor(skin.accent)

                Spacer()

                Button(document.selectedSubmissionTarget == .github ? "Send to GitHub" : "Create Jira Issue") {
                    document.submitCurrentBugReport()
                    if document.selectedSubmissionTarget == .github {
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!document.canSubmitCurrentBugReport || document.isSubmittingBugReport)
            }
        }
        .padding(20)
        .frame(minWidth: 640, minHeight: 720)
        .background(skin.isGlass ? AnyView(Rectangle().fill(.thinMaterial)) : AnyView(skin.panelBg))
    }
}

struct FlowLayout: Layout {
    var horizontalSpacing: CGFloat = 8
    var verticalSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .greatestFiniteMagnitude
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0
        var requiredWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX > 0, currentX + size.width > maxWidth {
                currentX = 0
                currentY += rowHeight + verticalSpacing
                rowHeight = 0
            }
            requiredWidth = max(requiredWidth, currentX + size.width)
            rowHeight = max(rowHeight, size.height)
            currentX += size.width + horizontalSpacing
        }

        return CGSize(width: requiredWidth, height: currentY + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX > bounds.minX, currentX + size.width > bounds.maxX {
                currentX = bounds.minX
                currentY += rowHeight + verticalSpacing
                rowHeight = 0
            }
            subview.place(
                at: CGPoint(x: currentX, y: currentY),
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )
            currentX += size.width + horizontalSpacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - AnyButtonStyle (type-erased wrapper)

struct AnyButtonStyle: ButtonStyle {
    private let makeBodyClosure: (Configuration) -> AnyView

    init<S: ButtonStyle>(_ style: S) {
        makeBodyClosure = { configuration in
            AnyView(style.makeBody(configuration: configuration))
        }
    }

    func makeBody(configuration: Configuration) -> some View {
        makeBodyClosure(configuration)
    }
}

// MARK: - ColorPanelCoordinator

final class ColorPanelCoordinator: NSObject, ObservableObject {
    var onColorChange: ((NSColor) -> Void)?

    func present(initial: NSColor) {
        let panel = NSColorPanel.shared
        panel.color = initial
        panel.setTarget(self)
        panel.setAction(#selector(colorDidChange(_:)))
        panel.orderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func colorDidChange(_ sender: NSColorPanel) {
        onColorChange?(sender.color)
    }
}

// MARK: - WindowTransparencyHelper

struct WindowTransparencyHelper: NSViewRepresentable {
    let isGlass: Bool

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.alphaValue = 0
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            if isGlass {
                window.isOpaque = false
                window.backgroundColor = .clear
            } else {
                window.isOpaque = true
                window.backgroundColor = .windowBackgroundColor
            }
        }
    }
}
