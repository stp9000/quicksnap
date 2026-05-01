import SwiftUI

struct SettingsView: View {
    @ObservedObject var document: AnnotationDocument
    @EnvironmentObject var skinManager: SkinManager

    private var skin: AppSkin { skinManager.current }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("QuickSnap Settings")
                .font(skin.primaryFont(size: 20))
                .foregroundColor(skin.accent)

            TabView {
                settingsTab {
                    storageSettings
                }
                .tabItem {
                    Label("Storage", systemImage: "externaldrive")
                }

                settingsTab {
                    cloudSettings
                }
                .tabItem {
                    Label("Cloud", systemImage: "cloud")
                }

                settingsTab {
                    aiSettings
                }
                .tabItem {
                    Label("AI", systemImage: "sparkles")
                }

                settingsTab {
                    integrationSettings
                }
                .tabItem {
                    Label("Integrations", systemImage: "point.3.connected.trianglepath.dotted")
                }
            }
            .tint(skin.accent)
        }
        .padding(24)
        .background(settingsBackground)
        .frame(width: 760, height: 620)
        .preferredColorScheme(skin.colorScheme)
        .foregroundColor(settingsText)
        .task {
            document.refreshSavedCredentialState()
        }
    }

    private func settingsTab<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                content()
            }
            .padding(.top, 14)
            .padding(.horizontal, 2)
            .padding(.bottom, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollContentBackground(.hidden)
        .background(Color.clear)
    }

    private var storageSettings: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsCard(title: "Capture Storage", subtitle: document.storageLocationSummaryText) {
                VStack(alignment: .leading, spacing: 10) {
                    settingsCodeBlock(document.captureLibraryPathText)

                    helperText("QuickSnap stores captured images in a `Captures` subfolder and its SQLite database in the selected root folder.")

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

                    helperText("QuickSnap stores generated `.md` files for the `Markdown` preset in this folder. If you leave it on the default, QuickSnap uses a `Markdown` subfolder under the main capture storage root.")

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
        }
    }

    private var cloudSettings: some View {
        settingsCard(title: "Cloud Capture Assets", subtitle: document.cloudAssetStorageSummary) {
            VStack(alignment: .leading, spacing: 12) {
                settingsToggle("Upload new capture PNGs to S3-compatible storage", isOn: $document.cloudAssetUploadEnabled)

                settingsToggle("Store image captures only in cloud", isOn: $document.cloudAssetCloudOnlyImages)
                    .disabled(!document.cloudAssetUploadEnabled)

                settingsToggle("Do not store OCR or capture metadata locally", isOn: $document.cloudAssetImageOnlyPrivacy)
                    .disabled(!document.cloudAssetUploadEnabled)

                settingsField(label: "Endpoint URL") {
                    settingsTextField("https://accountid.r2.cloudflarestorage.com", text: $document.cloudAssetEndpoint)
                }

                HStack(spacing: 10) {
                    settingsField(label: "Region") {
                        settingsTextField("auto", text: $document.cloudAssetRegion)
                    }

                    settingsField(label: "Bucket") {
                        settingsTextField("quicksnap-assets", text: $document.cloudAssetBucket)
                    }
                }

                settingsField(label: "Object Prefix") {
                    settingsTextField("quicksnap-captures", text: $document.cloudAssetPrefix)
                }

                HStack(spacing: 10) {
                    settingsField(label: "Access Key ID") {
                        settingsSecureField(document.hasSavedCloudAssetCredentials ? "Saved in Keychain" : "Enter access key ID", text: $document.cloudAssetAccessKeyIDDraft)
                    }

                    settingsField(label: "Secret Access Key") {
                        settingsSecureField(document.hasSavedCloudAssetCredentials ? "Saved in Keychain" : "Enter secret access key", text: $document.cloudAssetSecretAccessKeyDraft)
                    }
                }

                HStack(spacing: 10) {
                    settingsAction("Save Keys") {
                        document.saveCloudAssetCredentials()
                    }

                    settingsAction("Remove Keys") {
                        document.removeCloudAssetCredentials()
                    }
                    .disabled(!document.hasSavedCloudAssetCredentials)
                }

                helperText("Image-only privacy mode uploads the raw PNG to cloud storage and keeps only a temporary in-memory sidebar entry for the current session. Use a write-limited bucket credential and keep the bucket private.")
            }
        }
    }

    private var aiSettings: some View {
        settingsCard(title: "AI", subtitle: document.savedOpenAIKeySummary) {
            VStack(alignment: .leading, spacing: 12) {
                settingsToggle("Use personal OpenAI API key", isOn: $document.aiUsesPersonalKey)

                settingsField(label: "OpenAI Model") {
                    settingsTextField("gpt-4o-mini", text: $document.openAIModel)
                }

                settingsField(label: "OpenAI API Key") {
                    settingsSecureField(document.hasSavedOpenAIKey ? "sk-...saved in Keychain" : "Enter OpenAI API key", text: $document.openAIKeyDraft)
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
                        helperText("Testing OpenAI connection...")
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

                helperText("The API key is stored securely in your macOS Keychain. QuickSnap uses it only when you run Analyze with personal-key mode enabled.")
            }
        }
    }

    private var integrationSettings: some View {
        settingsCard(title: "GitHub", subtitle: document.savedGitHubPATSummary) {
            VStack(alignment: .leading, spacing: 12) {
                settingsField(label: "Owner or Organization") {
                    settingsTextField("org", text: $document.githubOwner)
                }

                settingsField(label: "Repository") {
                    settingsTextField("repo", text: $document.githubRepo)
                }

                settingsField(label: "Default Labels") {
                    settingsTextField("bug, ui", text: $document.githubLabels)
                }

                settingsField(label: "GitHub Personal Access Token") {
                    settingsSecureField(document.hasSavedGitHubPAT ? "ghp_...saved in Keychain" : "Enter GitHub PAT", text: $document.githubPATDraft)
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

                helperText("QuickSnap uses the owner, repo, and labels for GitHub issue drafting. The PAT is stored in Keychain for API-based GitHub workflows.")
            }
        }
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
                .foregroundColor(settingsText)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(settingsCardBackground)
        .overlay(settingsCardOverlay)
        .clipShape(RoundedRectangle(cornerRadius: skin.isModern ? 16 : 10, style: .continuous))
    }

    private func settingsField<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundColor(skin.textSecondary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func settingsTextField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .foregroundColor(settingsText)
            .tint(skin.accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(settingsInputBackground)
            .overlay(settingsInputOverlay)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func settingsSecureField(_ placeholder: String, text: Binding<String>) -> some View {
        SecureField(placeholder, text: text)
            .textFieldStyle(.plain)
            .foregroundColor(settingsText)
            .tint(skin.accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(settingsInputBackground)
            .overlay(settingsInputOverlay)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func settingsToggle(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(title, isOn: isOn)
            .toggleStyle(.switch)
            .foregroundColor(settingsText)
            .tint(skin.accent)
    }

    private func helperText(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundColor(skin.textSecondary)
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
            .foregroundColor(settingsText)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(settingsEditorBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var settingsText: Color {
        skin.colorScheme == .dark ? .white.opacity(0.94) : .black.opacity(0.88)
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
        if skin.colorScheme == .dark {
            return AnyShapeStyle(Color.white.opacity(skin.isModern ? 0.08 : 0.06))
        }
        return AnyShapeStyle(Color.black.opacity(0.06))
    }

    private var settingsEditorBackground: some ShapeStyle {
        if skin.colorScheme == .dark {
            return AnyShapeStyle(Color.black.opacity(skin.isModern ? 0.24 : 0.28))
        }
        return AnyShapeStyle(Color.white.opacity(0.68))
    }

    private var settingsInputBackground: some ShapeStyle {
        if skin.colorScheme == .dark {
            return AnyShapeStyle(Color.black.opacity(0.28))
        }
        return AnyShapeStyle(Color.white.opacity(0.86))
    }

    @ViewBuilder
    private var settingsInputOverlay: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .strokeBorder(skin.colorScheme == .dark ? Color.white.opacity(0.16) : Color.black.opacity(0.14), lineWidth: 1)
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
