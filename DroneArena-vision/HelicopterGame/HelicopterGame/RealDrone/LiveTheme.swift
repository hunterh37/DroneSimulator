#if os(visionOS)
import SwiftUI

/// Monochrome command center tokens. Red is the only hue.
enum LiveTheme {
    static let bg = Color.black
    static let surface = Color.white.opacity(0.04)
    static let surfaceHi = Color.white.opacity(0.08)
    static let hairline = Color.white.opacity(0.10)
    static let hairlineHi = Color.white.opacity(0.18)
    static let text = Color.white
    static let textDim = Color.white.opacity(0.60)
    static let textFaint = Color.white.opacity(0.35)
    static let danger = Color.red
    static let radius: CGFloat = 10
    static let spring = Animation.spring(response: 0.22, dampingFraction: 0.86)

    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

/// Uppercase tracked mono label.
struct LiveLabel: View {
    let text: String
    var size: CGFloat = 13
    var color: Color = LiveTheme.textDim
    init(_ text: String, size: CGFloat = 13, color: Color = LiveTheme.textDim) {
        self.text = text; self.size = size; self.color = color
    }
    var body: some View {
        Text(text.uppercased()).font(LiveTheme.mono(size)).tracking(1.2).foregroundStyle(color)
    }
}

struct LiveChipStyle: ButtonStyle {
    var filled = false
    var danger = false
    @State private var hover = false
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        let tint = danger ? LiveTheme.danger : LiveTheme.text
        let fill: Color = filled ? LiveTheme.text : (danger && hover ? LiveTheme.danger : (hover ? LiveTheme.surfaceHi : LiveTheme.surface))
        let fg: Color = filled ? .black : (danger && hover ? .white : tint)
        configuration.label
            .font(LiveTheme.mono(13, .medium)).tracking(1.2).textCase(.uppercase)
            .foregroundStyle(fg)
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(fill, in: RoundedRectangle(cornerRadius: LiveTheme.radius))
            .overlay(RoundedRectangle(cornerRadius: LiveTheme.radius)
                .stroke(danger ? LiveTheme.danger : (hover ? LiveTheme.hairlineHi : LiveTheme.hairline), lineWidth: 1))
            .opacity(enabled ? (configuration.isPressed ? 0.7 : 1) : 0.35)
            .hoverEffectDisabled()
            .onHover { hover = $0 }
            .animation(LiveTheme.spring, value: hover)
            .contentShape(RoundedRectangle(cornerRadius: LiveTheme.radius))
    }
}
#endif
