import SwiftUI

@main
struct ClipForgeApp: App {
    @StateObject private var store = EditorStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .task { await store.bootstrap() }
        }
    }
}
