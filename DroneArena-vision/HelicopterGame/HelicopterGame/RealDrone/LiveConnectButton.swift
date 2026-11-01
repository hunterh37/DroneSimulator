#if os(visionOS)
import DroneLink
import SwiftUI

/// Primary connect button with a 3-dot step indicator (Wi-Fi, Link, Video).
/// Text appears only on failure, or while the user must join the Wi-Fi by hand.
struct LiveConnectButton: View {
    let bridge: RealDroneBridge
    private var connector: TelloConnector { bridge.connector }
    private var link: TelloLink { bridge.link }

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            if let line = message {
                Text(line).font(LiveTheme.mono(12)).foregroundStyle(failed ? LiveTheme.danger : LiveTheme.textDim)
                    .multilineTextAlignment(.trailing)
            }
            HStack(spacing: 14) {
                dots
                Button { bridge.connect() } label: {
                    Text(label).frame(minWidth: 220)
                }
                .buttonStyle(LiveChipStyle(filled: connector.state == .ready))
                .disabled(connector.isBusy || connector.state == .ready)
            }
        }
        .animation(LiveTheme.spring, value: connector.state)
    }

    private var failed: Bool { if case .failed = connector.state { true } else { false } }

    private var label: String {
        switch connector.state {
        case .idle, .failed: "Connect"
        case .joiningWiFi: "Joining Tello Wi-Fi"
        case .handshaking: "Handshake"
        case .ready: "Ready"
        }
    }

    private var message: String? {
        if case .failed(let reason, let hint) = connector.state { return "\(reason.uppercased()). \(hint)" }
        if connector.needsManualJoin { return "SETTINGS > WI-FI > TELLO-" }
        return nil
    }

    private var dots: some View {
        HStack(spacing: 6) {
            dot(connector.wifiDone)
            dot(connector.linkDone)
            dot(link.video.fps > 0)
        }
    }

    private func dot(_ on: Bool) -> some View {
        Circle().fill(on ? LiveTheme.text : Color.clear)
            .overlay(Circle().stroke(on ? LiveTheme.text : LiveTheme.hairlineHi, lineWidth: 1))
            .frame(width: 9, height: 9)
    }
}
#endif
