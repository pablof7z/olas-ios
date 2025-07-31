import SwiftUI
import NDKSwift
import NDKSwiftUI

// MARK: - Particle System

class ParticleSystem: ObservableObject {
    @Published var particles: [Particle] = []
    
    func emit(count: Int, from origin: CGPoint) {
        for _ in 0..<count {
            let particle = Particle(
                position: origin,
                velocity: CGPoint(
                    x: CGFloat.random(in: -150...150),
                    y: CGFloat.random(in: -300...(-100))
                ),
                color: Color(hex: ["FFA726", "FFD54F", "4ECDC4", "667EEA"].randomElement()!),
                size: CGFloat.random(in: 4...8)
            )
            particles.append(particle)
        }
        
        // Remove particles after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.particles.removeAll()
        }
    }
}

struct Particle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var velocity: CGPoint
    let color: Color
    let size: CGFloat
    var opacity: Double = 1
}

struct ParticleEffectView: View {
    @ObservedObject var particleSystem: ParticleSystem
    @State private var animationTrigger = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particleSystem.particles) { particle in
                    Circle()
                        .fill(particle.color)
                        .frame(width: particle.size, height: particle.size)
                        .position(particle.position)
                        .opacity(particle.opacity)
                        .modifier(ParticleModifier(particle: particle))
                }
            }
        }
        .onChange(of: particleSystem.particles.count) { _, _ in
            animationTrigger.toggle()
        }
    }
}

struct ParticleModifier: ViewModifier {
    let particle: Particle
    @State private var offset = CGSize.zero
    @State private var opacity: Double = 1
    
    func body(content: Content) -> some View {
        content
            .offset(offset)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: 2)) {
                    offset = CGSize(
                        width: particle.velocity.x,
                        height: particle.velocity.y
                    )
                    opacity = 0
                }
            }
    }
}

// MARK: - Ripple Button

struct RippleButton: View {
    let icon: String
    let title: String
    let gradient: [Color]
    let action: () -> Void
    
    @State private var rippleScale: CGFloat = 0
    @State private var rippleOpacity: Double = 0
    
