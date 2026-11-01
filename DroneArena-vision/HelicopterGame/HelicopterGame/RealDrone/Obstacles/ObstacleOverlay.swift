#if os(visionOS)
import DroneLink
import SwiftUI

/// Red target boxes over the camera feed, flight corridor and collision banner.
struct ObstacleOverlay: View {
    let auto: AutonomyController

    var body: some View {
        GeometryReader { geo in
            let s = geo.size
            ZStack(alignment: .topLeading) {
                if auto.demo { demoScene(s) }
                corridor(s)
                ForEach(auto.obstacles) { o in box(o, s) }
                if auto.threat >= .warn { banner.frame(width: s.width).offset(y: s.height - 96) }
            }
        }
        .allowsHitTesting(false)
        .animation(.linear(duration: 0.1), value: auto.obstacles)
    }

    /// Demo camera: horizon plus grey pole silhouettes from the simulated world.
    private func demoScene(_ s: CGSize) -> some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [Color(white: 0.16), Color(white: 0.05)], startPoint: .top, endPoint: .center)
            Rectangle().fill(Color(white: 0.09)).frame(height: s.height / 2).offset(y: s.height / 2)
            ForEach(Array(auto.rawDetections.enumerated()), id: \.offset) { _, d in
                Rectangle().fill(Color(white: 0.55))
                    .frame(width: d.rect.width * s.width, height: d.rect.height * s.height)
                    .offset(x: d.rect.minX * s.width, y: d.rect.minY * s.height)
            }
            LiveLabel("Demo camera", size: 11, color: LiveTheme.textFaint).offset(x: 24, y: s.height - 30)
        }
    }

    private func corridor(_ s: CGSize) -> some View {
        let c = ObstacleTracker().corridor
        return RoundedRectangle(cornerRadius: 6)
            .stroke(Color.white.opacity(0.18), style: StrokeStyle(lineWidth: 1, dash: [6, 6]))
            .frame(width: c.width * s.width, height: c.height * s.height)
            .offset(x: c.minX * s.width, y: c.minY * s.height)
    }

    private func box(_ o: Obstacle, _ s: CGSize) -> some View {
        let r = CGRect(x: o.rect.minX * s.width, y: o.rect.minY * s.height,
                       width: max(o.rect.width * s.width, 14), height: max(o.rect.height * s.height, 14))
        let hot = o.threat >= .warn
        let color = Color.red.opacity(o.threat == .clear ? 0.55 : 1)
        return ZStack(alignment: .topLeading) {
            Rectangle().fill(Color.red.opacity(hot ? 0.18 : 0.06))
            Brackets().stroke(color, lineWidth: hot ? 4 : 2.5)
            Text(label(o))
                .font(LiveTheme.mono(12, .bold)).foregroundStyle(.white)
                .padding(.horizontal, 6).padding(.vertical, 3)
                .background(color)
                .fixedSize()
                .offset(y: -22)
        }
        .frame(width: r.width, height: r.height)
        .offset(x: r.minX, y: r.minY)
    }

    private func label(_ o: Obstacle) -> String {
        var t = o.kind.rawValue.uppercased()
        if let d = o.distanceM { t += String(format: " %.1fM", d) }
        if let ttc = o.ttc, ttc < 10 { t += String(format: " %.1fS", ttc) }
        return t
    }

    private var banner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(auto.braking ? "BRAKING" : (auto.mode == .autonomous ? "REROUTING" : "OBSTACLE AHEAD"))
                .font(LiveTheme.mono(16, .bold)).tracking(2)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18).padding(.vertical, 10)
        .background(Color.red, in: Capsule())
        .frame(maxWidth: .infinity)
    }
}

/// Corner bracket target frame.
struct Brackets: Shape {
    func path(in r: CGRect) -> Path {
        let l = min(r.width, r.height) * 0.28
        var p = Path()
        for (c, dx, dy) in [(CGPoint(x: r.minX, y: r.minY), 1.0, 1.0), (CGPoint(x: r.maxX, y: r.minY), -1.0, 1.0),
                            (CGPoint(x: r.minX, y: r.maxY), 1.0, -1.0), (CGPoint(x: r.maxX, y: r.maxY), -1.0, -1.0)] {
            p.move(to: CGPoint(x: c.x + dx * l, y: c.y))
            p.addLine(to: c)
            p.addLine(to: CGPoint(x: c.x, y: c.y + dy * l))
        }
        return p
    }
}
#endif
