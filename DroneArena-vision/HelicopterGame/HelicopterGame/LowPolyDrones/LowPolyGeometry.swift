//
//  LowPolyGeometry.swift
//  HelicopterGame
//
//  CPU-side flat-shaded triangle soups for drone parts. Parts are baked per material
//  role into a single mesh so each drone is 1 static ModelEntity + 1 entity per rotor.
//

import Foundation
import simd

struct TriSoup {
    var positions: [SIMD3<Float>] = []
    var normals: [SIMD3<Float>] = []

    var isEmpty: Bool { positions.isEmpty }

    mutating func tri(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>, outward: SIMD3<Float>? = nil) {
        var b = b, c = c
        var n = cross(b - a, c - a)
        let len = length(n)
        guard len > 1e-9 else { return }
        n /= len
        if let o = outward, dot(n, o) < 0 { swap(&b, &c); n = -n }
        positions += [a, b, c]
        normals += [n, n, n]
    }

    mutating func quad(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>, _ d: SIMD3<Float>, outward: SIMD3<Float>) {
        tri(a, b, c, outward: outward)
        tri(a, c, d, outward: outward)
    }

    mutating func append(_ other: TriSoup, transform: simd_float4x4) {
        let rot = simd_float3x3(SIMD3(transform.columns.0.x, transform.columns.0.y, transform.columns.0.z),
                                SIMD3(transform.columns.1.x, transform.columns.1.y, transform.columns.1.z),
                                SIMD3(transform.columns.2.x, transform.columns.2.y, transform.columns.2.z))
        positions.reserveCapacity(positions.count + other.positions.count)
        for p in other.positions {
            let w = transform * SIMD4(p, 1)
            positions.append(SIMD3(w.x, w.y, w.z))
        }
        for n in other.normals { normals.append(normalize(rot * n)) }
    }
}

enum LowPolyGeometry {
    static func matrix(position: SIMD3<Float>, euler: SIMD3<Float>) -> simd_float4x4 {
        let q = simd_quatf(angle: euler.y, axis: [0, 1, 0])
            * simd_quatf(angle: euler.x, axis: [1, 0, 0])
            * simd_quatf(angle: euler.z, axis: [0, 0, 1])
        var m = simd_float4x4(q)
        m.columns.3 = SIMD4(position, 1)
        return m
    }

    static func box(_ s: SIMD3<Float>) -> TriSoup {
        var t = TriSoup()
        let h = s * 0.5
        let v: [SIMD3<Float>] = [
            [-h.x, -h.y, -h.z], [h.x, -h.y, -h.z], [h.x, h.y, -h.z], [-h.x, h.y, -h.z],
            [-h.x, -h.y, h.z], [h.x, -h.y, h.z], [h.x, h.y, h.z], [-h.x, h.y, h.z]
        ]
        t.quad(v[0], v[1], v[2], v[3], outward: [0, 0, -1])
        t.quad(v[5], v[4], v[7], v[6], outward: [0, 0, 1])
        t.quad(v[4], v[0], v[3], v[7], outward: [-1, 0, 0])
        t.quad(v[1], v[5], v[6], v[2], outward: [1, 0, 0])
        t.quad(v[3], v[2], v[6], v[7], outward: [0, 1, 0])
        t.quad(v[4], v[5], v[1], v[0], outward: [0, -1, 0])
        return t
    }

    static func frustum(bottom: Float, top: Float, height: Float, segments: Int) -> TriSoup {
        var t = TriSoup()
        let y0 = -height * 0.5, y1 = height * 0.5
        let n = max(3, segments)
        for i in 0..<n {
            let a0 = Float(i) / Float(n) * 2 * .pi, a1 = Float(i + 1) / Float(n) * 2 * .pi
            let d0 = SIMD3<Float>(cos(a0), 0, sin(a0)), d1 = SIMD3<Float>(cos(a1), 0, sin(a1))
            let b0 = d0 * bottom + [0, y0, 0], b1 = d1 * bottom + [0, y0, 0]
            let t0 = d0 * top + [0, y1, 0], t1 = d1 * top + [0, y1, 0]
            let out = normalize(d0 + d1)
            t.tri(b0, b1, t1, outward: out)
            if top > 0 { t.tri(b0, t1, t0, outward: out) }
            t.tri([0, y0, 0], b0, b1, outward: [0, -1, 0])
            if top > 0 { t.tri([0, y1, 0], t0, t1, outward: [0, 1, 0]) }
        }
        return t
    }

