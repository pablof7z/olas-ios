import SwiftUI
import NDKSwift

struct MintInfo: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    let name: String
    
    static func == (lhs: MintInfo, rhs: MintInfo) -> Bool {
        lhs.url == rhs.url
    }
}

struct MintManagementView: View {
    @Environment(NostrManager.self) private var nostrManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMint: String?
    @State private var showingAddMint = false
    @State private var showingMintDetails = false
    @State private var mintStats: [String: MintStats] = [:]
    @State private var animateCards = false
    
    @State private var editableMints: [MintInfo] = []
    @State private var originalMintURLs: [String] = []
    @State private var transactionCount: Int = 0
    @State private var isSaving = false
    @State private var hasUnsavedChanges = false
    
    @State private var currentBalance: Int64 = 0
    
    struct MintStats {
        let balance: Int64
        let tokenCount: Int
        let status: MintStatus
        let lastActive: Date
        let fee: Double
        
        enum MintStatus {
            case active
            case syncing
            case offline
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Animated background
                AnimatedMeshGradient()
                    .opacity(0.3)
                    .ignoresSafeArea()
                
                OlasDesign.Colors.background
                    .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: OlasDesign.Spacing.xl) {
                        // Header with stats
                        headerView
                            .padding(.top, OlasDesign.Spacing.md)
                        
                        // Mint Cards
                        if editableMints.isEmpty {
                            emptyStateView
                        } else {
                            mintCardsSection
                        }
                        
                        // Add Mint Button
                        addMintButton
                            .padding(.bottom, OlasDesign.Spacing.xxl)
                    }
                    .padding(.horizontal, OlasDesign.Spacing.md)
                }
            }
            .navigationTitle("Mint Management")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        if hasUnsavedChanges {
                            // Could show confirmation dialog
                        }
                        dismiss()
                    }
                    .foregroundStyle(OlasDesign.Colors.text)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task { await saveChanges() }
                    }
                    .fontWeight(.bold)
                    .foregroundStyle(hasUnsavedChanges ? OlasDesign.Colors.primary : OlasDesign.Colors.textSecondary)
                    .disabled(!hasUnsavedChanges || isSaving)
                }
            }
            .sheet(isPresented: $showingAddMint) {
                AddMintView { url in
                    await addMintToLocal(url: url)
                }
            }
            .sheet(isPresented: $showingMintDetails) {
                if let mint = selectedMint {
                    MintDetailView(mintURL: mint, nostrManager: nostrManager)
                }
            }
            .onAppear {
                Task {
                    await loadData()
                    loadMintStats()
                }
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    animateCards = true
                }
            }
            .onChange(of: nostrManager.cashuWallet != nil) { _, _ in
                Task {
                    await loadData()
                    loadMintStats()
                }
            }
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        VStack(spacing: OlasDesign.Spacing.lg) {
            // Total Balance Across All Mints
            VStack(spacing: OlasDesign.Spacing.sm) {
                Text("Total Balance Across Mints")
                    .font(OlasDesign.Typography.caption)
                    .foregroundStyle(OlasDesign.Colors.textSecondary)
                
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(formatSats(currentBalance))
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [OlasDesign.Colors.text, OlasDesign.Colors.text.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: currentBalance)
                    
                    Text("sats")
                        .font(OlasDesign.Typography.body)
                        .foregroundStyle(OlasDesign.Colors.textSecondary)
                }
            }
            
            // Stats Row
            HStack(spacing: OlasDesign.Spacing.xl) {
                MintStatCard(
                    icon: "building.2.fill",
                    value: "\(editableMints.count)",
                    label: "Active Mints"
                )
                
                MintStatCard(
                    icon: "bitcoinsign.circle.fill",
                    value: "\(formatSats(currentBalance))",
                    label: "Total Balance"
                )
                
                MintStatCard(
                    icon: "bolt.fill",
                    value: "\(calculateTransactionCount())",
                    label: "Transactions"
                )
            }
        }
        .padding(OlasDesign.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: OlasDesign.CornerRadius.xl)
                .fill(
                    LinearGradient(
                        colors: [
                            OlasDesign.Colors.surface.opacity(0.8),
                            OlasDesign.Colors.surface.opacity(0.6)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: OlasDesign.CornerRadius.xl)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.2), Color.white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
    }
    
    // MARK: - Mint Cards Section
    
    private var mintCardsSection: some View {
        VStack(spacing: OlasDesign.Spacing.md) {
            ForEach(Array(editableMints.enumerated()), id: \.element.id) { index, mint in
                MintCard(
                    mintInfo: mint,
                    stats: mintStats[mint.url.absoluteString],
                    onTap: {
                        selectedMint = mint.url.absoluteString
                        showingMintDetails = true
                        OlasDesign.Haptic.selection()
                    },
                    onRemove: {
                        removeMint(mint)
                    }
                )
                .scaleEffect(animateCards ? 1 : 0.8)
                .opacity(animateCards ? 1 : 0)
                .animation(
                    .spring(response: 0.5, dampingFraction: 0.8)
                    .delay(Double(index) * 0.1),
                    value: animateCards
                )
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: OlasDesign.Spacing.xl) {
            // Animated illustration
            ZStack {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(hex: "667EEA").opacity(0.3 - Double(index) * 0.1),
                                    Color(hex: "764BA2").opacity(0.3 - Double(index) * 0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: CGFloat(100 + index * 30), height: CGFloat(100 + index * 30))
                        .rotationEffect(.degrees(Double(index) * 60))
                        .scaleEffect(animateCards ? 1.1 : 0.9)
                        .animation(
                            .easeInOut(duration: 3)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.3),
                            value: animateCards
                        )
                }
                
                Image(systemName: "building.2.crop.circle")
                    .font(.system(size: 60))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "667EEA"), Color(hex: "764BA2")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .frame(height: 200)
            
            VStack(spacing: OlasDesign.Spacing.sm) {
                Text("No Mints Added")
                    .font(OlasDesign.Typography.title)
                    .foregroundStyle(OlasDesign.Colors.text)
                
                Text("Add a Cashu mint to start using ecash")
                    .font(OlasDesign.Typography.body)
                    .foregroundStyle(OlasDesign.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, OlasDesign.Spacing.xxl)
    }
    
    // MARK: - Add Mint Button
    
    private var addMintButton: some View {
        Button {
            showingAddMint = true
            OlasDesign.Haptic.selection()
        } label: {
            HStack(spacing: OlasDesign.Spacing.md) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                
                Text("Add New Mint")
                    .font(OlasDesign.Typography.bodyBold)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(OlasDesign.Colors.textTertiary)
            }
            .foregroundStyle(.white)
            .padding(OlasDesign.Spacing.lg)
            .background(
                LinearGradient(
                    colors: OlasDesign.Colors.primaryGradient,
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: OlasDesign.CornerRadius.lg))
            .shadow(color: OlasDesign.Colors.primary.opacity(0.3), radius: 10, x: 0, y: 5)
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadData() async {
        guard let wallet = nostrManager.cashuWallet else {
            await MainActor.run {
                self.originalMintURLs = []
                self.editableMints = []
                self.transactionCount = 0
                self.currentBalance = 0
                self.hasUnsavedChanges = false
            }
            return
        }
        
        // Load current mint configuration from wallet
        let mintURLs = await wallet.mints.getMintURLs()
        let transactions = await wallet.getRecentTransactions(limit: 1000) // Get more for counting
        let balance = (try? await wallet.getBalance()) ?? 0
        
        await MainActor.run {
            self.originalMintURLs = mintURLs
            self.editableMints = mintURLs.compactMap { urlString in
                guard let url = URL(string: urlString) else { return nil }
                return MintInfo(url: url, name: url.host ?? "Unknown Mint")
            }
            self.transactionCount = transactions.count
            self.currentBalance = balance
            self.hasUnsavedChanges = false
        }
    }
    
    private func loadMintStats() {
        Task {
            guard let wallet = nostrManager.cashuWallet else { return }
            
            // Load mint balances
            let mintURLs = await wallet.mints.getMintURLs()
            var balances: [String: Int64] = [:]
            for mintString in mintURLs {
                if let mintURL = URL(string: mintString) {
                    let balance = await wallet.getBalance(mint: mintURL)
                    balances[mintString] = balance
                }
            }
            
            await MainActor.run {
                // Mock data - in production, fetch real stats  
                for mint in editableMints {
                    let urlString = mint.url.absoluteString
                    mintStats[urlString] = MintStats(
                        balance: balances[urlString] ?? 0,
                        tokenCount: 0,
                        status: .active,
                        lastActive: Date(),
                        fee: 0.5
                    )
                }
            }
        }
    }
    
    private func addMintToLocal(url: URL) async {
        let mintInfo = MintInfo(url: url, name: url.host ?? "Unknown Mint")
        
        // Check if already exists
        guard !editableMints.contains(where: { $0.url == url }) else {
            return
        }
        
        editableMints.append(mintInfo)
        hasUnsavedChanges = true
        loadMintStats()
    }
    
    private func removeMint(_ mint: MintInfo) {
        editableMints.removeAll { $0.id == mint.id }
        hasUnsavedChanges = true
        loadMintStats()
    }
    
    private func saveChanges() async {
        isSaving = true
        
        do {
            let mintURLs = editableMints.map { $0.url.absoluteString }
            try await nostrManager.saveMintConfiguration(mintURLs: mintURLs)
            
            await MainActor.run {
                self.originalMintURLs = mintURLs
                self.hasUnsavedChanges = false
                self.isSaving = false
            }
            
            dismiss()
        } catch {
            await MainActor.run {
                self.isSaving = false
                // Could show error alert
            }
        }
    }
    
    private func calculateTransactionCount() -> Int {
        transactionCount
    }
    
    private func formatSats(_ sats: Int64) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: sats)) ?? "0"
    }
}

