//
//  ZoneEntities.swift
//  HelicopterGame
//
//  Created by Hunter Harris on 10/1/25.
//

import RealityKit
import UIKit
import simd
import QuartzCore

public enum PlaceableType: String, Codable, CaseIterable {
    case hub
    case cargo
    case delivery
}

public protocol PlaceableEntity {
    var placeableType: PlaceableType { get }
    var zoneID: String { get }
}

public class ZoneAnchorEntity: Entity, HasAnchoring, HasCollision, PlaceableEntity {
    public let zoneID: String
    public let placeableType: PlaceableType
    private var labelEntity: ModelEntity?

    public required init() {
        self.zoneID = UUID().uuidString
        self.placeableType = .hub
        super.init()
    }

    public init(zoneID: String, type: PlaceableType) {
        self.zoneID = zoneID
        self.placeableType = type
        super.init()
        setupZoneVisual()
        setupCollision()
    }

    private func setupZoneVisual() {
        // Try to load USDZ model first, fallback to procedural geometry
        let modelName: String
        switch placeableType {
        case .hub:
            modelName = "HubZone"
        case .cargo:
            modelName = "CargoZone"
        case .delivery:
            modelName = "DeliveryZone"
        }

        loadUSDZModel(named: modelName)
    }

    private func loadUSDZModel(named modelName: String) {
        guard let modelURL = Bundle.main.url(forResource: modelName, withExtension: "usdz") else {
            gameLog("Error: Could not find \(modelName).usdz in bundle")
            setupFallbackVisual()
            return
        }

        Task {
            do {
                let zoneEntity = try await Entity(contentsOf: modelURL)

                await MainActor.run {
                    self.addChild(zoneEntity)
                    self.createLabel()
                }
            } catch {
                gameLog("Error loading \(modelName).usdz: \(error)")
                await MainActor.run {
                    self.setupFallbackVisual()
                }
            }
        }
    }

    private func setupFallbackVisual() {
        // Base platform (using box since cylinder not available)
        let radius: Float = 0.5
        let height: Float = 0.05
        let platformMesh = MeshResource.generateBox(width: radius * 2, height: height, depth: radius * 2)

        let color: UIColor
        switch placeableType {
        case .hub:
            color = .blue
        case .cargo:
            color = .green
        case .delivery:
            color = .red
        }

        let platformMaterial = SimpleMaterial(color: color, roughness: 0.2, isMetallic: false)
        let platform = ModelEntity(mesh: platformMesh, materials: [platformMaterial])

        addChild(platform)
        createLabel()
    }

    private func createLabel() {
        let labelText: String
        switch placeableType {
        case .hub:
            labelText = "Hub"
        case .cargo:
            labelText = "Cargo"
        case .delivery:
            labelText = "Delivery"
        }

        // Create a simple text mesh (simplified - would use MeshResource.generateText in real implementation)
        let labelMesh = MeshResource.generateBox(width: 0.3, height: 0.1, depth: 0.02)
        let labelMaterial = SimpleMaterial(color: .white, roughness: 0.1, isMetallic: false)
        labelEntity = ModelEntity(mesh: labelMesh, materials: [labelMaterial])
        labelEntity?.transform.translation = SIMD3<Float>(0, 0.3, 0)

        if let label = labelEntity {
            addChild(label)
        }
    }

    private func setupCollision() {
        let shape = ShapeResource.generateBox(width: 1.0, height: 0.05, depth: 1.0)
        self.components.set(CollisionComponent(shapes: [shape]))

        // Configure for interactive placement and gesture handling
        self.configureCollision()
    }

    public func setHighlighted(_ highlighted: Bool) {
        // Update visual to show highlight state
        guard let platform = children.first as? ModelEntity else { return }

        let baseColor: UIColor
        switch placeableType {
        case .hub:
            baseColor = highlighted ? .cyan : .blue
        case .cargo:
            baseColor = highlighted ? .yellow : .green
        case .delivery:
            baseColor = highlighted ? .orange : .red
        }

        let material = SimpleMaterial(color: baseColor, roughness: 0.2, isMetallic: false)
        platform.model?.materials = [material]
    }
}

// MARK: - Specific Zone Types

public class HubZoneEntity: ZoneAnchorEntity {
    public required init() {
        super.init()
    }

    public init(zoneID: String) {
        super.init(zoneID: zoneID, type: .hub)
    }
}

public class CargoZoneEntity: ZoneAnchorEntity {
    public var lastSpawnTime: TimeInterval = 0
    public var spawnCooldown: TimeInterval = 10.0 // 10 seconds between spawns
    public var activePackage: PackageEntity?

    public required init() {
        super.init()
    }

    public init(zoneID: String) {
        super.init(zoneID: zoneID, type: .cargo)
    }

    public func canSpawnPackage() -> Bool {
        return activePackage == nil && (CACurrentMediaTime() - lastSpawnTime) >= spawnCooldown
    }

    public func spawnPackage(spec: PackageSpec, deliveryLocation: SIMD3<Float>) -> PackageEntity? {
        guard canSpawnPackage() else { return nil }

        let packageID = UUID().uuidString
        let package = PackageEntity(id: packageID, spec: spec, deliveryLocation: deliveryLocation)

        // Position package slightly above the zone
        package.transform.translation = self.transform.translation + SIMD3<Float>(0, 0.2, 0)

        activePackage = package
        lastSpawnTime = CACurrentMediaTime()

        return package
    }

    public func packagePickedUp() {
        activePackage = nil
    }
}

public class DeliveryZoneEntity: ZoneAnchorEntity {
    public var targetDeliveries: [String] = [] // Package IDs expected at this zone

    public required init() {
        super.init()
    }

    public init(zoneID: String) {
        super.init(zoneID: zoneID, type: .delivery)
    }

    public func addTargetDelivery(packageID: String) {
        targetDeliveries.append(packageID)
    }

    public func canAcceptPackage(packageID: String) -> Bool {
        return targetDeliveries.contains(packageID)
    }

    public func completeDelivery(packageID: String) {
        targetDeliveries.removeAll { $0 == packageID }
    }

    public func checkProximity(to position: SIMD3<Float>, threshold: Float = 1.0) -> Bool {
        let distance = length(position - transform.translation)
        return distance <= threshold
    }
}