    static func ico(radius: Float, subdivisions: Int) -> TriSoup {
        let g: Float = (1 + sqrt(5)) / 2
        var verts: [SIMD3<Float>] = [
            [-1, g, 0], [1, g, 0], [-1, -g, 0], [1, -g, 0],
            [0, -1, g], [0, 1, g], [0, -1, -g], [0, 1, -g],
            [g, 0, -1], [g, 0, 1], [-g, 0, -1], [-g, 0, 1]
        ].map { normalize($0) }
        var faces: [SIMD3<Int>] = [
            [0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11],
            [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
            [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
            [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]
        ]
        for _ in 0..<max(0, subdivisions) {
            var mid: [Int: Int] = [:]
            func midpoint(_ a: Int, _ b: Int) -> Int {
                let k = min(a, b) << 20 | max(a, b)
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
        var t = TriSoup()
        for f in faces {
            let a = verts[f.x] * radius, b = verts[f.y] * radius, c = verts[f.z] * radius
            t.tri(a, b, c, outward: (a + b + c) / 3)
        }
        return t
    }

    /// Hollow ring (prop duct / race gate tube), axis +Y, centered.
    static func ring(radius: Float, height: Float, thickness: Float, segments: Int) -> TriSoup {
        var t = TriSoup()
        let ri = radius - thickness * 0.5, ro = radius + thickness * 0.5
        let y0 = -height * 0.5, y1 = height * 0.5
        for i in 0..<segments {
            let a0 = Float(i) / Float(segments) * 2 * .pi, a1 = Float(i + 1) / Float(segments) * 2 * .pi
            let d0 = SIMD3<Float>(cos(a0), 0, sin(a0)), d1 = SIMD3<Float>(cos(a1), 0, sin(a1))
            let out = normalize(d0 + d1)
            t.quad(d0 * ro + [0, y0, 0], d1 * ro + [0, y0, 0], d1 * ro + [0, y1, 0], d0 * ro + [0, y1, 0], outward: out)
            t.quad(d0 * ri + [0, y0, 0], d1 * ri + [0, y0, 0], d1 * ri + [0, y1, 0], d0 * ri + [0, y1, 0], outward: -out)
            t.quad(d0 * ri + [0, y1, 0], d1 * ri + [0, y1, 0], d1 * ro + [0, y1, 0], d0 * ro + [0, y1, 0], outward: [0, 1, 0])
            t.quad(d0 * ri + [0, y0, 0], d1 * ri + [0, y0, 0], d1 * ro + [0, y0, 0], d0 * ro + [0, y0, 0], outward: [0, -1, 0])
        }
        return t
    }

    /// Hub + pitched blades. Returns (solid, blurDisc).
    static func rotor(radius: Float, blades: Int) -> (TriSoup, TriSoup) {
        var solid = frustum(bottom: 0.007, top: 0.005, height: 0.008, segments: 6)
        let blade = box([radius * 0.92, 0.0016, radius * 0.22])
        for i in 0..<blades {
            let a = Float(i) / Float(blades) * 2 * .pi
            let m = matrix(position: [cos(a) * radius * 0.5, 0, -sin(a) * radius * 0.5], euler: [0, a, 0.16])
            solid.append(blade, transform: m)
        }
        let disc = frustum(bottom: radius, top: radius, height: 0.0008, segments: 14)
        return (solid, disc)
    }

    static func soup(for shape: DronePartShape) -> TriSoup {
        switch shape {
        case .box(let s): return box(s)
        case let .frustum(b, t, h, seg): return frustum(bottom: b, top: t, height: h, segments: seg)
        case let .ico(r, sub): return ico(radius: r, subdivisions: sub)
        case let .duct(r, h, th): return ring(radius: r, height: h, thickness: th, segments: 14)
        case let .rotor(r, blades): return rotor(radius: r, blades: blades).0
        }
    }
}
