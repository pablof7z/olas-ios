import SwiftUI
import NDKSwiftUI

// Wrapper to maintain API compatibility with existing code
struct QRScannerView: View {
    let completion: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NDKUIQRScanner(
            onScan: { code in
                completion(code)
            },
            onDismiss: {
                dismiss()
            }
        )
        .ignoresSafeArea()
    }
}