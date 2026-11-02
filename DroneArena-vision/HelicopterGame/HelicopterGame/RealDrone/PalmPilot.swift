#if os(visionOS)
import ARKit
import DroneLink
import Foundation
import Observation
import QuartzCore
import simd

/// Palm mode: right hand is the drone. Pinch to grab (clutch), move the hand from the grab
/// point to fly: forward/back pitch, left/right roll, up/down throttle, wrist twist yaw.
/// Release the pinch to hover. Left hand pinch held 1 s is an emergency land request.
@MainActor @Observable
final class PalmPilot {
    static let shared = PalmPilot()

    /// Hand travel (m) for full stick on pitch, roll, throttle.
    var reach: Float = 0.15
    /// Wrist twist (rad) for full yaw.
    var twistRange: Float = 0.9
    private(set) var engaged = false
    private(set) var tracking = false
    private(set) var sticks = DroneSticks.zero
    /// Seconds the left pinch has been held (land at 1 s).
    private(set) var landHold: Double = 0

    @ObservationIgnored private let session = ARKitSession()
    @ObservationIgnored private let hands = HandTrackingProvider()
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var anchor: simd_float4x4?
    @ObservationIgnored private var landStart: CFTimeInterval?
    @ObservationIgnored var onLand: (() -> Void)?

    private init() {}

    func start() {
        guard task == nil, HandTrackingProvider.isSupported else { return }
        task = Task { [weak self] in
            guard let self else { return }
            do { try await session.run([hands]) } catch { return }
            tracking = true
            for await update in hands.anchorUpdates { handle(update.anchor) }
        }
    }

    func stop() {
        task?.cancel(); task = nil
        session.stop()
        tracking = false
        release()
    }

    private func handle(_ a: HandAnchor) {
        guard let s = a.handSkeleton, a.isTracked else {
            if a.chirality == .right { release() } else { landStart = nil; landHold = 0 }
            return
        }
        let pinched = Self.pinch(s)
        let wrist = a.originFromAnchorTransform
        if a.chirality == .left {
            if pinched {
                let now = CACurrentMediaTime()
                if landStart == nil { landStart = now }
                landHold = now - landStart!
                if landHold >= 1 { landStart = .infinity; onLand?() }
            } else { landStart = nil; landHold = 0 }
            return
        }
        guard pinched else { release(); return }
        if anchor == nil { anchor = wrist; engaged = true }
        guard let base = anchor else { return }
        // Offset in the grab frame, yaw-only so a tilted hand does not leak into throttle.
        let fwd0 = Self.flatForward(base)
        let right0 = SIMD3<Float>(-fwd0.z, 0, fwd0.x)
        let d = wrist.columns.3.xyz - base.columns.3.xyz
        let pitch = Self.shape(simd_dot(d, fwd0) / reach)
        let roll = Self.shape(simd_dot(d, right0) / reach)
        let thr = Self.shape(d.y / reach)
        let f1 = Self.flatForward(wrist)
        let twist = atan2(simd_cross(fwd0, f1).y, simd_dot(fwd0, f1))
        let yaw = Self.shape(-twist / twistRange)
        sticks = DroneSticks(yaw: yaw, throttle: thr, roll: roll, pitch: pitch)
    }

    private func release() {
        anchor = nil
        if engaged { engaged = false }
        if sticks != .zero { sticks = .zero }
    }

    private static func pinch(_ s: HandSkeleton) -> Bool {
        let t = s.joint(.thumbTip), i = s.joint(.indexFingerTip)
        guard t.isTracked, i.isTracked else { return false }
        return simd_distance(t.anchorFromJointTransform.columns.3.xyz,
                             i.anchorFromJointTransform.columns.3.xyz) < 0.02
    }

    /// Forward of a hand on the floor plane. Hand anchor +X points along the fingers.
    private static func flatForward(_ m: simd_float4x4) -> SIMD3<Float> {
        var f = m.columns.0.xyz; f.y = 0
        let l = simd_length(f)
        return l > 1e-4 ? f / l : SIMD3(0, 0, -1)
    }

    /// Deadzone 0.1, then smoothstep-ish curve for fine control near center.
    private static func shape(_ v: Float) -> Float {
        let c = max(-1, min(1, v))
        let a = abs(c)
        guard a > 0.1 else { return 0 }
        let n = (a - 0.1) / 0.9
        return (c < 0 ? -1 : 1) * n * (0.4 + 0.6 * n)
    }
}

private extension SIMD4 where Scalar == Float {
    var xyz: SIMD3<Float> { SIMD3(x, y, z) }
}
#endif
