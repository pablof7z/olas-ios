import Foundation
import NDKSwift
import SwiftUI
import Observation

@MainActor
@Observable
class NostrManager: ObservableObject {
    // MARK: - Core Properties
    
    private(set) var isConnected = false
    private(set) var isInitialized = false
    private var _ndk: NDK?
    
    var ndk: NDK {
        guard let ndk = _ndk else {
            fatalError("NDK accessed before initialization. Check isInitialized before accessing ndk.")
        }
        return ndk
    }
    
    var cache: NDKSQLiteCache?
    var zapManager: NDKZapManager?
    
    // Auth manager
    private(set) var authManager: NDKAuthManager?
    
    // Authentication status
    var isAuthenticated: Bool {
        authManager?.isAuthenticated ?? false
    }
    
    // Current user
    var currentUser: NDKUser? {
        guard let pubkey = authManager?.activeSession?.pubkey else { return nil }
        let user = NDKUser(pubkey: pubkey)
        user.ndk = self.ndk
        return user
    }
    
    // MARK: - Olas-specific Properties
    
    // Wallet integration (direct NIP60Wallet access)
    private(set) var cashuWallet: NIP60Wallet?
    private(set) var isLoadingWallet = false
    private(set) var walletError: Error?
    
    // Blossom integration
    private(set) var blossomManager: NDKBlossomServerManager?
    
    // MARK: - Configuration Overrides
    
    var defaultRelays: [String] {
        [
            RelayConstants.primal,
            RelayConstants.damus,
            RelayConstants.nosLol,
            RelayConstants.nostrBand,
            "wss://relay.nostr.wine"
        ]
    }
    
    var appRelaysKey: String {
        "OlasAppAddedRelays"
    }
    
    var clientTagConfig: NDKClientTagConfig? {
        NDKClientTagConfig(
            name: "Olas",
            relay: RelayConstants.primal,
            autoTag: true,
            excludedKinds: [
                EventKind.encryptedDirectMessage
            ]
        )
    }
    
    var sessionConfiguration: NDKSessionConfiguration {
        NDKSessionConfiguration(
            dataRequirements: [.followList, .muteList],
            preloadStrategy: .progressive
        )
    }
    
    // MARK: - Initialization
    
    init() {
        print("🎨 [OlasManager] Initializing...")
        
        // Configure NDK logging to show subscription details
        NDKLogger.configure(
            logLevel: .info,
            enabledCategories: [.subscription, .network, .relay, .general],
            logNetworkTraffic: false
        )
        print("🎨 [OlasManager] Configured NDK logging for subscription visibility")
        
        Task {
            await setupNDK()
        }
    }
    
    // MARK: - Setup
    
    func setupNDK() async {
        print("🎨 [OlasManager] Setting up NDK...")
        
        // Initialize SQLite cache for better performance and offline access
        do {
            cache = try await NDKSQLiteCache()
            let allRelays = getAllRelays()
            _ndk = NDK(relayUrls: allRelays, cache: cache)
            print("🎨 [OlasManager] NDK initialized with SQLite cache and \(allRelays.count) relays: \(allRelays)")
        } catch {
            print("🎨 [OlasManager] Failed to initialize SQLite cache: \(error). Continuing without cache.")
            let allRelays = getAllRelays()
            _ndk = NDK(relayUrls: allRelays)
            print("🎨 [OlasManager] NDK initialized without cache and \(allRelays.count) relays: \(allRelays)")
        }
        
        // Configure client tags if provided
        if let config = clientTagConfig {
            ndk.clientTagConfig = config
            print("🎨 [OlasManager] Configured NIP-89 client tags")
        }
        
        // Initialize zap manager
        zapManager = NDKZapManager(ndk: ndk)
        print("🎨 [OlasManager] Zap manager initialized")
        
        // Initialize auth manager
        authManager = NDKAuthManager(ndk: ndk)
        await authManager?.initialize()
        print("🎨 [OlasManager] Auth manager initialized")
        
        // Initialize Blossom manager
        blossomManager = NDKBlossomServerManager(ndk: ndk)
        print("🎨 [OlasManager] Initialized Blossom manager")
        
        Task {
            await connectToRelays()
        }
        
        // Mark as initialized
        isInitialized = true
        print("🎨 [OlasManager] Initialization complete")
    }
    
    func connectToRelays() async {
        print("🎨 [OlasManager] Connecting to relays...")
        await ndk.connect()
        isConnected = true
        print("🎨 [OlasManager] Connected to relays")
    }
    
    func getAllRelays() -> [String] {
        let appRelays = UserDefaults.standard.stringArray(forKey: appRelaysKey) ?? []
        return Array(Set(defaultRelays + appRelays))
    }
    
    var appAddedRelays: [String] {
        UserDefaults.standard.stringArray(forKey: appRelaysKey) ?? []
    }
    
    // MARK: - Authentication Wrapper Methods
    
