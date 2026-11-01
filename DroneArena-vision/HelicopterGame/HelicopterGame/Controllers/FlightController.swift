//
//  FlightController.swift
//  HelicopterGame
//
//  Created by Hunter Harris on 10/1/25.
//

import Foundation
import Combine
import RealityKit
import simd

@MainActor
public class FlightController: ObservableObject {
    @Published public var batteryModel = BatteryModel()

    private let playerSettings: PlayerSettings
    private var lastUpdateTime: Date = Date()

    // Realistic flight physics parameters
    private let maxSpeed: Float = 4.0
    private let acceleration: Float = 8.0
    private let deceleration: Float = 12.0
    private let maxYawSpeed: Float = 2.5
    private let yawAcceleration: Float = 6.0
    private let hoverHeight: Float = 1.0
    private let emergencyHoverEnabled: Bool = true

    // Current velocity state
    private var currentVelocity: SIMD3<Float> = .zero
    private var currentYawVelocity: Float = 0.0

    // Public getters for UI display
    public var currentSpeed: Float {
        return length(currentVelocity)
    }

    public init(playerSettings: PlayerSettings) {
        self.playerSettings = playerSettings
    }

    public func updateFlight(
        drone: PlayerDroneEntity,
        intent: ControlIntent,
        deltaTime: Float
    ) {
        let currentTime = Date()
        let dt = Float(currentTime.timeIntervalSince(lastUpdateTime))
        lastUpdateTime = currentTime

        // Update battery
        updateBattery(deltaTime: Double(dt))

        // Handle emergency situations - simplified
        if batteryModel.isEmpty && emergencyHoverEnabled {
            drone.droneState = .emergency
            return
        }

        // Process control intent - only handle movement
        switch intent {
        case .move(let movement, let yaw):
            applyMovement(drone: drone, movement: movement, yaw: yaw, deltaTime: dt)
        case .boost, .interact, .toggleMap:
            // Simplified - these are handled elsewhere or ignored
            break
        }
    }

    private func applyMovement(
        drone: PlayerDroneEntity,
        movement: SIMD3<Float>,
        yaw: Float,
        deltaTime: Float
    ) {
        guard !batteryModel.isEmpty else { return }

        // While crashed (Time Trial), the course system owns the drone transform.
        if drone.isCrashActive {
            CourseInput.directLift = max(0, movement.y)
            return
        }

        // Apply control sensitivity
        let scaledMovement = movement * playerSettings.controlSensitivity
        let scaledYaw = yaw * playerSettings.turningSensitivity

        // Realistic drone physics with acceleration/deceleration
        let deltaTime: Float = 1.0 / 60.0
        var droneTransform = drone.transform

        // Calculate target velocity from input
        let targetVelocity = scaledMovement * maxSpeed
        let targetYawVelocity = scaledYaw * maxYawSpeed

        // Apply acceleration/deceleration for movement
        let movementLength = length(scaledMovement)
        if movementLength > 0.001 {
            // Accelerating towards target velocity
            let velocityDiff = targetVelocity - currentVelocity
            let accelerationStep = normalize(velocityDiff) * acceleration * deltaTime

            // Don't overshoot the target
            if length(accelerationStep) > length(velocityDiff) {
                currentVelocity = targetVelocity
            } else {
                currentVelocity += accelerationStep
            }
        } else {
            // Decelerating to stop
            let currentSpeed = length(currentVelocity)
            if currentSpeed > 0.001 {
                let decelerationStep = min(deceleration * deltaTime, currentSpeed)
                currentVelocity = currentVelocity * ((currentSpeed - decelerationStep) / currentSpeed)
            } else {
                currentVelocity = .zero
            }
        }

        // Apply acceleration/deceleration for yaw
        if abs(scaledYaw) > 0.001 {
            // Accelerating towards target yaw velocity
            let yawDiff = targetYawVelocity - currentYawVelocity
            let yawAccelStep = (yawDiff > 0 ? 1.0 : -1.0) * yawAcceleration * deltaTime

            if abs(yawAccelStep) > abs(yawDiff) {
                currentYawVelocity = targetYawVelocity
            } else {
                currentYawVelocity += yawAccelStep
            }
        } else {
            // Decelerating yaw to stop
            if abs(currentYawVelocity) > 0.001 {
                let yawDecelerationStep = min(yawAcceleration * deltaTime, abs(currentYawVelocity))
                currentYawVelocity = currentYawVelocity * ((abs(currentYawVelocity) - yawDecelerationStep) / abs(currentYawVelocity))
            } else {
                currentYawVelocity = 0.0
            }
        }

        // Apply movement using current velocity
        if length(currentVelocity) > 0.001 || abs(currentYawVelocity) > 0.001 {
            let movementDelta = currentVelocity * deltaTime
            droneTransform.translation += movementDelta

            // Apply rotation using current yaw velocity
            if abs(currentYawVelocity) > 0.001 {
                let rotationDelta = currentYawVelocity * deltaTime
                let yawRotation = simd_quatf(angle: rotationDelta, axis: SIMD3<Float>(0, 1, 0))
                droneTransform.rotation = droneTransform.rotation * yawRotation
            }

            // Move drone
            drone.move(to: droneTransform, relativeTo: nil)

            gameLog("🚁 REALISTIC FlightController: input=\(scaledMovement), velocity=\(currentVelocity), yaw=\(currentYawVelocity)")
        }

        // Update drone state
        if length(movement) > 0.01 {
            drone.droneState = drone.attachedParcel != nil ? .carryingParcel : .flying
        } else {
            drone.droneState = .idle
        }
    }

    // Simplified flight controller - these functions now use direct movement instead of velocity

    public func updateBattery(deltaTime: Double) {
        if batteryModel.isRecharging {
            batteryModel.recharge(dt: deltaTime)
        } else {
            batteryModel.drain(dt: deltaTime)
        }
    }

    public func startRecharging() {
        batteryModel.startRecharging()
    }

    public func stopRecharging() {
        batteryModel.stopRecharging()
    }

    public func resetBattery() {
        batteryModel = BatteryModel()
    }

    // Utility methods for external systems
    public var isInEmergencyMode: Bool {
        return batteryModel.isEmpty && emergencyHoverEnabled
    }

    public var canPerformActions: Bool {
        return !batteryModel.isEmpty
    }

    public var batteryPercentage: Double {
        return batteryModel.percent
    }
}