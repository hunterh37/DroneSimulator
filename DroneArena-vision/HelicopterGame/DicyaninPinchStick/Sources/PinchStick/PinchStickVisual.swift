#if os(visionOS)
import RealityKit
import PinchStickCore

/// Builds the container entity for one stick. Called once at start.
@MainActor
enum PinchStickVisual {
    static func make(side: StickSide, config: PinchStickConfig) -> Entity {
        let mat = UnlitMaterial(color: .white)
        var ringMat = mat
        ringMat.faceCulling = .none

        let container = Entity()
        container.name = side == .left ? "PinchStickLeft" : "PinchStickRight"

        let throwMesh = ringMesh(radius: config.fullThrow, width: 0.0015)
        let deadMesh = ringMesh(radius: config.deadzone, width: 0.0008)
        let ring = ModelEntity(mesh: throwMesh, materials: [ringMat])
        let dead = ModelEntity(mesh: deadMesh, materials: [ringMat])
        let knob = ModelEntity(mesh: .generateSphere(radius: 0.007), materials: [mat])
        let tether = ModelEntity(mesh: .generateCylinder(height: 1, radius: 0.0012), materials: [mat])

        // Ring meshes lie in XZ. The left stick stands vertical, so rotate into XY.
        let flat = Entity()
        if side == .left { flat.orientation = simd_quatf(angle: .pi / 2, axis: SIMD3(1, 0, 0)) }
        flat.addChild(ring)
        flat.addChild(dead)
        container.addChild(flat)
        container.addChild(knob)
        container.addChild(tether)

        var c = PinchStickComponent()
        c.side = side
        c.parts = PinchStickParts(ring: ring, deadRing: dead, knob: knob, tether: tether)
        container.components.set(c)
        container.isEnabled = false
        return container
    }

    /// Flat annulus in the XZ plane, 48 segments.
    private static func ringMesh(radius: Float, width: Float) -> MeshResource {
        let n = 48
        var positions: [SIMD3<Float>] = []
        var indices: [UInt32] = []
        for i in 0..<n {
            let a = Float(i) / Float(n) * 2 * .pi
            let (s, c) = (sin(a), cos(a))
            positions.append(SIMD3(c * (radius - width), 0, s * (radius - width)))
            positions.append(SIMD3(c * (radius + width), 0, s * (radius + width)))
        }
        for i in 0..<n {
            let a = UInt32(i * 2), b = a + 1
            let c = UInt32(((i + 1) % n) * 2), d = c + 1
            indices += [a, b, c, b, d, c]
        }
        var desc = MeshDescriptor(name: "PinchRing")
        desc.positions = MeshBuffer(positions)
        desc.primitives = .triangles(indices)
        return try! MeshResource.generate(from: [desc])
    }
}
#endif
