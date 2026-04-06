import SwiftUI

struct SettingsView: View {
    @ObservedObject var document: AnnotationDocument
    @EnvironmentObject var skinManager: SkinManager

    private var skin: AppSkin { skinManager.current }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("QuickSnap Settings")
                    .font(skin.primaryFont(size: 20))
                    .foregroundColor(skin.accent)

                settingsCard(title: "Capture Storage", subtitle: document.storageLocationSummaryText) {
                    VStack(alignment: .leading, spacing: 10) {
                        settingsCodeBlock(document.captureLibraryPathText)

                        Text("QuickSnap stores captured images in a `Captures` subfolder and its SQLite database in the selected root folder.")
                            .font(.caption)
                            .foregroundColor(skin.textSecondary)

                        HStack(spacing: 10) {
                            settingsAction("Choose Folder...") {
                                document.chooseStorageLocation()
                            }

                            settingsAction("Reveal in Finder") {
                                document.revealCaptureLibraryInFinder()
                            }
                            .disabled(document.captureLibraryPathText == "Unavailable")

                            settingsAction("Reset to Default") {
                                document.resetStorageLocationToDefault()
                            }
                            .disabled(document.isUsingDefaultStorageLocation)
                        }
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(settingsBackground)
        .frame(width: 700, height: 420)
    }

    private func settingsCard<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(skin.primaryFont(size: 15))
                    .foregroundColor(skin.accent)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(skin.textSecondary)
            }

            content()
        }
        .padding(18)
        .background(settingsCardBackground)
        .overlay(settingsCardOverlay)
        .clipShape(RoundedRectangle(cornerRadius: skin.isModern ? 16 : 10, style: .continuous))
    }

    private func settingsAction(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.borderless)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(settingsInnerCard)
            .foregroundColor(skin.accent)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func settingsCodeBlock(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundColor(.primary)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(settingsEditorBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    @ViewBuilder
    private var settingsBackground: some View {
        if skin.isGlass {
            Rectangle().fill(.thinMaterial)
        } else {
            skin.panelBg
        }
    }

    private var settingsCardBackground: some View {
        Group {
            if skin.isModern {
                skin.surface
            } else {
                skin.buttonFace
            }
        }
    }

    private var settingsInnerCard: some ShapeStyle {
        skin.isModern ? AnyShapeStyle(Color.white.opacity(0.05)) : AnyShapeStyle(Color.black.opacity(0.16))
    }

    private var settingsEditorBackground: some ShapeStyle {
        skin.isModern ? AnyShapeStyle(Color.white.opacity(0.04)) : AnyShapeStyle(Color.black.opacity(0.20))
    }

    @ViewBuilder
    private var settingsCardOverlay: some View {
        if skin.isModern {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(skin.border, lineWidth: 1)
        } else {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(skin.separator.opacity(0.7), lineWidth: 1)
        }
    }
}
