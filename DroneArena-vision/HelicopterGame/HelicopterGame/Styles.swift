//
//  Styles.swift
//  HelicopterGame
//
//  Chrome/Steel Block Design System with Cold Blue Neon Edge
//  Brand DNA: chunky, squared forms with beveled/embossed feel
//  Motif: winged reticle / targeting glyph
//

import SwiftUI

// MARK: - Brand Colors
extension Color {
    // Core Neutrals (Chrome)
    static let chromeHi = Color(hex: "F2F5F8")        // highlight
    static let chromeLo = Color(hex: "C9D2DD")        // mid
    static let steel = Color(hex: "8B96A6")           // deep
    static let gunmetal = Color(hex: "2E3441")        // UI outlines / text on light
    static let night = Color(hex: "07090E")           // app background

    // Blue Neon Edge
    static let neonBlue = Color(hex: "69C4FF")        // outer glow
    static let coreBlue = Color(hex: "2E86FF")        // primary accents
    static let iceCyan = Color(hex: "BDE9FF")         // specular highlight

    // Semantic Colors
    static let textPrimary = Color(hex: "E9EEF4")
    static let textSecondary = Color(hex: "A9B4C2")
    static let accentPrimary = coreBlue
    static let accentGlow = neonBlue

    // Glass Surface
    static let surface = Color.white.opacity(0.06)

    // Status Colors
    static let danger = Color(hex: "FF5E7E")
    static let success = Color(hex: "4AD6B6")
    static let warning = Color(hex: "F4B847")

    // Background Variants
    static let bgElevated = gunmetal.opacity(0.8)

    // MARK: - Drone Compatibility Tokens
    // Former Drone design-system colors, now re-pointed to the Steel/Chrome
    // palette so the whole app shares one visual identity. These exist only so
    // the screens originally built against the Drone theme keep compiling and
    // adopt the Steel look automatically.
    static let purpureus = coreBlue
    static let purpureus2 = neonBlue
    static let silverLakeBlue = neonBlue
    static let verdigris = success

    static let droneAccent = coreBlue
    static let droneSecondary = neonBlue
    static let droneInfo = neonBlue
    static let droneSuccess = success
    static let droneWarning = warning
    static let droneError = danger

    static let droneSurfacePrimary = bgElevated
    static let droneSurfaceSecondary = surface
    static let droneSurfaceGlass = surface

    static let droneTextPrimary = textPrimary
    static let droneTextSecondary = textSecondary
    static let droneTextAccent = coreBlue

    static let droneDisabled = Color.gray.opacity(0.3)

    // MARK: - Hex / blending helpers
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    func blended(with color: Color, ratio: Double) -> Color {
        return Color(
            red: Double(self.components.red * (1 - ratio) + color.components.red * ratio),
            green: Double(self.components.green * (1 - ratio) + color.components.green * ratio),
            blue: Double(self.components.blue * (1 - ratio) + color.components.blue * ratio)
        )
    }

    private var components: (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b, a)
    }
}

// MARK: - Chrome Block Gradient
struct ChromeBlockGradient {
    static let gradient = LinearGradient(
        gradient: Gradient(stops: [
            .init(color: Color(hex: "F2F5F8"), location: 0.0),
            .init(color: Color(hex: "DCE4EC"), location: 0.4),
            .init(color: Color(hex: "98A4B3"), location: 0.55),
            .init(color: Color(hex: "C9D2DD"), location: 0.62),
            .init(color: Color(hex: "8B96A6"), location: 1.0)
        ]),
        startPoint: .top,
        endPoint: .bottom
    )
}

// MARK: - Font Configuration
/// Central font configuration - change these to test different fonts across the entire app
struct FontConfig {
    // MARK: - Font Family Selection
    // Change these values to swap fonts globally
    static let displayFontName = "Copperplate"  // Try: "Futura", "Avenir Next", "Helvetica Neue"
    static let textFontName = "Copperplate"        // Try: "Futura", "Avenir Next", "Helvetica Neue"

    // Alternative font suggestions (built-in iOS fonts):
    // - "Futura" - Clean, geometric, modern
    // - "Avenir Next" - Geometric sans-serif
    // - "Helvetica Neue" - Classic Swiss design
    // - "Menlo" - Monospaced, technical look
    // - "Courier New" - Classic monospaced
    // - "DIN Alternate" - Industrial, technical (if available)
    // - "American Typewriter" - Vintage, mechanical
    // - "Copperplate" - Bold, structured

