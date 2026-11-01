//
//  LowPolyDroneFactory.swift
//  HelicopterGame
//
//  Builds procedural low-poly drones for RealityKit (game) and SceneKit (menu preview).
//  Meshes are cached per style; materials are cached per livery.
//

import RealityKit
import SceneKit
import UIKit
import simd

struct DroneLivery: Hashable {
    var primary: UIColor
    var accent: UIColor

    static let presets: [DroneLivery] = [
        DroneLivery(primary: UIColor(red: 0.93, green: 0.22, blue: 0.20, alpha: 1), accent: UIColor(red: 1.0, green: 0.85, blue: 0.2, alpha: 1)),
        DroneLivery(primary: UIColor(red: 0.12, green: 0.45, blue: 0.95, alpha: 1), accent: UIColor(red: 0.4, green: 0.95, blue: 1.0, alpha: 1)),
        DroneLivery(primary: UIColor(red: 0.15, green: 0.80, blue: 0.45, alpha: 1), accent: UIColor(red: 0.9, green: 1.0, blue: 0.3, alpha: 1)),
        DroneLivery(primary: UIColor(red: 0.98, green: 0.55, blue: 0.10, alpha: 1), accent: UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1)),
        DroneLivery(primary: UIColor(red: 0.62, green: 0.25, blue: 0.95, alpha: 1), accent: UIColor(red: 1.0, green: 0.4, blue: 0.85, alpha: 1)),
        DroneLivery(primary: UIColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1), accent: UIColor(red: 0.2, green: 0.9, blue: 0.8, alpha: 1)),
        DroneLivery(primary: UIColor(red: 0.10, green: 0.10, blue: 0.12, alpha: 1), accent: UIColor(red: 1.0, green: 0.2, blue: 0.3, alpha: 1)),
        DroneLivery(primary: UIColor(red: 0.95, green: 0.80, blue: 0.15, alpha: 1), accent: UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1))
    ]

    func color(for role: DronePartRole) -> UIColor {
        switch role {
        case .body, .canopy: return primary
        case .accent, .glow: return accent
        case .carbon: return UIColor(white: 0.09, alpha: 1)
        case .metal: return UIColor(white: 0.62, alpha: 1)
        case .prop: return UIColor(white: 0.16, alpha: 1)
        case .rubber: return UIColor(white: 0.04, alpha: 1)
        }
    }
}

/// Spins a rotor about its local +Y.
struct PropSpinComponent: Component {
    var direction: Float
    var speed: Float = 38
}

struct PropSpinSystem: System {
    private static let query = EntityQuery(where: .has(PropSpinComponent.self))
    init(scene: RealityKit.Scene) {}

    func update(context: SceneUpdateContext) {
        let dt = Float(context.deltaTime)
        for e in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            guard let spin = e.components[PropSpinComponent.self] else { continue }
            e.orientation = simd_quatf(angle: spin.direction * spin.speed * dt, axis: [0, 1, 0]) * e.orientation
        }
    }
}

@MainActor
enum LowPolyDroneFactory {
    private static let roles = DronePartRole.allCases
    private struct Baked {
        var body: MeshResource?
        var rotors: [(mesh: MeshResource, position: SIMD3<Float>, spin: Float, flip: Bool)]
        var blur: [SIMD3<Float>: MeshResource]
    }
    private static var bakedCache: [LowPolyDroneStyle: Baked] = [:]
    private static var materialCache: [String: RealityKit.Material] = [:]

    static func registerECS() {
        PropSpinComponent.registerComponent()
        PropSpinSystem.registerSystem()
    }

    // MARK: - RealityKit

    /// Returns a drone visual root. Forward is -Z. Props spin via PropSpinSystem.
    static func make(_ style: LowPolyDroneStyle, livery: DroneLivery, scale: Float = 1) -> Entity {
        let baked = bake(style)
        let root = Entity()
        root.name = "LowPolyDrone.\(style.rawValue)"
        if let mesh = baked.body {
            let model = ModelEntity(mesh: mesh, materials: roles.map { material($0, livery) })
            model.components.set(GroundingShadowComponent(castsShadow: true))
            root.addChild(model)
        }
        for rotor in baked.rotors {
            let prop = ModelEntity(mesh: rotor.mesh, materials: [material(.prop, livery)])
            prop.position = rotor.position
            prop.components.set(PropSpinComponent(direction: rotor.spin))
            if let blurMesh = baked.blur[rotor.position] {
                let blur = ModelEntity(mesh: blurMesh, materials: [blurMaterial()])
                prop.addChild(blur)
            }
            root.addChild(prop)
        }
        root.scale = .init(repeating: scale)
        return root
    }

