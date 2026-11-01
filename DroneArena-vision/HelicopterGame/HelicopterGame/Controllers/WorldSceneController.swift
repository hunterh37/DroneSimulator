//
//  WorldSceneController.swift
//  HelicopterGame
//
//  Created by Hunter Harris on 10/1/25.
//

import RealityKit
import UIKit
import Combine
import simd
import SwiftUI
import DicyaninVirtualJoystick
#if os(visionOS)
import DicyaninThumbController
#endif

@MainActor
public class WorldSceneController: ObservableObject {
    public let rootEntity = Entity()
    public private(set) var playerDrone: PlayerDroneEntity?
    public private(set) var dockPad: DockPadEntity?
    public private(set) var currentParcel: PackageEntity?

    // Zone management
    public private(set) var hubZone: HubZoneEntity?
    public private(set) var cargoZones: [CargoZoneEntity] = []
    public private(set) var deliveryZones: [DeliveryZoneEntity] = []
    public private(set) var packages: [PackageEntity] = []

    private var environmentEntity: Entity?
    private var lightingEntity: Entity?

#if os(visionOS)
    private var thumbVisualizer: ThumbControllerVisualizer?
#endif

    public init() {
        setupEnvironment()
        setupLighting()
        setupInitialScene()
#if os(visionOS)
        setupThumbVisualization()
#endif
    }

    private func setupEnvironment() {
        environmentEntity = Entity()
        rootEntity.addChild(environmentEntity!)
       // createLandmarks()
    }

    private func createLandmarks() {
        guard let environmentEntity = environmentEntity else { return }

        // Create landmark structures using USDZ models
        let landmarkPositions: [SIMD3<Float>] = [
            SIMD3<Float>(10, 0, 10),
            SIMD3<Float>(-10, 0, 10),
            SIMD3<Float>(10, 0, -10),
            SIMD3<Float>(-10, 0, -10)
        ]

        for position in landmarkPositions {
            createLandmark(at: position, in: environmentEntity)
        }
    }

    private func createLandmark(at position: SIMD3<Float>, in parent: Entity) {
        guard let landmarkURL = Bundle.main.url(forResource: "Landmark", withExtension: "usdz") else {
            gameLog("Error: Could not find Landmark.usdz in bundle, using fallback")
            createFallbackLandmark(at: position, in: parent)
            return
        }

        Task {
            do {
                let landmarkEntity = try await Entity(contentsOf: landmarkURL)
                await MainActor.run {
                    landmarkEntity.transform.translation = position
                    parent.addChild(landmarkEntity)
                }
            } catch {
                gameLog("Error loading Landmark.usdz: \(error)")
                await MainActor.run {
                    self.createFallbackLandmark(at: position, in: parent)
                }
            }
        }
    }

    private func createFallbackLandmark(at position: SIMD3<Float>, in parent: Entity) {
        let landmarkMesh = MeshResource.generateBox(width: 2, height: 4, depth: 2)
        let landmarkMaterial = SimpleMaterial(color: .gray, roughness: 0.6, isMetallic: false)
        let landmark = ModelEntity(mesh: landmarkMesh, materials: [landmarkMaterial])
        landmark.transform.translation = position
        parent.addChild(landmark)
    }

    private func setupLighting() {
        lightingEntity = Entity()
        rootEntity.addChild(lightingEntity!)

        // Add directional light (sun)
        let sunLight = DirectionalLight()
        sunLight.light.intensity = 500
        sunLight.light.color = .white
        sunLight.shadow = DirectionalLightComponent.Shadow()
        sunLight.transform.rotation = simd_quatf(angle: -.pi/4, axis: [1, 0, 0])

        lightingEntity!.addChild(sunLight)

        // Add ambient light
        // Note: In RealityKit, you'd typically use an IBL environment or image-based lighting
    }

#if os(visionOS)
    private func setupThumbVisualization() {
        // Hand-tracking debug spheres disabled: ThumbControllerVisualizer renders
        // pure-visualization green joint markers we don't want in the live scene.
        // Re-enable by uncommenting the three lines below.
        // thumbVisualizer = ThumbControllerVisualizer.shared
        // thumbVisualizer?.addToScene(rootEntity)
        // thumbVisualizer?.startVisualization()
        gameLog("👌 Thumb controller visualization disabled (debug spheres off)")

        // Hand-tracking control tutorial.
        GameContext.shared.handTutorial.start(in: rootEntity)
    }
#endif

