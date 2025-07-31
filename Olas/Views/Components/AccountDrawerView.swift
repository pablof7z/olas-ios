import SwiftUI
import NDKSwift
import NDKSwiftUI

struct AccountDrawerView: View {
    @Environment(NostrManager.self) private var nostrManager
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var showAddAccount = false
    @State private var showAccountManager = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                OlasDesign.Colors.background
                    .ignoresSafeArea()
                
                // Content
                VStack(spacing: 0) {
                    // Header
                    headerSection
                    
                    // Current Account
                    if let activeSession = nostrManager.authManager?.activeSession {
                        currentAccountSection(session: activeSession)
                    }
                    
                    // Available Accounts
                    availableAccountsSection
                    
                    // Quick Actions
                    quickActionsSection
                    
                    Spacer()
                }
                .padding(.top, OlasDesign.Spacing.lg)
            }
        }
        .presentationDetents([.height(500), .large])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showAddAccount) {
            AddAccountSheet()
                .environment(nostrManager)
                .environmentObject(appState)
        }
        .sheet(isPresented: $showAccountManager) {
            AccountManagerView()
                .environment(nostrManager)
                .environmentObject(appState)
        }
    }
    
    // MARK: - Header Section
    
    @ViewBuilder
    private var headerSection: some View {
        HStack {
            Text("My Accounts")
                .font(OlasDesign.Typography.title2)
                .foregroundColor(OlasDesign.Colors.text)
            
            Spacer()
            
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(OlasDesign.Colors.textSecondary)
            }
        }
        .padding(.horizontal, OlasDesign.Spacing.lg)
        .padding(.bottom, OlasDesign.Spacing.lg)
    }
    
    // MARK: - Current Account Section
    
    @ViewBuilder
    private func currentAccountSection(session: NDKSession) -> some View {
        VStack(spacing: OlasDesign.Spacing.md) {
            // Current account header
            HStack {
                Text("Active Account")
                    .font(OlasDesign.Typography.caption)
                    .foregroundColor(OlasDesign.Colors.textSecondary)
                    .textCase(.uppercase)
                
                Spacer()
                
                // Active indicator
                HStack(spacing: 4) {
                    Circle()
                        .fill(OlasDesign.Colors.success)
                        .frame(width: 8, height: 8)
                    Text("Online")
                        .font(OlasDesign.Typography.caption)
                        .foregroundColor(OlasDesign.Colors.success)
                }
            }
            .padding(.horizontal, OlasDesign.Spacing.lg)
            
            // Current account card
            CurrentAccountCard(session: session)
                .padding(.horizontal, OlasDesign.Spacing.lg)
        }
    }
    
    // MARK: - Available Accounts Section
    
    @ViewBuilder
    private var availableAccountsSection: some View {
        let availableSessions = nostrManager.authManager?.availableSessions ?? []
        let inactiveSessions = availableSessions.filter { !$0.isActive }
        
        if !inactiveSessions.isEmpty {
            VStack(spacing: OlasDesign.Spacing.md) {
                // Section header
                HStack {
                    Text("Switch Account")
                        .font(OlasDesign.Typography.caption)
                        .foregroundColor(OlasDesign.Colors.textSecondary)
                        .textCase(.uppercase)
                    
                    Spacer()
                    
                    Text("\(inactiveSessions.count)")
                        .font(OlasDesign.Typography.caption)
                        .foregroundColor(OlasDesign.Colors.textTertiary)
                }
                .padding(.horizontal, OlasDesign.Spacing.lg)
                .padding(.top, OlasDesign.Spacing.xl)
                
                // Account list
                LazyVStack(spacing: OlasDesign.Spacing.sm) {
                    ForEach(inactiveSessions, id: \.id) { session in
                        AccountRowView(session: session) {
                            Task {
                                await switchToAccount(session)
                            }
                        }
                        .padding(.horizontal, OlasDesign.Spacing.lg)
                    }
                }
            }
        }
    }
    
    // MARK: - Quick Actions Section
    
    @ViewBuilder
    private var quickActionsSection: some View {
        VStack(spacing: OlasDesign.Spacing.md) {
            // Section header
            HStack {
                Text("Account Options")
                    .font(OlasDesign.Typography.caption)
                    .foregroundColor(OlasDesign.Colors.textSecondary)
                    .textCase(.uppercase)
                
                Spacer()
            }
            .padding(.horizontal, OlasDesign.Spacing.lg)
            .padding(.top, OlasDesign.Spacing.xl)
            
            VStack(spacing: OlasDesign.Spacing.sm) {
                // Add account
                QuickActionButton(
                    icon: "plus.circle.fill",
                    title: "Add Account",
                    subtitle: "Sign in or create new",
                    color: OlasDesign.Colors.primary
                ) {
                    showAddAccount = true
                }
                
                // Manage accounts
                QuickActionButton(
                    icon: "person.2.circle.fill",
                    title: "Manage Accounts",
                    subtitle: "Settings and security",
                    color: OlasDesign.Colors.textSecondary
                ) {
                    showAccountManager = true
                }
            }
            .padding(.horizontal, OlasDesign.Spacing.lg)
        }
    }
    
    // MARK: - Actions
    
    private func switchToAccount(_ session: NDKSession) async {
        do {
            try await nostrManager.authManager?.switchToSession(session)
            
            // Haptic feedback
            OlasDesign.Haptic.success()
            
            // Dismiss the drawer
            await MainActor.run {
                dismiss()
            }
        } catch {
            print("Failed to switch account: \(error)")
            // TODO: Show error alert
        }
    }
}

