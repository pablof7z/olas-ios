import SwiftUI
import NDKSwift

// This file is kept for backward compatibility but redirects to OlasWalletView
struct WalletView: View {
    let nostrManager: NostrManager
    
    var body: some View {
        OlasWalletView()
            .environment(nostrManager)
    }
}