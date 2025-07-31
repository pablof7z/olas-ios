import SwiftUI

struct AddMintView: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: (URL) async -> Void
    @State private var mintURL = ""
    @State private var isValidating = false
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
                    Task { await addMint() }
                }
                .disabled(mintURL.isEmpty || isValidating)
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
    
    private func addMint() async {
        guard let url = URL(string: mintURL), 
              url.scheme != nil,
              url.host != nil else {
            errorMessage = "Please enter a valid URL"
            return
        }
        
        isValidating = true
        errorMessage = nil
        
        await onAdd(url)
        dismiss()
        
        isValidating = false
    }
}