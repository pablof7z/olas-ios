import Foundation
import NDKSwift
import CashuSwift
import SwiftUI

// JSONCoding is from NDKSwift
let JSONCoding = NDKSwift.JSONCoding.self

@MainActor
class OlasWalletManager: ObservableObject {
    @Published var wallet: NIP60Wallet?
    @Published var isLoading = false
    @Published var error: Error?
    
    /// Get current balance directly from the wallet
    var currentBalance: Int64 {
        get async {
            guard let wallet = wallet else { return 0 }
            return (try? await wallet.getBalance()) ?? 0
        }
    }
    
    /// Get transactions directly from the wallet's transaction history
    var transactions: [WalletTransaction] {
        get async {
            guard let wallet = wallet else { return [] }
            return await wallet.getRecentTransactions(limit: 50)
        }
    }
    
    /// Indicates if the wallet is properly configured with at least one mint
    var isWalletConfigured: Bool {
        get async {
            guard let wallet = wallet else { return false }
            let mints = await wallet.mints.getMintURLs()
            return !mints.isEmpty
        }
    }
    
    // Guard against duplicate initialization
    private var isInitializingWallet = false
    
    
    private let nostrManager: NostrManager
    
    init(nostrManager: NostrManager) {
        self.nostrManager = nostrManager
    }
    
    // MARK: - Wallet Operations
    
    /// Load wallet for currently authenticated user
    func loadWalletForCurrentUser() async throws {
        print("💰 OlasWalletManager.loadWalletForCurrentUser() called")
        guard NDKAuthManager.shared.isAuthenticated else {
            print("💰 Not authenticated, throwing error")
            throw WalletError.notAuthenticated
        }
        
        print("💰 Calling loadWallet()")
        try await loadWallet()
    }
    
    /// Load wallet from NIP-60 events
    func loadWallet() async throws {
        print("💰 OlasWalletManager.loadWallet() called")
        guard nostrManager.ndk != nil else {
            print("💰 NDK not initialized, throwing error")
            throw WalletError.ndkNotInitialized
        }
        
        isLoading = true
        defer { isLoading = false }
        
        print("💰 Calling ensureWalletExists()")
        // Ensure wallet exists (creates if needed)
        try await ensureWalletExists()
        
        guard wallet != nil else {
            print("💰 No wallet after ensureWalletExists, throwing error")
            throw WalletError.noActiveWallet
        }
        
        print("💰 Wallet loaded successfully")
    }
    
    /// Ensure wallet exists (called automatically by loadWallet)
    private func ensureWalletExists() async throws {
        print("💰 OlasWalletManager.ensureWalletExists() called")
        guard !isInitializingWallet else {
            print("💰 Already initializing wallet, skipping duplicate call")
            return
        }
        
        guard let ndk = nostrManager.ndk else {
            print("💰 NDK not initialized")
            throw WalletError.ndkNotInitialized
        }
        
        // Wait for signer to be available before creating wallet
        guard let signer = ndk.signer else {
            print("💰 Signer not available")
            throw WalletError.signerNotAvailable
        }
        
        isInitializingWallet = true
        defer { isInitializingWallet = false }
        
        let userPubkey = try await signer.pubkey
        print("💰 Got user pubkey: \(userPubkey.prefix(8))...")
        
        // Create NIP60Wallet instance with cache if available
        print("💰 Creating NIP60Wallet instance")
        let ndkWallet = try NIP60Wallet(ndk: ndk, cache: nostrManager.cache)
        
        // Set the wallet
        self.wallet = ndkWallet
        print("💰 Wallet set")
        
        // Register the wallet with the zap manager if available
        if let zapManager = nostrManager.zapManager {
            await zapManager.register(provider: ndkWallet)
        }
        
        // Load wallet - this will fetch initial config and subscribe to wallet events
        print("💰 Calling ndkWallet.load()")
        try await ndkWallet.load()
        print("💰 ndkWallet.load() completed")
        
        // Check if wallet has mints configured
        let fetchedMintURLs = await ndkWallet.mints.getMintURLs()
        print("💰 Current mint URLs: \(fetchedMintURLs)")
        if fetchedMintURLs.isEmpty {
            print("⚠️ OlasWalletManager - No mints configured. User needs to add mints in wallet settings.")
        } else {
            print("✅ OlasWalletManager - Wallet loaded with \(fetchedMintURLs.count) mints")
        }
    }
    
    
    /// Add a new mint
    func addMint(_ mintURL: String) async throws {
        guard let wallet = wallet else {
            throw WalletError.noActiveWallet
        }
        
        guard let url = URL(string: mintURL) else {
            throw WalletError.invalidMintURL
        }
        
        await wallet.mints.addMintURL(url: url)
    }
    
