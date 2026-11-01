//
//  RaceArenaBuilder.swift
//  HelicopterGame
//
//  Life-size esports drone stadium: floor, racing-line lights, square FPV gates,
//  start/finish arch, grandstands with a low-poly crowd, light towers and banners.
//  Static geometry is baked per material into a handful of meshes (few draw calls).
//

import RealityKit
import UIKit
import simd

@MainActor
struct RaceArena {
    let root: Entity
    let gateGlows: [ModelEntity]
    let nextGateBeacon: Entity
    /// Local grid slot positions + facing (yaw) behind the start gate.
    let gridSlots: [(position: SIMD3<Float>, yaw: Float)]
}

@MainActor
enum RaceArenaBuilder {
    static let floorColor = UIColor(red: 0.07, green: 0.08, blue: 0.11, alpha: 1)
    static let gateIdle = UIColor(red: 0.25, green: 0.55, blue: 1.0, alpha: 1)
    static let gateNext = UIColor(red: 0.2, green: 1.0, blue: 0.45, alpha: 1)
    static let gateStart = UIColor(red: 1.0, green: 0.25, blue: 0.35, alpha: 1)

    private static var glowCache: [String: UnlitMaterial] = [:]

    static func glow(_ color: UIColor, _ intensity: Float = 1) -> UnlitMaterial {
        let key = "\(color.hashValue)-\(intensity)"
        if let m = glowCache[key] { return m }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        let k = CGFloat(intensity)
        let m = UnlitMaterial(color: UIColor(red: min(1, r * k), green: min(1, g * k), blue: min(1, b * k), alpha: 1))
        glowCache[key] = m
        return m
    }

    static func build(track: RaceTrack) -> RaceArena {
        let root = Entity()
        root.name = "RaceArena.\(track.id.rawValue)"

        let b = track.bounds
        let center = (b.min + b.max) * 0.5
        let half = SIMD2<Float>((b.max.x - b.min.x) * 0.5 + 6, (b.max.z - b.min.z) * 0.5 + 6)

        root.addChild(makeLights(center: center))
        root.addChild(makeFloor(center: center, half: half))
        root.addChild(makeRacingLine(track))
        makeStands(center: center, half: half).forEach { root.addChild($0) }
        root.addChild(makeTowers(center: center, half: half))

        var glows: [ModelEntity] = []
        for gate in track.gates {
            let (frame, glowStrip) = makeGate(gate, isStart: gate.index == 0)
            root.addChild(frame)
            glows.append(glowStrip)
        }
        root.addChild(makeStartArch(track.gates[0]))

        let beacon = makeBeacon()
        root.addChild(beacon)

        // 2 x 4 staggered grid behind start gate, facing along the start tangent.
        let g0 = track.gates[0]
        let fwd = simd_normalize(SIMD3(g0.forward.x, 0, g0.forward.z))
        let right = simd_normalize(simd_cross(fwd, [0, 1, 0]))
        let yaw = atan2(-fwd.x, -fwd.z)
        var slots: [(SIMD3<Float>, Float)] = []
        for i in 0..<8 {
            let row = Float(i / 2), col: Float = i % 2 == 0 ? -0.55 : 0.55
            var p = g0.position - fwd * (1.6 + row * 0.9 + (i % 2 == 0 ? 0 : 0.45)) + right * col
            p.y = 0.32
            slots.append((p, yaw))
            root.addChild(makeGridPad(at: p, yaw: yaw, number: i + 1))
        }
        return RaceArena(root: root, gateGlows: glows, nextGateBeacon: beacon, gridSlots: slots)
    }

    // MARK: - Lighting

    private static func makeLights(center: SIMD3<Float>) -> Entity {
        let rig = Entity()
        let key = Entity()
        key.components.set(DirectionalLightComponent(color: UIColor(red: 0.9, green: 0.94, blue: 1, alpha: 1), intensity: 2600))
        key.components.set(DirectionalLightComponent.Shadow(maximumDistance: 40, depthBias: 2))
        key.look(at: center, from: center + [10, 22, 8], relativeTo: nil)
        rig.addChild(key)
        return rig
    }

    // MARK: - Floor + racing line