    // For custom fonts, add .ttf/.otf files to project and update Info.plist
    // Good gaming fonts: "Orbitron", "Rajdhani", "Exo 2", "Audiowide"

    // MARK: - Font Weights
    static let displayWeight: Font.Weight = .black
    static let titleWeight: Font.Weight = .semibold
    static let headlineWeight: Font.Weight = .semibold
    static let buttonWeight: Font.Weight = .semibold
    static let bodyWeight: Font.Weight = .regular
    static let captionWeight: Font.Weight = .medium
    static let hudWeight: Font.Weight = .semibold

    // MARK: - Size Scale
    // Adjust these to make fonts universally larger or smaller
    static let sizeMultiplier: CGFloat = 1.0  // Change to 1.1 for 10% larger, 0.9 for 10% smaller
}

// MARK: - Typography System
struct SteelTypography {
    // Display - Black 32–56pt, slightly expanded tracking (+2%)
    static let display = Font.custom(
        FontConfig.displayFontName,
        size: 48 * FontConfig.sizeMultiplier,
        relativeTo: .largeTitle
    ).weight(FontConfig.displayWeight)

    static let displayLarge = Font.custom(
        FontConfig.displayFontName,
        size: 56 * FontConfig.sizeMultiplier,
        relativeTo: .largeTitle
    ).weight(FontConfig.displayWeight)

    static let displayMedium = Font.custom(
        FontConfig.displayFontName,
        size: 40 * FontConfig.sizeMultiplier,
        relativeTo: .title
    ).weight(FontConfig.displayWeight)

    static let displaySmall = Font.custom(
        FontConfig.displayFontName,
        size: 32 * FontConfig.sizeMultiplier,
        relativeTo: .title2
    ).weight(FontConfig.displayWeight)

    // Label/HUD - Semibold 15–17pt, monospaced digits for timers
    static let hudLabel = Font.custom(
        FontConfig.textFontName,
        size: 17 * FontConfig.sizeMultiplier,
        relativeTo: .body
    )
    .weight(FontConfig.hudWeight)
    .monospacedDigit()

    static let hudLabelSmall = Font.custom(
        FontConfig.textFontName,
        size: 15 * FontConfig.sizeMultiplier,
        relativeTo: .subheadline
    )
    .weight(FontConfig.hudWeight)
    .monospacedDigit()

    // Standard Text Hierarchy
    static let title = Font.custom(
        FontConfig.displayFontName,
        size: 28 * FontConfig.sizeMultiplier,
        relativeTo: .title
    ).weight(FontConfig.titleWeight)

    static let headline = Font.custom(
        FontConfig.textFontName,
        size: 17 * FontConfig.sizeMultiplier,
        relativeTo: .headline
    ).weight(FontConfig.headlineWeight)

    static let body = Font.custom(
        FontConfig.textFontName,
        size: 15 * FontConfig.sizeMultiplier,
        relativeTo: .body
    ).weight(FontConfig.bodyWeight)

    static let caption = Font.custom(
        FontConfig.textFontName,
        size: 12 * FontConfig.sizeMultiplier,
        relativeTo: .caption
    ).weight(FontConfig.captionWeight)

    static let button = Font.custom(
        FontConfig.textFontName,
        size: 16 * FontConfig.sizeMultiplier,
        relativeTo: .callout
    ).weight(FontConfig.buttonWeight)
}

// MARK: - Typography Extensions
extension Text {
    // Apply expanded tracking for display fonts (+2%)
    func displayTracking(for font: Font) -> some View {
        self.kerning(1.0) // Approximate 2% tracking
    }

    func steelDisplayLarge() -> some View {
        self.font(SteelTypography.displayLarge)
            .kerning(1.12) // 2% of 56pt
    }

    func steelDisplay() -> some View {
        self.font(SteelTypography.display)
            .kerning(0.96) // 2% of 48pt
    }

    func steelDisplayMedium() -> some View {
        self.font(SteelTypography.displayMedium)
            .kerning(0.8) // 2% of 40pt
    }

    func steelDisplaySmall() -> some View {
        self.font(SteelTypography.displaySmall)
            .kerning(0.64) // 2% of 32pt
    }
}

// MARK: - Layout & Spacing
struct SteelLayout {
    // Spacing Scale
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 48

    // Corner Radius - 20–22pt for buttons, 12–16pt for cards
    static let radiusSmall: CGFloat = 8
    static let radiusMedium: CGFloat = 12
    static let radiusLarge: CGFloat = 16
    static let radiusButton: CGFloat = 20
    static let radiusButtonLarge: CGFloat = 22

