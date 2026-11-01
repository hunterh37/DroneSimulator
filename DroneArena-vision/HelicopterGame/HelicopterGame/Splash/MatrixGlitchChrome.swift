#if os(visionOS)
import SwiftUI

// Matrix-style chrome treatment with chromatic aberration + scanlines, used as the
// front face of the "DicyaninLabs" studio title in the splash. Ported verbatim from
// ZombieShooter (originally lived in RankTesterDebugView).

struct MatrixGlitchChrome<Mask: View>: View {
    var size: CGFloat = 120
    var glow: Bool = true
    @ViewBuilder var mask: () -> Mask

    var body: some View {
        TimelineView(.animation) { tl in
            content(tl.date.timeIntervalSinceReferenceDate)
        }
    }

    private func content(_ t: Double) -> some View {
        let phase = t.truncatingRemainder(dividingBy: 2.4)
        let glitching = phase < 0.22
        let jitter = glitching ? CGFloat(sin(t * 90)) * size * 0.05 : 0

        return ZStack {
            // Cold steel base tinted toward matrix green, masked to the shape.
            ZStack {
                LinearGradient(
                    colors: [
                        Color(white: 0.08),
                        Color(red: 0.0, green: 0.4, blue: 0.18),
                        Color(white: 0.9),
                        Color(red: 0.0, green: 0.3, blue: 0.12),
                        Color(white: 0.06)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
                BrushedNoise(angle: .degrees(90))
                    .blendMode(.overlay).opacity(0.4)
            }
            .mask(mask())

            // RGB channel split (chromatic aberration) during glitch bursts.
            mask().foregroundStyle(Color(red: 1, green: 0, blue: 0.2))
                .offset(x: -jitter).blendMode(.screen).opacity(glitching ? 0.9 : 0.0)
            mask().foregroundStyle(Color(red: 0, green: 1, blue: 0.4))
                .offset(x: jitter * 0.6).blendMode(.screen).opacity(glitching ? 0.9 : 0.0)
            mask().foregroundStyle(Color(red: 0.2, green: 0.4, blue: 1))
                .offset(x: jitter).blendMode(.screen).opacity(glitching ? 0.9 : 0.0)

            // Horizontal scanlines, clipped to the shape.
            ScanlinePattern(spacing: 3)
                .blendMode(.multiply).opacity(0.5)
                .mask(mask())

            // Occasional torn slice that shifts vertically, clipped to the shape.
            if glitching {
                Rectangle()
                    .fill(CyberTheme.green.opacity(0.5))
                    .frame(height: size * 0.12)
                    .offset(y: CGFloat(sin(t * 17)) * size * 0.3)
                    .blendMode(.screen)
                    .mask(mask())
            }
        }
        .compositingGroup()
        .shadow(color: glow ? CyberTheme.green.opacity(0.9) : .clear, radius: glow ? 10 : 0)
        .shadow(color: glow ? CyberTheme.green.opacity(0.5) : .clear, radius: glow ? 22 : 0)
    }
}

private struct BrushedNoise: View {
    var angle: Angle = .degrees(90)

    var body: some View {
        Canvas { ctx, size in
            var rng = SeededRNG(seed: 9173)
            let count = 90
            for _ in 0..<count {
                let x = CGFloat(rng.nextUnit()) * size.width
                let w = CGFloat(0.4 + rng.nextUnit() * 1.4)
                let gray = 0.35 + rng.nextUnit() * 0.6
                let rect = CGRect(x: x, y: -size.height, width: w, height: size.height * 3)
                ctx.fill(Path(rect), with: .color(Color(white: gray, opacity: 0.5)))
            }
        }
        .rotationEffect(angle - .degrees(90))
        .scaleEffect(1.6)
    }
}

private struct ScanlinePattern: View {
    var spacing: CGFloat = 3
    var body: some View {
        Canvas { ctx, size in
            var y: CGFloat = 0
            while y < size.height {
                ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)),
                         with: .color(.black.opacity(0.6)))
                y += spacing
            }
        }
    }
}

private struct SeededRNG {
    var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state ^= state >> 12; state ^= state << 25; state ^= state >> 27
        return state &* 0x2545F4914F6CDD1D
    }
    mutating func nextUnit() -> Double { Double(next() >> 11) / Double(1 << 53) }
}
#endif