    private static func makeFloor(center: SIMD3<Float>, half: SIMD2<Float>) -> Entity {
        let e = Entity()
        var floorMat = PhysicallyBasedMaterial()
        floorMat.baseColor = .init(tint: floorColor)
        floorMat.roughness = 0.35
        floorMat.metallic = 0.2
        floorMat.clearcoat = 0.7
        let floor = ModelEntity(mesh: .generatePlane(width: half.x * 2, depth: half.y * 2), materials: [floorMat])
        floor.position = [center.x, 0.001, center.z]
        e.addChild(floor)

        // Grid lines baked into one mesh
        var grid = TriSoup()
        let step: Float = 2
        var x = -half.x
        while x <= half.x {
            grid.append(LowPolyGeometry.box([0.02, 0.002, half.y * 2]), transform: LowPolyGeometry.matrix(position: [center.x + x, 0.004, center.z], euler: .zero))
            x += step
        }
        var z = -half.y
        while z <= half.y {
            grid.append(LowPolyGeometry.box([half.x * 2, 0.002, 0.02]), transform: LowPolyGeometry.matrix(position: [center.x, 0.004, center.z + z], euler: .zero))
            z += step
        }
        if let mesh = mesh(grid) {
            e.addChild(ModelEntity(mesh: mesh, materials: [glow(UIColor(red: 0.15, green: 0.3, blue: 0.6, alpha: 1), 0.55)]))
        }
        return e
    }

    private static func makeRacingLine(_ track: RaceTrack) -> Entity {
        var dots = TriSoup()
        var s: Float = 0
        let dot = LowPolyGeometry.box([0.22, 0.006, 0.06])
        while s < track.length {
            var p = track.position(at: s)
            let t = track.tangent(at: s)
            p.y = 0.006
            dots.append(dot, transform: LowPolyGeometry.matrix(position: p, euler: [0, atan2(t.x, t.z) + .pi / 2, 0]))
            s += 1.2
        }
        let e = Entity()
        if let mesh = mesh(dots) {
            e.addChild(ModelEntity(mesh: mesh, materials: [glow(UIColor(red: 0.3, green: 0.9, blue: 1, alpha: 1), 0.8)]))
        }
        return e
    }

    // MARK: - Gates

    private static func makeGate(_ gate: RaceGate, isStart: Bool) -> (Entity, ModelEntity) {
        let e = Entity()
        e.name = "RaceGate_\(gate.index)"
        e.position = gate.position
        let flat = simd_normalize(SIMD3(gate.forward.x, 0, gate.forward.z))
        e.orientation = simd_quatf(angle: atan2(-flat.x, -flat.z), axis: [0, 1, 0])

        let h = gate.halfSize, pad: Float = 0.09
        var frame = TriSoup()
        frame.append(LowPolyGeometry.box([h * 2 + pad * 2, pad, pad]), transform: LowPolyGeometry.matrix(position: [0, h + pad / 2, 0], euler: .zero))
        frame.append(LowPolyGeometry.box([h * 2 + pad * 2, pad, pad]), transform: LowPolyGeometry.matrix(position: [0, -h - pad / 2, 0], euler: .zero))
        frame.append(LowPolyGeometry.box([pad, h * 2, pad]), transform: LowPolyGeometry.matrix(position: [h + pad / 2, 0, 0], euler: .zero))
        frame.append(LowPolyGeometry.box([pad, h * 2, pad]), transform: LowPolyGeometry.matrix(position: [-h - pad / 2, 0, 0], euler: .zero))
        // Support legs to floor
        let legH = max(0.05, gate.position.y - h - pad)
        for side: Float in [-1, 1] {
            frame.append(LowPolyGeometry.frustum(bottom: 0.03, top: 0.025, height: legH, segments: 6),
                         transform: LowPolyGeometry.matrix(position: [side * (h + pad / 2), -h - pad - legH / 2, 0], euler: .zero))
            frame.append(LowPolyGeometry.box([0.28, 0.03, 0.28]), transform: LowPolyGeometry.matrix(position: [side * (h + pad / 2), -gate.position.y + 0.015, 0], euler: .zero))
        }
        var padMat = PhysicallyBasedMaterial()
        padMat.baseColor = .init(tint: UIColor(white: 0.12, alpha: 1))
        padMat.roughness = 0.6
        if let m = mesh(frame) { e.addChild(ModelEntity(mesh: m, materials: [padMat])) }

        // Inner glow strip (swapped when this is the next gate)
        var strip = TriSoup()
        let t: Float = 0.025, inset = h - t / 2
        strip.append(LowPolyGeometry.box([h * 2, t, t]), transform: LowPolyGeometry.matrix(position: [0, inset, 0], euler: .zero))
        strip.append(LowPolyGeometry.box([h * 2, t, t]), transform: LowPolyGeometry.matrix(position: [0, -inset, 0], euler: .zero))
        strip.append(LowPolyGeometry.box([t, h * 2, t]), transform: LowPolyGeometry.matrix(position: [inset, 0, 0], euler: .zero))
        strip.append(LowPolyGeometry.box([t, h * 2, t]), transform: LowPolyGeometry.matrix(position: [-inset, 0, 0], euler: .zero))
        let glowEntity = ModelEntity(mesh: mesh(strip) ?? .generateBox(size: 0.01), materials: [glow(isStart ? gateStart : gateIdle)])
        e.addChild(glowEntity)
        return (e, glowEntity)
    }

