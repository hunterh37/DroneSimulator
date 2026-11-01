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
    public var visualsEnabled = true {
        didSet { applyVisible() }
    }

    private let session = ARKitSession()
    private let hands = HandTrackingProvider()
    private let world = WorldTrackingProvider()
    private var task: Task<Void, Never>?
    private var left = PinchStickMachine(side: .left)
    private var right = PinchStickMachine(side: .right)
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

        let l = PinchStickVisual.make(side: .left, config: config)
        let r = PinchStickVisual.make(side: .right, config: config)
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

    private func applyVisible() {
        for e in [leftEntity, rightEntity] {
            guard let e, var c = e.components[PinchStickComponent.self] else { continue }
            c.visible = visualsEnabled
            e.components[PinchStickComponent.self] = c
        }
    }

    private func emit(_ out: PinchStickOutput) {
        guard out != last else { return }
        last = out
        onOutput?(out)
    }
}
#endif