    // Component Heights
    static let buttonHeight: CGFloat = 44
    static let buttonHeightLarge: CGFloat = 52
    static let chipHeight: CGFloat = 32
    static let toggleHeight: CGFloat = 28
}

// MARK: - Glass Materials
struct GlassMaterial {
    static func glassSurface() -> some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .overlay(
                Rectangle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.45), radius: 15, x: 0, y: 10)
    }

    static func glassCard() -> some View {
        RoundedRectangle(cornerRadius: SteelLayout.radiusLarge)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: SteelLayout.radiusLarge)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.45), radius: 15, x: 0, y: 10)
    }

    static func overlayGlassCard() -> some View {
        RoundedRectangle(cornerRadius: SteelLayout.radiusLarge)
            .fill(.thinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: SteelLayout.radiusLarge)
                    .stroke(Color.neonBlue.opacity(0.3), lineWidth: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: SteelLayout.radiusLarge)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    .offset(x: 1, y: 1)
            )
            .shadow(color: .black.opacity(0.6), radius: 20, x: 0, y: 15)
            .background(
                RoundedRectangle(cornerRadius: SteelLayout.radiusLarge)
                    .fill(Color.coreBlue.opacity(0.05))
                    .blur(radius: 8)
            )
    }
}

// MARK: - Neon Glow Effects
struct NeonGlow {
    static func primaryGlow(radius: CGFloat = 16, opacity: Double = 0.3) -> some View {
        Circle()
            .fill(Color.neonBlue.opacity(opacity))
            .blur(radius: radius)
    }

    static func accentGlow(radius: CGFloat = 12, opacity: Double = 0.4) -> some View {
        RoundedRectangle(cornerRadius: SteelLayout.radiusButton)
            .fill(Color.neonBlue.opacity(opacity))
            .blur(radius: radius)
    }

    static func ringRipple() -> some View {
        Circle()
            .stroke(
                LinearGradient(
                    colors: [.coreBlue, .iceCyan],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 2
            )
            .scaleEffect(1.2)
            .opacity(0.8)
    }
}

// MARK: - Motion & Animation
struct SteelMotion {
    // Timings: 120–220ms ease-out; 180ms spring for confirmations
    static let fastEaseOut = Animation.easeOut(duration: 0.12)
    static let mediumEaseOut = Animation.easeOut(duration: 0.18)
    static let slowEaseOut = Animation.easeOut(duration: 0.22)

    // Spring for confirmations
    static let confirmationSpring = Animation.spring(duration: 0.18, bounce: 0.3)

    // Neon pulse: brief 180ms on focus/hover; brightness +15%
    static let neonPulse = Animation.easeInOut(duration: 0.18)

    // VFX timings
    static let innerShineSweep = Animation.easeOut(duration: 0.18)
    static let successRipple = Animation.easeOut(duration: 0.24)
}

// MARK: - Haptic Feedback
struct SteelHaptics {
    static func lightTap() {
#if os(iOS)
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
#endif
    }

    static func successFeedback() {
#if os(iOS)
        let notification = UINotificationFeedbackGenerator()
        notification.notificationOccurred(.success)
        let impact = UIImpactFeedbackGenerator(style: .rigid)
        impact.impactOccurred()
#endif
    }

    static func errorFeedback() {
#if os(iOS)
        let notification = UINotificationFeedbackGenerator()
        notification.notificationOccurred(.error)
#endif
    }
}

// MARK: - Primary Chrome Button
struct ChromeButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    let size: Size

    @State private var isPressed = false
    @State private var isHovered = false

    enum Size {
        case medium, large

        var height: CGFloat {
            switch self {
            case .medium: return SteelLayout.buttonHeight
            case .large: return SteelLayout.buttonHeightLarge
            }
        }

        var cornerRadius: CGFloat {
            switch self {
            case .medium: return SteelLayout.radiusButton
            case .large: return SteelLayout.radiusButtonLarge
            }
        }

        var font: Font {
            switch self {
            case .medium: return SteelTypography.button
            case .large: return SteelTypography.headline
            }
        }

        var iconSize: CGFloat {
            switch self {
            case .medium: return 18
            case .large: return 20
            }
        }
    }

    init(_ title: String, icon: String? = "scope", size: Size = .medium, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.size = size
        self.action = action
    }

