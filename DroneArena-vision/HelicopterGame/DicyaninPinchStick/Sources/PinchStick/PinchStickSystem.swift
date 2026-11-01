#if os(visionOS)
import RealityKit
import PinchStickCore

public struct PinchStickSystem: System {
    static let query = EntityQuery(where: .has(PinchStickComponent.self))
    static let fadeSeconds: Float = 0.12
    static let throwRadius: Float = 0.06
    nonisolated(unsafe) private static var registered = false

    public init(scene: Scene) {}

    /// Registers the component and system once per process.
    @MainActor public static func registerOnce() {
        guard !registered else { return }
        registered = true
        PinchStickComponent.registerComponent()
        PinchStickSystem.registerSystem()
    }

    public func update(context: SceneUpdateContext) {
        let step = Float(context.deltaTime) / Self.fadeSeconds
        for entity in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            guard var c = entity.components[PinchStickComponent.self], let p = c.parts else { continue }
            let target: Float = (c.held && c.visible) ? 1 : 0
            if c.alpha < target { c.alpha = min(target, c.alpha + step) }
            else if c.alpha > target { c.alpha = max(target, c.alpha - step) }

            entity.isEnabled = c.alpha > 0.001
            if entity.isEnabled {
                if c.held {
                    entity.position = c.origin
                    entity.orientation = simd_quatf(angle: c.yaw, axis: SIMD3(0, 1, 0))
                }
                let k = c.side == .left
                    ? SIMD3<Float>(c.knobPlane.x, c.knobPlane.y, 0)
                    : SIMD3<Float>(c.knobPlane.x, 0, -c.knobPlane.y)
                p.knob.position = k
                let len = simd_length(k)
                p.tether.isEnabled = len > 0.001
                if len > 0.001 {
                    let dir = k / len
                    p.tether.position = k * 0.5
                    p.tether.orientation = simd_quatf(from: SIMD3(0, 1, 0), to: dir)
                    p.tether.scale = SIMD3(1, len, 1)
                }
                let out = c.outsideDeadzone
                p.ring.components[OpacityComponent.self] = OpacityComponent(opacity: c.alpha * (out ? 0.6 : 0.35))
                p.deadRing.components[OpacityComponent.self] = OpacityComponent(opacity: c.alpha * 0.35)
                p.knob.components[OpacityComponent.self] = OpacityComponent(opacity: c.alpha * (out ? 1 : 0.6))
                p.tether.components[OpacityComponent.self] = OpacityComponent(opacity: c.alpha * 0.6)
            }
            entity.components[PinchStickComponent.self] = c
        }
    }
}
#endif
