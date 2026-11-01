#if os(visionOS)
import RealityKit
import UIKit
import PinchStickCore

/// Written by the controller each update, consumed by `ThumbStickSystem`.
public struct ThumbStickComponent: Component {
    public var held = false
    public var origin = SIMD3<Float>.zero
    public var rotation = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
    public var knob = SIMD2<Float>.zero
    public var fullThrow: Float = 0.016
    public var visible = true
    public var alpha: Float = 0
    var pivot: Entity?
    var parts: [Entity] = []

    public init() {}
}

/// Miniature 3D gamepad thumbstick floating at the thumb rest point:
/// base disc, travel ring, tilting shaft and cap.
@MainActor
enum ThumbStickVisual {
    static let tiltMax: Float = 0.45

    static func make(side: StickSide, fullThrow: Float) -> Entity {
        let tint: UIColor = side == .left
            ? UIColor(red: 0.45, green: 0.75, blue: 1, alpha: 1)
            : UIColor(red: 1, green: 0.62, blue: 0.35, alpha: 1)
        let dark = SimpleMaterial(color: UIColor(white: 0.12, alpha: 1), roughness: 0.4, isMetallic: false)
        let metal = SimpleMaterial(color: UIColor(white: 0.7, alpha: 1), roughness: 0.25, isMetallic: true)
        let cap = SimpleMaterial(color: tint, roughness: 0.35, isMetallic: false)
        var glow = UnlitMaterial(color: tint)
        glow.faceCulling = .none

        let r = fullThrow + 0.004
        let base = ModelEntity(mesh: .generateCylinder(height: 0.002, radius: r), materials: [dark])
        base.position.y = -0.001
        let ring = ModelEntity(mesh: .generateCylinder(height: 0.0024, radius: r + 0.0008), materials: [glow])
        ring.position.y = -0.0012
        let well = ModelEntity(mesh: .generateSphere(radius: 0.005), materials: [metal])
        well.scale = SIMD3(1, 0.5, 1)

        let pivot = Entity()
        let shaft = ModelEntity(mesh: .generateCylinder(height: 0.012, radius: 0.0018), materials: [metal])
        shaft.position.y = 0.006
        let head = ModelEntity(mesh: .generateCylinder(height: 0.004, radius: 0.0075), materials: [cap])
        head.position.y = 0.013
        let rim = ModelEntity(mesh: .generateCylinder(height: 0.0045, radius: 0.0079), materials: [dark])
        rim.position.y = 0.0128
        pivot.addChild(shaft)
        pivot.addChild(rim)
        pivot.addChild(head)

        let container = Entity()
        container.name = side == .left ? "ThumbStickLeft" : "ThumbStickRight"
        for e in [ring, base, well] { container.addChild(e) }
        container.addChild(pivot)

        var c = ThumbStickComponent()
        c.fullThrow = fullThrow
        c.pivot = pivot
        c.parts = [ring, base, well, shaft, rim, head]
        container.components.set(c)
        container.isEnabled = false
        return container
    }
}

public struct ThumbStickSystem: System {
    static let query = EntityQuery(where: .has(ThumbStickComponent.self))
    nonisolated(unsafe) private static var registered = false

    public init(scene: Scene) {}

    @MainActor public static func registerOnce() {
        guard !registered else { return }
        registered = true
        ThumbStickComponent.registerComponent()
        ThumbStickSystem.registerSystem()
    }

    public func update(context: SceneUpdateContext) {
        let step = Float(context.deltaTime) / 0.12
        for entity in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            guard var c = entity.components[ThumbStickComponent.self], let pivot = c.pivot else { continue }
            let target: Float = (c.held && c.visible) ? 1 : 0
            c.alpha = c.alpha < target ? min(target, c.alpha + step) : max(target, c.alpha - step)
            entity.isEnabled = c.alpha > 0.001
            if entity.isEnabled {
                if c.held {
                    entity.position = c.origin
                    entity.orientation = c.rotation
                }
                // Knob plane x = right, y = forward (-Z). Tilt the shaft toward it.
                let k = SIMD3<Float>(c.knob.x, 0, -c.knob.y)
                let len = simd_length(k)
                if len > 1e-5 {
                    let axis = simd_normalize(simd_cross(SIMD3(0, 1, 0), k / len))
                    let angle = min(len / max(c.fullThrow, 1e-5), 1) * ThumbStickVisual.tiltMax
                    pivot.orientation = simd_quatf(angle: angle, axis: axis)
                } else {
                    pivot.orientation = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
                }
                let o = OpacityComponent(opacity: c.alpha)
                for p in c.parts { p.components[OpacityComponent.self] = o }
            }
            entity.components[ThumbStickComponent.self] = c
        }
    }
}
#endif