    var body: some View {
        Button(action: {
            SteelHaptics.lightTap()
            action()
        }) {
            HStack(spacing: SteelLayout.sm) {
                if let icon = icon {
                    if UIImage(named: icon) != nil {
                        Image(icon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: size.iconSize + 6, height: size.iconSize + 6)
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: size.iconSize, weight: .semibold))
                    }
                }

                Text(title)
                    .font(size.font)
            }
            .foregroundColor(.night)
            .frame(height: size.height)
            .padding(.horizontal, SteelLayout.xl)
            .background(
                ZStack {
                    // Neon glow background
                    RoundedRectangle(cornerRadius: size.cornerRadius)
                        .fill(Color.neonBlue.opacity(isHovered ? 0.4 : 0.3))
                        .blur(radius: 16)
                        .scaleEffect(isHovered ? 1.1 : 1.0)

                    // Chrome gradient
                    RoundedRectangle(cornerRadius: size.cornerRadius)
                        .fill(ChromeBlockGradient.gradient)
                        .overlay(
                            RoundedRectangle(cornerRadius: size.cornerRadius)
                                .stroke(Color.coreBlue, lineWidth: 1.5)
                        )
                }
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(SteelMotion.mediumEaseOut, value: isPressed)
            .animation(SteelMotion.neonPulse, value: isHovered)
        }
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .onHover { hovering in
            isHovered = hovering
        }
        .buttonStyle(BorderlessButtonStyle())
    }
}

// MARK: - Glass Button (Secondary)
struct GlassButton: View {
    let title: String
    let icon: String?
    let action: () -> Void

    @State private var isPressed = false
    @State private var isHovered = false

    init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button(action: {
            SteelHaptics.lightTap()
            action()
        }) {
            HStack(spacing: SteelLayout.sm) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                }

                Text(title)
                    .font(SteelTypography.button)
            }
            .foregroundColor(.coreBlue)
            .frame(height: SteelLayout.buttonHeight)
            .padding(.horizontal, SteelLayout.xl)
            .background(
                ZStack {
                    // Glass surface
                    RoundedRectangle(cornerRadius: SteelLayout.radiusButton)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: SteelLayout.radiusButton)
                                .stroke(Color.white.opacity(0.14), lineWidth: 1)
                        )

                    // Neon outline on hover
                    if isHovered {
                        RoundedRectangle(cornerRadius: SteelLayout.radiusButton)
                            .stroke(Color.neonBlue.opacity(0.4), lineWidth: 2)
                    }
                }
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(SteelMotion.mediumEaseOut, value: isPressed)
            .animation(SteelMotion.neonPulse, value: isHovered)
        }
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .onHover { hovering in
            isHovered = hovering
        }
        .buttonStyle(BorderlessButtonStyle())
    }
}


// MARK: - Image Background Button (for LargeButtonBg1.png style)
struct ImageBackgroundButton: View {
    let icon: String
    let action: () -> Void
    let backgroundImage: String
    let width: CGFloat
    let height: CGFloat
    let iconSize: CGFloat

    @State private var isPressed = false

    init(
        icon: String,
        backgroundImage: String = "LargeButtonBg1",
        width: CGFloat = 60,
        height: CGFloat = 60,
        iconSize: CGFloat? = nil,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.backgroundImage = backgroundImage
        self.width = width
        self.height = height
        self.iconSize = iconSize ?? (width / 3.0) // Default icon size is 1/3 of button width
        self.action = action
    }

    var body: some View {
        Button(action: {
            SteelHaptics.lightTap()
            action()
        }) {
            ZStack {
                // Background image
                Image(backgroundImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: width, height: height)

                // Icon centered on top
                Image(systemName: icon)
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(SteelMotion.fastEaseOut, value: isPressed)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .buttonStyle(BorderlessButtonStyle())
    }
}

// MARK: - Steel Card Component
struct SteelCard<Content: View>: View {
    let content: Content
    let hasHeaderStripe: Bool
    let variant: CardVariant

    enum CardVariant {
        case standard, overlay
    }

    init(hasHeaderStripe: Bool = false, variant: CardVariant = .standard, @ViewBuilder content: () -> Content) {
        self.hasHeaderStripe = hasHeaderStripe
        self.variant = variant
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            if hasHeaderStripe {
                Rectangle()
                    .fill(Color.neonBlue)
                    .frame(height: 2)
            }

            content
                .padding(SteelLayout.lg)
        }
        .background(
            Group {
                switch variant {
                case .standard:
                    GlassMaterial.glassCard()
                case .overlay:
                    GlassMaterial.overlayGlassCard()
                }
            }
        )
    }
}

// MARK: - Status Chip Component
struct StatusChip: View {
    let icon: String
    let label: String
    let isActive: Bool

