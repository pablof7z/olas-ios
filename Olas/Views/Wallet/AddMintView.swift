import SwiftUI

struct AddMintView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var walletManager: OlasWalletManager
    @State private var mintURL = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @FocusState private var isTextFieldFocused: Bool
    
    private let suggestedMints = [
        ("Mint 1", "https://mint1.example.com"),
        ("Mint 2", "https://mint2.example.com")
    ]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Add Cashu Mint")
                    .font(.title)
                    .padding()
                
                TextField("Mint URL", text: $mintURL)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                
                Button("Add Mint") {
                    addMint()
                }
                .disabled(mintURL.isEmpty || isLoading)
                .padding()
                
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                }
                
                Spacer()
            }
            .navigationTitle("Add Mint")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func addMint() {
        Task {
            do {
                try await walletManager.addMint(mintURL)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}