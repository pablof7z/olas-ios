import SwiftUI
import NDKSwift

struct NutZapView: View {
    @ObservedObject var walletManager: OlasWalletManager
    let nostrManager: NostrManager
    let recipientPubkey: String?
    
    @State private var selectedAmount: Int64 = 21
    @State private var customAmount: String = ""
    @State private var comment: String = ""
    @State private var isSearching = false
    @State private var searchQuery = ""
    @State private var selectedUser: NDKUserProfile?
    @State private var selectedUserPubkey: String?
    @State private var isSending = false
    @State private var showSuccess = false
    @State private var errorMessage: String?
    @State private var currentBalance: Int64 = 0
    
    @Environment(\.dismiss) private var dismiss
    
    private let quickAmounts: [Int64] = [21, 100, 500, 1000, 5000, 10000]
    
    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient
                mainContent
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                toolbarContent
            }
            .task {
                // Load current balance
                currentBalance = await walletManager.currentBalance
                
                if let pubkey = recipientPubkey {
                    await loadUserProfile(pubkey: pubkey)
                }
            }
            .alert("Success!", isPresented: $showSuccess) {
                Button("Done") {
                    dismiss()
                }
            } message: {
                Text("NutZap sent successfully!")
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                if let error = errorMessage {
                    Text(error)
                }
            }
        }
    }
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                OlasDesign.Colors.background,
                OlasDesign.Colors.surface.opacity(0.5)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
    
    private var mainContent: some View {
        ScrollView {
            VStack(spacing: OlasDesign.Spacing.xl) {
                headerSection
                recipientSection
                amountSection
                commentField
                sendButton
            }
            .padding(.horizontal, OlasDesign.Spacing.lg)
            .padding(.bottom, OlasDesign.Spacing.xl)
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button("Cancel") {
                dismiss()
            }
            .foregroundStyle(OlasDesign.Colors.primary)
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: OlasDesign.Spacing.sm) {
            Text("⚡ NutZap")
                .font(OlasDesign.Typography.title)
                .foregroundStyle(OlasDesign.Colors.text)
            
            Text("Send ecash instantly")
                .font(OlasDesign.Typography.body)
                .foregroundStyle(OlasDesign.Colors.textSecondary)
            
            HStack(spacing: 4) {
                Text("Balance:")
                    .font(OlasDesign.Typography.caption)
                    .foregroundStyle(OlasDesign.Colors.textTertiary)
                
                Text("\(currentBalance) sats")
                    .font(OlasDesign.Typography.caption)
                    .foregroundStyle(OlasDesign.Colors.primary)
            }
        }
        .padding(.top, OlasDesign.Spacing.md)
    }
    
    private var recipientSection: some View {
        Group {
            if recipientPubkey == nil {
                recipientSelector
            } else if let userProfile = selectedUser {
                selectedRecipientCard(profile: userProfile, pubkey: recipientPubkey!)
            }
        }
    }
    
    private var recipientSelector: some View {
        VStack(alignment: .leading, spacing: OlasDesign.Spacing.sm) {
            Text("Recipient")
                .font(OlasDesign.Typography.bodyMedium)
                .foregroundStyle(OlasDesign.Colors.text)
            
            HStack(spacing: OlasDesign.Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(OlasDesign.Colors.textTertiary)
                
                TextField("Search by name or npub...", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        Task {
                            await searchUser()
                        }
                    }
            }
            .padding(OlasDesign.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: OlasDesign.CornerRadius.md)
                    .fill(OlasDesign.Colors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: OlasDesign.CornerRadius.md)
                    .stroke(OlasDesign.Colors.divider, lineWidth: 1)
            )
            
            if isSearching {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Searching...")
                        .font(OlasDesign.Typography.caption)
                        .foregroundStyle(OlasDesign.Colors.textSecondary)
                }
                .padding(.top, OlasDesign.Spacing.xs)
            }
        }
    }
    
    private func selectedRecipientCard(profile: NDKUserProfile, pubkey: String) -> some View {
        HStack(spacing: OlasDesign.Spacing.md) {
            // Avatar
            if let avatarURL = profile.picture {
                AsyncImage(url: URL(string: avatarURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(OlasDesign.Colors.surface)
                        .overlay(
                            Text((profile.displayName ?? profile.name ?? "?").prefix(1))
                                .font(OlasDesign.Typography.bodyMedium)
                                .foregroundStyle(OlasDesign.Colors.textSecondary)
                        )
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(profile.displayName ?? profile.name ?? "Anonymous")
                    .font(OlasDesign.Typography.bodyMedium)
                    .foregroundStyle(OlasDesign.Colors.text)
                
                Text("@\(profile.name ?? String(pubkey.prefix(8)))")
                    .font(OlasDesign.Typography.caption)
                    .foregroundStyle(OlasDesign.Colors.textSecondary)
            }
            
            Spacer()
            
            if recipientPubkey == nil {
                Button {
                    selectedUser = nil
                    selectedUserPubkey = nil
                    searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(OlasDesign.Colors.textTertiary)
                }
            }
        }
        .padding(OlasDesign.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: OlasDesign.CornerRadius.md)
                .fill(OlasDesign.Colors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: OlasDesign.CornerRadius.md)
                .stroke(OlasDesign.Colors.primary.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var amountSection: some View {
        VStack(alignment: .leading, spacing: OlasDesign.Spacing.md) {
            Text("Amount")
                .font(OlasDesign.Typography.bodyMedium)
                .foregroundStyle(OlasDesign.Colors.text)
            
            // Quick amount buttons
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: OlasDesign.Spacing.sm) {
                ForEach(quickAmounts, id: \.self) { amount in
                    Button {
                        selectedAmount = amount
                        customAmount = ""
                        OlasDesign.Haptic.selection()
                    } label: {
                        Text("\(amount)")
                            .font(OlasDesign.Typography.bodyMedium)
                            .foregroundStyle(selectedAmount == amount ? .white : OlasDesign.Colors.text)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, OlasDesign.Spacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: OlasDesign.CornerRadius.sm)
                                    .fill(selectedAmount == amount ? OlasDesign.Colors.primary : OlasDesign.Colors.surface)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: OlasDesign.CornerRadius.sm)
                                    .stroke(selectedAmount == amount ? Color.clear : OlasDesign.Colors.divider, lineWidth: 1)
                            )
                    }
                }
            }
            
            // Custom amount
            HStack {
                TextField("Custom amount", text: $customAmount)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.plain)
                    .onChange(of: customAmount) { _, newValue in
                        if !newValue.isEmpty {
                            selectedAmount = Int64(newValue) ?? 0
                        }
                    }
                
                Text("sats")
                    .font(OlasDesign.Typography.body)
                    .foregroundStyle(OlasDesign.Colors.textSecondary)
            }
            .padding(OlasDesign.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: OlasDesign.CornerRadius.md)
                    .fill(OlasDesign.Colors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: OlasDesign.CornerRadius.md)
                    .stroke(customAmount.isEmpty ? OlasDesign.Colors.divider : OlasDesign.Colors.primary, lineWidth: 1)
            )
        }
    }
    
    private var commentField: some View {
        VStack(alignment: .leading, spacing: OlasDesign.Spacing.sm) {
            Text("Comment (optional)")
                .font(OlasDesign.Typography.bodyMedium)
                .foregroundStyle(OlasDesign.Colors.text)
            
            TextField("Add a message...", text: $comment, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(3...5)
                .padding(OlasDesign.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: OlasDesign.CornerRadius.md)
                        .fill(OlasDesign.Colors.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: OlasDesign.CornerRadius.md)
                        .stroke(OlasDesign.Colors.divider, lineWidth: 1)
                )
        }
    }
    
    private var sendButton: some View {
        Button {
            Task {
                await sendNutZap()
            }
        } label: {
            HStack(spacing: OlasDesign.Spacing.sm) {
                if isSending {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "bolt.heart.fill")
                }
                
                Text(isSending ? "Sending..." : "Send NutZap")
            }
            .font(OlasDesign.Typography.bodyMedium)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, OlasDesign.Spacing.md)
            .background(
                LinearGradient(
                    colors: OlasDesign.Colors.primaryGradient,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(OlasDesign.CornerRadius.full)
            .shadow(color: OlasDesign.Colors.primary.opacity(0.3), radius: 10, x: 0, y: 5)
        }
        .disabled(isSending || selectedAmount == 0 || (recipientPubkey == nil && selectedUserPubkey == nil))
        .opacity((selectedAmount == 0 || (recipientPubkey == nil && selectedUserPubkey == nil)) ? 0.5 : 1)
    }
    
    private func loadUserProfile(pubkey: String) async {
        guard let ndk = nostrManager.ndk,
              let profileManager = ndk.profileManager else { return }
        
        var foundProfile: NDKUserProfile?
        for await profile in await profileManager.observe(for: pubkey, maxAge: 3600) {
            foundProfile = profile
            break // Just get the first one
        }
        
        if let profile = foundProfile {
            await MainActor.run {
                self.selectedUser = profile
                self.selectedUserPubkey = pubkey
            }
        }
    }
    
    private func searchUser() async {
        guard !searchQuery.isEmpty else { return }
        
        await MainActor.run {
            isSearching = true
        }
        
        defer {
            Task { @MainActor in
                isSearching = false
            }
        }
        
        // Try to decode npub
        if searchQuery.starts(with: "npub1") {
            // For now, show error for npub search
            await MainActor.run {
                errorMessage = "npub search coming soon. Please use hex pubkey for now."
            }
            return
        }
        
        // Search by name - for now just show error
        await MainActor.run {
            errorMessage = "Search by name coming soon. Please use npub for now."
        }
    }
    
    private func sendNutZap() async {
        let targetPubkey = recipientPubkey ?? selectedUserPubkey
        guard let pubkey = targetPubkey else { return }
        
        await MainActor.run {
            isSending = true
        }
        
        defer {
            Task { @MainActor in
                isSending = false
            }
        }
        
        // Find a recent event from the user to zap
        guard let ndk = nostrManager.ndk else { return }
            
            let filter = NDKFilter(
                authors: [pubkey],
                kinds: [EventKind.textNote],
                limit: 1
            )
            
            // Use observe to get an event
            let dataSource = ndk.observe(
                filter: filter,
                maxAge: 0,
                cachePolicy: .cacheOnly
            )
            
            var foundEvent: NDKEvent?
            for await event in dataSource.events {
                foundEvent = event
                break // Just get the first one
            }
            
        if let event = foundEvent {
            do {
                // Get accepted mints (using default mints for now)
                let mintURLs = await walletManager.getActiveMintURLs()
                let acceptedMints = mintURLs.compactMap { URL(string: $0) }
                
                // Send nutzap to the event's author
                try await walletManager.sendNutzap(
                    to: event.pubkey,
                    amount: selectedAmount,
                    comment: comment.isEmpty ? nil : comment,
                    acceptedMints: acceptedMints
                )
                
                await MainActor.run {
                    showSuccess = true
                    OlasDesign.Haptic.success()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    OlasDesign.Haptic.error()
                }
            }
        } else {
            await MainActor.run {
                errorMessage = "Couldn't find a recent post from this user to zap"
            }
        }
    }
}