    private static func makeStartArch(_ gate: RaceGate) -> Entity {
        let e = Entity()
        e.position = [gate.position.x, 0, gate.position.z]
        let flat = simd_normalize(SIMD3(gate.forward.x, 0, gate.forward.z))
        e.orientation = simd_quatf(angle: atan2(-flat.x, -flat.z), axis: [0, 1, 0])
        let top = gate.position.y + gate.halfSize + 0.6
        var dark = TriSoup(), white = TriSoup()
        for side: Float in [-1, 1] {
            dark.append(LowPolyGeometry.box([0.16, top, 0.16]), transform: LowPolyGeometry.matrix(position: [side * 1.5, top / 2, 0.4], euler: .zero))
        }
        dark.append(LowPolyGeometry.box([3.16, 0.32, 0.12]), transform: LowPolyGeometry.matrix(position: [0, top, 0.4], euler: .zero))
        // Checkered banner
        for i in 0..<16 {
            for j in 0..<2 {
                let cell = LowPolyGeometry.box([0.18, 0.13, 0.02])
                let m = LowPolyGeometry.matrix(position: [-1.35 + Float(i) * 0.18, top - 0.07 + Float(j) * 0.14, 0.33], euler: .zero)
                if (i + j) % 2 == 0 { white.append(cell, transform: m) } else { dark.append(cell, transform: m) }
            }
        }
        // Checkered start line on floor
        for i in 0..<12 {
            for j in 0..<2 {
                let cell = LowPolyGeometry.box([0.25, 0.004, 0.2])
                let m = LowPolyGeometry.matrix(position: [-1.375 + Float(i) * 0.25, 0.008, -0.1 + Float(j) * 0.2], euler: .zero)
                if (i + j) % 2 == 0 { white.append(cell, transform: m) }
            }
        }
        var darkMat = PhysicallyBasedMaterial()
        darkMat.baseColor = .init(tint: UIColor(white: 0.08, alpha: 1))
        darkMat.roughness = 0.4
        if let m = mesh(dark) { e.addChild(ModelEntity(mesh: m, materials: [darkMat])) }
        if let m = mesh(white) { e.addChild(ModelEntity(mesh: m, materials: [glow(.white, 0.95)])) }
        return e
    }

    private static func makeGridPad(at p: SIMD3<Float>, yaw: Float, number: Int) -> Entity {
        let pad = ModelEntity(mesh: .generateBox(width: 0.42, height: 0.01, depth: 0.42, cornerRadius: 0.02),
                              materials: [glow(number == 1 ? gateStart : UIColor(white: 0.5, alpha: 1), 0.5)])
        pad.position = [p.x, 0.006, p.z]
        pad.orientation = simd_quatf(angle: yaw, axis: [0, 1, 0])
        return pad
    }

    private static func makeBeacon() -> Entity {
        let e = Entity()
        e.name = "NextGateBeacon"
        let arrow = ModelEntity(mesh: mesh(LowPolyGeometry.frustum(bottom: 0.14, top: 0, height: 0.26, segments: 4)) ?? .generateBox(size: 0.1),
                                materials: [glow(gateNext)])
        arrow.orientation = simd_quatf(angle: .pi, axis: [1, 0, 0])
        e.addChild(arrow)
        return e
    }

    // MARK: - Stadium

