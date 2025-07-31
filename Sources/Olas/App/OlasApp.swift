import SwiftUI
import NDKSwift

@main
struct OlasApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
        }
    }
}

enum AuthError: LocalizedError {
    case invalidKey
    
    var errorDescription: String? {
        switch self {
        case .invalidKey:
            return "Invalid private key"
        }
    }
}

@MainActor
class AppState: ObservableObject {
    @Published var ndk: NDK
    @Published var currentUser: NDKUser?
    @Published var isAuthenticated = false
    
    private let authManager = NDKAuthManager.shared
    
    var activeSigner: NDKSigner? {
        authManager.activeSigner
    }
    
    init() {
        // Initialize NDK synchronously
        ndk = NDK()
        setupNDK()
    }
    
    // MARK: - Authentication Methods
    
    func createAccount() async throws {
        let signer = try NDKPrivateKeySigner.generate()
        
        // Create persistent auth session
        let session = try await authManager.addSession(
            signer,
            requiresBiometric: false
        )
        
        // Start NDK session
        try await ndk.startSession(
            signer: signer,
            config: NDKSessionConfiguration(
                dataRequirements: [.followList],
                preloadStrategy: .progressive
            )
        )
        
        isAuthenticated = true
    }
    
    func importAccount(nsec: String) async throws {
        let signer = try NDKPrivateKeySigner(nsec: nsec)
        
        // Create persistent auth session
        let session = try await authManager.addSession(
            signer,
            requiresBiometric: false
        )
        
        // Start NDK session
        try await ndk.startSession(
            signer: signer,
            config: NDKSessionConfiguration(
                dataRequirements: [.followList],
                preloadStrategy: .progressive
            )
        )
        
        isAuthenticated = true
    }
    
    func logout() async {
        // Clear all sessions from keychain
        try? await authManager.clearAllSessions()
        
        // Clear memory state
        authManager.logout()
        
        // Clear NDK signer
        ndk?.signer = nil
        
        isAuthenticated = false
    }
    
    private func setupNDK() {
        Task {
            do {
                // Add default relays
                try await ndk.addRelay("wss://relay.damus.io")
                try await ndk.addRelay("wss://relay.nostr.band")
                try await ndk.addRelay("wss://nos.lol")
                try await ndk.connect()
                
                // Set NDK on auth manager and initialize
                authManager.setNDK(ndk)
                await authManager.initialize()
                
                // Update authentication state
                isAuthenticated = authManager.hasActiveSession
                
                // If authenticated, set the signer on NDK
                if let signer = authManager.activeSigner {
                    ndk.signer = signer
                }
            } catch {
                print("Failed to setup NDK: \(error)")
            }
        }
    }
}