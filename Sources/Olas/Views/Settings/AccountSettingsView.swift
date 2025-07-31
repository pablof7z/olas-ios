import SwiftUI
import NDKSwift
import CryptoKit

struct AccountSettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showKeyBackup = false
    @State private var showCopyAlert = false
    @State private var copiedText = ""
    @State private var showBiometricToggle = false
    @State private var biometricEnabled = false
    @State private var showNsecWarning = false
    @State private var showProfileEditAlert = false
    
    var body: some View {
        ZStack {
            OlasDesign.Colors.background
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: OlasDesign.Spacing.xl) {
                    // Profile section
                    profileSection
                    
                    // Key management section
                    keyManagementSection
                    
                    // Security section
                    securitySection
                    
                    // Data management section
                    dataManagementSection
                }
                .padding(OlasDesign.Spacing.lg)
            }
        }
        .navigationTitle("Account Settings")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .sheet(isPresented: $showKeyBackup) {
            keyBackupSheet
        }
        .alert("Copied!", isPresented: $showCopyAlert) {
            Button("OK") { }
        } message: {
            Text("\(copiedText) copied to clipboard")
        }
        .alert("Private Key Warning", isPresented: $showNsecWarning) {
            Button("I Understand", role: .destructive) {
                showKeyBackup = true
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Your private key (nsec) controls your account. Anyone with this key has full access. Keep it secure and never share it.")
        }
        .alert("Coming Soon", isPresented: $showProfileEditAlert) {
            Button("OK") { }
        } message: {
            Text("Profile editing will be available in a future update.")
        }
    }
    
    // MARK: - Sections
    
    @ViewBuilder
    private var profileSection: some View {
        VStack(spacing: OlasDesign.Spacing.lg) {
            // Avatar
            if let currentUserProfile = appState.currentUserProfile {
                AsyncImage(url: URL(string: currentUserProfile.picture ?? "")) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [OlasDesign.Colors.primary, OlasDesign.Colors.secondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .frame(width: 100, height: 100)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(OlasDesign.Colors.border, lineWidth: 2)
                )
                
                VStack(spacing: OlasDesign.Spacing.sm) {
                    Text(currentUserProfile.displayName ?? currentUserProfile.name ?? "Unknown")
                        .font(OlasDesign.Typography.title2)
                        .foregroundColor(OlasDesign.Colors.text)
                    
                    if let nip05 = currentUserProfile.nip05 {
                        Text(nip05)
                            .font(OlasDesign.Typography.caption)
                            .foregroundColor(OlasDesign.Colors.textSecondary)
                    }
                }
            }
            
            OlasButton(
                title: "Edit Profile",
                action: {
                    showProfileEditAlert = true
                    OlasDesign.Haptic.selection()
                },
                style: .secondary
            )
        }
        .frame(maxWidth: .infinity)
        .padding(OlasDesign.Spacing.lg)
        .background(OlasDesign.Colors.surface)
        .cornerRadius(16)
    }
    
    @ViewBuilder
    private var keyManagementSection: some View {
        VStack(alignment: .leading, spacing: OlasDesign.Spacing.md) {
            Text("Key Management")
                .font(OlasDesign.Typography.title3)
                .foregroundColor(OlasDesign.Colors.text)
            
            VStack(spacing: OlasDesign.Spacing.sm) {
                // Public key
                keyRow(
                    title: "Public Key",
                    subtitle: "Your public identity",
                    icon: "key",
                    action: copyPublicKey
                )
                
                Divider()
                    .background(OlasDesign.Colors.border)
                
                // Private key backup
                keyRow(
                    title: "Backup Private Key",
                    subtitle: "Secure your account",
                    icon: "lock.shield",
                    action: {
                        showNsecWarning = true
                    },
                    isDestructive: true
                )
            }
            .padding(OlasDesign.Spacing.md)
            .background(OlasDesign.Colors.surface)
            .cornerRadius(12)
        }
    }
    
    @ViewBuilder
    private var securitySection: some View {
        VStack(alignment: .leading, spacing: OlasDesign.Spacing.md) {
            Text("Security")
                .font(OlasDesign.Typography.title3)
                .foregroundColor(OlasDesign.Colors.text)
            
            VStack(spacing: 0) {
                // Biometric lock
                HStack {
                    Image(systemName: "faceid")
                        .font(.body)
                        .foregroundColor(OlasDesign.Colors.primary)
                        .frame(width: 30)
                    
                    VStack(alignment: .leading, spacing: OlasDesign.Spacing.xs) {
                        Text("Biometric Lock")
                            .font(OlasDesign.Typography.body)
                            .foregroundColor(OlasDesign.Colors.text)
                        
                        Text("Require Face ID to access")
                            .font(OlasDesign.Typography.caption)
                            .foregroundColor(OlasDesign.Colors.textSecondary)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $biometricEnabled)
                        .tint(OlasDesign.Colors.primary)
                }
                .padding(OlasDesign.Spacing.md)
                
                Divider()
                    .background(OlasDesign.Colors.border)
                    .padding(.leading, 46)
                
                // Session management
                sessionRow(
                    title: "Active Sessions",
                    subtitle: "Manage logged in devices",
                    icon: "laptopcomputer.and.iphone",
                    badge: "3"
                )
            }
            .background(OlasDesign.Colors.surface)
            .cornerRadius(12)
        }
    }
    
    @ViewBuilder
    private var dataManagementSection: some View {
        VStack(alignment: .leading, spacing: OlasDesign.Spacing.md) {
            Text("Data Management")
                .font(OlasDesign.Typography.title3)
                .foregroundColor(OlasDesign.Colors.text)
            
            VStack(spacing: OlasDesign.Spacing.sm) {
                dataRow(
                    title: "Export Data",
                    subtitle: "Download all your content",
                    icon: "square.and.arrow.up"
                )
                
                Divider()
                    .background(OlasDesign.Colors.border)
                
                dataRow(
                    title: "Clear Cache",
                    subtitle: "Free up storage space",
                    icon: "trash",
                    isDestructive: true
                )
            }
            .padding(OlasDesign.Spacing.md)
            .background(OlasDesign.Colors.surface)
            .cornerRadius(12)
        }
    }
    
    // MARK: - Components
    
    @ViewBuilder
    private func keyRow(title: String, subtitle: String, icon: String, action: @escaping () -> Void, isDestructive: Bool = false) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundColor(isDestructive ? OlasDesign.Colors.warning : OlasDesign.Colors.primary)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: OlasDesign.Spacing.xs) {
                    Text(title)
                        .font(OlasDesign.Typography.body)
                        .foregroundColor(OlasDesign.Colors.text)
                    
                    Text(subtitle)
                        .font(OlasDesign.Typography.caption)
                        .foregroundColor(OlasDesign.Colors.textSecondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(OlasDesign.Colors.textTertiary)
            }
            .padding(.vertical, OlasDesign.Spacing.sm)
        }
    }
    
    @ViewBuilder
    private func sessionRow(title: String, subtitle: String, icon: String, badge: String? = nil) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(OlasDesign.Colors.primary)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: OlasDesign.Spacing.xs) {
                Text(title)
                    .font(OlasDesign.Typography.body)
                    .foregroundColor(OlasDesign.Colors.text)
                
                Text(subtitle)
                    .font(OlasDesign.Typography.caption)
                    .foregroundColor(OlasDesign.Colors.textSecondary)
            }
            
            Spacer()
            
            if let badge = badge {
                Text(badge)
                    .font(OlasDesign.Typography.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(OlasDesign.Colors.primary)
                    .cornerRadius(10)
            }
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(OlasDesign.Colors.textTertiary)
        }
        .padding(OlasDesign.Spacing.md)
    }
    
    @ViewBuilder
    private func dataRow(title: String, subtitle: String, icon: String, isDestructive: Bool = false) -> some View {
        Button(action: {
            // TODO: Implement actions
            OlasDesign.Haptic.selection()
        }) {
            HStack {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundColor(isDestructive ? OlasDesign.Colors.warning : OlasDesign.Colors.primary)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: OlasDesign.Spacing.xs) {
                    Text(title)
                        .font(OlasDesign.Typography.body)
                        .foregroundColor(OlasDesign.Colors.text)
                    
                    Text(subtitle)
                        .font(OlasDesign.Typography.caption)
                        .foregroundColor(OlasDesign.Colors.textSecondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(OlasDesign.Colors.textTertiary)
            }
            .padding(.vertical, OlasDesign.Spacing.sm)
        }
    }
    
    // MARK: - Key Backup Sheet
    
    @ViewBuilder
    private var keyBackupSheet: some View {
        NavigationStack {
            ZStack {
                OlasDesign.Colors.background
                    .ignoresSafeArea()
                
                VStack(spacing: OlasDesign.Spacing.xl) {
                    // Warning
                    VStack(spacing: OlasDesign.Spacing.md) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(OlasDesign.Colors.warning)
                        
                        Text("Private Key Backup")
                            .font(OlasDesign.Typography.title2)
                            .foregroundColor(OlasDesign.Colors.text)
                        
                        Text("Keep this key secure. Anyone with access can control your account.")
                            .font(OlasDesign.Typography.body)
                            .foregroundColor(OlasDesign.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, OlasDesign.Spacing.xl)
                    
                    // Key display
                    if let signer = NDKAuthManager.shared.activeSigner as? NDKPrivateKeySigner {
                        VStack(spacing: OlasDesign.Spacing.lg) {
                            // Hex format
                            keyDisplayBox(
                                title: "Hex Format",
                                value: signer.privateKey,
                                action: {
                                    copyToClipboard(signer.privateKey, label: "Private key (hex)")
                                }
                            )
                            
                            // nsec format
                            if let nsec = try? signer.privateKey.nsec() {
                                keyDisplayBox(
                                    title: "nsec Format",
                                    value: nsec,
                                    action: {
                                        copyToClipboard(nsec, label: "Private key (nsec)")
                                    }
                                )
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Done button
                    OlasButton(
                        title: "Done",
                        action: {
                            showKeyBackup = false
                        },
                        style: .primary
                    )
                    .padding(.bottom, OlasDesign.Spacing.lg)
                }
                .padding(.horizontal, OlasDesign.Spacing.lg)
            }
        }
    }
    
    @ViewBuilder
    private func keyDisplayBox(title: String, value: String, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: OlasDesign.Spacing.sm) {
            Text(title)
                .font(OlasDesign.Typography.caption)
                .foregroundColor(OlasDesign.Colors.textSecondary)
            
            HStack {
                Text(value)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(OlasDesign.Colors.text)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Spacer()
                
                Button(action: action) {
                    Image(systemName: "doc.on.doc")
                        .font(.body)
                        .foregroundColor(OlasDesign.Colors.primary)
                }
            }
            .padding(OlasDesign.Spacing.md)
            .background(OlasDesign.Colors.surface)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(OlasDesign.Colors.border, lineWidth: 1)
            )
        }
    }
    
    // MARK: - Methods
    
    private func copyPublicKey() {
        guard let signer = NDKAuthManager.shared.activeSigner as? NDKPrivateKeySigner else { return }
        
        let pubkey = signer.publicKey
        copyToClipboard(pubkey, label: "Public key")
    }
    
    private func copyToClipboard(_ text: String, label: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
        
        copiedText = label
        showCopyAlert = true
        OlasDesign.Haptic.success()
    }
}

// MARK: - Preview

struct AccountSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            AccountSettingsView()
                .environmentObject(AppState())
        }
    }
}