// MARK: - Supporting Views

struct MintStatCard: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(OlasDesign.Colors.primary)
            
            Text(value)
                .font(OlasDesign.Typography.bodyBold)
                .foregroundStyle(OlasDesign.Colors.text)
            
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(OlasDesign.Colors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

struct MintCard: View {
    let mintInfo: MintInfo
    let stats: MintManagementView.MintStats?
    let onTap: () -> Void
    let onRemove: () -> Void
    
    @State private var isPressed = false
    @State private var showRemoveConfirmation = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Header
                HStack(spacing: OlasDesign.Spacing.md) {
                    // Mint icon with status indicator
                    ZStack(alignment: .bottomTrailing) {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "667EEA"), Color(hex: "764BA2")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 50, height: 50)
                            .overlay(
                                Text("₿")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.white)
                            )
                        
                        // Status indicator
                        Circle()
                            .fill(statusColor)
                            .frame(width: 14, height: 14)
                            .overlay(
                                Circle()
                                    .stroke(OlasDesign.Colors.background, lineWidth: 2)
                            )
                    }
                    
                    // Mint info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(mintInfo.name)
                            .font(OlasDesign.Typography.bodyBold)
                            .foregroundStyle(OlasDesign.Colors.text)
                        
                        HStack(spacing: 4) {
                            Text(mintInfo.url.absoluteString.replacingOccurrences(of: "https://", with: ""))
                                .font(OlasDesign.Typography.caption)
                                .foregroundStyle(OlasDesign.Colors.textSecondary)
                                .lineLimit(1)
                            
                            if let stats = stats {
                                Text("•")
                                    .foregroundStyle(OlasDesign.Colors.textTertiary)
                                Text("\(stats.fee)% fee")
                                    .font(OlasDesign.Typography.caption)
                                    .foregroundStyle(OlasDesign.Colors.textTertiary)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Balance
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(formatSats(stats?.balance ?? 0))
                            .font(OlasDesign.Typography.bodyBold)
                            .foregroundStyle(OlasDesign.Colors.text)
                        Text("sats")
                            .font(.system(size: 11))
                            .foregroundStyle(OlasDesign.Colors.textSecondary)
                    }
                }
                .padding(OlasDesign.Spacing.lg)
                
                // Stats bar
                if let stats = stats {
                    HStack(spacing: OlasDesign.Spacing.xl) {
                        MintStatItem(
                            icon: "bitcoinsign.circle",
                            value: "\(stats.tokenCount)",
                            label: "Tokens"
                        )
                        
                        MintStatItem(
                            icon: "clock",
                            value: formatLastActive(stats.lastActive),
                            label: "Last Active"
                        )
                        
                        MintStatItem(
                            icon: "arrow.triangle.2.circlepath",
                            value: statusText,
                            label: "Status"
                        )
                    }
                    .padding(.horizontal, OlasDesign.Spacing.lg)
                    .padding(.bottom, OlasDesign.Spacing.md)
                    .background(
                        OlasDesign.Colors.background.opacity(0.5)
                    )
                }
            }
            .background(
                RoundedRectangle(cornerRadius: OlasDesign.CornerRadius.lg)
                    .fill(
                        LinearGradient(
                            colors: [
                                OlasDesign.Colors.surface,
                                OlasDesign.Colors.surface.opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: OlasDesign.CornerRadius.lg)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.15), Color.white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
            .scaleEffect(isPressed ? 0.98 : 1)
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            Button(role: .destructive) {
                showRemoveConfirmation = true
            } label: {
                Label("Remove Mint", systemImage: "trash")
            }
        }
        .confirmationDialog(
            "Remove Mint?",
            isPresented: $showRemoveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                onRemove()
            }
        } message: {
            Text("This mint has \(stats?.balance ?? 0) sats. You cannot remove it until the balance is zero.")
        }
        .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
    
    private var statusColor: Color {
        guard let stats = stats else { return Color.gray }
        switch stats.status {
        case .active:
            return Color.green
        case .syncing:
            return Color.orange
        case .offline:
            return Color.red
        }
    }
    
    private var statusText: String {
        guard let stats = stats else { return "Unknown" }
        switch stats.status {
        case .active:
            return "Active"
        case .syncing:
            return "Syncing"
        case .offline:
            return "Offline"
        }
    }
    
    private func extractMintName(from url: String) -> String {
        if url.contains("minibits") {
            return "Minibits"
        } else if url.contains("cashu.space") {
            return "Cashu Space"
        } else if url.contains("8333") {
            return "8333.space"
        } else if url.contains("lnbits") {
            return "LNbits"
        } else {
            // Extract domain name
            let cleanURL = url.replacingOccurrences(of: "https://", with: "")
                .replacingOccurrences(of: "http://", with: "")
            let components = cleanURL.split(separator: "/")
            if let domain = components.first {
                let domainParts = domain.split(separator: ".")
                if let name = domainParts.first {
                    return String(name).capitalized
                }
            }
            return "Mint"
        }
    }
    
    private func formatSats(_ sats: Int64) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: sats)) ?? "0"
    }
    
    private func formatLastActive(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 {
            return "Now"
        } else if interval < 3600 {
            return "\(Int(interval / 60))m"
        } else if interval < 86400 {
            return "\(Int(interval / 3600))h"
        } else {
            return "\(Int(interval / 86400))d"
        }
    }
}

