#if os(visionOS)
import DroneLink
import SwiftUI

/// Connect, arm, takeoff, land, kill, speed limit and settings.
struct LiveControls: View {
    let bridge: RealDroneBridge
    @State private var showSettings = false
    private var link: TelloLink { bridge.link }

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            LiveConnectButton(bridge: bridge)
            HStack(spacing: 8) {
                Button("Arm") { link.sticksEnabled.toggle() }
                    .buttonStyle(LiveChipStyle(filled: link.sticksEnabled))
                    .disabled(link.state == .disconnected)
                Button("Take off") { link.takeoff() }
                    .buttonStyle(LiveChipStyle())
                    .disabled(link.state != .connected || !link.sticksEnabled)
                // shortcut: hidden behind Debug until Task 4 of notes/PLAN-return-to-home.md passes
                if bridge.showDebug {
                    Button("Return") { link.returnHome() }
                        .buttonStyle(LiveChipStyle())
                        .disabled(!link.canReturnHome)
                }
                Button("Land") { link.land() }.buttonStyle(LiveChipStyle())
                Button("Kill") { link.emergency() }.buttonStyle(LiveChipStyle(danger: true))
            }
            HStack(spacing: 8) {
                LiveLabel("Speed", size: 12, color: LiveTheme.textFaint)
                speedRow
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape").font(.system(size: 14))
                        .foregroundStyle(LiveTheme.textDim).padding(7)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showSettings) {
                    @Bindable var b = bridge
                    VStack(spacing: 12) {
                        Toggle(isOn: $b.invertPitch) { LiveLabel("Invert pitch", color: LiveTheme.text) }
                        Toggle(isOn: $b.showDebug) { LiveLabel("Debug", color: LiveTheme.text) }
                    }
                    .padding(16).frame(width: 240)
                }
            }
        }
    }

    private var speedRow: some View {
        HStack(spacing: 0) {
            ForEach([20, 40, 60, 80, 100], id: \.self) { v in
                let on = link.speedLimit == v
                Button { link.speedLimit = v } label: {
                    Text("\(v)").font(LiveTheme.mono(12, on ? .bold : .regular))
                        .foregroundStyle(on ? Color.black : LiveTheme.textDim)
                        .frame(width: 38, height: 26)
                        .background(on ? LiveTheme.text : Color.clear)
                }
                .buttonStyle(.plain)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(LiveTheme.hairline, lineWidth: 1))
        .animation(LiveTheme.spring, value: link.speedLimit)
    }
}
#endif
