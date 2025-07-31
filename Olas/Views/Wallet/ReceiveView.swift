import SwiftUI
import CoreImage.CIFilterBuiltins
import NDKSwift
import NDKSwiftUI
import CashuSwift

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct ReceiveView: View {
    @Environment(NostrManager.self) private var nostrManager
    @Environment(\.dismiss) var dismiss
    
    @State private var amount = ""
    @State private var description = ""
    @State private var invoice = ""
    @State private var isGenerating = false
    @State private var showingCopiedAlert = false
    @State private var mintQuote: CashuMintQuote?
    @State private var showInvoice = false
    @State private var depositTask: Task<Void, Never>?
    @State private var showPaymentAnimation = false
    @State private var mintedAmount: Int64 = 0
    @State private var manualCheckContinuation: AsyncStream<Void>.Continuation?
    @State private var selectedMintURL: String = ""
    @State private var availableMints: [String] = []
    
    var body: some View {
        NavigationView {
            ZStack {
                OlasDesign.Colors.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: OlasDesign.Spacing.xl) {
                        // Header
                        VStack(spacing: OlasDesign.Spacing.md) {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "4ECDC4"), Color(hex: "44A08D")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Image(systemName: "qrcode")
                                        .font(.system(size: 40))
                                        .foregroundColor(.white)
                                )
                            
                            Text("Receive Sats")
                                .font(OlasDesign.Typography.title)
                                .foregroundStyle(OlasDesign.Colors.text)
                        }
                        .padding(.top, OlasDesign.Spacing.lg)
                        
                        // Input fields
                        VStack(spacing: OlasDesign.Spacing.md) {
                            // Amount input
                            VStack(alignment: .leading, spacing: OlasDesign.Spacing.sm) {
                                Text("Amount (optional)")
                                    .font(OlasDesign.Typography.caption)
                                    .foregroundStyle(OlasDesign.Colors.textSecondary)
                                
                                HStack {
                                    Image(systemName: "bitcoinsign.circle")
                                        .font(.title2)
                                        .foregroundStyle(OlasDesign.Colors.textSecondary)
                                    
                                    TextField("0", text: $amount)
                                        .font(OlasDesign.Typography.body)
                                        .foregroundStyle(OlasDesign.Colors.text)
                                        #if os(iOS)
                                        .keyboardType(.numberPad)
                                        #endif
                                    
                                    Text("sats")
                                        .font(OlasDesign.Typography.body)
                                        .foregroundStyle(OlasDesign.Colors.textSecondary)
                                }
                                .padding(OlasDesign.Spacing.md)
                                .background(
                                    RoundedRectangle(cornerRadius: OlasDesign.CornerRadius.md)
                                        .fill(OlasDesign.Colors.surface)
                                )
                            }
                            
                            // Description input
                            VStack(alignment: .leading, spacing: OlasDesign.Spacing.sm) {
                                Text("Description (optional)")
                                    .font(OlasDesign.Typography.caption)
                                    .foregroundStyle(OlasDesign.Colors.textSecondary)
                                
                                HStack {
                                    Image(systemName: "text.alignleft")
                                        .font(.title2)
                                        .foregroundStyle(OlasDesign.Colors.textSecondary)
                                    
                                    TextField("What's this for?", text: $description)
                                        .font(OlasDesign.Typography.body)
                                        .foregroundStyle(OlasDesign.Colors.text)
                                }
                                .padding(OlasDesign.Spacing.md)
                                .background(
                                    RoundedRectangle(cornerRadius: OlasDesign.CornerRadius.md)
                                        .fill(OlasDesign.Colors.surface)
                                )
                            }
                        }
                        .padding(.horizontal, OlasDesign.Spacing.md)
                        
                        // Generate button
                        OlasButton(
                            title: "Generate Invoice",
                            action: {
                                Task {
                                    await generateInvoice()
                                }
                            },
                            style: .primary,
                            isLoading: isGenerating
                        )
                        .padding(.horizontal, OlasDesign.Spacing.md)
                        
                        // Invoice display
                        if !invoice.isEmpty {
                            VStack(spacing: OlasDesign.Spacing.md) {
                                // QR Code
                                if let qrImage = NDKUIQRCodeGenerator.generate(from: invoice) {
                                    #if canImport(UIKit)
                                    Image(uiImage: qrImage)
                                        .interpolation(.none)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 250, height: 250)
                                        .padding()
                                        .background(Color.white)
                                        .cornerRadius(OlasDesign.CornerRadius.lg)
                                    #elseif canImport(AppKit)
                                    Image(nsImage: qrImage)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 250, height: 250)
                                        .padding()
                                        .background(Color.white)
                                        .cornerRadius(OlasDesign.CornerRadius.lg)
                                    #endif
                                }
                                
                                // Invoice text
                                VStack(spacing: OlasDesign.Spacing.sm) {
                                    Text("Lightning Invoice")
                                        .font(OlasDesign.Typography.caption)
                                        .foregroundStyle(OlasDesign.Colors.textSecondary)
                                    
                                    Text(invoice)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(OlasDesign.Colors.textSecondary)
                                        .lineLimit(3)
                                        .truncationMode(.middle)
                                        .padding()
                                        .background(OlasDesign.Colors.surface)
                                        .cornerRadius(OlasDesign.CornerRadius.md)
                                }
                                .padding(.horizontal, OlasDesign.Spacing.md)
                                
                                // Copy button
                                OlasButton(
                                    title: showingCopiedAlert ? "Copied!" : "Copy Invoice",
                                    action: {
                                        copyInvoice()
                                    },
                                    style: .secondary
                                )
                                .padding(.horizontal, OlasDesign.Spacing.md)
                                
                                // Check Payment Status button
                                OlasButton(
                                    title: "Check Payment Status",
                                    action: {
                                        manualCheckContinuation?.yield()
                                    },
                                    style: .secondary
                                )
                                .padding(.horizontal, OlasDesign.Spacing.md)
                                
                                // Waiting indicator
                                VStack(spacing: OlasDesign.Spacing.sm) {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Waiting for payment...")
                                        .font(OlasDesign.Typography.caption)
                                        .foregroundStyle(OlasDesign.Colors.textSecondary)
                                }
                                .padding(.top, OlasDesign.Spacing.md)
                            }
                        }
                        
                        Spacer(minLength: 100)
                    }
                }
            }
            .navigationTitle("Receive")
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
                    .foregroundStyle(OlasDesign.Colors.text)
                }
            }
        }
        .task {
            await loadMints()
        }
        .onDisappear {
            depositTask?.cancel()
        }
        .fullScreenCover(isPresented: $showPaymentAnimation) {
            PaymentReceivedAnimationView(amount: mintedAmount) {
                dismiss()
            }
        }
    }
    
    private func loadMints() async {
        guard let wallet = nostrManager.cashuWallet else {
            availableMints = []
            return
        }
        availableMints = await wallet.mints.getMintURLs()
        if selectedMintURL.isEmpty && !availableMints.isEmpty {
            selectedMintURL = availableMints.first ?? ""
        }
    }
    
    private func generateInvoice() async {
        guard let amountInt = Int64(amount), amountInt > 0 else { return }
        
        isGenerating = true
        defer { isGenerating = false }
        
        do {
            // Use the first available mint if none selected
            let mintURL = selectedMintURL.isEmpty ? (availableMints.first ?? "") : selectedMintURL
            
            guard !mintURL.isEmpty else {
                print("No mints available")
                return
            }
            
            // Request mint quote from the wallet
            guard let wallet = nostrManager.cashuWallet else {
                print("No wallet available")
                return
            }
            let quote = try await wallet.requestMint(
                amount: amountInt,
                mintURL: mintURL
            )
            
            mintQuote = quote
            invoice = quote.invoice
            
            OlasDesign.Haptic.success()
            
            // Start monitoring for deposit
            startDepositMonitoring(quote: quote)
            
        } catch {
            print("Error generating invoice: \(error)")
            OlasDesign.Haptic.error()
        }
    }
    
    private func startDepositMonitoring(quote: CashuMintQuote) {
        depositTask?.cancel()
        
        // Create manual check trigger stream
        let (triggerStream, continuation) = AsyncStream<Void>.makeStream()
        manualCheckContinuation = continuation
        
        depositTask = Task {
            do {
                guard let wallet = nostrManager.cashuWallet else { return }
                let depositSequence = await wallet.monitorDeposit(
                    quote: quote,
                    manualCheckTrigger: triggerStream
                )
                for try await status in depositSequence {
                    switch status {
                    case .pending:
                        // Still waiting for payment
                        print("Deposit pending for quote: \(quote.quoteId)")
                        
                    case .minted(let proofs):
                        // Success! Tokens have been minted
                        print("Successfully minted \(proofs.count) proofs")
                        
                        // Calculate total amount from proofs
                        let totalAmount = proofs.reduce(0) { $0 + $1.amount }
                        
                        await MainActor.run {
                            mintedAmount = Int64(totalAmount)
                            invoice = ""
                            showPaymentAnimation = true
                            OlasDesign.Haptic.success()
                        }
                        return
                        
                    case .expired:
                        await MainActor.run {
                            print("Lightning invoice expired")
                            invoice = ""
                            OlasDesign.Haptic.error()
                        }
                        return
                        
                    case .cancelled:
                        return
                    }
                }
            } catch {
                await MainActor.run {
                    print("Failed to monitor deposit: \(error.localizedDescription)")
                    OlasDesign.Haptic.error()
                }
            }
        }
    }
    
    private func copyInvoice() {
        #if os(iOS)
        UIPasteboard.general.string = invoice
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(invoice, forType: .string)
        #endif
        
        showingCopiedAlert = true
        OlasDesign.Haptic.success()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showingCopiedAlert = false
        }
    }
    
}

// MARK: - Payment Received Animation
struct PaymentReceivedAnimationView: View {
    let amount: Int64
    let onComplete: () -> Void
    
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0.0
    @State private var checkmarkScale: CGFloat = 0.0
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
            
            VStack(spacing: OlasDesign.Spacing.xl) {
                // Success checkmark
                ZStack {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 120, height: 120)
                        .scaleEffect(scale)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 60, weight: .bold))
                        .foregroundColor(.white)
                        .scaleEffect(checkmarkScale)
                }
                
                VStack(spacing: OlasDesign.Spacing.md) {
                    Text("Payment Received!")
                        .font(OlasDesign.Typography.title)
                        .foregroundColor(.white)
                        .opacity(opacity)
                    
                    Text("\(amount) sats")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                        .opacity(opacity)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                scale = 1.0
                opacity = 1.0
            }
            
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.2)) {
                checkmarkScale = 1.0
            }
            
            // Auto dismiss after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    opacity = 0.0
                    scale = 0.8
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onComplete()
                }
            }
        }
    }
}

// End of ReceiveView.swift
