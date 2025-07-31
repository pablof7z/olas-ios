import SwiftUI
import NDKSwift

struct ContentView: View {
    @Environment(NostrManager.self) private var nostrManager
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Group {
            if nostrManager.isAuthenticated && appState.isAuthenticated {
                // Authenticated content
                MainTabView()
            } else {
                // Authentication screen
                AuthenticationView()
            }
        }
        .onAppear {
            // Link AppState to NostrManager
            appState.setNostrManager(nostrManager)
        }
    }
}