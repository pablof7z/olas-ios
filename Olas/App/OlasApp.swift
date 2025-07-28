import SwiftUI
import NDKSwift

@main
struct OlasApp: App {
    @State private var nostrManager: NostrManager
    @StateObject private var appState = AppState()
    
    init() {
        let manager = NostrManager()
        self._nostrManager = State(initialValue: manager)
        self._appState = StateObject(wrappedValue: AppState())
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(nostrManager)
                .environmentObject(appState)
                .preferredColorScheme(.dark)
        }
    }
}