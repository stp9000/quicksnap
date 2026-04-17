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

                settingsCard(title: "Markdown Output", subtitle: document.markdownStorageSummaryText) {
                    VStack(alignment: .leading, spacing: 10) {
                        settingsCodeBlock(document.markdownStoragePathText)

                        Text("QuickSnap stores generated `.md` files for the `Markdown` preset in this folder. If you leave it on the default, QuickSnap uses a `Markdown` subfolder under the main capture storage root.")
                            .font(.caption)
                            .foregroundColor(skin.textSecondary)

                        HStack(spacing: 10) {
                            settingsAction("Choose Folder...") {
                                document.chooseMarkdownStorageLocation()
                            }

                            settingsAction("Reveal in Finder") {
                                document.revealMarkdownStorageInFinder()
                            }

                            settingsAction("Reset to Default") {
                                document.resetMarkdownStorageLocationToDefault()
                            }
                            .disabled(document.isUsingDefaultMarkdownStorageLocation)
                        }
                    }
                }

                settingsCard(title: "AI", subtitle: document.savedOpenAIKeySummary) {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Use personal OpenAI API key", isOn: $document.aiUsesPersonalKey)
                            .toggleStyle(.switch)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("OpenAI Model")
                                .font(.caption)
                                .foregroundColor(skin.textSecondary)
                            TextField("gpt-4o-mini", text: $document.openAIModel)
                                .textFieldStyle(.roundedBorder)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("OpenAI API Key")
                                .font(.caption)
                                .foregroundColor(skin.textSecondary)
                            SecureField(document.hasSavedOpenAIKey ? "sk-...saved in Keychain" : "Enter OpenAI API key", text: $document.openAIKeyDraft)
                                .textFieldStyle(.roundedBorder)
                        }

                        HStack(spacing: 10) {
                            settingsAction("Save Key") {
                                document.saveOpenAIKey()
                            }

                            settingsAction("Test Connection") {
                                document.testOpenAIConnection()
                            }
                            .disabled(!document.hasSavedOpenAIKey || document.isTestingOpenAIConnection)

                            settingsAction("Remove Key") {
                                document.removeOpenAIKey()
                            }
                            .disabled(!document.hasSavedOpenAIKey)
                        }

                        if document.isTestingOpenAIConnection {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("Testing OpenAI connection...")
                                    .font(.caption)
                                    .foregroundColor(skin.textSecondary)
                            }
                        } else if let message = document.aiSettingsStatusMessage, !message.isEmpty {
                            Text(message)
                                .font(.caption)
                                .foregroundColor(document.analysisErrorMessage == nil ? skin.accent : .red.opacity(0.9))
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(settingsEditorBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }

                        Text("The API key is stored securely in your macOS Keychain. QuickSnap uses it only when you run Analyze with personal-key mode enabled.")
                            .font(.caption)
                            .foregroundColor(skin.textSecondary)
                    }
                }

                settingsCard(title: "GitHub", subtitle: document.savedGitHubPATSummary) {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Owner or Organization")
                                .font(.caption)
                                .foregroundColor(skin.textSecondary)
                            TextField("org", text: $document.githubOwner)
                                .textFieldStyle(.roundedBorder)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Repository")
                                .font(.caption)
                                .foregroundColor(skin.textSecondary)
                            TextField("repo", text: $document.githubRepo)
                                .textFieldStyle(.roundedBorder)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Default Labels")
                                .font(.caption)
                                .foregroundColor(skin.textSecondary)
                            TextField("bug, ui", text: $document.githubLabels)
                                .textFieldStyle(.roundedBorder)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("GitHub Personal Access Token")
                                .font(.caption)
                                .foregroundColor(skin.textSecondary)
                            SecureField(document.hasSavedGitHubPAT ? "ghp_...saved in Keychain" : "Enter GitHub PAT", text: $document.githubPATDraft)
                                .textFieldStyle(.roundedBorder)
                        }

                        HStack(spacing: 10) {
                            settingsAction("Save Token") {
                                document.saveGitHubPAT()
                            }

                            settingsAction("Remove Token") {
                                document.removeGitHubPAT()
                            }
                            .disabled(!document.hasSavedGitHubPAT)
                        }

                        Text("QuickSnap uses the owner, repo, and labels for GitHub issue drafting. The PAT is stored in Keychain for API-based GitHub workflows.")
                            .font(.caption)
                            .foregroundColor(skin.textSecondary)
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(settingsBackground)
        .frame(width: 700, height: 700)
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
