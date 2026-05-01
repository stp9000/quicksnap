import SwiftUI

public struct QuickSnapScenes: Scene {
    @StateObject private var document = AnnotationDocument()
    @StateObject private var skinManager = SkinManager()

    public init() {}

    public var body: some Scene {
        WindowGroup {
            ContentView(document: document)
                .environmentObject(skinManager)
                .frame(minWidth: 820, minHeight: 620)
                .preferredColorScheme(skinManager.current.colorScheme)
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Open Image...") {
                    document.openImageFromDisk()
                }
                .keyboardShortcut("o", modifiers: .command)

                Button("Save Image...") {
                    document.saveAnnotatedImage()
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(document.backgroundImage == nil)

                Button("Toggle Workspace") {
                    NotificationCenter.default.post(name: .quickSnapToggleWorkspace, object: nil)
                }
                .keyboardShortcut("w", modifiers: [.command, .shift])
                .disabled(document.selectedCapture == nil)
            }
        }

        Settings {
            SettingsView(document: document)
                .environmentObject(skinManager)
        }
    }
}
