#if os(visionOS)
import DroneLink
import SwiftUI

/// Camera feed window with HUD and flight controls.
struct LiveDroneFeedView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @State private var bridge = RealDroneBridge.shared
    private var link: TelloLink { bridge.link }

    var body: some View {
        VStack(spacing: 16) {
            ZStack(alignment: .topLeading) {
                TelloVideoView(stream: link.video)
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    .background(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                hud.padding(14)
            }
            .overlay(alignment: .top) { banner.padding(10) }
            controls
        }
        .padding(24)
        .onDisappear { bridge.stop() }
    }

    private var hud: some View {
        Grid(alignment: .leading, verticalSpacing: 2) {
            GridRow { Text("State"); Text(stateText).foregroundStyle(stateColor) }
            GridRow { Text("Battery"); Text(link.battery.map { "\($0)%" } ?? "-") }
            GridRow { Text("Height"); Text(link.heightCM.map { "\($0) cm" } ?? "-") }
            GridRow { Text("RC"); Text(link.lastRC) }
            GridRow { Text("FPS"); Text(String(format: "%.0f", link.video.fps)) }
        }
        .font(.caption.monospaced())
        .padding(10)
        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder private var banner: some View {
        if let b = bannerContent {
            Text(b.0)
                .font(.headline)
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(b.1.opacity(0.85), in: Capsule())
        }
    }

    private var bannerContent: (String, Color)? {
        let ft = link.heightCM.map { String(format: "%.1f ft", Double($0) / 30.48) } ?? "-"
        switch link.safety {
        case .normal: return link.takeoffBlockedReason.map { ("Takeoff blocked: \($0)", .red) }
        case .warning: return ("Near ceiling \(ft)", .orange)
        case .ceiling: return ("Ceiling \(ft), climb stopped", .orange)
        case .over: return ("Over ceiling \(ft), descending", .red)
        case .noTelemetry: return ("No telemetry, climb disabled", .red)
        }
    }

    private var controls: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button("Connect") { bridge.start(); link.startVideo() }
                    .disabled(bridge.isActive)
                Toggle("Arm", isOn: Binding(
                    get: { link.sticksEnabled }, set: { link.sticksEnabled = $0 }))
                    .toggleStyle(.button)
                    .disabled(link.state == .disconnected)
                Button("Take off") { link.takeoff() }
                    .disabled(link.state != .connected || !link.sticksEnabled)
                Button("Land") { link.land() }.tint(.orange)
                Button("Kill") { link.emergency() }.tint(.red)
                Button("Exit") {
                    Task {
                        await LiveDroneMode.exit(appModel: appModel, dismissSpace: dismissImmersiveSpace,
                                                 openWindow: openWindow, dismissWindow: dismissWindow)
                    }
                }
            }
            HStack(spacing: 20) {
                Text("Speed \(link.speedLimit)").font(.callout.monospaced())
                Slider(value: Binding(
                    get: { Double(link.speedLimit) },
                    set: { link.speedLimit = Int($0) }), in: 10...100, step: 5)
                    .frame(width: 280)
                Toggle("Invert pitch", isOn: $bridge.invertPitch).fixedSize()
            }
        }
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

    private var stateColor: Color {
        switch link.state {
        case .connected: .green
        case .flying: .cyan
        case .failed: .red
        default: .secondary
        }
    }
}
#endif
