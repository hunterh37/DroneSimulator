#if os(visionOS)
import DicyaninThumbController
import RealityKit
import SwiftUI

/// Entry and exit flow for Live Drone mode (real Tello, camera feed window,
/// hand thumb sticks). Independent of the simulator scenes.
@MainActor
enum LiveDroneMode {
    static let spaceID = "live-drone"
    static let feedWindowID = "live-drone-feed"

    static func enter(
        appModel: AppModel,
        openSpace: OpenImmersiveSpaceAction,
        dismissSpace: DismissImmersiveSpaceAction,
        openWindow: OpenWindowAction,
        dismissWindow: DismissWindowAction
    ) async {
        guard appModel.immersiveSpaceState != .inTransition else { return }
        if appModel.immersiveSpaceState == .open {
            appModel.immersiveSpaceState = .inTransition
            await dismissSpace()
        }
        appModel.immersiveSpaceState = .inTransition
        switch await openSpace(id: spaceID) {
        case .opened:
            openWindow(id: feedWindowID)
            dismissWindow(id: "MainWindow")
        default:
            appModel.immersiveSpaceState = .closed
        }
    }

    static func exit(
        appModel: AppModel,
        dismissSpace: DismissImmersiveSpaceAction,
        openWindow: OpenWindowAction,
        dismissWindow: DismissWindowAction
    ) async {
        RealDroneBridge.shared.stop()
        openWindow(id: "MainWindow")
        dismissWindow(id: feedWindowID)
        appModel.immersiveSpaceState = .inTransition
        await dismissSpace()
        appModel.immersiveSpaceState = .closed
    }
}

/// Mixed immersive space: thumb joystick visualizers and hand input only.
struct LiveDroneImmersiveView: View {
    @Environment(AppModel.self) private var appModel
    @State private var liveRoot: Entity?

    var body: some View {
        RealityView { content in
            let root = Entity()
            content.add(root)
            liveRoot = root
        }
        .task {
            try? await DualThumbController.shared.start()
            if let root = liveRoot { await PinchStickRouter.shared.start(rootEntity: root) }
        }
        .onAppear { appModel.immersiveSpaceState = .open }
        .onDisappear {
            PinchStickRouter.shared.stop()
            DualThumbController.shared.stop()
            appModel.immersiveSpaceState = .closed
        }
    }
}
#endif