    var body: some View {
        Button(action: {
            // Trigger ripple
            withAnimation(.easeOut(duration: 0.6)) {
                rippleScale = 3
                rippleOpacity = 0
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                rippleScale = 0
                rippleOpacity = 0.4
            }
            
            OlasDesign.Haptic.selection()
            action()
        }) {
            ZStack {
                // Ripple effect
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.white.opacity(rippleOpacity), Color.clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 50
                        )
                    )
                    .scaleEffect(rippleScale)
                
                HStack {
                    Image(systemName: icon)
                    Text(title)
                }
                .font(OlasDesign.Typography.bodyMedium)
                .foregroundStyle(.white)
                .padding(.horizontal, OlasDesign.Spacing.lg)
                .padding(.vertical, OlasDesign.Spacing.md)
            }
            .background(
                LinearGradient(
                    colors: gradient,
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: OlasDesign.CornerRadius.md))
            .shadow(color: gradient[0].opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct TransactionDetailView: View {
    let transaction: WalletTransaction
    let nostrManager: NostrManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingShareSheet = false
    @State private var copiedToClipboard = false
    @State private var animateContent = false
    @State private var showingQRCode = false
    @State private var particleSystem = ParticleSystem()
    
    var body: some View {
        NavigationStack {
            mainContent
                .navigationTitle("Transaction Details")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
                .sheet(isPresented: $showingShareSheet) {
                    if let invoice = transaction.lightningData?.invoice {
                        ShareSheet(items: [invoice])
                    }
                }
                .sheet(isPresented: $showingQRCode) {
                    TransactionQRCodeView(content: transaction.lightningData?.invoice ?? transaction.id)
                }
        }
    }
    
    private var mainContent: some View {
        ZStack {
            // Background
            OlasDesign.Colors.background
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: OlasDesign.Spacing.xl) {
                    // Transaction Icon with particle effects
                    iconSection
                    
                    // Amount with counter animation
                    amountSection
                        .offset(y: animateContent ? 0 : 50)
                        .opacity(animateContent ? 1 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: animateContent)
                    
                    // Status with pulse animation
                    statusSection
                        .offset(y: animateContent ? 0 : 50)
                        .opacity(animateContent ? 1 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: animateContent)
                    
                    // Details with glass morphism
                    detailsSection
                        .offset(y: animateContent ? 0 : 50)
                        .opacity(animateContent ? 1 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4), value: animateContent)
                    
                    // Actions with ripple effects
                    if transaction.lightningData?.invoice != nil || transaction.status == .pending {
                        actionsSection
                            .offset(y: animateContent ? 0 : 50)
                            .opacity(animateContent ? 1 : 0)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.5), value: animateContent)
                    }
                    
                    Spacer(minLength: 50)
                }
                .padding(.horizontal, OlasDesign.Spacing.md)
            }
            .onAppear {
                withAnimation {
                    animateContent = true
                }
                
                // Trigger particle effect based on transaction type
                if transaction.status == .completed {
                    #if os(iOS)
                    particleSystem.emit(count: 20, from: CGPoint(x: UIScreen.main.bounds.width / 2, y: 200))
                    #else
                    particleSystem.emit(count: 20, from: CGPoint(x: 400, y: 200))
                    #endif
                }
            }
        }
    }
    
    private var iconSection: some View {
        ZStack {
            ParticleEffectView(particleSystem: particleSystem)
                .allowsHitTesting(false)
            
            transactionIcon
                .padding(.top, OlasDesign.Spacing.xl)
                .scaleEffect(animateContent ? 1 : 0.8)
                .opacity(animateContent ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: animateContent)
        }
    }
    
    private var transactionIcon: some View {
        ZStack {
            animatedBackgroundCircles
            centralIcon
        }
        .frame(height: 200)
    }
    
    private var animatedBackgroundCircles: some View {
        ForEach(0..<4) { index in
            backgroundCircle(for: index)
        }
    }
    
    private func backgroundCircle(for index: Int) -> some View {
        Circle()
            .stroke(
                LinearGradient(
                    colors: [OlasDesign.Colors.primary.opacity(0.3 - Double(index) * 0.08), OlasDesign.Colors.primary.opacity(0.2 - Double(index) * 0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 2
            )
            .frame(width: CGFloat(100 + index * 25), height: CGFloat(100 + index * 25))
            .scaleEffect(transaction.status == .pending ? 1.1 : 1.0)
            .rotationEffect(.degrees(Double(index) * 45))
            .animation(
                transaction.status == .pending ?
                Animation.linear(duration: Double(3 + index)).repeatForever(autoreverses: false) :
                    .default,
                value: transaction.status
            )
    }
    
    private var centralIcon: some View {
        ZStack {
            Circle()
                .fill(iconBackground)
                .frame(width: 80, height: 80)
            
            Image(systemName: iconName)
                .font(.system(size: 35, weight: .semibold))
                .foregroundColor(.white)
                .scaleEffect(transaction.status == .pending ? 1.0 : 1.2)
                .animation(
                    transaction.status == .pending ?
                    Animation.easeInOut(duration: 1).repeatForever(autoreverses: true) :
                        .default,
                    value: transaction.status
                )
        }
        .shadow(color: OlasDesign.Colors.primary.opacity(0.5), radius: 20, x: 0, y: 10)
    }
    
    private var amountSection: some View {
        VStack(spacing: OlasDesign.Spacing.xs) {
            AnimatedCounterView(
                value: transaction.amount,
                fontSize: 42,
                fontWeight: .bold,
                color: amountColor,
                prefix: transaction.type == .send || transaction.type == .nutzapSent || transaction.type == .melt ? "-" : "+",
                suffix: " sats"
            )
            
            if let fiatValue = calculateFiatValue(sats: transaction.amount) {
                Text(fiatValue)
                    .font(OlasDesign.Typography.body)
                    .foregroundStyle(OlasDesign.Colors.textSecondary)
            }
        }
        .padding(.top, OlasDesign.Spacing.md)
    }
    
    private var statusSection: some View {
        HStack(spacing: OlasDesign.Spacing.md) {
            // Status indicator with pulse
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                if transaction.status == .pending {
                    Circle()
                        .stroke(statusColor, lineWidth: 2)
                        .frame(width: 40, height: 40)
                        .scaleEffect(1.2)
                        .opacity(0)
                        .animation(
                            Animation.easeOut(duration: 1.5)
                                .repeatForever(autoreverses: false),
                            value: transaction.status
                        )
                }
                
                Image(systemName: statusIcon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(statusColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(statusText)
                    .font(OlasDesign.Typography.bodyMedium)
                    .foregroundStyle(OlasDesign.Colors.text)
                
                Text(transaction.timestamp.formatted())
                    .font(OlasDesign.Typography.caption)
                    .foregroundStyle(OlasDesign.Colors.textSecondary)
            }
            
            Spacer()
        }
        .padding(OlasDesign.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: OlasDesign.CornerRadius.md)
                .fill(OlasDesign.Colors.surface)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        )
    }
    
    private var detailsSection: some View {
        VStack(spacing: 0) {
            DetailRow(
                icon: "rectangle.portrait.and.arrow.right",
                label: "Type",
                value: typeText
            )
            
            if let mintURL = transaction.mint {
                Divider()
                    .foregroundStyle(OlasDesign.Colors.divider)
                
                DetailRow(
                    icon: "building.columns",
                    label: "Mint",
                    value: mintURL.replacingOccurrences(of: "https://", with: "")
                )
            }
            
            if let memo = transaction.memo, !memo.isEmpty {
                Divider()
                    .foregroundStyle(OlasDesign.Colors.divider)
                
                DetailRow(
                    icon: "text.quote",
                    label: "Note",
                    value: memo
                )
            }
            
            if let invoice = transaction.lightningData?.invoice {
                Divider()
                    .foregroundStyle(OlasDesign.Colors.divider)
                
                DetailRow(
                    icon: "doc.text",
                    label: "Invoice",
                    value: String(invoice.prefix(20)) + "...",
                    showCopyButton: true,
                    onCopy: {
                        copyToClipboard(invoice)
                    }
                )
            }
        }
        .background(
            RoundedRectangle(cornerRadius: OlasDesign.CornerRadius.md)
                .fill(OlasDesign.Colors.surface)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        )
    }
    
    private var actionsSection: some View {
        VStack(spacing: OlasDesign.Spacing.md) {
            if transaction.lightningData?.invoice != nil {
                // View QR Code
                RippleButton(
                    icon: "qrcode",
                    title: "View QR Code",
                    gradient: [Color(hex: "667EEA"), Color(hex: "764BA2")],
                    action: {
                        showingQRCode = true
                    }
                )
                
                // Share invoice
                RippleButton(
                    icon: "square.and.arrow.up",
                    title: "Share Invoice",
                    gradient: [Color(hex: "4FACFE"), Color(hex: "00F2FE")],
                    action: {
                        showingShareSheet = true
                    }
                )
            }
            
            if transaction.status == .pending {
                // Cancel transaction (if applicable)
                Button {
                    // TODO: Implement cancel
                    OlasDesign.Haptic.impact(.medium)
                } label: {
                    HStack {
                        Image(systemName: "xmark.circle")
                        Text("Cancel Transaction")
                    }
                    .font(OlasDesign.Typography.bodyMedium)
                    .foregroundStyle(OlasDesign.Colors.error)
                    .frame(maxWidth: .infinity)
                    .padding(OlasDesign.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: OlasDesign.CornerRadius.md)
                            .stroke(OlasDesign.Colors.error, lineWidth: 1)
                    )
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var iconName: String {
        switch transaction.type {
        case .send:
            return "paperplane.fill"
        case .receive:
            return "arrow.down.circle.fill"
        case .nutzapSent, .nutzapReceived:
            return "bolt.fill"
        case .mint:
            return "plus.circle.fill"
        case .melt:
            return "flame.fill"
        case .swap:
            return "arrow.triangle.2.circlepath"
        }
    }
    
    private var iconBackground: LinearGradient {
        switch transaction.type {
        case .send:
            return LinearGradient(
                colors: [Color(hex: "FF6B6B"), Color(hex: "FF8E53")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .receive:
            return LinearGradient(
                colors: [Color(hex: "48BB78"), Color(hex: "68D391")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .nutzapSent, .nutzapReceived:
            return LinearGradient(
                colors: [Color(hex: "805AD5"), Color(hex: "9F7AEA")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .mint:
            return LinearGradient(
                colors: [Color(hex: "3182CE"), Color(hex: "4299E1")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .melt:
            return LinearGradient(
                colors: [Color(hex: "ED8936"), Color(hex: "F6AD55")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .swap:
            return LinearGradient(
                colors: [Color(hex: "319795"), Color(hex: "38B2AC")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private var amountColor: Color {
        switch transaction.type {
        case .receive, .mint:
            return OlasDesign.Colors.success
        case .send, .nutzapSent, .nutzapReceived, .melt:
            return OlasDesign.Colors.text
        case .swap:
            return OlasDesign.Colors.warning
        }
    }
    
    private var statusIcon: String {
        switch transaction.status {
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "xmark.circle.fill"
        case .pending:
            return "clock.fill"
        case .processing:
            return "arrow.2.circlepath"
        case .expired:
            return "exclamationmark.triangle.fill"
        }
    }
    
    private var statusColor: Color {
        switch transaction.status {
        case .completed:
            return OlasDesign.Colors.success
        case .failed:
            return OlasDesign.Colors.error
        case .pending:
            return OlasDesign.Colors.warning
        case .processing:
            return OlasDesign.Colors.warning
        case .expired:
            return OlasDesign.Colors.error
        }
    }
    
    private var statusText: String {
        switch transaction.status {
        case .completed:
            return "Completed"
        case .failed:
            return "Failed"
        case .pending:
            return "Pending"
        case .processing:
            return "Processing"
        case .expired:
            return "Expired"
        }
    }
    
    private var typeText: String {
        switch transaction.type {
        case .send:
            return "Sent"
        case .receive:
            return "Received"
        case .nutzapSent:
            return "Zap Sent"
        case .nutzapReceived:
            return "Zap Received"
        case .mint:
            return "Minted"
        case .melt:
            return "Melted"
        case .swap:
            return "Swapped"
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatSats(_ sats: Int64) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: sats)) ?? "\(sats)"
    }
    
    private func copyToClipboard(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.string = text
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
        
        OlasDesign.Haptic.success()
        copiedToClipboard = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copiedToClipboard = false
        }
    }
    
    private func calculateFiatValue(sats: Int64) -> String? {
        // TODO: Implement real BTC price fetching
        let btcPriceUSD = 45000.0 // Placeholder
        let btcValue = Double(sats) / 100_000_000
        let usdValue = btcValue * btcPriceUSD
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        
        return formatter.string(from: NSNumber(value: usdValue))
    }
}

// MARK: - Supporting Views

struct AnimatedCounterView: View {
    let value: Int64
    let fontSize: CGFloat
    let fontWeight: Font.Weight
    let color: Color
    let prefix: String
    let suffix: String
    
    @State private var displayValue: Int64 = 0
    
    var body: some View {
        HStack(spacing: 2) {
            Text(prefix)
                .font(.system(size: fontSize, weight: fontWeight))
                .foregroundColor(color)
            
            Text(formatSats(displayValue))
                .font(.system(size: fontSize, weight: fontWeight, design: .rounded))
                .foregroundColor(color)
            
            Text(suffix)
                .font(.system(size: fontSize * 0.7, weight: .medium))
                .foregroundColor(color.opacity(0.8))
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                displayValue = value
            }
        }
    }
    
    private func formatSats(_ sats: Int64) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: sats)) ?? "\(sats)"
    }
}

struct DetailRow: View {
    let icon: String
    let label: String
    let value: String
    var showCopyButton: Bool = false
    var onCopy: (() -> Void)? = nil
    
    @State private var showCopied = false
    
    var body: some View {
        HStack(spacing: OlasDesign.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(OlasDesign.Colors.textSecondary)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(OlasDesign.Typography.caption)
                    .foregroundStyle(OlasDesign.Colors.textSecondary)
                
                Text(value)
                    .font(OlasDesign.Typography.body)
                    .foregroundStyle(OlasDesign.Colors.text)
            }
            
            Spacer()
            
            if showCopyButton, let onCopy = onCopy {
                Button {
                    onCopy()
                    withAnimation {
                        showCopied = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation {
                            showCopied = false
                        }
                    }
                } label: {
                    Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 14))
                        .foregroundStyle(showCopied ? OlasDesign.Colors.success : OlasDesign.Colors.primary)
                }
            }
        }
        .padding(.vertical, OlasDesign.Spacing.xs)
    }
}

// MARK: - QR Code View

struct TransactionQRCodeView: View {
    let content: String
    @Environment(\.dismiss) private var dismiss
    @State private var showCopied = false
    
    var body: some View {
        NavigationView {
            ZStack {
                OlasDesign.Colors.background
                    .ignoresSafeArea()
                
                VStack(spacing: OlasDesign.Spacing.xl) {
                    NDKUIQRCodeView(content: content, size: 280)
                        .padding(OlasDesign.Spacing.lg)
                        .background(Color.white)
                        .cornerRadius(OlasDesign.CornerRadius.lg)
                        .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
                        .scaleEffect(showCopied ? 0.95 : 1)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: showCopied)
                    
                    Text("Scan to view details")
                        .font(OlasDesign.Typography.body)
                        .foregroundStyle(OlasDesign.Colors.textSecondary)
                    
                    // Copy button
                    Button {
                        copyContent()
                    } label: {
                        HStack {
                            Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                            Text(showCopied ? "Copied!" : "Copy")
                        }
                        .font(OlasDesign.Typography.bodyMedium)
                        .foregroundStyle(showCopied ? OlasDesign.Colors.success : OlasDesign.Colors.primary)
                        .padding(.horizontal, OlasDesign.Spacing.xl)
                        .padding(.vertical, OlasDesign.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: OlasDesign.CornerRadius.full)
                                .stroke(showCopied ? OlasDesign.Colors.success : OlasDesign.Colors.primary, lineWidth: 2)
                        )
                    }
                    .disabled(showCopied)
                }
                .padding()
            }
            .navigationTitle("QR Code")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    
    private func copyContent() {
        #if os(iOS)
        UIPasteboard.general.string = content
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
        #endif
        
        OlasDesign.Haptic.success()
        
        withAnimation {
            showCopied = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showCopied = false
            }
        }
    }
}