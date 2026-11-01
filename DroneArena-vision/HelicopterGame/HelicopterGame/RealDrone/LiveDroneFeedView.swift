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
        VStack(spacing: 0) {
            videoPane
            deck
        }
        .frame(width: 1280)
        .background(LiveTheme.bg)
        .preferredColorScheme(.dark)
        .onDisappear { bridge.stop() }
    }

    private var videoPane: some View {
        ZStack {
            LiveTheme.bg
            TelloVideoView(stream: link.video)
            if link.video.fps <= 0 { noSignal }
        }
        .aspectRatio(4.0 / 3.0, contentMode: .fit)
        .clipped()
        .overlay(alignment: .top) {
            VStack(spacing: 0) {
                LiveTopBar(link: link, onExit: exit)
                LiveSafetyStrip(link: link)
            }
        }
        .overlay(alignment: .leading) { LiveAltitudeTape(heightCM: link.heightCM).padding(.leading, 24) }
        .overlay(alignment: .trailing) {
            if bridge.showDebug { LiveDebugView(bridge: bridge).padding(.top, 56).padding(.bottom, 24) }
        }
    }

    private var deck: some View {
        VStack(spacing: 0) {
            Rectangle().fill(LiveTheme.hairline).frame(height: 1)
            HStack(alignment: .center, spacing: 16) {
                LiveTouchStick(side: .left)
                Rectangle().fill(LiveTheme.hairline).frame(width: 1)
                VStack(spacing: 8) {
                    LiveControls(bridge: bridge)
                    LiveLabel(link.lastRC, size: 11, color: LiveTheme.textFaint)
                }
                .frame(maxWidth: .infinity)
                Rectangle().fill(LiveTheme.hairline).frame(width: 1)
                LiveTouchStick(side: .right)
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity)
        .background(Color.black)
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