struct MintStatItem: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(value)
                    .font(OlasDesign.Typography.caption)
            }
            .foregroundStyle(OlasDesign.Colors.text)
            
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(OlasDesign.Colors.textTertiary)
        }
    }
}

// MARK: - Mint Detail View

struct MintDetailView: View {
    let mintURL: String
    let nostrManager: NostrManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                OlasDesign.Colors.background
                    .ignoresSafeArea()
                
                // Content placeholder
                VStack {
                    Text("Mint Details")
                        .font(OlasDesign.Typography.title)
                    Text(mintURL)
                        .font(OlasDesign.Typography.body)
                        .foregroundStyle(OlasDesign.Colors.textSecondary)
                }
            }
            .navigationTitle("Mint Details")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: {
                    #if os(iOS)
                    .navigationBarTrailing
                    #else
                    .automatic
                    #endif
                }()) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Animated Mesh Gradient

struct AnimatedMeshGradient: View {
    @State private var animationTrigger = false
    
    var body: some View {
        TimeBasedGradient()
            .blur(radius: 30)
            .scaleEffect(1.5)
            .rotationEffect(.degrees(animationTrigger ? 360 : 0))
            .animation(
                .linear(duration: 60)
                .repeatForever(autoreverses: false),
                value: animationTrigger
            )
            .onAppear {
                animationTrigger = true
            }
    }
}

// End of MintManagementView.swift
