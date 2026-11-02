#if os(visionOS)
import DroneLink
import SwiftUI

/// Camera feed window. Header with mode switch, 1440x1080 video between two control
/// columns (sticks in Manual, target and obstacle panels in Auto), flight bar below.
struct LiveDroneFeedView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @State private var bridge = RealDroneBridge.shared
    @State private var auto = AutonomyController.shared
    private var link: TelloLink { bridge.link }

    static let videoSize = CGSize(width: 1440, height: 1080)
    static let sideWidth: CGFloat = 240

    var body: some View {
        VStack(spacing: 0) {
            header
            line
            HStack(spacing: 0) {
                column {
                    switch auto.mode {
                    case .joystick: LiveTouchStick(side: .left)
                    case .palm: LivePalmPanel(palm: PalmPilot.shared)
                    case .autonomous: LiveAutoPanel(auto: auto)
                    }
                }
                videoPane
                column { if auto.mode == .joystick { LiveTouchStick(side: .right) } else { LiveObstaclePanel(auto: auto) } }
            }
            line
            footer
        }
        .frame(width: Self.videoSize.width + Self.sideWidth * 2)
        .background(LiveTheme.bg)
        .preferredColorScheme(.dark)
        .onAppear { auto.start(link: link) }
        .onChange(of: auto.mode, initial: true) { _, m in
            if m == .palm {
                PalmPilot.shared.onLand = { [link] in link.land() }
                PalmPilot.shared.start()
            } else { PalmPilot.shared.stop() }
        }
        .onDisappear { bridge.stop(); auto.stop(); PalmPilot.shared.stop() }
    }

    private var line: some View { Rectangle().fill(LiveTheme.hairline).frame(height: 1) }

    private var header: some View {
        ZStack {
            LiveTopBar(link: link, onExit: exit)
            LiveModeSwitch(auto: auto)
        }
        .frame(height: 76)
    }

    private func column<C: View>(@ViewBuilder _ c: () -> C) -> some View {
        c().frame(width: Self.sideWidth, height: Self.videoSize.height).background(Color.black)
    }

    private var videoPane: some View {
        ZStack {
            LiveTheme.bg
            TelloVideoView(stream: link.video)
            if link.video.fps <= 0, !auto.demo { noSignal }
            ObstacleOverlay(auto: auto)
        }
        .frame(width: Self.videoSize.width, height: Self.videoSize.height)
        .clipped()
        .overlay(alignment: .top) { LiveSafetyStrip(link: link) }
        .overlay(alignment: .leading) { LiveAltitudeTape(heightCM: link.heightCM).padding(.leading, 24) }
        .overlay(alignment: .trailing) {
            if bridge.showDebug { LiveDebugView(bridge: bridge).padding(.vertical, 24) }
        }
    }

    private var footer: some View {
        HStack(spacing: 20) {
            LiveControls(bridge: bridge)
            Spacer()
            LiveScanToggles(auto: auto)
        }
        .padding(.horizontal, 24).padding(.vertical, 16)
        .background(Color.black)
    }

    private var noSignal: some View {
        VStack(spacing: 14) {
            LiveLabel("No signal", size: 20, color: LiveTheme.textDim)
            LiveLabel("Connect a Tello or turn on Demo", size: 12, color: LiveTheme.textFaint)
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