    init(_ icon: String, label: String, isActive: Bool = false) {
        self.icon = icon
        self.label = label
        self.isActive = isActive
    }

    var body: some View {
        HStack(spacing: SteelLayout.xs) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))

            Text(label)
                .font(SteelTypography.caption)
        }
        .foregroundColor(isActive ? .night : .textSecondary)
        .padding(.horizontal, SteelLayout.sm)
        .padding(.vertical, SteelLayout.xs)
        .background(
            Capsule()
                .fill(Color.surface)
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .background(
                    // Active glow
                    Capsule()
                        .fill(Color.neonBlue.opacity(isActive ? 0.3 : 0))
                        .blur(radius: 8)
                )
        )
    }
}

// MARK: - Steel Toggle
struct SteelToggle: View {
    @Binding var isOn: Bool
    let label: String?

    init(isOn: Binding<Bool>, label: String? = nil) {
        self._isOn = isOn
        self.label = label
    }

    var body: some View {
        HStack {
            if let label = label {
                Text(label)
                    .font(SteelTypography.body)
                    .foregroundColor(.textPrimary)
                Spacer()
            }

            Button(action: {
                SteelHaptics.lightTap()
                withAnimation(SteelMotion.confirmationSpring) {
                    isOn.toggle()
                }
            }) {
                ZStack {
                    // Track
                    Capsule()
                        .fill(isOn ? Color.coreBlue : Color.gunmetal)
                        .frame(width: 50, height: SteelLayout.toggleHeight)

                    // Thumb
                    Circle()
                        .fill(Color.chromeHi)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle()
                                .fill(Color.iceCyan)
                                .frame(width: 4, height: 4)
                        )
                        .offset(x: isOn ? 11 : -11)
                }
            }
        }
    }
}

// MARK: - Winged Reticle Badge
struct ReticleBadge: View {
    let rank: Rank
    let size: CGFloat

    enum Rank {
        case bronze, silver, gold

        var tint: Color {
            switch self {
            case .bronze: return Color(hex: "CD7F32")
            case .silver: return Color(hex: "C0C0C0")
            case .gold: return Color(hex: "FFD700")
            }
        }
    }

    init(rank: Rank, size: CGFloat = 32) {
        self.rank = rank
        self.size = size
    }

    var body: some View {
        ZStack {
            // Background chrome gradient with rank tint
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.chromeHi.blended(with: rank.tint, ratio: 0.3),
                            Color.steel.blended(with: rank.tint, ratio: 0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)

            // Reticle symbol
            Image(systemName: "scope")
                .font(.system(size: size * 0.5, weight: .bold))
                .foregroundColor(.night)
        }
    }
}

// MARK: - Tab/Segment Control
struct SteelSegmentedControl: View {
    @Binding var selection: Int
    let options: [String]

    init(selection: Binding<Int>, options: [String]) {
        self._selection = selection
        self.options = options
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                Button(action: {
                    SteelHaptics.lightTap()
                    withAnimation(SteelMotion.confirmationSpring) {
                        selection = index
                    }
                }) {
                    Text(option)
                        .font(SteelTypography.button)
                        .foregroundColor(selection == index ? .night : .textSecondary)
                        .padding(.horizontal, SteelLayout.lg)
                        .padding(.vertical, SteelLayout.sm)
                        .background(
                            Group {
                                if selection == index {
                                    Capsule()
                                        .fill(ChromeBlockGradient.gradient)
                                        .overlay(
                                            Capsule()
                                                .stroke(Color.neonBlue, lineWidth: 1)
                                        )
                                } else {
                                    Color.clear
                                }
                            }
                        )
                }
            }
        }
        .padding(4)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

// MARK: - VFX Overlay Components
struct InnerShineOverlay: View {
    @State private var animationOffset: CGFloat = -1
    let isActive: Bool

    init(isActive: Bool = false) {
        self.isActive = isActive
    }

    var body: some View {
        GeometryReader { geometry in
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            .clear,
                            .white.opacity(0.3),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: geometry.size.width * 0.3)
                .offset(x: animationOffset * geometry.size.width)
                .opacity(isActive ? 1 : 0)
        }
        .clipped()
        .onChange(of: isActive) { active in
            if active {
                animationOffset = -1
                withAnimation(SteelMotion.innerShineSweep) {
                    animationOffset = 1.3
                }
            }
        }
    }
}

