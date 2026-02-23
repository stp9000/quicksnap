import SwiftUI

@main
struct QuickSnapApp: App {
    @StateObject private var document = AnnotationDocument()
    @AppStorage("quicksnap.darkMode") private var isDarkMode = true

    var body: some Scene {
        WindowGroup {
            ContentView(document: document, isDarkMode: $isDarkMode)
                .frame(minWidth: 1000, minHeight: 700)
                .preferredColorScheme(isDarkMode ? .dark : .light)
        }
    }
}