    private static func makeStands(center: SIMD3<Float>, half: SIMD2<Float>) -> [Entity] {
        var structure = TriSoup()
        var crowd: [TriSoup] = Array(repeating: TriSoup(), count: 5)
        var rng = SplitMix(seed: 0xDA7E)
        let tiers = 5
        let sides: [(SIMD3<Float>, Float, Float)] = [
            ([center.x, 0, center.z - half.y - 1.5], 0, half.x * 2),
            ([center.x - half.x - 1.5, 0, center.z], .pi / 2, half.y * 2),
            ([center.x + half.x + 1.5, 0, center.z], -.pi / 2, half.y * 2)
        ]
        for (origin, yaw, width) in sides {
            let rot = simd_quatf(angle: yaw, axis: [0, 1, 0])
            for tier in 0..<tiers {
                let y = Float(tier) * 0.5 + 0.25, back = Float(tier) * 0.7
                let local = SIMD3<Float>(0, y, -back)
                structure.append(LowPolyGeometry.box([width, 0.5, 0.7]),
                                 transform: LowPolyGeometry.matrix(position: origin + rot.act(local), euler: [0, yaw, 0]))
                var x = -width / 2 + 0.4
                while x < width / 2 - 0.4 {
                    if Float.random(in: 0...1, using: &rng) < 0.78 {
                        let bucket = Int.random(in: 0..<crowd.count, using: &rng)
                        let hgt = Float.random(in: 0.32...0.42, using: &rng)
                        let fan = SIMD3<Float>(x, y + 0.25 + hgt / 2, -back + 0.05)
                        crowd[bucket].append(LowPolyGeometry.box([0.2, hgt, 0.16]),
                                             transform: LowPolyGeometry.matrix(position: origin + rot.act(fan), euler: [0, yaw, 0]))
                        crowd[bucket].append(LowPolyGeometry.ico(radius: 0.085, subdivisions: 0),
                                             transform: LowPolyGeometry.matrix(position: origin + rot.act(fan + [0, hgt / 2 + 0.09, 0]), euler: .zero))
                    }
                    x += 0.34
                }
            }
        }
        var out: [Entity] = []
        var standMat = PhysicallyBasedMaterial()
        standMat.baseColor = .init(tint: UIColor(red: 0.16, green: 0.18, blue: 0.24, alpha: 1))
        standMat.roughness = 0.7
        if let m = mesh(structure) { out.append(ModelEntity(mesh: m, materials: [standMat])) }
        let crowdColors: [UIColor] = [.systemRed, .systemBlue, .systemYellow, .white, .systemTeal]
        for (i, soup) in crowd.enumerated() {
            guard let m = mesh(soup) else { continue }
            var mat = PhysicallyBasedMaterial()
            mat.baseColor = .init(tint: crowdColors[i])
            mat.roughness = 0.8
            out.append(ModelEntity(mesh: m, materials: [mat]))
        }
        return out
    }

    private static func makeTowers(center: SIMD3<Float>, half: SIMD2<Float>) -> Entity {
        var poles = TriSoup(), lamps = TriSoup()
        let corners: [SIMD2<Float>] = [[-1, -1], [1, -1], [-1, 1], [1, 1]]
        for c in corners {
            let base = SIMD3<Float>(center.x + c.x * (half.x + 0.5), 0, center.z + c.y * (half.y + 0.5))
            poles.append(LowPolyGeometry.frustum(bottom: 0.18, top: 0.1, height: 7, segments: 6), transform: LowPolyGeometry.matrix(position: base + [0, 3.5, 0], euler: .zero))
            poles.append(LowPolyGeometry.box([1.4, 0.8, 0.2]), transform: LowPolyGeometry.matrix(position: base + [0, 7.2, 0], euler: [0.5 * c.y, atan2(c.x, c.y), 0]))
            for i in 0..<3 {
                for j in 0..<2 {
                    lamps.append(LowPolyGeometry.box([0.34, 0.26, 0.05]),
                                 transform: LowPolyGeometry.matrix(position: base + [0, 7.2, 0] + simd_quatf(angle: atan2(c.x, c.y), axis: [0, 1, 0]).act([Float(i - 1) * 0.42, Float(j) * 0.3 - 0.15, -0.12]),
                                                                   euler: [0.5 * c.y, atan2(c.x, c.y), 0]))
                }
            }
        }
        let e = Entity()
        var poleMat = PhysicallyBasedMaterial()
        poleMat.baseColor = .init(tint: UIColor(white: 0.55, alpha: 1))
        poleMat.metallic = 1.0
        poleMat.roughness = 0.35
        if let m = mesh(poles) { e.addChild(ModelEntity(mesh: m, materials: [poleMat])) }
        if let m = mesh(lamps) { e.addChild(ModelEntity(mesh: m, materials: [glow(UIColor(red: 1, green: 0.97, blue: 0.9, alpha: 1))])) }
        return e
    }

    static func mesh(_ soup: TriSoup) -> MeshResource? {
        guard !soup.isEmpty else { return nil }
        var d = MeshDescriptor(name: "arena")
        d.positions = MeshBuffers.Positions(soup.positions)
        d.normals = MeshBuffers.Normals(soup.normals)
        d.primitives = .triangles((0..<UInt32(soup.positions.count)).map { $0 })
        return try? MeshResource.generate(from: [d])
    }
}