// MARK: - Current Account Card

struct CurrentAccountCard: View {
    let session: NDKSession
    @Environment(NostrManager.self) private var nostrManager
    @State private var metadata: NDKUserMetadata?
    
    var body: some View {
        VStack(spacing: OlasDesign.Spacing.md) {
            HStack(spacing: OlasDesign.Spacing.md) {
                // Avatar
                NDKUIProfilePicture(
                    ndk: nostrManager.ndk,
                    pubkey: session.pubkey,
                    size: 60
                )
                .overlay(
                    Circle()
                        .stroke(OlasDesign.Colors.primary, lineWidth: 3)
                )
                
                // User info
                VStack(alignment: .leading, spacing: 4) {
                    Text(metadata?.displayName ?? metadata?.name ?? String(session.pubkey.prefix(8)) + "...")
                        .font(OlasDesign.Typography.title3)
                        .foregroundColor(OlasDesign.Colors.text)
                        .lineLimit(1)
                    
                    Text("@\(metadata?.name ?? String(session.pubkey.prefix(8)))")
                        .font(OlasDesign.Typography.body)
                        .foregroundColor(OlasDesign.Colors.textSecondary)
                        .lineLimit(1)
                    
                    HStack(spacing: 4) {
                        Image(systemName: accountTypeIcon)
                            .font(.caption2)
                            .foregroundColor(OlasDesign.Colors.primary)
                        
                        Text(accountTypeText)
                            .font(OlasDesign.Typography.caption)
                            .foregroundColor(OlasDesign.Colors.textTertiary)
                    }
                }
                
                Spacer()
                
                // Account badge
                VStack(spacing: 2) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(OlasDesign.Colors.success)
                    
                    Text("Active")
                        .font(OlasDesign.Typography.caption)
                        .foregroundColor(OlasDesign.Colors.success)
                }
            }
        }
        .padding(OlasDesign.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: OlasDesign.CornerRadius.lg)
                .fill(OlasDesign.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: OlasDesign.CornerRadius.lg)
                        .stroke(OlasDesign.Colors.primary.opacity(0.3), lineWidth: 1)
                )
        )
        .task {
            await loadProfile()
        }
    }
    
    private var accountTypeIcon: String {
        if session.signerType == nil {
            return "eye.fill"
        } else if session.requiresBiometric {
            return "faceid"
        } else {
            return "key.fill"
        }
    }
    
    private var accountTypeText: String {
        if session.signerType == nil {
            return "Read-only"
        } else if session.requiresBiometric {
            return "Secured with Face ID"
        } else {
            return "Full access"
        }
    }
    
    private func loadProfile() async {
        guard nostrManager.isInitialized,
              let profileManager = nostrManager.ndk.profileManager else { return }
        
        for await loadedMetadata in await profileManager.subscribe(for: session.pubkey, maxAge: 3600) {
            if let loadedMetadata = loadedMetadata {
                await MainActor.run {
                    self.metadata = loadedMetadata
                }
                break
            }
        }
    }
}

// MARK: - Account Row View

struct AccountRowView: View {
    let session: NDKSession
    let onTap: () -> Void
    @Environment(NostrManager.self) private var nostrManager
    @State private var metadata: NDKUserMetadata?
    
