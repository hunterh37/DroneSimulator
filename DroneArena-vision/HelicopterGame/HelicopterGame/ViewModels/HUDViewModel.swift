//
//  HUDViewModel.swift
//  HelicopterGame
//
//  Created by Hunter Harris on 10/1/25.
//

import Foundation
import SwiftUI
import Combine

@MainActor
@Observable
public class HUDViewModel {
    // Battery state
    public var batteryPercentage: Double = 100.0
    public var isRecharging: Bool = false

    // Timer state
    public var elapsedTime: TimeInterval = 0.0
    public var isRunActive: Bool = false

    // Coins and progress
    public var coinsEarned: Int = 0

    // Interaction state
    public var interactionPrompt: String = ""

    // Drone state
    public var droneState: DroneState = .idle
    public var isCarryingParcel: Bool = false

    // Combat / flight stats (driven into the head-anchored DroneStatsHUDView)
    public var speed: Float = 0.0            // m/s
    public var altitude: Float = 0.0         // meters
    public var health: Int = 100
    public var maxHealth: Int = 100
    // Per-slot missile readouts.
    public var missile1Count: Int = 0
    public var missile1Name: String = "—"
    public var missile2Count: Int = 0
    public var missile2Name: String = "—"

    // Job state
    public var hasActiveJob: Bool = false
    public var jobStage: String = "No Active Job"
    public var jobRemainingTime: TimeInterval = 0.0
    public var jobTotalTime: TimeInterval = 0.0

    // Claw state
    public var clawStatus: String = "Stowed"

    private var gameSessionManager: GameSessionManager
    private var updateTimer: Timer?

    public init(gameSessionManager: GameSessionManager = GameContext.shared.gameSession) {
        self.gameSessionManager = gameSessionManager
        startUpdating()
    }

    private func startUpdating() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateFromGameState()
            }
        }
    }

    private func updateFromGameState() {
        // Update from current run session
        if let runSession = gameSessionManager.currentRunSession {
            elapsedTime = runSession.elapsedTime
            coinsEarned = runSession.coinsEarned
            isRunActive = runSession.runActive

            // Update job state
            if let job = runSession.currentJob {
                hasActiveJob = true
                if job.isCompleted {
                    jobStage = "Delivered"
                } else if job.isPickedUp {
                    jobStage = "Deliver Parcel"
                } else {
                    jobStage = "Pick Up Parcel"
                }
            } else {
                hasActiveJob = false
                jobStage = "No Active Job"
            }
        } else {
            isRunActive = false
            hasActiveJob = false
            jobStage = "No Active Job"
        }
    }

    public func updateBattery(percentage: Double, isRecharging: Bool) {
        // Diff before assigning: every write to an @Observable property notifies
        // observers even when the value is unchanged, so skip no-op writes to
        // avoid a SwiftUI invalidation storm on the per-frame HUD update path.
        if self.batteryPercentage != percentage { self.batteryPercentage = percentage }
        if self.isRecharging != isRecharging { self.isRecharging = isRecharging }
    }

    public func updateDroneState(_ state: DroneState, carryingParcel: Bool) {
        if self.droneState != state { self.droneState = state }
        if self.isCarryingParcel != carryingParcel { self.isCarryingParcel = carryingParcel }
    }

    public func updateInteractionPrompt(_ prompt: String) {
        if self.interactionPrompt != prompt { self.interactionPrompt = prompt }
    }

    public func updateClawStatus(_ status: String) {
        if self.clawStatus != status { self.clawStatus = status }
    }

    public func updateJobTimer(remaining: TimeInterval, total: TimeInterval) {
        if self.jobRemainingTime != remaining { self.jobRemainingTime = remaining }
        if self.jobTotalTime != total { self.jobTotalTime = total }
    }

    /// Feeds the live combat / flight readouts shown in the head-anchored
    /// `DroneStatsHUDView` (ammo, health, speed, altitude).
    public func updateCombatStats(speed: Float, altitude: Float, health: Int, maxHealth: Int,
                                  missile1Count: Int, missile1Name: String,
                                  missile2Count: Int, missile2Name: String) {
        if self.speed != speed { self.speed = speed }
        if self.altitude != altitude { self.altitude = altitude }
        if self.health != health { self.health = health }
        if self.maxHealth != maxHealth { self.maxHealth = maxHealth }
        if self.missile1Count != missile1Count { self.missile1Count = missile1Count }
        if self.missile1Name != missile1Name { self.missile1Name = missile1Name }
        if self.missile2Count != missile2Count { self.missile2Count = missile2Count }
        if self.missile2Name != missile2Name { self.missile2Name = missile2Name }
    }
}