// MARK: - Drone Component Compatibility Layer
// These components originated in the former Drone design system. They now live
// here, backed by the Steel/Chrome palette tokens above, so the screens that
// use them keep working under the single unified design system.

struct DroneTypography {
    static let heroTitle = Font.custom("SF Pro Display", size: 34, relativeTo: .largeTitle).weight(.bold)
    static let title = Font.custom("SF Pro Display", size: 28, relativeTo: .title).weight(.semibold)
    static let headline = Font.custom("SF Pro Text", size: 17, relativeTo: .headline).weight(.semibold)
    static let body = Font.custom("SF Pro Text", size: 15, relativeTo: .body).weight(.regular)
    static let caption = Font.custom("SF Pro Text", size: 12, relativeTo: .caption).weight(.medium)
    static let button = Font.custom("SF Pro Text", size: 16, relativeTo: .callout).weight(.semibold)
}

struct DroneLayout {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48

    static let radiusXS: CGFloat = 6
    static let radiusSM: CGFloat = 10
    static let radiusMD: CGFloat = 16
    static let radiusLG: CGFloat = 20
    static let radiusXL: CGFloat = 28

    static var shadowColor: Color { Color.black.opacity(0.3) }
    static var glowColor: Color { Color.coreBlue.opacity(0.3) }
}

// Icon-only rounded button
struct DroneIconButton: View {
    let icon: String
    let style: ButtonStyle
    let size: IconButtonSize
    let isEnabled: Bool
    let action: () -> Void

    enum IconButtonSize {
        case small, medium, large

        var dimension: CGFloat {
            switch self {
            case .small: return 32
            case .medium: return 40
            case .large: return 48
            }
        }

        var iconSize: Font {
            switch self {
            case .small: return .caption
            case .medium: return .body
            case .large: return .title3
            }
        }

        var cornerRadius: CGFloat {
            return dimension / 2
        }
    }

    enum ButtonStyle {
        case primary, secondary, ghost, danger

        var backgroundColor: Color {
            switch self {
            case .primary: return Color.droneAccent
            case .secondary: return Color.droneSecondary
            case .ghost: return Color.clear
            case .danger: return Color.droneError
            }
        }

        var foregroundColor: Color {
            switch self {
            case .primary, .secondary, .danger: return Color.white
            case .ghost: return Color.droneAccent
            }
        }

        var strokeColor: Color {
            switch self {
            case .primary, .secondary, .danger: return Color.clear
            case .ghost: return Color.droneAccent.opacity(0.5)
            }
        }
    }

    init(
        _ icon: String,
        style: ButtonStyle = .primary,
        size: IconButtonSize = .medium,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.style = style
        self.size = size
        self.isEnabled = isEnabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(size.iconSize.weight(.semibold))
                .foregroundColor(isEnabled ? style.foregroundColor : .droneDisabled)
                .frame(width: size.dimension, height: size.dimension)
                .background(
                    Circle()
                        .fill(isEnabled ? style.backgroundColor : .droneDisabled)
                        .stroke(style.strokeColor, lineWidth: style == .ghost ? 1 : 0)
                )
        }
        .disabled(!isEnabled)
        .scaleEffect(isEnabled ? 1.0 : 0.95)
        .animation(.easeInOut(duration: 0.15), value: isEnabled)
    }
}

// Glassmorphic Card with subtle bloom
struct DroneCard<Content: View>: View {
    let content: Content
    var variant: CardVariant = .primary
    var isGlowing: Bool = false

    enum CardVariant {
        case primary, secondary, glass

        var backgroundColor: Color {
            switch self {
            case .primary: return .droneSurfacePrimary
            case .secondary: return .droneSurfaceSecondary
            case .glass: return .droneSurfaceGlass
            }
        }

        var strokeColor: Color {
            switch self {
            case .primary: return .droneAccent.opacity(0.3)
            case .secondary: return .droneSecondary.opacity(0.5)
            case .glass: return .white.opacity(0.1)
            }
        }
    }

    init(variant: CardVariant = .primary, isGlowing: Bool = false, @ViewBuilder content: () -> Content) {
        self.variant = variant
        self.isGlowing = isGlowing
        self.content = content()
    }

