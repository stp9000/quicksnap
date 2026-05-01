import AppKit
import SwiftUI

extension Notification.Name {
    static let quickSnapToggleWorkspace = Notification.Name("QuickSnapToggleWorkspace")
}

private enum CenterSurfaceMode {
    case editor
    case workspace
}

enum CaptureWorkspaceTab: String, CaseIterable, Identifiable {
    case overview
    case artifacts
    case cloud
    case wiki
    case ai

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: "Overview"
        case .artifacts: "Artifacts"
        case .cloud: "Cloud"
        case .wiki: "Wiki"
        case .ai: "AI"
        }
    }
}

struct ContentView: View {
    @ObservedObject var document: AnnotationDocument
    @EnvironmentObject var skinManager: SkinManager
    @AppStorage("quicksnap.workspace.selectedTab") private var selectedWorkspaceTabID = CaptureWorkspaceTab.overview.rawValue
    @AppStorage("quicksnap.sidebar.width") private var storedSidebarWidth = 292.0
    @StateObject private var colorPanel = ColorPanelCoordinator()
    @State private var inspectorShowsAllFields = false
    @State private var isHistorySidebarVisible = true
    @State private var isResizingSidebar = false
    @State private var sidebarWidth = 292.0
    @State private var sidebarResizeStartWidth = 292.0
    @State private var centerSurfaceMode: CenterSurfaceMode = .editor

    private let sidebarMinWidth = 240.0
    private let sidebarMaxWidth = 430.0
    private var skin: AppSkin { skinManager.current }
    private var toolbarIconColor: Color { Color.white.opacity(skin.isGlass ? 0.82 : 0.9) }
    private var isWorkspaceSurfaceVisible: Bool { centerSurfaceMode == .workspace }
    private var workspaceTabSelection: Binding<CaptureWorkspaceTab> {
        Binding(
            get: { CaptureWorkspaceTab(rawValue: selectedWorkspaceTabID) ?? .overview },
            set: { selectedWorkspaceTabID = $0.rawValue }
        )
    }

    var body: some View {
        HStack(spacing: 0) {
            if isHistorySidebarVisible {
                ZStack(alignment: .trailing) {
                    CaptureLibrarySidebarView(document: document, skin: skin)
                        .frame(width: sidebarWidth)

                    sidebarResizeHandle
                }
                .frame(width: sidebarWidth)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }

            VStack(spacing: 0) {
                toolBar

                Rectangle()
                    .fill(skin.isModern ? skin.border : skin.separator)
                    .frame(height: 1)

                centerSurface

                Rectangle()
                    .fill(skin.isModern ? skin.border : skin.separator)
                    .frame(height: 1)

                exportFooter
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(windowBackground)
        }
        .animation(.easeInOut(duration: 0.22), value: isHistorySidebarVisible)
        .background(windowBackground)
        .background(WindowTransparencyHelper(isGlass: skin.isGlass))
        .transaction { transaction in
            if isResizingSidebar {
                transaction.animation = nil
            }
        }
        .sheet(isPresented: $document.isWindowPickerPresented) {
            WindowPickerSheet(document: document, skin: skin)
        }
        .sheet(isPresented: $document.isBugReportSubmissionSheetPresented) {
            BugReportSubmissionSheet(document: document, skin: skin)
        }
        .onDeleteCommand {
            document.deleteSelectedAnnotation()
        }
        .onReceive(NotificationCenter.default.publisher(for: .quickSnapToggleWorkspace)) { _ in
            withAnimation(.easeInOut(duration: 0.18)) {
                toggleWorkspaceSurface()
            }
        }
        .onAppear {
            sidebarWidth = min(max(storedSidebarWidth, sidebarMinWidth), sidebarMaxWidth)
        }
    }

    private var sidebarResizeHandle: some View {
        ZStack(alignment: .trailing) {
            Rectangle()
                .fill(Color.clear)
                .frame(width: 9)

            Rectangle()
                .fill(isResizingSidebar ? skin.accent.opacity(0.55) : (skin.isModern ? skin.border.opacity(0.7) : skin.separator.opacity(0.75)))
                .frame(width: isResizingSidebar ? 2 : 1)
        }
            .frame(width: 9)
            .contentShape(Rectangle())
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeLeftRight.set()
                } else {
                    NSCursor.arrow.set()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isResizingSidebar {
                            sidebarResizeStartWidth = sidebarWidth
                        }
                        isResizingSidebar = true
                        sidebarWidth = min(max(sidebarResizeStartWidth + value.translation.width, sidebarMinWidth), sidebarMaxWidth)
                    }
                    .onEnded { _ in
                        storedSidebarWidth = sidebarWidth
                        isResizingSidebar = false
                        NSCursor.arrow.set()
                    }
            )
            .help("Resize Sidebar")
    }

    @ViewBuilder
    private var centerSurface: some View {
        switch centerSurfaceMode {
        case .editor:
            editorSurface
        case .workspace:
            CaptureWorkspaceView(
                document: document,
                skin: skin,
                selectedTab: workspaceTabSelection,
                inspectorShowsAllFields: $inspectorShowsAllFields
            ) {
                withAnimation(.easeInOut(duration: 0.18)) {
                    centerSurfaceMode = .editor
                }
            }
        }
    }

    private var editorSurface: some View {
        canvasViewport
            .background(canvasBackground)
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
        HStack(spacing: 10) {
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

            themeDivider()

            toolbarGroup {
                iconButton(symbol: "macwindow.on.rectangle", helpText: "Capture Front Window") {
                    document.presentWindowPicker()
                }

                iconButton(symbol: "selection.pin.in.out", helpText: "Capture Selection") {
                    document.captureSelectionFromScreen()
                }
            }

            themeDivider()

            toolbarGroup {
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
            }

            themeDivider()

            toolbarGroup {
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
            }

            Spacer(minLength: 0)

            toolbarGroup {
                skinPicker
                outputMenu

                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        toggleWorkspaceSurface()
                    }
                } label: {
                    Image(systemName: "square.grid.2x2")
                        .foregroundColor(toolbarIconColor)
                        .frame(width: skin.isModern ? 32 : 28, height: skin.isModern ? 32 : 28)
                }
                .buttonStyle(currentButtonStyle(isActive: isWorkspaceSurfaceVisible))
                .disabled(document.selectedCapture == nil)
                .help(document.selectedCapture == nil ? "Select a capture to show Workspace" : (isWorkspaceSurfaceVisible ? "Return to Editor" : "Show Workspace"))
            }
        }
        .padding(.horizontal, skin.isModern ? 14 : 10)
        .padding(.vertical, skin.isModern ? 9 : 8)
        .background(toolbarBackground)
    }

    private func toolbarGroup<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: skin.isModern ? 6 : 5) {
            content()
        }
    }

    private func toggleWorkspaceSurface() {
        guard document.selectedCapture != nil else { return }
        if isWorkspaceSurfaceVisible {
            centerSurfaceMode = .editor
        } else {
            document.normalizeSelectedSendPreviewKind()
            document.closeRightPanel()
            centerSurfaceMode = .workspace
        }
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
