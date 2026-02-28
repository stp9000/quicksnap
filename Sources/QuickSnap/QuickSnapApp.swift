import SwiftUI

@main
struct QuickSnapApp: App {
    @StateObject private var document = AnnotationDocument()

    var body: some Scene {
        WindowGroup {
            ContentView(document: document)
                .frame(minWidth: 1000, minHeight: 700)
                .preferredColorScheme(.dark)
        }
    }
}