    var body: some View {
        content
            .padding(DroneLayout.md)
            .background(
                RoundedRectangle(cornerRadius: DroneLayout.radiusMD)
                    .fill(variant.backgroundColor)
                    .stroke(variant.strokeColor, lineWidth: 1)
                    .background(
                        RoundedRectangle(cornerRadius: DroneLayout.radiusMD)
                            .fill(isGlowing ? DroneLayout.glowColor : Color.clear)
                            .blur(radius: isGlowing ? 8 : 0)
                    )
            )
            .shadow(color: DroneLayout.shadowColor, radius: 8, x: 0, y: 4)
    }
}

// Chunky, rounded button
struct DroneButton: View {
    let title: String
    let icon: String?
    let style: ButtonStyle
    let size: ButtonSize
    let isEnabled: Bool
    let action: () -> Void

    enum ButtonStyle {
        case primary, secondary, ghost, danger

        var backgroundColor: Color {
            switch self {
            case .primary: return Color.droneAccent
            case .secondary: return Color.droneSecondary
            case .ghost: return Color.clear
            case .danger: return Color.droneError
            }
        }

        var foregroundColor: Color {
            switch self {
            case .primary, .secondary, .danger: return Color.white
            case .ghost: return Color.droneAccent
            }
        }

        var strokeColor: Color {
            switch self {
            case .primary, .secondary, .danger: return Color.clear
            case .ghost: return Color.droneAccent.opacity(0.5)
            }
        }
    }

    enum ButtonSize {
        case small, medium, large, hero

        var padding: EdgeInsets {
            switch self {
            case .small: return EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
            case .medium: return EdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20)
            case .large: return EdgeInsets(top: 16, leading: 24, bottom: 16, trailing: 24)
            case .hero: return EdgeInsets(top: 20, leading: 32, bottom: 20, trailing: 32)
            }
        }

        var cornerRadius: CGFloat {
            switch self {
            case .small: return DroneLayout.radiusXS
            case .medium: return DroneLayout.radiusSM
            case .large: return DroneLayout.radiusMD
            case .hero: return DroneLayout.radiusLG
            }
        }

        var font: Font {
            switch self {
            case .small: return DroneTypography.caption
            case .medium: return DroneTypography.button
            case .large: return DroneTypography.button
            case .hero: return DroneTypography.headline
            }
        }
    }

    init(
        _ title: String,
        icon: String? = nil,
        style: ButtonStyle = .primary,
        size: ButtonSize = .medium,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.size = size
        self.isEnabled = isEnabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: DroneLayout.xs) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(size.font.weight(.semibold))
                }

                Text(title)
                    .font(size.font)
            }
            .foregroundColor(isEnabled ? style.foregroundColor : .droneDisabled)
            .padding(size.padding)
            .background(
                RoundedRectangle(cornerRadius: size.cornerRadius)
                    .fill(isEnabled ? style.backgroundColor : .droneDisabled)
                    .stroke(style.strokeColor, lineWidth: style == .ghost ? 1 : 0)
            )
        }
        .disabled(!isEnabled)
        .scaleEffect(isEnabled ? 1.0 : 0.95)
        .animation(.easeInOut(duration: 0.15), value: isEnabled)
    }
}

// Status indicator with glow
struct StatusIndicator: View {
    let status: Status
    let label: String?

    enum Status {
        case online, offline, warning, error, charging

        var color: Color {
            switch self {
            case .online: return Color.droneSuccess
            case .offline: return Color.droneDisabled
            case .warning: return Color.droneWarning
            case .error: return Color.droneError
            case .charging: return Color.droneInfo
            }
        }

        var icon: String {
            switch self {
            case .online: return "checkmark.circle.fill"
            case .offline: return "xmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "xmark.octagon.fill"
            case .charging: return "bolt.circle.fill"
            }
        }
    }

    init(_ status: Status, label: String? = nil) {
        self.status = status
        self.label = label
    }

    var body: some View {
        HStack(spacing: DroneLayout.xs) {
            Image(systemName: status.icon)
                .foregroundColor(status.color)
                .background(
                    Circle()
                        .fill(status.color.opacity(0.2))
                        .frame(width: 20, height: 20)
                        .blur(radius: 4)
                )

            if let label = label {
                Text(label)
                    .font(DroneTypography.caption)
                    .foregroundColor(.droneTextSecondary)
            }
        }
    }
}

// MARK: - Glossy Shine View Modifier
struct GlossyShineModifier: ViewModifier {
    let intensity: Double
    let angle: Angle

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [
                        .white.opacity(0),
                        .white.opacity(intensity * 0.6),
                        .white.opacity(intensity * 0.8),
                        .white.opacity(intensity * 0.6),
                        .white.opacity(0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .rotationEffect(angle)
                .blendMode(.overlay)
            )
            .overlay(
                // Top edge highlight
                LinearGradient(
                    colors: [
                        .white.opacity(intensity * 0.5),
                        .clear
                    ],
                    startPoint: .top,
                    endPoint: .center
                )
                .blendMode(.softLight)
            )
    }
}