    private func setupInitialScene() {
        createPlayerDrone()
       // createDockPad()
        setupGamepad3DIfNeeded()
    }

    /// The world-anchored joystick stand (present only for `.physicalJoystick`).
    public private(set) var gamepadPillar: GamepadPillarEntity?

    /// Spawns the joystick stand when that scheme is selected.
    func setupGamepad3DIfNeeded() {
        applyControlScheme()
    }

    /// Brings the scene in line with the selected scheme: spawns or removes the
    /// joystick stand. Safe to call repeatedly and mid-session.
    func applyControlScheme() {
#if os(visionOS)
        ControlSchemeConfig.syncHandTrackingGate()
        if ControlSchemeConfig.useWorldJoystickRig {
            guard gamepadPillar == nil else { return }
            let pillar = GamepadPillarEntity.make()
            rootEntity.addChild(pillar)
            gamepadPillar = pillar
            gameLog("Joystick stand spawned")
        } else if let pillar = gamepadPillar {
            pillar.removeFromParent()
            gamepadPillar = nil
            gameLog("Joystick stand removed")
        }
#endif
    }

    private func createPlayerDrone() {
        playerDrone = PlayerDroneEntity()
        playerDrone!.transform.translation = SIMD3<Float>(0, 0.3, -1.3)

#if os(visionOS)
        // Add Mode-2 flight controls: Left stick (throttle/yaw), Right stick (pitch/roll)
        playerDrone!.addDualThumbControl(
            throttleSpeed: 2.0,  // Left stick Y - up/down movement
            yawSpeed: 1.5,       // Left stick X - rotation left/right
            pitchSpeed: 2.0,     // Right stick Y - forward/backward movement
            rollSpeed: 2.0       // Right stick X - strafe left/right movement
        )

#endif
        
        // Note: iOS mobile virtual joystick control is added in MobileRealityView.setupMobileJoystickSystem()
        // This is because the system needs access to the InputRouter instance

        // Add missile capability to the drone
        playerDrone!.addDroneMissileCapability()

        rootEntity.addChild(playerDrone!)

        gameLog("🎮 Drone created with Mode-2 flight controls:")
        gameLog("   Left stick: Y=throttle (up/down), X=yaw (turn)")
        gameLog("   Right stick: Y=pitch (forward/back), X=roll (strafe)")
    }

    private func createDockPad() {
        dockPad = DockPadEntity()
        dockPad!.transform.translation = SIMD3<Float>(0, -1.9, 0)
        rootEntity.addChild(dockPad!)
    }


    public func createHandAnchoredHUD(with hudViewModel: HUDViewModel) {
#if os(visionOS)
        // Create an entity to hold the HUD
        let hudEntity = Entity()

        // Create the HUD view with the provided view model
        let hudView = HUDView(hudViewModel: hudViewModel)

        // Create ViewAttachmentComponent with the HUD
        let attachment = ViewAttachmentComponent(rootView: hudView)
        hudEntity.components.set(attachment)

        // Add built-in hand anchoring to left hand
        hudEntity.components.set(AnchoringComponent(.hand(.left, location: .aboveHand)))

        // Add to scene
       // rootEntity.addChild(hudEntity)

        gameLog("🖐️ Created hand-anchored HUD attached to left hand")
#endif
    }

    public func updateScene(deltaTime: Float) {
        // Movement is now handled directly in SimulatorJoystickView and FlightController

        // Check dock pad proximity
        if let drone = playerDrone, let dock = dockPad {
            _ = dock.checkPlayerProximity(to: drone.transform.translation)
        }

        // Update any animated elements
        updateAnimations(deltaTime: deltaTime)
    }


    private func updateAnimations(deltaTime: Float) {
        // Implement any ongoing animations here
        // For example, rotating elements, pulsing lights, etc.
    }

    public func reset() {
        // Remove all dynamic entities
        playerDrone?.removeFromParent()
        currentParcel?.removeFromParent()

        // Recreate initial scene
        setupInitialScene()
    }

