import SwiftUI
import NDKSwift

struct CreateAccountView: View {
    @Environment(NostrManager.self) private var nostrManager
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var displayName = ""
    @State private var mnemonic: [String] = []
    @State private var privateKey = ""
    @State private var showConfirmation = false
    @State private var isCreatingAccount = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Text("Create New Account")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                if mnemonic.isEmpty {
                    VStack(spacing: 20) {
                        TextField("Display Name", text: $displayName)
                            .textFieldStyle(.roundedBorder)
                            #if os(iOS)
                            .autocapitalization(.words)
                            #endif
                        
                        Button("Generate Keys") {
                            generateKeys()
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "667eea"), Color(hex: "764ba2")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                        .disabled(displayName.isEmpty)
                    }
                    .padding(.horizontal)
                } else {
                    VStack(spacing: 24) {
                        Text("Your Recovery Phrase")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 12) {
                            ForEach(Array(mnemonic.enumerated()), id: \.offset) { index, word in
                                HStack {
                                    Text("\(index + 1).")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(word)
                                        .font(.system(.body, design: .monospaced))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                        
                        Text("⚠️ Write down these words in order. This is the only way to recover your account.")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .multilineTextAlignment(.center)
                        
                        Button("I've Saved My Recovery Phrase") {
                            showConfirmation = true
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Confirm Backup", isPresented: $showConfirmation) {
                Button("Yes, I've saved it") {
                    completeAccountCreation()
                }
                Button("No, let me save it", role: .cancel) {}
            } message: {
                Text("Have you securely saved your recovery phrase? You won't be able to see it again.")
            }
        }
    }
    
    private func generateKeys() {
        do {
            // Generate a new private key signer
            let signer = try NDKPrivateKeySigner.generate()
            privateKey = signer.privateKeyValue
            
            // In a real app, you would generate a proper BIP39 mnemonic
            // This is just a placeholder for demo purposes
            mnemonic = ["example", "words", "would", "be", "generated", "here", 
                       "using", "proper", "bip39", "implementation", "for", "security"]
        } catch {
            print("Key generation failed: \(error)")
        }
    }
    
    private func completeAccountCreation() {
        Task {
            do {
                isCreatingAccount = true
                _ = try await nostrManager.olasCreateNewAccount(displayName: displayName)
                dismiss()
            } catch {
                print("Account creation failed: \(error)")
                isCreatingAccount = false
                // TODO: Show error alert
            }
        }
    }
}