extension View {
    /// Applies a glossy/shine effect to images and views
    /// - Parameters:
    ///   - intensity: Shine intensity from 0.0 to 1.0 (default: 0.4)
    ///   - angle: Rotation angle for the shine gradient (default: 45°)
    func glossyShine(intensity: Double = 0.4, angle: Angle = .degrees(45)) -> some View {
        self.modifier(GlossyShineModifier(intensity: intensity, angle: angle))
    }
}

// MARK: - Preview
struct StylesPreview: View {
    @State private var toggleState = false
    @State private var selectedSegment = 0
    @State private var showShine = false

    var body: some View {
        ScrollView {
            VStack(spacing: SteelLayout.xl) {
                // Color Palette
                SteelCard(hasHeaderStripe: true) {
                    VStack(alignment: .leading, spacing: SteelLayout.lg) {
                        Text("Chrome & Steel Palette")
                            .font(SteelTypography.headline)
                            .foregroundColor(.textPrimary)

                        HStack(spacing: SteelLayout.md) {
                            ColorSwatch(.chromeHi, "Chrome Hi")
                            ColorSwatch(.steel, "Steel")
                            ColorSwatch(.gunmetal, "Gunmetal")
                            ColorSwatch(.night, "Night")
                        }

                        HStack(spacing: SteelLayout.md) {
                            ColorSwatch(.neonBlue, "Neon Blue")
                            ColorSwatch(.coreBlue, "Core Blue")
                            ColorSwatch(.iceCyan, "Ice Cyan")
                        }
                    }
                }

                // Typography
                SteelCard {
                    VStack(alignment: .leading, spacing: SteelLayout.md) {
                        Text("Typography")
                            .font(SteelTypography.headline)
                            .foregroundColor(.textPrimary)

                        Text("Display Title")
                            .font(SteelTypography.displayMedium)
                            .foregroundColor(.textPrimary)

                        Text("HUD Label: 00:45")
                            .font(SteelTypography.hudLabel)
                            .foregroundColor(.textSecondary)

                        Text("Body text for descriptions and content.")
                            .font(SteelTypography.body)
                            .foregroundColor(.textSecondary)
                    }
                }

                // Buttons
                SteelCard {
                    VStack(spacing: SteelLayout.lg) {
                        Text("Buttons")
                            .font(SteelTypography.headline)
                            .foregroundColor(.textPrimary)

                        ChromeButton("Primary Action", icon: "scope") {}

                        GlassButton("Secondary Action", icon: "gear") {}

                        Button(action: { showShine.toggle() }) {
                            Text("Trigger Shine Effect")
                                .foregroundColor(.coreBlue)
                        }
                        .overlay(InnerShineOverlay(isActive: showShine))
                        .clipped()
                    }
                }

                // Components
                SteelCard {
                    VStack(spacing: SteelLayout.lg) {
                        Text("Components")
                            .font(SteelTypography.headline)
                            .foregroundColor(.textPrimary)

                        HStack(spacing: SteelLayout.md) {
                            StatusChip("bolt.fill", label: "Charging", isActive: true)
                            StatusChip("antenna.radiowaves.left.and.right", label: "Signal")
                            StatusChip("gauge.high", label: "Thrust")
                        }

                        SteelToggle(isOn: $toggleState, label: "Flight Mode")

                        SteelSegmentedControl(
                            selection: $selectedSegment,
                            options: ["Solo", "Team", "Battle"]
                        )

                        HStack {
                            ReticleBadge(rank: .bronze)
                            ReticleBadge(rank: .silver)
                            ReticleBadge(rank: .gold)
                        }
                    }
                }
            }
            .padding(SteelLayout.xl)
        }
        .background(Color.night)
    }
}

struct ColorSwatch: View {
    let color: Color
    let name: String

    init(_ color: Color, _ name: String) {
        self.color = color
        self.name = name
    }

    var body: some View {
        VStack(spacing: SteelLayout.xs) {
            RoundedRectangle(cornerRadius: SteelLayout.radiusSmall)
                .fill(color)
                .frame(width: 60, height: 40)

            Text(name)
                .font(SteelTypography.caption)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
        }
    }
}

#Preview {
    StylesPreview()
}
