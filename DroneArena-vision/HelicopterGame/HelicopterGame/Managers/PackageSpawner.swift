//
//  PackageSpawner.swift
//  HelicopterGame
//
//  Created by Hunter Harris on 10/1/25.
//

import Foundation
import RealityKit
import simd
import QuartzCore

@MainActor
@Observable
public class PackageSpawner {
    private weak var worldScene: WorldSceneController?
    private var spawnTimer: Timer?
    private let spawnInterval: TimeInterval = 8.0 // Spawn every 8-12 seconds

    public init() {}

    public func setup(worldScene: WorldSceneController) {
        self.worldScene = worldScene
    }

    public func startSpawning() {
        stopSpawning()

        spawnTimer = Timer.scheduledTimer(withTimeInterval: spawnInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.attemptSpawn()
            }
        }
    }

    public func stopSpawning() {
        spawnTimer?.invalidate()
        spawnTimer = nil
    }

    private func attemptSpawn() {
        guard let worldScene = worldScene else { return }

        // Find cargo zones that can spawn packages
        let availableCargoZones = worldScene.cargoZones.filter { $0.canSpawnPackage() }

        guard !availableCargoZones.isEmpty else { return }

        // Pick a random cargo zone
        let cargoZone = availableCargoZones.randomElement()!

        // Pick a random delivery zone for the target
        let deliveryZones = worldScene.deliveryZones
        guard !deliveryZones.isEmpty else { return }

        let targetDeliveryZone = deliveryZones.randomElement()!

        // Choose package spec (random between medium and large)
        let packageSpec: PackageSpec = Bool.random() ? .medium : .large

        // Spawn the package
        if let package = cargoZone.spawnPackage(
            spec: packageSpec,
            deliveryLocation: targetDeliveryZone.transform.translation
        ) {
            worldScene.addPackage(package)
            gameLog("Spawned \(packageSpec.size) package at cargo zone \(cargoZone.zoneID)")
        }
    }

    public func spawnPackageAtCargoZone(_ cargoZoneID: String, spec: PackageSpec, deliveryZoneID: String) -> PackageEntity? {
        guard let worldScene = worldScene,
              let cargoZone = worldScene.findCargoZone(withID: cargoZoneID),
              let deliveryZone = worldScene.findDeliveryZone(withID: deliveryZoneID) else {
            return nil
        }

        if let package = cargoZone.spawnPackage(
            spec: spec,
            deliveryLocation: deliveryZone.transform.translation
        ) {
            worldScene.addPackage(package)
            return package
        }

        return nil
    }

    public func forceSpawnAtCargoZone(_ cargoZoneID: String, spec: PackageSpec, deliveryLocation: SIMD3<Float>) -> PackageEntity? {
        guard let worldScene = worldScene,
              let cargoZone = worldScene.findCargoZone(withID: cargoZoneID) else {
            return nil
        }

        // Force spawn even if cooldown isn't ready
        let packageID = UUID().uuidString
        let package = PackageEntity(id: packageID, spec: spec, deliveryLocation: deliveryLocation)
        package.transform.translation = cargoZone.transform.translation + SIMD3<Float>(0, 0.2, 0)

        cargoZone.activePackage = package
        cargoZone.lastSpawnTime = CACurrentMediaTime()

        worldScene.addPackage(package)
        return package
    }
}