    /// Remove a mint
    func removeMint(_ mintURL: String) async throws {
        guard let wallet = wallet else {
            throw WalletError.noActiveWallet
        }
        
        guard let url = URL(string: mintURL) else {
            throw WalletError.invalidMintURL
        }
        
        _ = await wallet.mints.removeMint(url: url)
    }
    
    /// Pay a Lightning invoice
    func payLightning(invoice: String, amount: Int64) async throws -> String {
        guard let wallet = wallet else {
            throw WalletError.noActiveWallet
        }
        
        let (preimage, feePaid) = try await wallet.payLightning(
            invoice: invoice,
            amount: amount
        )
        
        print("💰 Paid Lightning invoice: \(amount) sats, fee: \(feePaid ?? 0) sats")
        return preimage
    }
    
    /// Send ecash tokens
    func send(amount: Int64, memo: String?, fromMint: URL? = nil) async throws -> String {
        guard let wallet = wallet else {
            throw WalletError.noActiveWallet
        }
        
        // Select mint if not specified
        let selectedMintURL: URL
        if let fromMint = fromMint {
            selectedMintURL = fromMint
        } else {
            // Auto-select mint with sufficient balance
            let mintURLs = await wallet.mints.getMintURLs()
            let mints = mintURLs.compactMap { URL(string: $0) }
            var selectedMint: URL?
            
            for mint in mints {
                let balance = await wallet.getBalance(mint: mint)
                if balance >= amount {
                    selectedMint = mint
                    break
                }
            }
            
            guard let selected = selectedMint else {
                throw WalletError.insufficientBalance
            }
            selectedMintURL = selected
        }
        
        // Generate P2PK pubkey for locking
        let p2pkPubkey = try await wallet.getP2PKPubkey()
        
        // Send tokens (creates P2PK locked proofs)
        let (proofs, _) = try await wallet.send(
            amount: amount,
            to: p2pkPubkey,
            mint: selectedMintURL
        )
        
        // Create token from proofs
        let token = CashuSwift.Token(
            proofs: [selectedMintURL.absoluteString: proofs],
            unit: "sat",
            memo: memo
        )
        
        // Encode token
        let tokenData = try JSONCoding.encoder.encode(token)
        guard String(data: tokenData, encoding: .utf8) != nil else {
            throw WalletError.encodingError
        }
        
        // Create base64url encoded token
        let base64Token = tokenData.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        
        let tokenString = "cashuA\(base64Token)"
        
        print("💰 Sent \(amount) sats")
        return tokenString
    }
    
    /// Send a nutzap
    func sendNutzap(
        to recipient: String,
        amount: Int64,
        comment: String?,
        acceptedMints: [URL]
    ) async throws {
        print("💰 OlasWalletManager.sendNutzap called - recipient: \(recipient), amount: \(amount)")
        
        guard let wallet = wallet else {
            print("❌ No wallet!")
            throw WalletError.noActiveWallet
        }
        
        // Create nutzap request
        let request = NutzapPaymentRequest(
            amountSats: amount,
            recipientPubkey: recipient,
            recipientP2PK: "", // Empty P2PK for now, will be set by wallet
            acceptedMints: acceptedMints,
            comment: comment
        )
        
        print("💰 Created NutzapPaymentRequest, calling wallet.pay()")
        
        // Send nutzap
        _ = try await wallet.pay(request)
        
        print("✅ Nutzap completed successfully!")
    }
    
    /// Mint tokens from a Lightning invoice
    func mintTokens(amount: Int64, mint mintURL: URL) async throws -> String {
        guard let wallet = wallet else {
            throw WalletError.noActiveWallet
        }
        
        // Request mint quote
        let mintQuote = try await wallet.mints.requestMintQuote(
            amount: amount,
            mintURL: mintURL.absoluteString
        )
        
        // Return the Lightning invoice to be paid
        return mintQuote.request
    }
    
    /// Generate a Lightning invoice to receive payment
    func generateInvoice(amount: Int64, description: String?) async throws -> String {
        guard let wallet = wallet else {
            throw WalletError.noActiveWallet
        }
        
        // Get first available mint
        let mintURLs = await wallet.mints.getMintURLs()
        guard let firstMintString = mintURLs.first,
              let mintURL = URL(string: firstMintString) else {
            throw WalletError.noActiveWallet
        }
        
        // Request mint quote to get Lightning invoice
        let mintQuote = try await wallet.mints.requestMintQuote(
            amount: amount,
            mintURL: mintURL.absoluteString
        )
        
        // Return the Lightning invoice
        return mintQuote.request
    }
    
