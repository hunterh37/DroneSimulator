#if os(visionOS)
import DroneLink
import SwiftUI

/// Top bar, safety strip and stick readouts overlaid on the video.
struct LiveTopBar: View {
    let link: TelloLink
    let onExit: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onExit) { LiveLabel("Exit", color: LiveTheme.text) }
                .buttonStyle(.plain)
            LiveLabel("Tello")
            LiveLabel(stateText, color: link.state == .flying || link.state == .connected ? LiveTheme.text : LiveTheme.textDim)
            Spacer()
            LiveLabel(link.battery.map { "BAT \($0)%" } ?? "BAT -",
                      color: link.battery == nil ? LiveTheme.textDim : LiveTheme.text)
            LiveLabel(String(format: "%.0f FPS", link.video.fps),
                      color: link.video.fps > 0 ? LiveTheme.text : LiveTheme.textDim)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(LiveTheme.bg.opacity(0.55))
    }

    private var stateText: String {
        switch link.state {
        case .disconnected: "offline"
        case .connecting: "connecting"
        case .connected: "ready"
        case .flying: "flying"
        case .failed(let e): e
        }
    }
}

struct LiveSafetyStrip: View {
    let link: TelloLink

    var body: some View {
        if let b = content {
            Text(b.text.uppercased())
                .font(LiveTheme.mono(13, .medium)).tracking(1.2)
                .foregroundStyle(b.fg)
                .frame(maxWidth: .infinity).padding(.vertical, 8)
                .background(b.bg)
                .overlay(Rectangle().stroke(b.border, lineWidth: 1))
        }
    }

    private var content: (text: String, fg: Color, bg: Color, border: Color)? {
        let ft = link.heightCM.map { String(format: "%.1f FT", Double($0) / 30.48) } ?? "-"
        let warn = (fg: Color.black, bg: Color.white, border: Color.white)
        let red = (fg: Color.white, bg: LiveTheme.danger, border: LiveTheme.danger)
        let none = (fg: Color.white, bg: Color.black, border: Color.white)
        switch link.safety {
        case .normal:
            return link.takeoffBlockedReason.map { ("Takeoff blocked. \($0)", red.fg, red.bg, red.border) }
        case .warning: return ("ALT \(ft). Near ceiling", warn.fg, warn.bg, warn.border)
        case .ceiling: return ("ALT \(ft). Ceiling, climb stopped", red.fg, red.bg, red.border)
        case .over: return ("ALT \(ft). Over ceiling, descending", red.fg, red.bg, red.border)
        case .noTelemetry: return ("No telemetry. Climb disabled", none.fg, none.bg, none.border)
        }
    }
}

struct LiveStickDot: View {
    let x: Float
    let y: Float
    var body: some View {
        ZStack {
            Circle().stroke(LiveTheme.hairlineHi, lineWidth: 1)
            Circle().fill(LiveTheme.text).frame(width: 6, height: 6)
                .offset(x: CGFloat(x) * 14, y: -CGFloat(y) * 14)
        }
        .frame(width: 36, height: 36)
    }
}

struct LiveStickReadout: View {
    let sticks: DroneSticks
    let rc: String

    var body: some View {
        HStack(spacing: 12) {
            LiveStickDot(x: sticks.yaw, y: sticks.throttle)
            LiveStickDot(x: sticks.roll, y: sticks.pitch)
            LiveLabel(rc, size: 12, color: LiveTheme.textFaint)
        }
    }
}
#endif
