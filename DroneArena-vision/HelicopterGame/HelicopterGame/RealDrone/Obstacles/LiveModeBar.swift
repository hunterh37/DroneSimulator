#if os(visionOS)
import DroneLink
import SwiftUI

/// Large two-segment switch: Manual (hand or touch sticks) or Auto (tap floor, drone flies).
struct LiveModeSwitch: View {
    @Bindable var auto: AutonomyController
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 4) {
            segment(.joystick, "Manual", "gamecontroller.fill")
            segment(.autonomous, "Auto", "location.north.line.fill")
        }
        .padding(4)
        .background(LiveTheme.surface, in: Capsule())
        .overlay(Capsule().stroke(LiveTheme.hairlineHi, lineWidth: 1))
        .animation(LiveTheme.spring, value: auto.mode)
    }

    private func segment(_ m: ControlMode, _ title: String, _ icon: String) -> some View {
        let on = auto.mode == m
        let tint: Color = m == .autonomous ? Color(red: 0.25, green: 0.55, blue: 1) : LiveTheme.text
        return Button { auto.mode = m } label: {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 18, weight: .semibold))
                Text(title.uppercased()).font(LiveTheme.mono(18, .bold)).tracking(2)
            }
            .foregroundStyle(on ? Color.black : LiveTheme.textDim)
            .frame(width: 190, height: 52)
            .background {
                if on { Capsule().fill(tint).matchedGeometryEffect(id: "mode", in: ns) }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .hoverEffect(.highlight)
    }
}

/// Scan, brake and demo toggles.
struct LiveScanToggles: View {
    @Bindable var auto: AutonomyController

    var body: some View {
        HStack(spacing: 8) {
            Button("Scan") { auto.scanEnabled.toggle() }.buttonStyle(LiveChipStyle(filled: auto.scanEnabled))
            Button("Brake") { auto.autoBrake.toggle() }
                .buttonStyle(LiveChipStyle(filled: auto.autoBrake))
                .disabled(auto.mode != .joystick)
            Button("Demo") { auto.demo.toggle() }.buttonStyle(LiveChipStyle(filled: auto.demo))
        }
    }
}

/// Auto mode, left column: target status and stop.
struct LiveAutoPanel: View {
    let auto: AutonomyController
    private let blue = Color(red: 0.25, green: 0.55, blue: 1)

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: auto.target == nil ? "hand.tap" : "location.north.line.fill")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(auto.target == nil ? LiveTheme.textDim : blue)
            LiveLabel(status, size: 15, color: auto.target == nil ? LiveTheme.text : blue)
            if let t = auto.target {
                LiveLabel(String(format: "%.1f m", simd_length(t - auto.pose.xy)), size: 22, color: LiveTheme.text)
                LiveLabel("\(max(0, auto.path.count - 1)) waypoints", size: 11, color: LiveTheme.textFaint)
                Button("Stop") { auto.cancelTarget() }.buttonStyle(LiveChipStyle(danger: true))
            } else {
                LiveLabel("Drone flies there", size: 11, color: LiveTheme.textFaint)
            }
        }
        .multilineTextAlignment(.center)
    }

    private var status: String {
        if auto.target == nil { return "Tap the floor" }
        return auto.rerouted ? "Rerouted" : "Flying to target"
    }
}

/// Right column in Auto mode: detected obstacles, nearest first.
struct LiveObstaclePanel: View {
    let auto: AutonomyController

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            LiveLabel("Obstacles \(auto.obstacles.count)", size: 13, color: LiveTheme.text)
            ForEach(auto.obstacles.prefix(5)) { o in
                HStack {
                    Circle().fill(o.threat >= .warn ? Color.red : Color.red.opacity(0.4)).frame(width: 8, height: 8)
                    LiveLabel(o.kind.rawValue, size: 12, color: LiveTheme.textDim)
                    Spacer()
                    LiveLabel(o.distanceM.map { String(format: "%.1f m", $0) } ?? "-", size: 12, color: LiveTheme.text)
                }
            }
            if auto.obstacles.isEmpty { LiveLabel("Path clear", size: 12, color: LiveTheme.textFaint) }
        }
        .frame(width: 180)
    }
}
#endif
