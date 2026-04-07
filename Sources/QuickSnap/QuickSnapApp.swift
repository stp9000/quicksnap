import SwiftUI

@main
struct QuickSnapApp: App {
    @StateObject private var document = AnnotationDocument()
    @StateObject private var skinManager = SkinManager()

    var body: some Scene {
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
            }
        }

        Settings {
            SettingsView(document: document)
                .environmentObject(skinManager)
        }
    }
}
