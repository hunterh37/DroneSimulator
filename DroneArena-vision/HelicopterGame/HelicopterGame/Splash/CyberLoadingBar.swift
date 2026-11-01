#if os(visionOS)
import SwiftUI

// Cyber-themed loading bar + glitch modifier. Ported verbatim from ZombieShooter
// (originally in SplashScreenView.swift).

struct CyberLoadingBar: View {
    var progress: Double   // 0.0 ... 1.0
    var label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Track + fill
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: 2)
                        .fill(CyberTheme.green.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(CyberTheme.green.opacity(0.35), lineWidth: 1)
                        )

                    // Fill
                    RoundedRectangle(cornerRadius: 2)
                        .fill(CyberTheme.green)
                        .shadow(color: CyberTheme.green.opacity(0.8), radius: 6)
                        .frame(width: geo.size.width * CGFloat(max(0, min(1, progress))))
                        .animation(.linear(duration: 0.2), value: progress)

                    // Scanline shimmer over fill
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.08), .clear, .white.opacity(0.04)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .frame(width: geo.size.width * CGFloat(max(0, min(1, progress))))
                        .animation(.linear(duration: 0.2), value: progress)
                }
            }
            .frame(height: 8)

            // Label row
            HStack {
                Text(label)
                    .font(CyberTheme.monospaced(36, weight: .bold))
                    .kerning(4)
                    .foregroundStyle(CyberTheme.green)

                Spacer()

                Text("\(Int(progress * 100))%")
                    .font(CyberTheme.monospaced(36, weight: .bold))
                    .foregroundStyle(CyberTheme.green)
                    .animation(.linear(duration: 0.2), value: progress)
            }
        }
    }
}

struct GlitchModifier: ViewModifier {
    var active: Bool
    var intensity: CGFloat = 12

    func body(content: Content) -> some View {
        content
            .offset(x: active ? .random(in: -intensity...intensity) : 0,
                    y: active ? .random(in: -intensity...intensity) : 0)
            .rotationEffect(.degrees(active ? .random(in: -2...2) : 0))
            .scaleEffect(active ? .random(in: 0.98...1.02) : 1.0)
            .overlay(
                content
                    .foregroundColor(CyberTheme.green.opacity(0.8))
                    .offset(x: active ? intensity / 1.5 : 0)
                    .opacity(active ? 0.6 : 0)
                    .blendMode(.screen)
            )
            .overlay(
                content
                    .foregroundColor(CyberTheme.alertRed.opacity(0.8))
                    .offset(x: active ? -intensity / 1.5 : 0)
                    .opacity(active ? 0.6 : 0)
                    .blendMode(.screen)
            )
    }
}
#endif
