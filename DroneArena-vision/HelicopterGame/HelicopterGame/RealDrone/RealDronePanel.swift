#if os(visionOS)
import DroneLink
import SwiftUI

struct RealDronePanel: View {
    @State private var bridge = RealDroneBridge.shared
    private var link: TelloLink { bridge.link }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Real drone").font(.title2.bold())
                Spacer()
                Text(stateText).font(.callout.monospaced()).foregroundStyle(stateColor)
            }
            Text("Join TELLO-XXXXXX Wi-Fi in Settings, then connect.")
                .font(.footnote).foregroundStyle(.secondary)

            HStack {
                Button("Connect") { bridge.start() }
                Button("Disconnect") { bridge.stop() }
            }

            Toggle("Hand sticks fly drone", isOn: Binding(
                get: { link.sticksEnabled }, set: { link.sticksEnabled = $0 }))
            Toggle("Invert pitch", isOn: $bridge.invertPitch)

            VStack(alignment: .leading) {
                Text("Speed limit \(link.speedLimit)")
                Slider(value: Binding(
                    get: { Double(link.speedLimit) },
                    set: { link.speedLimit = Int($0) }), in: 10...100, step: 5)
            }

            HStack(spacing: 12) {
                Button("Take off") { link.takeoff() }.disabled(link.state != .connected)
                Button("Land") { link.land() }.tint(.orange)
                Button("Kill") { link.emergency() }.tint(.red)
            }

            Grid(alignment: .leading, verticalSpacing: 4) {
                GridRow { Text("Battery"); Text(link.battery.map { "\($0)%" } ?? "-") }
                GridRow { Text("Height"); Text(link.heightCM.map { "\($0) cm" } ?? "-") }
                GridRow { Text("Out"); Text(link.lastRC) }
                GridRow { Text("Reply"); Text(link.lastReply) }
            }
            .font(.callout.monospaced())
        }
        .padding(28)
        .frame(width: 460)
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