    var body: some View {
        Button(action: {
            OlasDesign.Haptic.selection()
            onTap()
        }) {
            HStack(spacing: OlasDesign.Spacing.md) {
                // Avatar
                NDKUIProfilePicture(
                    ndk: nostrManager.ndk,
                    pubkey: session.pubkey,
                    size: 44
                )
                
                // User info
                VStack(alignment: .leading, spacing: 2) {
                    Text(metadata?.displayName ?? metadata?.name ?? String(session.pubkey.prefix(8)) + "...")
                        .font(OlasDesign.Typography.bodyMedium)
                        .foregroundColor(OlasDesign.Colors.text)
                        .lineLimit(1)
                    
                    HStack(spacing: 4) {
                        Text("@\(metadata?.name ?? String(session.pubkey.prefix(8)))")
                            .font(OlasDesign.Typography.caption)
                            .foregroundColor(OlasDesign.Colors.textSecondary)
                        
                        Text("•")
                            .font(OlasDesign.Typography.caption)
                            .foregroundColor(OlasDesign.Colors.textTertiary)
                        
                        Text(session.signerType?.capitalized ?? "Read-only")
                            .font(OlasDesign.Typography.caption)
                            .foregroundColor(OlasDesign.Colors.textTertiary)
                    }
                    .lineLimit(1)
                }
                
                Spacer()
                
                // Switch indicator
                Image(systemName: "arrow.right.circle")
                    .font(.title3)
                    .foregroundColor(OlasDesign.Colors.primary)
            }
            .padding(OlasDesign.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: OlasDesign.CornerRadius.md)
                    .fill(OlasDesign.Colors.surface)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .task {
            await loadProfile()
        }
    }
    
    private func loadProfile() async {
        guard nostrManager.isInitialized,
              let profileManager = nostrManager.ndk.profileManager else { return }
        
        for await loadedMetadata in await profileManager.subscribe(for: session.pubkey, maxAge: 3600) {
            if let loadedMetadata = loadedMetadata {
                await MainActor.run {
                    self.metadata = loadedMetadata
                }
                break
            }
        }
    }
}

// MARK: - Quick Action Button

struct QuickActionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            OlasDesign.Haptic.selection()
            action()
        }) {
            HStack(spacing: OlasDesign.Spacing.md) {
                // Icon
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 30)
                
                // Text
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(OlasDesign.Typography.bodyMedium)
                        .foregroundColor(OlasDesign.Colors.text)
                    
                    Text(subtitle)
                        .font(OlasDesign.Typography.caption)
                        .foregroundColor(OlasDesign.Colors.textSecondary)
                }
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(OlasDesign.Colors.textTertiary)
            }
            .padding(OlasDesign.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: OlasDesign.CornerRadius.md)
                    .fill(OlasDesign.Colors.surface)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Add Account Sheet

struct AddAccountSheet: View {
    @Environment(NostrManager.self) private var nostrManager
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var showCreateAccount = false
    @State private var showImportAccount = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                OlasDesign.Colors.background
                    .ignoresSafeArea()
                
                VStack(spacing: OlasDesign.Spacing.xl) {
                    // Header
                    VStack(spacing: OlasDesign.Spacing.md) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 60))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: OlasDesign.Colors.primaryGradient,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Text("Add Account")
                            .font(OlasDesign.Typography.title)
                            .foregroundColor(OlasDesign.Colors.text)
                        
                        Text("Create a new account or import an existing one")
                            .font(OlasDesign.Typography.body)
                            .foregroundColor(OlasDesign.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, OlasDesign.Spacing.xl)
                    
                    Spacer()
                    
                    // Options
                    VStack(spacing: OlasDesign.Spacing.lg) {
                        // Create new account
                        Button(action: { showCreateAccount = true }) {
                            HStack {
                                Image(systemName: "sparkles")
                                    .font(.title2)
                                Text("Create New Account")
                                    .font(OlasDesign.Typography.bodyBold)
                                Spacer()
                            }
                            .foregroundColor(.white)
                            .padding(OlasDesign.Spacing.lg)
                            .background(
                                LinearGradient(
                                    colors: OlasDesign.Colors.primaryGradient,
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(OlasDesign.CornerRadius.lg)
                        }
                        
                        // Import existing account
                        Button(action: { showImportAccount = true }) {
                            HStack {
                                Image(systemName: "key.horizontal")
                                    .font(.title2)
                                Text("Import Existing Account")
                                    .font(OlasDesign.Typography.bodyBold)
                                Spacer()
                            }
                            .foregroundColor(OlasDesign.Colors.text)
                            .padding(OlasDesign.Spacing.lg)
                            .background(OlasDesign.Colors.surface)
                            .cornerRadius(OlasDesign.CornerRadius.lg)
                            .overlay(
                                RoundedRectangle(cornerRadius: OlasDesign.CornerRadius.lg)
                                    .stroke(OlasDesign.Colors.border, lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal, OlasDesign.Spacing.lg)
                    
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showCreateAccount) {
            CreateAccountView()
                .environment(nostrManager)
                .environmentObject(appState)
        }
        .sheet(isPresented: $showImportAccount) {
            AuthenticationView()
                .environment(nostrManager)
                .environmentObject(appState)
        }
    }
}

// MARK: - Account Manager View

struct AccountManagerView: View {
    @Environment(NostrManager.self) private var nostrManager
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            AccountSettingsView()
                .environment(nostrManager)
                .environmentObject(appState)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }
}