//
//  InteractionController.swift
//  HelicopterGame
//
//  Created by Hunter Harris on 10/1/25.
//

import Foundation
import Combine
import RealityKit
import simd

@MainActor
public class InteractionController: ObservableObject {
    @Published public private(set) var nearestInteractable: Entity?
    @Published public private(set) var canInteract: Bool = false
    @Published public private(set) var interactionType: InteractionType = .none

    private let worldScene: WorldSceneController
    private let flightController: FlightController
    private let interactionRange: Float = 2.0
    private let dockingRange: Float = 1.2

    public init(worldScene: WorldSceneController, flightController: FlightController) {
        self.worldScene = worldScene
        self.flightController = flightController
    }

    public func updateInteractions() {
        guard let drone = worldScene.playerDrone else { return }

        let dronePosition = drone.transform.translation

        // Find nearest interactable entity
        nearestInteractable = worldScene.findNearestInteractable(
            to: dronePosition,
            maxDistance: interactionRange
        )

        // Determine interaction type and capability
        updateInteractionState(dronePosition: dronePosition, drone: drone)

        // Update visual feedback
        updateVisualFeedback()
    }

    private func updateInteractionState(dronePosition: SIMD3<Float>, drone: PlayerDroneEntity) {
        guard let nearest = nearestInteractable else {
            canInteract = false
            interactionType = .none
            return
        }

        let distance = length(nearest.transform.translation - dronePosition)

        if let parcel = nearest as? PackageEntity {
            if !parcel.isPickedUp && drone.attachedParcel == nil {
                // Can pick up parcel
                canInteract = distance <= interactionRange
                interactionType = .pickup
            } else if parcel.isPickedUp && drone.attachedParcel == parcel {
                // Can drop parcel
                canInteract = true
                interactionType = .drop
            } else {
                canInteract = false
                interactionType = .none
            }
        } else if let dockPad = nearest as? DockPadEntity {
            // Can dock for recharging
            canInteract = distance <= dockingRange
            interactionType = .dock
        } else {
            canInteract = false
            interactionType = .none
        }
    }

    private func updateVisualFeedback() {
        // Update parcel highlighting
        if let parcel = worldScene.currentParcel {
            let shouldHighlight = (nearestInteractable == parcel) &&
                                 (interactionType == .pickup || interactionType == .drop)
            parcel.highlightForInteraction(shouldHighlight)
        }

        // Update dock pad state
        if let dockPad = worldScene.dockPad,
           let drone = worldScene.playerDrone {
            let isInRange = dockPad.checkPlayerProximity(to: drone.transform.translation)

            if isInRange && interactionType == .dock {
                if !flightController.batteryModel.isRecharging {
                    dockPad.startRecharging()
                }
            } else {
                if flightController.batteryModel.isRecharging {
                    dockPad.stopRecharging()
                }
            }
        }
    }

    public func handleInteraction() {
        guard canInteract, let drone = worldScene.playerDrone else { return }

        switch interactionType {
        case .pickup:
            handlePickup(drone: drone)
        case .drop:
            handleDrop(drone: drone)
        case .dock:
            handleDocking(drone: drone)
        case .none:
            break
        }
    }

    private func handlePickup(drone: PlayerDroneEntity) {
        guard let parcel = nearestInteractable as? PackageEntity,
              !parcel.isPickedUp,
              drone.attachedParcel == nil else { return }

        // Remove parcel from world
        parcel.removeFromParent()

        // Attach to drone
        drone.attachPackage(parcel)
        parcel.pickup()

        gameLog("Parcel picked up!")
    }

    private func handleDrop(drone: PlayerDroneEntity) {
        guard let parcel = drone.detachPackage() else { return }

        // Add parcel back to world
        worldScene.addEntity(parcel, at: drone.transform.translation + SIMD3<Float>(0, -0.5, 0))
        parcel.drop()

        // Check if dropped at delivery location
        let dronePosition = drone.transform.translation
        if parcel.checkDeliveryProximity(to: dronePosition, threshold: 2.0) {
            handleDelivery(parcel: parcel)
        }

        gameLog("Parcel dropped!")
    }

    private func handleDelivery(parcel: PackageEntity) {
        parcel.deliver()

        // Complete the job in the current run session
        if let runSession = GameContext.shared.gameSession.currentRunSession {
            runSession.completeJob()
        }

        gameLog("Parcel delivered! Job complete!")
    }

    private func handleDocking(drone: PlayerDroneEntity) {
        guard let dockPad = worldScene.dockPad else { return }

        let distance = length(drone.transform.translation - dockPad.transform.translation)

        if distance <= dockingRange {
            // Start recharging
            flightController.startRecharging()
            drone.droneState = .recharging
            gameLog("Recharging started!")
        } else {
            // Stop recharging
            flightController.stopRecharging()
            if drone.droneState == .recharging {
                drone.droneState = .idle
            }
            gameLog("Recharging stopped!")
        }
    }

    public func stopRecharging() {
        guard let drone = worldScene.playerDrone else { return }

        flightController.stopRecharging()
        if drone.droneState == .recharging {
            drone.droneState = .idle
        }

        if let dockPad = worldScene.dockPad {
            dockPad.stopRecharging()
        }
    }

    // Utility methods
    public var interactionPrompt: String {
        switch interactionType {
        case .pickup:
            return "Pinch to Pick Up"
        case .drop:
            return "Pinch to Drop"
        case .dock:
            return "Pinch to Dock"
        case .none:
            return ""
        }
    }

    public var isCarryingParcel: Bool {
        return worldScene.playerDrone?.attachedParcel != nil
    }

    public var isRecharging: Bool {
        return flightController.batteryModel.isRecharging
    }
}