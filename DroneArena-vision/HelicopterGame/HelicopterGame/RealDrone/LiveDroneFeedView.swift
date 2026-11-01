#if os(visionOS)
import DroneLink
import SwiftUI

/// Camera feed window: video edge to edge with HUD and flight controls overlaid.
struct LiveDroneFeedView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @State private var bridge = RealDroneBridge.shared
    private var link: TelloLink { bridge.link }

    var body: some View {
        ZStack {
            LiveTheme.bg
            TelloVideoView(stream: link.video)
            if link.video.fps <= 0 { noSignal }
        }
        .aspectRatio(4.0 / 3.0, contentMode: .fit)
        .overlay(alignment: .top) {
            VStack(spacing: 0) {
                LiveTopBar(link: link, onExit: exit)
                LiveSafetyStrip(link: link)
            }
        }
        .overlay(alignment: .leading) { LiveAltitudeTape(heightCM: link.heightCM).padding(.leading, 16) }
        .overlay(alignment: .bottomLeading) {
            LiveStickReadout(sticks: bridge.sticks, rc: link.lastRC).padding(16)
        }
        .overlay(alignment: .bottomTrailing) { LiveControls(bridge: bridge).padding(16) }
        .background(LiveTheme.bg)
        .preferredColorScheme(.dark)
        .onDisappear { bridge.stop() }
    }

    private var noSignal: some View {
        VStack(spacing: 10) {
            LiveLabel("No signal", size: 16, color: LiveTheme.textFaint)
            Rectangle().fill(LiveTheme.text).frame(width: 120, height: 1)
        }
    }

    private func exit() {
        Task {
            await LiveDroneMode.exit(appModel: appModel, dismissSpace: dismissImmersiveSpace,
                                     openWindow: openWindow, dismissWindow: dismissWindow)
        }
    }
}
#endif
