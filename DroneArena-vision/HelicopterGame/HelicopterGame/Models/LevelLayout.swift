//
//  LevelLayout.swift
//  HelicopterGame
//
//  Created by Hunter Harris on 10/1/25.
//

import Foundation
import simd

public struct EntityPlacement: Codable {
    public let type: PlaceableType
    private let _position: CodableSIMD3
    private let _rotation: CodableQuaternion
    public let zoneID: String

    public var position: SIMD3<Float> {
        return _position.simd3
    }

    public var rotation: simd_quatf {
        return _rotation.quaternion
    }

    public init(type: PlaceableType, position: SIMD3<Float>, rotation: simd_quatf, zoneID: String) {
        self.type = type
        self._position = CodableSIMD3(position)
        self._rotation = CodableQuaternion(rotation)
        self.zoneID = zoneID
    }
}

public struct LevelLayout: Codable {
    public var hub: EntityPlacement?
    public var cargoZones: [EntityPlacement]
    public var deliveryZones: [EntityPlacement]

    public init() {
        self.hub = nil
        self.cargoZones = []
        self.deliveryZones = []
    }

    public init(hub: EntityPlacement?, cargoZones: [EntityPlacement], deliveryZones: [EntityPlacement]) {
        self.hub = hub
        self.cargoZones = cargoZones
        self.deliveryZones = deliveryZones
    }

    public var isValid: Bool {
        return hub != nil && !cargoZones.isEmpty && !deliveryZones.isEmpty
    }

    public mutating func addPlacement(_ placement: EntityPlacement) {
        switch placement.type {
        case .hub:
            hub = placement
        case .cargo:
            cargoZones.append(placement)
        case .delivery:
            deliveryZones.append(placement)
        }
    }

    public mutating func removePlacement(ofType type: PlaceableType, withID zoneID: String) {
        switch type {
        case .hub:
            if hub?.zoneID == zoneID {
                hub = nil
            }
        case .cargo:
            cargoZones.removeAll { $0.zoneID == zoneID }
        case .delivery:
            deliveryZones.removeAll { $0.zoneID == zoneID }
        }
    }

    public func getAllPlacements() -> [EntityPlacement] {
        var placements: [EntityPlacement] = []
        if let hub = hub {
            placements.append(hub)
        }
        placements.append(contentsOf: cargoZones)
        placements.append(contentsOf: deliveryZones)
        return placements
    }
}

// MARK: - SIMD Codable Extensions

// Custom Codable implementation for SIMD3<Float> since it's not available by default
public struct CodableSIMD3: Codable {
    public let x: Float
    public let y: Float
    public let z: Float

    public init(_ simd: SIMD3<Float>) {
        self.x = simd.x
        self.y = simd.y
        self.z = simd.z
    }

    public var simd3: SIMD3<Float> {
        return SIMD3<Float>(x, y, z)
    }
}

// Custom Codable implementation for simd_quatf
public struct CodableQuaternion: Codable {
    public let x: Float
    public let y: Float
    public let z: Float
    public let w: Float

    public init(_ quat: simd_quatf) {
        self.x = quat.vector.x
        self.y = quat.vector.y
        self.z = quat.vector.z
        self.w = quat.vector.w
    }

    public var quaternion: simd_quatf {
        return simd_quatf(vector: SIMD4<Float>(x, y, z, w))
    }
}