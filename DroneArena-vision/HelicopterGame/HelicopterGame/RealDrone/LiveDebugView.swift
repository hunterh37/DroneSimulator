#if os(visionOS)
import DroneLink
import SwiftUI
import UIKit

/// Packet log and link stats. Toggled from the gear popover.
struct LiveDebugView: View {
    let bridge: RealDroneBridge
    private var link: TelloLink { bridge.link }
    private var video: TelloVideoStream { link.video }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                LiveLabel("Debug", color: LiveTheme.text)
                Spacer()
                Button { UIPasteboard.general.string = link.log.text } label: { LiveLabel("Copy log", size: 12, color: LiveTheme.text) }
                    .buttonStyle(.plain)
                Button { link.log.clear() } label: { LiveLabel("Clear", size: 12) }
                    .buttonStyle(.plain)
            }
            stats
            Divider().overlay(LiveTheme.hairline)
            logList
            Divider().overlay(LiveTheme.hairline)
            fields
        }
        .padding(12)
        .frame(width: 340)
        .background(LiveTheme.bg.opacity(0.88), in: RoundedRectangle(cornerRadius: LiveTheme.radius))
        .overlay(RoundedRectangle(cornerRadius: LiveTheme.radius).stroke(LiveTheme.hairline, lineWidth: 1))
        .padding(.trailing, 16)
    }

    private var stats: some View {
        let nal = video.nalCounts
        return VStack(alignment: .leading, spacing: 3) {
            row("State", "\(bridge.connector.state)".prefix(24).description)
            row("Cmd RTT", link.cmdRTT.map { "\($0) ms" } ?? "-")
            row("State rate", String(format: "%.1f Hz", link.stateRate))
            row("Video", String(format: "%.0f fps  %.0f KB/s", video.fps, video.bytesPerSecond / 1024))
            row("NAL", "SPS \(nal[7] ?? 0)  PPS \(nal[8] ?? 0)  IDR \(nal[5] ?? 0)  P \(nal[1] ?? 0)")
            row("Ports", "cmd \(link.port)  state \(link.statePort)  video \(video.port)")
            row("SSID", "n/a")
            row("Last rc", link.lastRC)
        }
    }

    private var logList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(link.log.entries) { e in
                        HStack(alignment: .top, spacing: 6) {
                            Text(Self.stamp(e.time)).foregroundStyle(LiveTheme.textFaint)
                            Text(e.direction.rawValue.uppercased()).foregroundStyle(e.direction == .tx ? LiveTheme.text : LiveTheme.textDim)
                            Text(e.text).foregroundStyle(LiveTheme.text).lineLimit(2)
                        }
                        .font(LiveTheme.mono(11)).id(e.id)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: 120)
            .onChange(of: link.log.entries.last?.id) { _, id in
                if let id { proxy.scrollTo(id, anchor: .bottom) }
            }
        }
    }

    private var fields: some View {
        let f = link.stateFields.sorted { $0.key < $1.key }
        return Text(f.isEmpty ? "NO TELEMETRY" : f.map { "\($0.key) \($0.value)" }.joined(separator: "  "))
            .font(LiveTheme.mono(10)).foregroundStyle(LiveTheme.textDim)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(_ k: String, _ v: String) -> some View {
        HStack(alignment: .top) {
            LiveLabel(k, size: 11, color: LiveTheme.textFaint).frame(width: 84, alignment: .leading)
            Text(v).font(LiveTheme.mono(11)).foregroundStyle(LiveTheme.text)
            Spacer(minLength: 0)
        }
    }

    private static func stamp(_ d: Date) -> String {
        let c = Calendar.current.dateComponents([.minute, .second, .nanosecond], from: d)
        return String(format: "%02d:%02d.%03d", c.minute ?? 0, c.second ?? 0, (c.nanosecond ?? 0) / 1_000_000)
    }
}
#endif
