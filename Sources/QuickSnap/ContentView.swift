import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var document: AnnotationDocument
    @EnvironmentObject var skinManager: SkinManager
    @StateObject private var colorPanel = ColorPanelCoordinator()
    @State private var inspectorShowsAllFields = false

    private var skin: AppSkin { skinManager.current }
    private var toolbarIconColor: Color { Color.white.opacity(skin.isGlass ? 0.82 : 0.9) }

    var body: some View {
        HSplitView {
            historySidebar
                .frame(minWidth: 240, idealWidth: 290, maxWidth: 340)

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
            .background(windowBackground)

            if document.isRightPanelVisible {
                workspacePanel
                    .frame(minWidth: 280, idealWidth: 360, maxWidth: 460)
            }
        }
        .background(windowBackground)
        .background(WindowTransparencyHelper(isGlass: skin.isGlass))
        .sheet(isPresented: $document.isWindowPickerPresented) {
            WindowPickerSheet(document: document, skin: skin)
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
        var fields: [InspectorField] = [
            InspectorField(label: "Preset", value: capture.presetDefinition.name),
            InspectorField(label: "Title", value: capture.displayTitle),
            InspectorField(label: "Source", value: capture.displaySubtitle),
            InspectorField(label: "URL", value: document.selectedCapturePrimaryURLText, isLink: true),
            InspectorField(label: "OCR", value: capture.ocrStatus.displayName),
            InspectorField(label: "Status", value: capture.fileExists ? "Available locally" : "Image file missing")
        ]

        switch capture.normalizedPresetID {
        case "bug_report":
            fields.append(InspectorField(label: "Browser", value: capture.presetPayload.browser))
            fields.append(InspectorField(label: "Viewport", value: capture.presetPayload.viewport))
            fields.append(InspectorField(label: "Console Summary", value: capture.presetPayload.consoleSummary))
            fields.append(InspectorField(label: "Error Message", value: capture.presetPayload.errorMessage))
            fields.append(InspectorField(label: "Stack Trace", value: capture.presetPayload.stackTrace))
        default:
            if let custom = capture.presetDefinition.customDefinition {
                fields.append(contentsOf: custom.fieldNames.map { field in
                    InspectorField(label: field, value: capture.presetPayload.customFields[field, default: ""])
                })
            }
        }

        return fields.filter { inspectorShowsAllFields || !$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
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
            .padding(12)
            .background(toolbarBackground)

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
                    HStack {
                        Text(capture.presetDefinition.name)
                            .font(.caption)
                            .foregroundColor(skin.textSecondary)
                        Spacer()
                        Button("Run Local Analysis") {
                            document.runLocalAnalysisForSelectedCapture()
                        }
                        .buttonStyle(.borderless)
                        .foregroundColor(skin.accent)

                        Button("Run AI Analysis") {
                            document.runAIAnalysisForSelectedCapture()
                        }
                        .buttonStyle(.borderless)
                        .foregroundColor(skin.accent)
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
                        analysisTextBlock(label: "Summary", value: capture.analysis.summary)
                        if !capture.analysis.tags.isEmpty {
                            analysisTextBlock(label: "Tags", value: capture.analysis.tags.joined(separator: ", "))
                        }
                        if !capture.analysis.recommendedActions.isEmpty {
                            analysisTextBlock(label: "Recommended Actions", value: capture.analysis.recommendedActions.joined(separator: "\n"))
                        }
                        if !capture.analysis.severity.isEmpty {
                            metadataRow(label: "Severity", value: capture.analysis.severity.capitalized)
                        }
                        if !capture.analysis.issueTitle.isEmpty {
                            analysisTextBlock(label: "Issue Title", value: capture.analysis.issueTitle)
                        }
                        if !capture.analysis.issueBody.isEmpty {
                            analysisTextBlock(label: "Issue Draft", value: capture.analysis.issueBody)
                        }
                        if !capture.analysis.rawJSON.isEmpty {
                            Group {
                                Text("Raw Analysis")
                                    .font(.caption)
                                    .foregroundColor(skin.textSecondary)
                                ScrollView {
                                    Text(capture.analysis.rawJSON)
                                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                                        .foregroundColor(.primary)
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .frame(minHeight: 120)
                                .padding(8)
                                .background(Color.white.opacity(skin.isGlass ? 0.08 : 0.04))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
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

    private func analysisTextBlock(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundColor(skin.textSecondary)
            Text(value.isEmpty ? "Unavailable" : value)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
    }

    private var sendPanelContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Send Preview")
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
            Spacer(minLength: 0)

            presetPicker

            iconButton(symbol: "folder", helpText: "Open Image") {
                document.openImageFromDisk()
            }

            iconButton(symbol: "camera", helpText: "Capture Full Screen") {
                document.captureMainDisplay()
            }

            iconButton(symbol: "macwindow.on.rectangle", helpText: "Capture Front Window") {
                document.presentWindowPicker()
            }

            iconButton(symbol: "selection.pin.in.out", helpText: "Capture Selection") {
                document.captureSelectionFromScreen()
            }

            iconButton(symbol: "square.and.arrow.down", helpText: "Export PNG") {
                document.saveAnnotatedImage()
            }

            themeDivider()

            iconButton(symbol: document.isRightPanelVisible ? "sidebar.right" : "sidebar.right", helpText: "Toggle Workspace Panel") {
                if document.isRightPanelVisible {
                    document.closeRightPanel()
                } else {
                    document.openWorkspacePanel()
                }
            }

            iconButton(symbol: "sparkles", helpText: "Show Analyze Panel") {
                document.showAnalyzePanel()
            }
            .disabled(document.selectedCapture == nil)

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

            themeDivider()

            iconButton(symbol: "arrow.uturn.backward", helpText: "Undo Last Annotation") {
                document.undoLastAnnotation()
            }
            .disabled(document.strokes.isEmpty && document.shapes.isEmpty)

            iconButton(symbol: "trash", helpText: "Delete Selected Annotation") {
                document.deleteSelectedAnnotation()
            }
            .disabled(document.selectedAnnotation == nil)

            iconButton(symbol: "trash.slash", helpText: "Clear All Annotations") {
                document.clearAnnotations()
            }

            themeDivider()

            skinPicker

            outputMenu

            Spacer(minLength: 0)
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
            }
            .frame(height: skin.isModern ? 32 : 28)
            .padding(.horizontal, 10)
            .foregroundColor(toolbarIconColor)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(height: skin.isModern ? 32 : 28)
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

            Button("Preview Capture File Path") {
                document.openSendPreview(.filePath)
            }
            .disabled(!document.canCopyCaptureOutputs)

            Button("Preview Markdown Snippet") {
                document.openSendPreview(.markdownSnippet)
            }
            .disabled(!document.canCopyCaptureOutputs)

            Button("Preview Markdown Document") {
                document.openSendPreview(.markdownDocument)
            }
            .disabled(!document.canCopyCaptureOutputs)

            if document.canExportIssueDraft {
                Button("Preview Issue Draft") {
                    document.openSendPreview(.issueDraft)
                }
            }

            if document.canSendToGitHub {
                Button("Preview GitHub Issue URL") {
                    document.openSendPreview(.githubIssueURL)
                }
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
            Image(systemName: "paperplane")
                .frame(width: skin.isModern ? 32 : 28, height: skin.isModern ? 32 : 28)
                .foregroundColor(toolbarIconColor)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: skin.isModern ? 32 : 28, height: skin.isModern ? 32 : 28)
        .background(skinPickerBackground)
        .overlay(skinPickerOverlay)
        .help("Copy Outputs")
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
