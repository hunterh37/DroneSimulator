//
//  LowPolyMesh.swift
//  HelicopterGame
//
//  Faceted (flat-normal) procedural meshes + cached PBR materials for Safari.
//

import RealityKit
import UIKit
import simd

@MainActor
enum LowPolyMesh {
    private static var meshCache: [String: MeshResource] = [:]
    private static var materialCache: [String: PhysicallyBasedMaterial] = [:]

    // MARK: - Materials

    /// Soft stylized PBR: rough, slightly clearcoated so low-poly facets catch light realistically.
    static func material(_ color: UIColor, roughness: Float = 0.65, metallic: Float = 0, clearcoat: Float = 0.15, emissive: Float = 0) -> PhysicallyBasedMaterial {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        let key = "\(Int(r * 255))-\(Int(g * 255))-\(Int(b * 255))-\(roughness)-\(metallic)-\(clearcoat)-\(emissive)"
        if let cached = materialCache[key] { return cached }
        var m = PhysicallyBasedMaterial()
        m.baseColor = .init(tint: color)
        m.roughness = .init(floatLiteral: roughness)
        m.metallic = .init(floatLiteral: metallic)
        m.clearcoat = .init(floatLiteral: clearcoat)
        m.clearcoatRoughness = .init(floatLiteral: 0.4)
        if emissive > 0 {
            m.emissiveColor = .init(color: color)
            m.emissiveIntensity = emissive
        }
        materialCache[key] = m
        return m
    }

    // MARK: - Meshes

    /// Icosahedron with optional subdivision, flat shaded. `jitter` perturbs vertices for organic rocks/foliage.
    static func icosphere(radius: Float, subdivisions: Int = 1, jitter: Float = 0, seed: UInt64 = 0) -> MeshResource {
        let key = "ico-\(radius)-\(subdivisions)-\(jitter)-\(seed)"
        if let cached = meshCache[key] { return cached }

        let t: Float = (1 + sqrt(5)) / 2
        var verts: [SIMD3<Float>] = [
            [-1, t, 0], [1, t, 0], [-1, -t, 0], [1, -t, 0],
            [0, -1, t], [0, 1, t], [0, -1, -t], [0, 1, -t],
            [t, 0, -1], [t, 0, 1], [-t, 0, -1], [-t, 0, 1]
        ].map { normalize($0) }
        var faces: [SIMD3<Int>] = [
            [0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11],
            [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
            [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
            [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]
        ]
        for _ in 0..<max(0, subdivisions) {
            var mid: [Int64: Int] = [:]
            func midpoint(_ a: Int, _ b: Int) -> Int {
                let k = Int64(min(a, b)) << 32 | Int64(max(a, b))
                if let i = mid[k] { return i }
                verts.append(normalize((verts[a] + verts[b]) * 0.5))
                mid[k] = verts.count - 1
                return verts.count - 1
            }
            var next: [SIMD3<Int>] = []
            for f in faces {
                let ab = midpoint(f.x, f.y), bc = midpoint(f.y, f.z), ca = midpoint(f.z, f.x)
                next += [[f.x, ab, ca], [f.y, bc, ab], [f.z, ca, bc], [ab, bc, ca]]
            }
            faces = next
        }
        var rng = SplitMix(seed: seed &+ 1)
        verts = verts.map { v in
            let j = jitter > 0 ? 1 + Float.random(in: -jitter...jitter, using: &rng) : 1
            return v * radius * j
        }
        let mesh = flatMesh(verts: verts, faces: faces, name: key)
        meshCache[key] = mesh
        return mesh
    }

    /// Faceted cone / cylinder (topRadius 0 = cone). Base sits at y = 0.
    static func frustum(bottomRadius: Float, topRadius: Float, height: Float, segments: Int = 7) -> MeshResource {
        let key = "fr-\(bottomRadius)-\(topRadius)-\(height)-\(segments)"
        if let cached = meshCache[key] { return cached }
        var verts: [SIMD3<Float>] = []
        var faces: [SIMD3<Int>] = []
        for i in 0..<segments {
            let a = Float(i) / Float(segments) * 2 * .pi
            verts.append([cos(a) * bottomRadius, 0, sin(a) * bottomRadius])
            verts.append([cos(a) * topRadius, height, sin(a) * topRadius])
        }
        let bottomCenter = verts.count; verts.append([0, 0, 0])
        let topCenter = verts.count; verts.append([0, height, 0])
        for i in 0..<segments {
            let b0 = i * 2, t0 = i * 2 + 1
            let b1 = ((i + 1) % segments) * 2, t1 = b1 + 1
            faces.append([b0, t0, b1])
            if topRadius > 0 {
                faces.append([b1, t0, t1])
                faces.append([topCenter, t1, t0])
            }
            faces.append([bottomCenter, b0, b1])
        }
        let mesh = flatMesh(verts: verts, faces: faces, name: key, center: [0, height * 0.5, 0])
        meshCache[key] = mesh
        return mesh
    }

    /// Faceted terrain disc with gentle rolling hills. Center stays flat for the play spawn.
    static func terrain(radius: Float, rings: Int, segments: Int, heightFn: (Float, Float) -> Float) -> MeshResource {
        var verts: [SIMD3<Float>] = [[0, heightFn(0, 0), 0]]
        for r in 1...rings {
            let rr = radius * Float(r) / Float(rings)
            for s in 0..<segments {
                let a = Float(s) / Float(segments) * 2 * .pi + Float(r % 2) * (.pi / Float(segments))
                let x = cos(a) * rr, z = sin(a) * rr
                verts.append([x, heightFn(x, z), z])
            }
        }
        var faces: [SIMD3<Int>] = []
        for s in 0..<segments { faces.append([0, 1 + (s + 1) % segments, 1 + s]) }
        for r in 1..<rings {
            let inner = 1 + (r - 1) * segments, outer = 1 + r * segments
            for s in 0..<segments {
                let i0 = inner + s, i1 = inner + (s + 1) % segments
                let o0 = outer + s, o1 = outer + (s + 1) % segments
                faces.append([i0, i1, o0])
                faces.append([i1, o1, o0])
            }
        }
        return flatMesh(verts: verts, faces: faces, name: "terrain", center: nil)
    }

    /// Unwelded triangles with per-face normals (the low-poly look).
    /// Winding is corrected to face away from `center`, or upward when `center` is nil.
    private static func flatMesh(verts: [SIMD3<Float>], faces: [SIMD3<Int>], name: String, center: SIMD3<Float>? = .zero) -> MeshResource {
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        positions.reserveCapacity(faces.count * 3)
        normals.reserveCapacity(faces.count * 3)
        for f in faces {
            let a = verts[f.x]
            var b = verts[f.y], c = verts[f.z]
            var n = normalize(cross(b - a, c - a))
            let flip: Bool
            if let center { flip = dot(n, (a + b + c) / 3 - center) < 0 } else { flip = n.y < 0 }
            if flip { swap(&b, &c); n = -n }
            positions += [a, b, c]
            normals += [n, n, n]
        }
        var desc = MeshDescriptor(name: name)
        desc.positions = MeshBuffers.Positions(positions)
        desc.normals = MeshBuffers.Normals(normals)
        desc.primitives = .triangles((0..<UInt32(positions.count)).map { $0 })
        return (try? MeshResource.generate(from: [desc])) ?? .generateBox(size: 0.1)
    }
}

/// Deterministic RNG so world layout is identical every session.
struct SplitMix: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
