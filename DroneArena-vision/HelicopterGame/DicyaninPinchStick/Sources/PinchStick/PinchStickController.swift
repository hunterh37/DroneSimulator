#if os(visionOS)
import ARKit
import RealityKit
import QuartzCore
import PinchStickCore

/// Reads hand tracking, runs the pinch-stick machines and drives the visual.
/// Requires an open ImmersiveSpace and hand tracking authorization.
/// `rootEntity` must sit at the immersive space origin (identity transform).
@MainActor
public final class PinchStickController {
    public var onOutput: ((PinchStickOutput) -> Void)?
    public var config = PinchStickConfig()
    public var thumbConfig = ThumbStickConfig()
    /// Pinch-drag sticks or thumb-on-index thumbsticks. Applies on next start.
    public var mode: StickMode = .pinch
    public var visualsEnabled = true {
        didSet { applyVisible() }
    }

    private let session = ARKitSession()
    private let hands = HandTrackingProvider()
    private let world = WorldTrackingProvider()
    private var task: Task<Void, Never>?
    private var left = PinchStickMachine(side: .left)
    private var right = PinchStickMachine(side: .right)
    private var thumbL = ThumbStickMachine(side: .left)
    private var thumbR = ThumbStickMachine(side: .right)
    private var leftEntity: Entity?
    private var rightEntity: Entity?
    private var last = PinchStickOutput.zero
    private var lastYaw: Float = 0

    public init() {}

    public func start(rootEntity: Entity) async {
        stop()
        PinchStickSystem.registerOnce()
        left = PinchStickMachine(side: .left, config: config)
        right = PinchStickMachine(side: .right, config: config)

        ThumbStickSystem.registerOnce()
        thumbL = ThumbStickMachine(side: .left, config: thumbConfig)
        thumbR = ThumbStickMachine(side: .right, config: thumbConfig)
        let thumb = mode == .thumb
        let l = thumb ? ThumbStickVisual.make(side: .left, fullThrow: thumbConfig.fullThrow)
                      : PinchStickVisual.make(side: .left, config: config)
        let r = thumb ? ThumbStickVisual.make(side: .right, fullThrow: thumbConfig.fullThrow)
                      : PinchStickVisual.make(side: .right, config: config)
        applyVisible(l, r)
        rootEntity.addChild(l)
        rootEntity.addChild(r)
        leftEntity = l
        rightEntity = r

        do {
            try await session.run([hands, world])
        } catch {
            emit(.zero)
            return
        }
        task = Task { [weak self] in
            while !Task.isCancelled {
                self?.tick()
                try? await Task.sleep(for: .milliseconds(11))
            }
        }
    }

    public func stop() {
        task?.cancel()
        task = nil
        session.stop()
        leftEntity?.removeFromParent()
        rightEntity?.removeFromParent()
        leftEntity = nil
        rightEntity = nil
        left.update(sample: nil, headYaw: 0)
        right.update(sample: nil, headYaw: 0)
        emit(.zero)
    }

    private func tick() {
        let now = CACurrentMediaTime()
        if let device = world.queryDeviceAnchor(atTimestamp: now) {
            let m = device.originFromAnchorTransform
            let fwd = SIMD3<Float>(-m.columns.2.x, -m.columns.2.y, -m.columns.2.z)
            if simd_length(SIMD2(fwd.x, fwd.z)) > 0.1 { lastYaw = StickMapping.yaw(forward: fwd) }
        }
        let anchors = hands.latestAnchors
        if mode == .thumb {
            let ls = thumbL.update(sample: thumbSample(anchors.leftHand, now))
            let rs = thumbR.update(sample: thumbSample(anchors.rightHand, now))
            pushThumb(ls, to: leftEntity)
            pushThumb(rs, to: rightEntity)
            emit(PinchStickOutput(left: ls.output, right: rs.output, leftHeld: ls.held, rightHeld: rs.held))
            return
        }
        let ls = left.update(sample: sample(anchors.leftHand, now), headYaw: lastYaw)
        let rs = right.update(sample: sample(anchors.rightHand, now), headYaw: lastYaw)
        push(ls, to: leftEntity, config: left.config)
        push(rs, to: rightEntity, config: right.config)
        emit(PinchStickOutput(left: ls.output, right: rs.output, leftHeld: ls.held, rightHeld: rs.held))
    }

    private func sample(_ anchor: HandAnchor?, _ time: Double) -> PinchSample? {
        guard let anchor, anchor.isTracked, let skel = anchor.handSkeleton else { return nil }
        let thumb = skel.joint(.thumbTip), index = skel.joint(.indexFingerTip)
        guard thumb.isTracked, index.isTracked else { return nil }
        let t = anchor.originFromAnchorTransform * thumb.anchorFromJointTransform
        let i = anchor.originFromAnchorTransform * index.anchorFromJointTransform
        return PinchSample(thumbTip: SIMD3(t.columns.3.x, t.columns.3.y, t.columns.3.z),
                           indexTip: SIMD3(i.columns.3.x, i.columns.3.y, i.columns.3.z),
                           time: time)
    }

    private func push(_ s: PinchStickState, to entity: Entity?, config: PinchStickConfig) {
        guard let entity, var c = entity.components[PinchStickComponent.self] else { return }
        c.held = s.held
        if s.held {
            c.origin = s.origin
            c.yaw = s.yaw
            c.knobPlane = s.knobPlane
            c.outsideDeadzone = simd_length(s.knobPlane) > config.deadzone
        }
        entity.components[PinchStickComponent.self] = c
    }

    private func applyVisible() { applyVisible(leftEntity, rightEntity) }

    private func applyVisible(_ es: Entity?...) {
        for e in es {
            guard let e else { continue }
            if var c = e.components[PinchStickComponent.self] {
                c.visible = visualsEnabled
                e.components[PinchStickComponent.self] = c
            }
            if var c = e.components[ThumbStickComponent.self] {
                c.visible = visualsEnabled
                e.components[ThumbStickComponent.self] = c
            }
        }
    }

    private func thumbSample(_ anchor: HandAnchor?, _ time: Double) -> ThumbSample? {
        guard let anchor, anchor.isTracked, let skel = anchor.handSkeleton else { return nil }
        func p(_ j: HandSkeleton.JointName) -> SIMD3<Float>? {
            let joint = skel.joint(j)
            guard joint.isTracked else { return nil }
            let m = anchor.originFromAnchorTransform * joint.anchorFromJointTransform
            return SIMD3(m.columns.3.x, m.columns.3.y, m.columns.3.z)
        }
        guard let t = p(.thumbTip), let mid = p(.indexFingerIntermediateBase),
              let k = p(.indexFingerKnuckle), let w = p(.wrist) else { return nil }
        return ThumbSample(thumbTip: t, indexMiddle: mid, indexKnuckle: k, wrist: w, time: time)
    }

    private func pushThumb(_ s: ThumbStickState, to entity: Entity?) {
        guard let entity, var c = entity.components[ThumbStickComponent.self] else { return }
        c.held = s.held
        if s.held {
            c.origin = s.origin
            c.rotation = s.rotation
            c.knob = s.knobPlane
        }
        entity.components[ThumbStickComponent.self] = c
    }

    private func emit(_ out: PinchStickOutput) {
        guard out != last else { return }
        last = out
        onOutput?(out)
    }
}
#endif