    /// Login with private key and initialize Olas-specific features
    func olasLogin(with privateKey: String) async throws {
        print("🎨 [OlasManager] olasLogin() called")
        
        // Create signer and add session
        let signer = try NDKPrivateKeySigner(nsec: privateKey)
        guard let authManager = authManager else {
            throw NDKError.notConfigured("Auth manager not initialized")
        }
        _ = try await authManager.addSession(signer, requiresBiometric: true)
        
        // Start NDK session
        if authManager.isAuthenticated, let activeSigner = authManager.activeSigner {
            try await ndk.startSession(signer: activeSigner, config: sessionConfiguration)
        }
        
        // Initialize app-specific features
        await initializeAppFeatures()
    }
    
    /// Create new account and initialize Olas-specific features
    func olasCreateNewAccount(displayName: String, about: String? = nil, picture: String? = nil) async throws {
        print("🎨 [OlasManager] olasCreateNewAccount() called with displayName: \(displayName)")
        
        // Generate new key
        let signer = try NDKPrivateKeySigner.generate()
        
        // Add session
        guard let authManager = authManager else {
            throw NDKError.notConfigured("Auth manager not initialized")
        }
        _ = try await authManager.addSession(signer, requiresBiometric: true)
        
        // Start NDK session
        if authManager.isAuthenticated, let activeSigner = authManager.activeSigner {
            try await ndk.startSession(signer: activeSigner, config: sessionConfiguration)
        }
        
        // Create profile metadata dictionary
        var metadataDict: [String: String] = [:]
        metadataDict["name"] = displayName
        metadataDict["about"] = about ?? "Visual storyteller on Nostr 📸"
        if let picture = picture {
            metadataDict["picture"] = picture
        }
        
        // Convert to JSON string
        let metadataData = try JSONSerialization.data(withJSONObject: metadataDict, options: [])
        let metadataJSON = String(data: metadataData, encoding: .utf8) ?? "{}"
        
        // Create a profile event and publish it
        let profileEvent = try await NDKEventBuilder(ndk: ndk)
            .kind(0)
            .content(metadataJSON)
            .build(signer: signer)
        _ = try await ndk.publish(profileEvent)
        
        // Initialize app-specific features
        await initializeAppFeatures()
        
        print("🎨 [OlasManager] olasCreateNewAccount() completed successfully")
    }
    
    /// Logout and clear Olas-specific data
    func olasLogout() async {
        // Clear wallet data
        await clearWalletData()
        
        // Logout through auth manager
        authManager?.logout()
    }
    
    // MARK: - Wallet Management
    
    /// Load wallet for currently authenticated user
    func loadCashuWallet() async throws {
        print("🎨 [NostrManager] loadCashuWallet() called")
        guard authManager?.isAuthenticated == true else {
            print("🎨 [NostrManager] Not authenticated, throwing error")
            throw NDKError.notConfigured("Not authenticated")
        }
        
        guard isInitialized else {
            print("🎨 [NostrManager] NDK not initialized, throwing error")
            throw NDKError.notConfigured("NDK not initialized")
        }
        
        isLoadingWallet = true
        walletError = nil
        
        do {
            print("🎨 [NostrManager] Creating NIP60Wallet instance")
            let wallet = try NIP60Wallet(ndk: ndk)
            
            print("🎨 [NostrManager] Loading wallet...")
            try await wallet.load()
            
            // Register with zap manager if available
            if let zapManager = zapManager {
                await zapManager.register(provider: wallet)
            }
            
            self.cashuWallet = wallet
            print("🎨 [NostrManager] Wallet loaded successfully")
        } catch {
            print("🎨 [NostrManager] Failed to load wallet: \(error)")
            walletError = error
            throw error
        }
        
        isLoadingWallet = false
    }
    
    /// Clear wallet data and stop wallet operations
    func clearWalletData() async {
        print("🎨 [NostrManager] Clearing wallet data")
        
        // Stop wallet operations
        await cashuWallet?.stop()
        cashuWallet = nil
        walletError = nil
        isLoadingWallet = false
        
        print("🎨 [NostrManager] Wallet data cleared")
    }
    
    /// Configuration operations (batch updates)
    func saveMintConfiguration(mintURLs: [String]) async throws {
        guard let wallet = cashuWallet else {
            throw NDKError.notConfigured("Not authenticated")
        }
        
        // Get current relay configuration
        let relays = await wallet.walletConfigRelays
        
        // Setup wallet with new mint configuration
        try await wallet.setup(
            mints: mintURLs,
            relays: relays,
            publishMintList: true
        )
        
        print("🎨 [NostrManager] Saved mint configuration with \(mintURLs.count) mints")
    }
    
    // MARK: - App-specific Features
    
    private func initializeAppFeatures() async {
        // Load wallet in the background
        Task {
            do {
                try await loadCashuWallet()
                print("🎨 [OlasManager] Wallet loaded successfully")
            } catch {
                print("🎨 [OlasManager] Failed to load wallet: \(error)")
            }
        }
    }
}