import SwiftUI
import NDKSwift
import NDKSwiftUI

struct WalletContactsScrollView: View {
    @Environment(NostrManager.self) private var nostrManager
    @State private var contacts: [(pubkey: String, metadata: NDKUserMetadata?)] = []
    @State private var isLoading = true
    @Binding var showNutZap: Bool
    @Binding var nutZapRecipient: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: OlasDesign.Spacing.sm) {
            // Header
            HStack {
                HStack(spacing: OlasDesign.Spacing.sm) {
                    Image(systemName: "person.2.circle.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: OlasDesign.Colors.primaryGradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text("Quick Send")
                        .font(OlasDesign.Typography.bodyMedium)
                        .foregroundStyle(OlasDesign.Colors.text)
                }
                
                Spacer()
                
                Button {
                    // Navigate to full contacts
                    OlasDesign.Haptic.selection()
                } label: {
                    HStack(spacing: 4) {
                        Text("View All")
                            .font(OlasDesign.Typography.caption)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(OlasDesign.Colors.primary)
                }
            }
            .padding(.horizontal, OlasDesign.Spacing.md)
            
            // Contacts scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: OlasDesign.Spacing.md) {
                    // Add contact button
                    Button {
                        OlasDesign.Haptic.selection()
                        // Show add contact sheet
                    } label: {
                        VStack(spacing: OlasDesign.Spacing.sm) {
                            ZStack {
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .frame(width: 60, height: 60)
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                LinearGradient(
                                                    colors: OlasDesign.Colors.primaryGradient,
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                style: StrokeStyle(lineWidth: 2, dash: [5, 5])
                                            )
                                    )
                                
                                Image(systemName: "plus")
                                    .font(.system(size: 24, weight: .medium))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: OlasDesign.Colors.primaryGradient,
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                            
                            Text("Add")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(OlasDesign.Colors.textSecondary)
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(ContactButtonStyle())
                    
                    // Contact items
                    if isLoading {
                        ForEach(0..<5) { _ in
                            ContactSkeletonView()
                        }
                    } else {
                        ForEach(contacts, id: \.pubkey) { contact in
                            ContactItemView(
                                pubkey: contact.pubkey,
                                metadata: contact.metadata
                            ) {
                                nutZapRecipient = contact.pubkey
                                showNutZap = true
                                OlasDesign.Haptic.selection()
                            }
                        }
                    }
                }
                .padding(.horizontal, OlasDesign.Spacing.md)
            }
        }
        .task {
            await loadContacts()
        }
    }
    
    private func loadContacts() async {
        guard nostrManager.isInitialized,
              let userPubkey = try? await nostrManager.ndk.signer?.pubkey else { return }
        
        let ndk = nostrManager.ndk
        
        // Load contact list (kind 3)
        let filter = NDKFilter(
            authors: [userPubkey],
            kinds: [EventKind.contacts]
        )
        
        let dataSource = ndk.subscribe(
            filter: filter,
            maxAge: 3600,
            cachePolicy: .cacheWithNetwork
        )
            
        for await event in dataSource.events {
            // Extract pubkeys from tags
            let pTags = event.tags.filter { $0.count >= 2 && $0[0] == "p" }
            let pubkeyList = pTags.map { $0[1] }
            let pubkeys = Array(pubkeyList.prefix(10)) // Limit to 10 for horizontal scroll
            
            // Load profiles
            var loadedContacts: [(pubkey: String, metadata: NDKUserMetadata?)] = []
            
            for pubkey in pubkeys {
                if let profileManager = ndk.profileManager {
                    var metadata: NDKUserMetadata?
                    for await m in await profileManager.subscribe(for: pubkey, maxAge: 3600) {
                        metadata = m
                        break
                    }
                    loadedContacts.append((pubkey: pubkey, metadata: metadata))
                }
            }
            
            await MainActor.run {
                self.contacts = loadedContacts
                self.isLoading = false
            }
            
            break // Only need first contact list event
        }
    }
}

struct ContactItemView: View {
    let pubkey: String
    let metadata: NDKUserMetadata?
    let action: () -> Void
    
    @State private var isPressed = false
    @Environment(NostrManager.self) private var nostrManager
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: OlasDesign.Spacing.sm) {
                NDKUIProfilePicture(
                    ndk: nostrManager.ndk,
                    pubkey: pubkey,
                    size: 60
                )
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: isPressed ? OlasDesign.Colors.primaryGradient : [Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .animation(.spring(), value: isPressed)
                )
                
                Text(displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(OlasDesign.Colors.text)
                    .lineLimit(1)
                    .frame(width: 60)
            }
        }
        .buttonStyle(ContactButtonStyle())
    }
    
    private var displayName: String {
        if let name = metadata?.displayName ?? metadata?.name {
            return name
        }
        return String(pubkey.prefix(8))
    }
}

struct ContactSkeletonView: View {
    @State private var shimmerAnimation = false
    
    var body: some View {
        VStack(spacing: OlasDesign.Spacing.sm) {
            Circle()
                .fill(OlasDesign.Colors.surface)
                .overlay(shimmerGradient)
                .frame(width: 60, height: 60)
            
            RoundedRectangle(cornerRadius: 4)
                .fill(OlasDesign.Colors.surface)
                .overlay(shimmerGradient)
                .frame(width: 50, height: 12)
        }
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                shimmerAnimation = true
            }
        }
    }
    
    private var shimmerGradient: some View {
        LinearGradient(
            colors: [
                Color.white.opacity(0),
                Color.white.opacity(0.1),
                Color.white.opacity(0)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .rotationEffect(.degrees(30))
        .offset(x: shimmerAnimation ? 300 : -300)
    }
}

struct ContactButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}