#if os(visionOS)
import DicyaninThumbController
import DroneLink
import Foundation
import Observation

/// App glue: samples the shared thumb joystick channels (hand thumb sticks or
/// world joystick rig, both write DualThumbController) and feeds DroneLink.
/// All drone protocol and hardware code lives in the DroneLink package.
@MainActor @Observable
final class RealDroneBridge {
    static let shared = RealDroneBridge()

    let link = TelloLink()
    var invertPitch = false
    private(set) var sticks = DroneSticks.zero
    private var timer: Timer?

    private init() {}

    func start() {
        guard timer == nil else { return }
        link.connect()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { _ in
            Task { @MainActor in RealDroneBridge.shared.sample() }
        }
    }

    func stop() {
        link.land()
        timer?.invalidate(); timer = nil
        link.disconnect()
    }

    private func sample() {
        let c = DualThumbController.shared
        let l = c.leftIsActive ? c.leftDirection * c.leftMagnitude : .zero
        let r = c.rightIsActive ? c.rightDirection * c.rightMagnitude : .zero
        // Mode 2, matches MobileVirtualJoystickComponent: left = throttle (y) + yaw (x),
        // right = pitch (y) + roll (x).
        sticks = DroneSticks(
            yaw: l.x,
            throttle: l.y,
            roll: r.x,
            pitch: invertPitch ? -r.y : r.y
        )
        link.update(sticks)
    }
}
#endif