    private static func bake(_ style: LowPolyDroneStyle) -> Baked {
        if let cached = bakedCache[style] { return cached }
        var perRole: [DronePartRole: TriSoup] = [:]
        var rotors: [(MeshResource, SIMD3<Float>, Float, Bool)] = []
        var blur: [SIMD3<Float>: MeshResource] = [:]
        for part in style.parts {
            if case let .rotor(r, blades) = part.shape {
                let (solid, disc) = LowPolyGeometry.rotor(radius: r, blades: blades)
                if let mesh = meshResource(solid, name: "rotor") {
                    rotors.append((mesh, part.position, part.spin, false))
                    blur[part.position] = meshResource(disc, name: "blur")
                }
                continue
            }
            let m = LowPolyGeometry.matrix(position: part.position, euler: part.euler)
            perRole[part.role, default: TriSoup()].append(LowPolyGeometry.soup(for: part.shape), transform: m)
        }
        var descriptors: [MeshDescriptor] = []
        for (i, role) in roles.enumerated() {
            guard let soup = perRole[role], !soup.isEmpty else { continue }
            var d = MeshDescriptor(name: "\(style.rawValue)-\(role)")
            d.positions = MeshBuffers.Positions(soup.positions)
            d.normals = MeshBuffers.Normals(soup.normals)
            d.primitives = .triangles((0..<UInt32(soup.positions.count)).map { $0 })
            d.materials = .allFaces(UInt32(i))
            descriptors.append(d)
        }
        let body = try? MeshResource.generate(from: descriptors)
        let result = Baked(body: body, rotors: rotors.map { ($0.0, $0.1, $0.2, $0.3) }, blur: blur)
        bakedCache[style] = result
        return result
    }

    private static func meshResource(_ soup: TriSoup, name: String) -> MeshResource? {
        var d = MeshDescriptor(name: name)
        d.positions = MeshBuffers.Positions(soup.positions)
        d.normals = MeshBuffers.Normals(soup.normals)
        d.primitives = .triangles((0..<UInt32(soup.positions.count)).map { $0 })
        return try? MeshResource.generate(from: [d])
    }

    static func material(_ role: DronePartRole, _ livery: DroneLivery) -> RealityKit.Material {
        let color = livery.color(for: role)
        let key = "\(role)-\(color.hashValue)"
        if let m = materialCache[key] { return m }
        var m = PhysicallyBasedMaterial()
        m.baseColor = .init(tint: color)
        switch role {
        case .body:
            m.roughness = 0.35; m.metallic = 0.1; m.clearcoat = 0.8; m.clearcoatRoughness = 0.1
        case .canopy:
            m.roughness = 0.15; m.metallic = 0.2; m.clearcoat = 1.0; m.clearcoatRoughness = 0.05
        case .accent:
            m.roughness = 0.4; m.metallic = 0.3
        case .glow:
            m.roughness = 0.3
            m.emissiveColor = .init(color: color)
            m.emissiveIntensity = 2.2
        case .carbon:
            m.roughness = 0.45; m.metallic = 0.2; m.clearcoat = 0.6; m.clearcoatRoughness = 0.3
        case .metal:
            m.roughness = 0.25; m.metallic = 1.0
        case .prop:
            m.roughness = 0.5
        case .rubber:
            m.roughness = 0.9
        }
        materialCache[key] = m
        return m
    }

    private static func blurMaterial() -> RealityKit.Material {
        if let m = materialCache["blur"] { return m }
        var m = UnlitMaterial(color: UIColor(white: 0.85, alpha: 1))
        m.blending = .transparent(opacity: .init(floatLiteral: 0.12))
        m.faceCulling = .none
        materialCache["blur"] = m
        return m
    }

    // MARK: - SceneKit (menu preview)

    static func makeSceneKitNode(_ style: LowPolyDroneStyle, livery: DroneLivery) -> SCNNode {
        let root = SCNNode()
        root.name = "LowPolyDrone.\(style.rawValue)"
        var perRole: [DronePartRole: TriSoup] = [:]
        for part in style.parts {
            let m = LowPolyGeometry.matrix(position: part.position, euler: part.euler)
            perRole[part.role, default: TriSoup()].append(LowPolyGeometry.soup(for: part.shape), transform: m)
        }
        for (role, soup) in perRole where !soup.isEmpty {
            let geo = scnGeometry(soup)
            let mat = SCNMaterial()
            mat.lightingModel = .physicallyBased
            mat.diffuse.contents = livery.color(for: role)
            mat.metalness.contents = role == .metal ? 1.0 : 0.15
            mat.roughness.contents = role == .rubber ? 0.9 : 0.35
            if role == .glow { mat.emission.contents = livery.accent }
            geo.materials = [mat]
            root.addChildNode(SCNNode(geometry: geo))
        }
        return root
    }

    private static func scnGeometry(_ soup: TriSoup) -> SCNGeometry {
        let v = soup.positions.map { SCNVector3($0.x, $0.y, $0.z) }
        let n = soup.normals.map { SCNVector3($0.x, $0.y, $0.z) }
        let idx = (0..<Int32(v.count)).map { $0 }
        return SCNGeometry(sources: [SCNGeometrySource(vertices: v), SCNGeometrySource(normals: n)],
                           elements: [SCNGeometryElement(indices: idx, primitiveType: .triangles)])
    }
}

extension UIColor {
    convenience init(hexString: String) {
        let s = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        self.init(red: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255, blue: CGFloat(v & 0xFF) / 255, alpha: 1)
    }
}
