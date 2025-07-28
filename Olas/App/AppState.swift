import SwiftUI
import NDKSwift
import Observation

// MARK: - App State
@MainActor
class AppState: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: NDKUser?
    
    // UI state
    @Published var selectedTab = 0
    @Published var isCreatingPost = false
    @Published var selectedImage: Data?
    @Published var replyingTo: NDKEvent?
    
    // Lazy reference to NostrManager
    private weak var nostrManager: NostrManager?
    private var authObservationTask: Task<Void, Never>?
    
    func setNostrManager(_ manager: NostrManager) {
        self.nostrManager = manager
        
        // Cancel any existing observation
        authObservationTask?.cancel()
        
        // Observe authentication state
        authObservationTask = Task { [weak self] in
            await self?.observeAuthState()
        }
    }
    
    private func observeAuthState() async {
        guard let nostrManager = nostrManager else { return }
        
        // Initial update
        await updateAuthState()
        
        // Observe auth state changes using withObservationTracking properly
        while !Task.isCancelled {
            _ = withObservationTracking {
                _ = nostrManager.isAuthenticated
            } onChange: {
                Task { [weak self] in
                    await self?.updateAuthState()
                }
            }
            
            // Only continue if task is not cancelled
            guard !Task.isCancelled else { break }
            
            // Small delay to prevent busy waiting
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
    }
    
    private func updateAuthState() async {
        guard let nostrManager = nostrManager else { return }
        
        isAuthenticated = nostrManager.isAuthenticated
        currentUser = await nostrManager.currentUser
    }
    
    deinit {
        authObservationTask?.cancel()
    }
    
    func reset() {
        isAuthenticated = false
        currentUser = nil
        selectedImage = nil
        replyingTo = nil
        isCreatingPost = false
    }
}