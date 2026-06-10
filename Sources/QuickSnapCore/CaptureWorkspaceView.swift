import AppKit
import SwiftUI

struct CaptureWorkspaceView: View {
    @ObservedObject var document: AnnotationDocument
    let skin: AppSkin
    @Binding var selectedTab: CaptureWorkspaceTab
    @Binding var inspectorShowsAllFields: Bool
    let onClose: () -> Void

    private let contentCardCornerRadius: CGFloat = 8
    private var toolbarIconColor: Color { Color.white.opacity(skin.isGlass ? 0.82 : 0.9) }
    private var selectedCaptureTitle: String { document.selectedCapture?.displayTitle ?? "Workspace" }

    var body: some View {
        VStack(spacing: 0) {
            header

            Rectangle()
                .fill(skin.isModern ? skin.border : skin.separator)
                .frame(height: 1)

            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(canvasBackground)
        }
        .background(canvasBackground)
        .onChange(of: document.selectedCaptureID) { _ in
            inspectorShowsAllFields = false
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Label("Workspace", systemImage: "square.grid.2x2")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)

            Text(selectedCaptureTitle)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: 220, alignment: .leading)

            Picker("Workspace", selection: $selectedTab) {
                ForEach(CaptureWorkspaceTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 420)

            Spacer(minLength: 0)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .foregroundColor(toolbarIconColor)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help("Return to Editor")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(toolbarBackground)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .overview:
            overviewContent
        case .artifacts:
            artifactContent
        case .cloud:
            cloudContent
        case .wiki:
            wikiContent
        case .ai:
            aiContent
        }
    }

    private var overviewContent: some View {
        page {
            if let capture = document.selectedCapture {
                captureSummary(capture: capture)

                LazyVGrid(columns: overviewColumns, alignment: .leading, spacing: 14) {
                    infoCard {
                        sectionTitle("Capture Details")
                        LazyVGrid(columns: detailColumns, alignment: .leading, spacing: 12) {
                            ForEach(inspectorFields(for: capture), id: \.label) { field in
                                if field.isLink {
                                    metadataLinkRow(label: field.label, value: field.value)
                                } else {
                                    metadataRow(label: field.label, value: field.value)
                                }
                            }
                        }
                    }

                    infoCard {
                        sectionTitle("Tags")
                        FlowLayout(horizontalSpacing: 6, verticalSpacing: 6) {
                            if capture.tags.isEmpty {
                                Text("No tags yet")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(skin.textSecondary)
                            } else {
                                ForEach(capture.tags, id: \.self) { tag in
                                    tagPill(tag)
                                }
                            }
                        }
                        TextField("comma, separated, tags", text: $document.selectedCaptureTagsText)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                document.saveSelectedCaptureTags()
                            }
                        FlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                            pillButton("Save Tags") {
                                document.saveSelectedCaptureTags()
                            }
                            pillButton("Reveal Library") {
                                document.revealCaptureLibraryInFinder()
                            }
                        }
                    }
                }

            } else {
                emptyState(
                    symbol: "square.grid.2x2",
                    title: "No capture selected",
                    message: "Select a stored capture from the library to inspect details."
                )
            }
        }
    }

    private var cloudContent: some View {
        page {
            VStack(alignment: .leading, spacing: 14) {
                sectionTitle("Cloud Storage")

                if let capture = document.selectedCapture {
                    let objectKey = document.cloudObjectKey(for: capture)
                    infoCard {
                        metadataRow(label: "Status", value: document.storageStatusText(for: capture))
                        metadataRow(label: "Object Key", value: objectKey)
                        metadataRow(label: "Endpoint", value: document.cloudAssetEndpoint)
                        metadataRow(label: "Bucket", value: document.cloudAssetBucket)
                        metadataRow(label: "Prefix", value: document.cloudAssetPrefix)
                    }

                    if document.hasCloudUploadFailure(capture) {
                        infoCard {
                            metadataRow(label: "Upload State", value: "Cloud upload failed")
                            metadataRow(label: "Last Cloud Error", value: capture.cloudUploadError.isEmpty ? document.statusMessage : capture.cloudUploadError)
                        }
                    }

                    Button("Reveal Library in Finder") {
                        document.revealCaptureLibraryInFinder()
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(skin.accent)

                    Button("Copy Object Key") {
                        copyText(objectKey)
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(skin.accent)
                } else {
                    Text("Select a stored capture to inspect cloud storage details.")
                        .font(.caption)
                        .foregroundColor(skin.textSecondary)
                }
            }
        }
    }

    private var wikiContent: some View {
        page {
            VStack(alignment: .leading, spacing: 14) {
                sectionTitle("Wiki")

                if let capture = document.selectedCapture {
                    infoCard {
                        metadataRow(label: "Ingest Status", value: capture.presetPayload.wikiIngestStatus)
                        metadataRow(label: "Capture Page", value: capture.presetPayload.wikiCapturePagePath)
                        metadataRow(label: "Entities", value: capture.presetPayload.wikiEntities.joined(separator: "\n"))
                        metadataRow(label: "Concepts", value: capture.presetPayload.wikiConcepts.joined(separator: "\n"))
                        metadataRow(label: "Pages", value: capture.presetPayload.wikiPagesAffected.joined(separator: "\n"))
                        metadataRow(label: "Error", value: capture.presetPayload.wikiIngestError)
                    }

                    Button(capture.presetPayload.wikiIngestStatus == "complete" ? "Re-ingest to Wiki" : "Ingest to Wiki") {
                        document.ingestSelectedCaptureToWiki()
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(skin.accent)
                } else {
                    Text("Select a stored capture to inspect wiki status.")
                        .font(.caption)
                        .foregroundColor(skin.textSecondary)
                }
            }
        }
    }

    private var aiContent: some View {
        page {
            VStack(alignment: .leading, spacing: 14) {
                sectionTitle("AI")

                if let capture = document.selectedCapture {
                    infoCard {
                        metadataRow(label: "Analysis Status", value: capture.analysis.status.displayName)
                        metadataRow(label: "Summary", value: capture.analysis.summary)
                        metadataRow(label: "Severity", value: capture.analysis.severity)
                        metadataRow(label: "Suggested Tags", value: capture.analysis.tags.joined(separator: ", "))
                        metadataRow(label: "Recommended Actions", value: capture.analysis.recommendedActions.joined(separator: "\n"))
                    }

                    if let analysisErrorMessage = document.analysisErrorMessage, !analysisErrorMessage.isEmpty {
                        infoCard {
                            metadataRow(label: "Analysis Error", value: analysisErrorMessage)
                        }
                    }

                    Button("Run Analysis") {
                        document.runAIAnalysisForSelectedCapture()
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(skin.accent)
                } else {
                    Text("Select a stored capture to inspect analysis.")
                        .font(.caption)
                        .foregroundColor(skin.textSecondary)
                }
            }
        }
    }

    private var artifactContent: some View {
        page {
            if document.selectedCapture == nil {
                emptyState(
                    symbol: "doc.text",
                    title: "No artifact selected",
                    message: "Select a stored capture to preview Markdown and issue artifacts."
                )
            } else {
                if let capture = document.selectedCapture {
                    captureSummary(capture: capture)
                }

                infoCard {
                    HStack(spacing: 12) {
                        sectionTitle("Artifact")

                        Picker("Artifact", selection: $document.selectedSendPreviewKind) {
                            Text("Markdown").tag(SendPreviewKind.markdownDocument)
                            if document.canSendToGitHub {
                                Text("GitHub Issue").tag(SendPreviewKind.githubIssueURL)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 180)

                        Spacer(minLength: 0)
                    }

                    if document.selectedPreviewText != nil {
                        FlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                            pillButton("Copy") {
                                document.copySelectedPreviewArtifact()
                            }

                            if document.selectedSendPreviewKind == .markdownDocument {
                                pillButton("Export") {
                                    document.exportSelectedPreviewArtifactIfAvailable()
                                }
                            }

                            if document.selectedSendPreviewKind == .githubIssueURL && document.canSendToGitHub {
                                pillButton("Review") {
                                    document.openBugReportSubmissionSheet()
                                }

                                pillButton("Copy Screenshot") {
                                    document.copySelectedCaptureImageForGitHub()
                                }

                                pillButton("Send to GitHub") {
                                    document.openSelectedCaptureGitHubIssue()
                                }
                            }
                        }
                    }
                }

                if let previewText = document.selectedPreviewText {
                    infoCard {
                        Text(document.selectedPreviewTitle)
                            .font(skin.primaryFont(size: 13))
                            .foregroundColor(skin.accent)

                        if document.selectedSendPreviewKind == .githubIssueURL {
                            Text("QuickSnap will copy the current screenshot to your clipboard and open a prefilled GitHub new-issue page with the draft title, body, and labels.")
                                .font(.caption)
                                .foregroundColor(skin.textSecondary)

                            if let lastSubmittedIssueURL = document.lastSubmittedIssueURL, !lastSubmittedIssueURL.isEmpty {
                                metadataRow(label: "Last opened issue URL", value: lastSubmittedIssueURL)
                            }

                            if let submissionErrorMessage = document.submissionErrorMessage, !submissionErrorMessage.isEmpty {
                                Text(submissionErrorMessage)
                                    .font(.caption)
                                    .foregroundColor(.red.opacity(0.9))
                            }
                        }

                        Text(previewText)
                            .font(.system(size: 11, weight: .medium, design: document.selectedSendPreviewKind.usesMonospace ? .monospaced : .default))
                            .foregroundColor(.primary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color.black.opacity(skin.isModern ? 0.12 : 0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                } else {
                    Text("This workspace artifact is unavailable for the selected capture.")
                        .font(.caption)
                        .foregroundColor(skin.textSecondary)
                }
            }
        }
    }

    private var detailColumns: [GridItem] {
        [
            GridItem(.adaptive(minimum: 190, maximum: 320), spacing: 16, alignment: .topLeading)
        ]
    }

    private var overviewColumns: [GridItem] {
        [
            GridItem(.adaptive(minimum: 320, maximum: 460), spacing: 14, alignment: .topLeading)
        ]
    }

    private func page<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                content()
            }
            .padding(18)
            .frame(maxWidth: 980, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func infoCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: contentCardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: contentCardCornerRadius, style: .continuous)
                .strokeBorder(skin.isModern ? skin.border.opacity(0.7) : skin.separator.opacity(0.5), lineWidth: 1)
        )
    }

    private func captureSummary(capture: CaptureRecord) -> some View {
        HStack(alignment: .center, spacing: 12) {
                CaptureThumbnailView(capture: capture, fallbackImage: document.thumbnailImage(for: capture))
                    .frame(width: 54, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text(capture.displayTitle)
                        .font(skin.primaryFont(size: 15))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Text("\(document.timelineTimestamp(for: capture)) · \(capture.metadataBadgeTitle) · \(capture.dimensionsText)")
                        .font(.caption)
                        .foregroundColor(skin.textSecondary)
                        .lineLimit(1)

                    if let primaryURL = capture.primaryURL, !primaryURL.isEmpty, let url = URL(string: primaryURL) {
                        Link(primaryURL, destination: url)
                            .font(.caption)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 12)

                Label(
                    document.storageStatusText(for: capture),
                    systemImage: document.hasCloudUploadFailure(capture) ? "cloud.slash" : (document.isCloudHostedCapture(capture) ? "cloud.fill" : "internaldrive")
                )
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(document.hasCloudUploadFailure(capture) ? .orange : skin.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.white.opacity(skin.isGlass ? 0.1 : 0.05)))
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 4)
    }

    private func metadataRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(skin.textSecondary)
            Text(value.isEmpty ? "Unavailable" : value)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(3)
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
                    .lineLimit(3)
            } else {
                Text(value.isEmpty ? "Unavailable" : value)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(3)
            }
        }
    }

    private func tagPill(_ tag: String) -> some View {
        Text(tag)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(skin.accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(Color.white.opacity(skin.isGlass ? 0.1 : 0.05))
            )
            .overlay(
                Capsule()
                    .stroke(skin.accent.opacity(0.25), lineWidth: 1)
            )
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
            InspectorField(label: "Status", value: document.storageStatusText(for: capture))
        ]

        let detailFields: [InspectorField]
        let wikiFields = [
            InspectorField(label: "Wiki Ingest", value: capture.presetPayload.wikiIngestStatus),
            InspectorField(label: "Wiki Entities", value: capture.presetPayload.wikiEntities.joined(separator: "\n")),
            InspectorField(label: "Wiki Concepts", value: capture.presetPayload.wikiConcepts.joined(separator: "\n")),
            InspectorField(label: "Wiki Pages", value: capture.presetPayload.wikiPagesAffected.joined(separator: "\n")),
            InspectorField(label: "Wiki Capture Page", value: capture.presetPayload.wikiCapturePagePath),
            InspectorField(label: "Wiki Error", value: capture.presetPayload.wikiIngestError)
        ]
        switch capture.normalizedPresetID {
        case "markdown":
            detailFields = [
                InspectorField(label: "Page Title", value: capture.presetPayload.pageTitle),
                InspectorField(label: "Page URL", value: capture.presetPayload.urlString, isLink: true),
                InspectorField(label: "Canonical URL", value: capture.presetPayload.canonicalURL, isLink: true),
                InspectorField(label: "Viewport", value: capture.presetPayload.viewport),
                InspectorField(label: "Referrer", value: capture.presetPayload.referrerURL, isLink: true),
                InspectorField(label: "Clip Status", value: capture.presetPayload.markdownClipStatus),
                InspectorField(label: "Extraction Engine", value: capture.presetPayload.markdownExtractionEngine),
                InspectorField(label: "Site", value: capture.presetPayload.markdownSiteName),
                InspectorField(label: "Author", value: capture.presetPayload.markdownAuthor),
                InspectorField(label: "Published", value: capture.presetPayload.markdownPublishedDate),
                InspectorField(label: "Word Count", value: capture.presetPayload.markdownWordCount > 0 ? "\(capture.presetPayload.markdownWordCount)" : ""),
                InspectorField(label: "Source HTML", value: capture.presetPayload.sourceHTMLCharacterCount > 0 ? "\(capture.presetPayload.sourceHTMLCharacterCount) characters" : ""),
                InspectorField(label: "Filtered HTML", value: capture.presetPayload.filteredHTMLCharacterCount > 0 ? "\(capture.presetPayload.filteredHTMLCharacterCount) characters" : ""),
                InspectorField(label: "Extraction Error", value: capture.presetPayload.markdownExtractionError),
                InspectorField(label: "Markdown File", value: capture.presetPayload.markdownFilePath),
                InspectorField(label: "Excerpt", value: capture.presetPayload.markdownClipExcerpt)
            ] + wikiFields
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
            ] + wikiFields
        default:
            detailFields = wikiFields
        }

        let fields = baseFields + detailFields
        return fields.filter { !$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private func pillButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(skin.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(skin.isGlass ? 0.1 : 0.05))
                )
                .overlay(
                    Capsule()
                        .stroke(skin.accent.opacity(0.22), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.primary)
            .padding(.bottom, 2)
    }

    private func emptyState(symbol: String, title: String, message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 28))
                .foregroundColor(skin.accentDim)
            Text(title)
                .font(skin.primaryFont(size: 15))
                .foregroundColor(skin.accent)
            Text(message)
                .font(.caption)
                .foregroundColor(skin.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .padding(32)
    }

    private func copyText(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
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
    private var cardBackground: some View {
        if skin.isGlass {
            RoundedRectangle(cornerRadius: contentCardCornerRadius, style: .continuous)
                .fill(.thinMaterial)
        } else if skin.isModern {
            RoundedRectangle(cornerRadius: contentCardCornerRadius, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.28))
        } else {
            RoundedRectangle(cornerRadius: contentCardCornerRadius, style: .continuous)
                .fill(skin.surface.opacity(0.5))
        }
    }
}

private struct InspectorField {
    let label: String
    let value: String
    var isLink: Bool = false
}
