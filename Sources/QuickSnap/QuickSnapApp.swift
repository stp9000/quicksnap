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

        Settings {
            SettingsView(document: document)
                .environmentObject(skinManager)
        }
    }
}