    public func addEntity(_ entity: Entity, at position: SIMD3<Float>) {
        entity.transform.translation = position
        rootEntity.addChild(entity)
    }

    public func removeEntity(_ entity: Entity) {
        entity.removeFromParent()
    }

    public func findNearestInteractable(to position: SIMD3<Float>, maxDistance: Float = 2.0) -> Entity? {
        var nearestEntity: Entity? = nil
        var nearestDistance: Float = maxDistance

        // Check parcel
        if let parcel = currentParcel, !parcel.isPickedUp {
            let distance = length(parcel.transform.translation - position)
            if distance < nearestDistance {
                nearestDistance = distance
                nearestEntity = parcel
            }
        }

        // Check dock pad
        if let dock = dockPad {
            let distance = length(dock.transform.translation - position)
            if distance < nearestDistance {
                nearestDistance = distance
                nearestEntity = dock
            }
        }

        return nearestEntity
    }

    // MARK: - Zone Management

    public func loadZones(from layout: LevelLayout) {
        clearZones()

        // Load hub
        if let hubPlacement = layout.hub {
            hubZone = HubZoneEntity(zoneID: hubPlacement.zoneID)
            hubZone?.transform.translation = hubPlacement.position
            hubZone?.transform.rotation = hubPlacement.rotation
            if let hub = hubZone {
                rootEntity.addChild(hub)
            }
        }

        // Load cargo zones
        for cargoPlacement in layout.cargoZones {
            let cargoZone = CargoZoneEntity(zoneID: cargoPlacement.zoneID)
            cargoZone.transform.translation = cargoPlacement.position
            cargoZone.transform.rotation = cargoPlacement.rotation
            cargoZones.append(cargoZone)
            rootEntity.addChild(cargoZone)
        }

        // Load delivery zones
        for deliveryPlacement in layout.deliveryZones {
            let deliveryZone = DeliveryZoneEntity(zoneID: deliveryPlacement.zoneID)
            deliveryZone.transform.translation = deliveryPlacement.position
            deliveryZone.transform.rotation = deliveryPlacement.rotation
            deliveryZones.append(deliveryZone)
            rootEntity.addChild(deliveryZone)
        }
    }

    public func clearZones() {
        hubZone?.removeFromParent()
        hubZone = nil

        for cargoZone in cargoZones {
            cargoZone.removeFromParent()
        }
        cargoZones.removeAll()

        for deliveryZone in deliveryZones {
            deliveryZone.removeFromParent()
        }
        deliveryZones.removeAll()
    }

    public func addPackage(_ package: PackageEntity) {
        packages.append(package)
        rootEntity.addChild(package)
    }

    public func removePackage(_ package: PackageEntity) {
        packages.removeAll { $0 === package }
        package.removeFromParent()
    }

    public func findCargoZone(withID zoneID: String) -> CargoZoneEntity? {
        return cargoZones.first { $0.zoneID == zoneID }
    }

    public func findDeliveryZone(withID zoneID: String) -> DeliveryZoneEntity? {
        return deliveryZones.first { $0.zoneID == zoneID }
    }

    public func findPackage(withID packageID: String) -> PackageEntity? {
        return packages.first { $0.packageID == packageID }
    }

    public func findNearestCargoZone(to position: SIMD3<Float>) -> CargoZoneEntity? {
        var nearest: CargoZoneEntity?
        var nearestDistance: Float = Float.greatestFiniteMagnitude

        for cargoZone in cargoZones {
            let distance = length(cargoZone.transform.translation - position)
            if distance < nearestDistance {
                nearestDistance = distance
                nearest = cargoZone
            }
        }

        return nearest
    }

    public func findNearestDeliveryZone(to position: SIMD3<Float>) -> DeliveryZoneEntity? {
        var nearest: DeliveryZoneEntity?
        var nearestDistance: Float = Float.greatestFiniteMagnitude

        for deliveryZone in deliveryZones {
            let distance = length(deliveryZone.transform.translation - position)
            if distance < nearestDistance {
                nearestDistance = distance
                nearest = deliveryZone
            }
        }

        return nearest
    }

#if os(visionOS)
    public func stopThumbVisualization() {
        thumbVisualizer?.stopVisualization()
        thumbVisualizer = nil
        gameLog("👌 Thumb controller visualization stopped")
    }
#endif
}
