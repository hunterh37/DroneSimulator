#if os(visionOS)
import DicyaninThumbController
import Foundation
import PinchStick
import PinchStickCore
import RealityKit
import simd

/// Owns the pinch stick controller and routes its output to DualThumbController,
/// the channel shared by the simulator and the live drone.
@MainActor
final class PinchStickRouter {
    static let shared = PinchStickRouter()
    private(set) var isRunning = false
    let controller = PinchStickController()
    private weak var root: Entity?

    /// Pinch-drag sticks or thumb-on-index 3D thumbsticks. Persisted; restarts live input.
    var mode: StickMode {
        get { StickMode(rawValue: UserDefaults.standard.string(forKey: "stickMode.v2") ?? "") ?? .thumb }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "stickMode.v2")
            controller.mode = newValue
            guard isRunning, let root else { return }
            Task { await start(rootEntity: root) }
        }
    }

    private init() {
        controller.onOutput = { out in
            Self.apply(out)
        }
    }

    var visualsEnabled: Bool {
        get { controller.visualsEnabled }
        set { controller.visualsEnabled = newValue }
    }

    func start(rootEntity: Entity) async {
        root = rootEntity
        if StickDebugFlags.shared.legacyThumb { return }
        isRunning = true
        controller.mode = mode
        DualThumbController.shared.isHandTrackingInputEnabled = false
        await controller.start(rootEntity: rootEntity)
    }

    /// Debug flag A: stop pinch sticks but remember the root for resume.
    func suspend() {
        guard isRunning else { return }
        isRunning = false
        controller.stop()
    }

    func resume() {
        guard !isRunning, let root else { return }
        Task { await start(rootEntity: root) }
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        controller.stop()
        DualThumbController.shared.setVirtualJoystickInput(
            leftDirection: .zero, leftMagnitude: 0, leftActive: false,
            rightDirection: .zero, rightMagnitude: 0, rightActive: false)
    }

    private static func apply(_ o: PinchStickOutput) {
        if DemoDirector.ownsInput || StickDebugFlags.shared.legacyThumb { return }
        let l = o.left, r = o.right
        let lm = simd_length(l), rm = simd_length(r)
        let ld = lm > 0 ? SIMD3<Float>(l.x / lm, l.y / lm, 0) : .zero
        let rd = rm > 0 ? SIMD3<Float>(r.x / rm, r.y / rm, 0) : .zero
        DualThumbController.shared.setVirtualJoystickInput(
            leftDirection: ld, leftMagnitude: lm, leftActive: o.leftHeld,
            rightDirection: rd, rightMagnitude: rm, rightActive: o.rightHeld)
    }
}
#endif
