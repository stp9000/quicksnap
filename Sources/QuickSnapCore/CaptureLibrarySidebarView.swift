import AppKit
import ImageIO
import SwiftUI

struct CaptureLibrarySidebarView: View {
    @ObservedObject var document: AnnotationDocument
    let skin: AppSkin

    var body: some View {
        VStack(spacing: 0) {
            sidebarHeader

            Group {
                if document.captures.isEmpty {
                    emptyState
                } else {
                    captureList
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(nil, value: document.searchText)
            .animation(nil, value: document.captureCountSummary)
        }
        .background(sidebarBackground)
    }

    private var sidebarHeader: some View {
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
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(sidebarHeaderBackground)
    }

    private var filterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(CaptureFilter.allCases) { filter in
                    Button {
                        document.activeFilter = filter
                    } label: {
                        Text(filter.displayName)
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(filter == document.activeFilter ? skin.accentOverlay : Color.clear)
                            .foregroundColor(filter == document.activeFilter ? skin.accent : skin.textSecondary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var emptyState: some View {
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
    }

    private var captureList: some View {
        List(document.captures) { capture in
            CaptureLibraryRowView(
                capture: capture,
                isSelected: document.selectedCaptureID == capture.id,
                timestamp: document.timelineTimestamp(for: capture),
                skin: skin,
                thumbnailImage: document.thumbnailImage(for: capture),
                showsMissingImageWarning: document.shouldShowMissingImageWarning(for: capture),
                isCloudHosted: document.isCloudHostedCapture(capture),
                showsCloudUploadFailure: document.hasCloudUploadFailure(capture),
                tagsText: $document.selectedCaptureTagsText,
                onOpen: { document.openCapture(capture) },
                onSaveTags: { document.saveSelectedCaptureTags() },
                onDelete: { document.deleteCapture(capture) }
            )
            .listRowInsets(EdgeInsets(top: 3, leading: 10, bottom: 3, trailing: 8))
            .listRowBackground(Color.clear)
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(sidebarBackground)
    }

    @ViewBuilder
    private var sidebarHeaderBackground: some View {
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
    private var sidebarBackground: some View {
        if skin.isGlass {
            Rectangle().fill(.regularMaterial)
        } else if skin.isModern {
            skin.surface
        } else {
            skin.panelBg
        }
    }
}

private struct CaptureLibraryRowView: View {
    let capture: CaptureRecord
    let isSelected: Bool
    let timestamp: String
    let skin: AppSkin
    let thumbnailImage: NSImage?
    let showsMissingImageWarning: Bool
    let isCloudHosted: Bool
    let showsCloudUploadFailure: Bool
    @Binding var tagsText: String
    let onOpen: () -> Void
    let onSaveTags: () -> Void
    let onDelete: () -> Void
    @State private var isTagPopoverPresented = false

    var body: some View {
        HStack(alignment: .center, spacing: 9) {
            CaptureThumbnailView(capture: capture, fallbackImage: thumbnailImage)

            VStack(alignment: .leading, spacing: 2) {
                Text(capture.displayTitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .primary)
                    .lineLimit(1)

                Text(rowDetail)
                    .font(.caption)
                    .foregroundColor(isSelected ? Color.white.opacity(0.78) : .secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            statusIcon
            rowAction(symbol: "tag", helpText: "Edit Tags") {
                onOpen()
                isTagPopoverPresented = true
            }
            .popover(isPresented: $isTagPopoverPresented, arrowEdge: .trailing) {
                tagEditor
            }
            rowAction(symbol: "trash", helpText: "Delete Capture", action: onDelete)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(rowBackground)
        .overlay(rowOverlay)
        .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .onTapGesture(perform: onOpen)
        .contextMenu {
            Button("Edit Tags") {
                onOpen()
                isTagPopoverPresented = true
            }
            Button("Delete Capture", role: .destructive, action: onDelete)
        }
    }

    private var tagEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tags")
                .font(.system(size: 13, weight: .semibold))

            TextField("comma, separated, tags", text: $tagsText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 260)
                .onSubmit {
                    onSaveTags()
                    isTagPopoverPresented = false
                }

            HStack {
                Spacer()
                Button("Cancel") {
                    isTagPopoverPresented = false
                }
                Button("Save") {
                    onSaveTags()
                    isTagPopoverPresented = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(14)
    }

    private func rowAction(symbol: String, helpText: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(isSelected ? Color.white.opacity(0.84) : .secondary)
                .frame(width: 18, height: 18)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(helpText)
    }

    @ViewBuilder
    private var statusIcon: some View {
        if isCloudHosted {
            Image(systemName: "cloud.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(isSelected ? Color.white.opacity(0.82) : skin.accent)
                .frame(width: 18, height: 16)
                .help("Stored in R2")
        } else if showsCloudUploadFailure {
            Image(systemName: "cloud.slash")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.orange)
                .frame(width: 18, height: 16)
                .help("Cloud upload failed")
        } else if showsMissingImageWarning {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.orange)
                .frame(width: 18, height: 16)
                .help("Local image missing")
        }
    }

    @ViewBuilder
    private var rowBackground: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(skin.accentOverlay.opacity(0.95))
        } else {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.clear)
        }
    }

    @ViewBuilder
    private var rowOverlay: some View {
        if skin.isModern && isSelected {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(skin.accent.opacity(0.45), lineWidth: 1)
        }
    }

    private var rowDetail: String {
        "\(timestamp) - \(capture.presetDefinition.name) - \(capture.dimensionsText)"
    }
}

struct CaptureThumbnailView: View {
    let capture: CaptureRecord
    let fallbackImage: NSImage?
    @State private var thumbnail: NSImage?

    private static let cache = NSCache<NSString, NSImage>()

    var body: some View {
        Group {
            if let thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                    Image(systemName: "photo")
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(width: 42, height: 42)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .task(id: "\(capture.id)-\(capture.imagePath)") {
            if let fallbackImage {
                thumbnail = fallbackImage
                return
            }
            guard !capture.imagePath.isEmpty else {
                thumbnail = nil
                return
            }
            if let cached = Self.cache.object(forKey: capture.imagePath as NSString) {
                thumbnail = cached
                return
            }

            let generated = generateThumbnail(at: capture.imagePath, maxPixelSize: 116)

            if let generated {
                Self.cache.setObject(generated, forKey: capture.imagePath as NSString)
            }
            thumbnail = generated
        }
    }
}

private func generateThumbnail(at path: String, maxPixelSize: Int) -> NSImage? {
    guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil) else {
        return NSImage(contentsOfFile: path)
    }

    let options: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
    ]

    if let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) {
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }

    return NSImage(contentsOfFile: path)
}
