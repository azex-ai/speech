import SwiftUI

/// Azex branded dark theme — warm wasteland aesthetic with amber accents.
enum AzexTheme {
    // MARK: - Background
    static let bg = Color(hex: 0x0D0D0D)
    static let bgCard = Color(hex: 0x1A1A1A)
    static let bgCardHover = Color(hex: 0x222222)
    static let bgSidebar = Color(hex: 0x111111)
    static let bgInput = Color(hex: 0x151515)

    // MARK: - Accent (Amber/Orange)
    static let accent = Color(hex: 0xE8853D)
    static let accentMuted = Color(hex: 0xE8853D).opacity(0.15)
    static let accentText = Color(hex: 0xF0A060)

    // MARK: - Text
    static let textPrimary = Color(hex: 0xF5F5F5)
    static let textSecondary = Color(hex: 0x9A9590)
    static let textTertiary = Color(hex: 0x5C5550)

    // MARK: - Border
    static let border = Color(hex: 0x2A2520)
    static let borderSubtle = Color(hex: 0x1F1C18)

    // MARK: - Status
    static let success = Color(hex: 0x4ADE80)
    static let error = Color(hex: 0xF87171)
    static let recording = Color(hex: 0xEF4444)

    // MARK: - Card Style
    static let cardCorner: CGFloat = 12
    static let cardPadding: CGFloat = 16
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

// MARK: - Reusable Card Modifier

struct AzexCardStyle: ViewModifier {
    var padding: CGFloat = AzexTheme.cardPadding

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(AzexTheme.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: AzexTheme.cardCorner))
            .overlay(
                RoundedRectangle(cornerRadius: AzexTheme.cardCorner)
                    .strokeBorder(AzexTheme.border, lineWidth: 1)
            )
    }
}

extension View {
    func azexCard(padding: CGFloat = AzexTheme.cardPadding) -> some View {
        modifier(AzexCardStyle(padding: padding))
    }
}