    /// Receive ecash tokens
    func receive(tokenString: String) async throws -> Int64 {
        guard let wallet = wallet else {
            throw WalletError.noActiveWallet
        }
        
        // Parse token string to get amount first
        guard tokenString.hasPrefix("cashuA") else {
            throw WalletError.invalidToken
        }
        
        let base64Part = String(tokenString.dropFirst(6))
        
        // Convert base64url to base64
        var base64 = base64Part
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        // Add padding if needed
        while base64.count % 4 != 0 {
            base64.append("=")
        }
        
        guard let tokenData = Data(base64Encoded: base64),
              let token = try? JSONCoding.decoder.decode(CashuSwift.Token.self, from: tokenData) else {
            throw WalletError.invalidToken
        }
        
        // Calculate total amount from token (currently unused but may be needed for validation)
        _ = token.proofsByMint.values.reduce(0) { sum, proofs in
            sum + proofs.reduce(0) { $0 + Int64($1.amount) }
        }
        
        var totalReceived: Int64 = 0
        
        // Process proofs from each mint
        for (_, proofs) in token.proofsByMint {
            // Receive the proofs - wallet can handle proofs from any mint
            try await wallet.receive(proofs: proofs)
            
            // Calculate total
            totalReceived += proofs.reduce(0) { $0 + Int64($1.amount) }
        }
        
        print("💰 Successfully received \(totalReceived) sats")
        return totalReceived
    }
    
    /// Get active mint URLs
    func getActiveMintURLs() async -> [String] {
        guard let wallet = wallet else { return [] }
        return await wallet.mints.getMintURLs()
    }
    
    /// Get mint balance
    func getMintBalance(mint mintURL: URL) async -> Int64 {
        guard let wallet = wallet else { return 0 }
        return await wallet.getBalance(mint: mintURL)
    }
    
    /// Get all mint balances
    func getAllMintBalances() async -> [String: Int64] {
        guard let wallet = wallet else { return [:] }
        let mintURLs = await wallet.mints.getMintURLs()
        var balances: [String: Int64] = [:]
        
        for mintString in mintURLs {
            if let mintURL = URL(string: mintString) {
                let balance = await wallet.getBalance(mint: mintURL)
                balances[mintString] = balance
            }
        }
        
        return balances
    }
    
    // MARK: - Session Management
    
    /// Clear all wallet data (called during logout)
    func clearWalletData() {
        // Clear wallet state
        wallet = nil
        
        print("💰 OlasWalletManager - Cleared all wallet data")
    }
    
    deinit {
        print("💰 OlasWalletManager - Deallocated")
    }
}


// MARK: - WalletTransaction Extensions

extension WalletTransaction {
    /// UI-friendly display description for transactions
    var uiDisplayDescription: String {
        if let memo = memo, !memo.isEmpty {
            return memo
        }
        return displayDescription
    }
    
    /// UI-friendly transaction type text
    var uiTypeText: String {
        switch type {
        case .send:
            return "Sent"
        case .receive:
            return "Received"
        case .nutzapSent:
            return "Zap Sent"
        case .nutzapReceived:
            return "Zap Received"
        case .mint:
            return "Minted"
        case .melt:
            return "Melted"
        case .swap:
            return "Swapped"
        }
    }
    
    /// Check if transaction is incoming for UI purposes
    var isIncoming: Bool {
        return direction == .incoming || type == .receive || type == .mint || type == .nutzapReceived
    }
    
    /// Get the lightning invoice for display if available
    var invoiceForDisplay: String? {
        return lightningData?.invoice
    }
    
    /// Get formatted mint URL for display
    var formattedMintURL: String? {
        guard let mint = mint else { return nil }
        return mint.replacingOccurrences(of: "https://", with: "")
    }
}

// MARK: - Error Types

enum WalletError: LocalizedError {
    case notAuthenticated
    case ndkNotInitialized
    case noActiveWallet
    case insufficientBalance
    case invalidToken
    case encodingError
    case signerNotAvailable
    case invalidMintURL
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User not authenticated"
        case .ndkNotInitialized:
            return "NDK not initialized"
        case .noActiveWallet:
            return "No wallet found"
        case .insufficientBalance:
            return "Insufficient balance"
        case .invalidToken:
            return "Invalid token format"
        case .encodingError:
            return "Failed to encode data"
        case .signerNotAvailable:
            return "Signer not available yet"
        case .invalidMintURL:
            return "Invalid mint URL"
        }
    }
}