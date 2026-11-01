//
//  DeliveryDirector.swift
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
public class DeliveryDirector {
    // Step 3: Multi-job system (up to 3 concurrent jobs)
    public private(set) var activeJobs: [Job] = []
    public private(set) var completedJobs: [Job] = []
    public private(set) var failedJobs: [Job] = []

    // Legacy support
    public var activeJob: Job? { activeJobs.first }

    private weak var worldScene: WorldSceneController?
    private weak var packageSpawner: PackageSpawner?
    private var currentLayout: LevelLayout?
    private var sessionStartTime: TimeInterval = 0
    private var sessionActive: Bool = false

    // Step 3: Enhanced job parameters
    private let baseTimeLimit: TimeInterval = 60.0 // 1 minute base time
    private let timePerDistance: TimeInterval = 2.0 // 2 seconds per unit distance
    private let maxConcurrentJobs: Int = 3
    private let priorityJobChance: Float = 0.3 // 30% chance for priority jobs

    public init() {}

    // Step 3: Session management
    public func startSession(with layout: LevelLayout) {
        currentLayout = layout
        sessionActive = true
        sessionStartTime = CACurrentMediaTime()
        activeJobs.removeAll()
        completedJobs.removeAll()
        failedJobs.removeAll()

        gameLog("Delivery session started with layout")

        // Start initial jobs
        for _ in 0..<min(2, maxConcurrentJobs) {
            startNextJob()
        }
    }

    public func cleanup() {
        sessionActive = false
        activeJobs.removeAll()
        gameLog("Delivery session ended")
    }

    public var activeJobCount: Int {
        return activeJobs.count
    }

    public var sessionDuration: TimeInterval {
        guard sessionActive else { return 0 }
        return CACurrentMediaTime() - sessionStartTime
    }

    public func setup(worldScene: WorldSceneController, packageSpawner: PackageSpawner) {
        self.worldScene = worldScene
        self.packageSpawner = packageSpawner
    }

    public func startNextJob() {
        guard sessionActive,
              activeJobs.count < maxConcurrentJobs,
              let worldScene = worldScene else { return }

        // Make sure we have zones to work with
        guard !worldScene.cargoZones.isEmpty,
              !worldScene.deliveryZones.isEmpty else {
            gameLog("Cannot start job: No cargo or delivery zones available")
            return
        }

        // Pick random cargo and delivery zones
        let cargoZone = worldScene.cargoZones.randomElement()!
        let deliveryZone = worldScene.deliveryZones.randomElement()!

        // Calculate time limit based on distance
        let distance = length(cargoZone.transform.translation - deliveryZone.transform.translation)
        let timeLimit = baseTimeLimit + TimeInterval(distance) * timePerDistance

        // Step 3: Determine if this is a priority job
        let isPriority = Float.random(in: 0...1) < priorityJobChance
        let adjustedTimeLimit = isPriority ? timeLimit * 0.7 : timeLimit // Priority jobs have shorter time

        // Step 3: Choose package type based on priority and randomness
        let packageType: PackageType
        if isPriority {
            packageType = .priorityCargo
        } else {
            packageType = PackageType.allCases.randomElement() ?? .generic
        }

        // Map package type to spec (temporary until PackageEntity is updated)
        let packageSpec: PackageSpec
        switch packageType {
        case .generic, .toyCrate:
            packageSpec = .medium
        case .energyPod:
            packageSpec = .small
        case .priorityCargo:
            packageSpec = .large
        }

        // Create job
        let job = Job(
            pickupZoneID: cargoZone.zoneID,
            deliveryZoneID: deliveryZone.zoneID,
            timeLimit: adjustedTimeLimit,
            packageSpec: packageSpec
        )

        // Spawn package at cargo zone
        if let package = packageSpawner?.spawnPackageAtCargoZone(
            cargoZone.zoneID,
            spec: packageSpec,
            deliveryZoneID: deliveryZone.zoneID
        ) {
            // Mark delivery zone as expecting this package
            deliveryZone.addTargetDelivery(packageID: package.packageID)

            activeJobs.append(job)
            if var lastJob = activeJobs.last {
                lastJob.start()
                activeJobs[activeJobs.count - 1] = lastJob
            }

            let priorityLabel = isPriority ? " (PRIORITY)" : ""
            gameLog("Started job: \(job.id) - Pickup at \(cargoZone.zoneID), deliver to \(deliveryZone.zoneID)\(priorityLabel)")
        } else {
            gameLog("Failed to spawn package for job")
        }
    }

    public func checkJobProgress() {
        guard let worldScene = worldScene else { return }

        // Check all active jobs
        for i in (0..<activeJobs.count).reversed() {
            var job = activeJobs[i]

            // Check if job has expired
            if job.isExpired {
                failJob(job, reason: "Time expired")
                activeJobs.remove(at: i)
                continue
            }

            // Check if package was picked up
            if !job.isPickedUp {
                if let cargoZone = worldScene.findCargoZone(withID: job.pickupZoneID),
                   cargoZone.activePackage == nil {
                    job.isPickedUp = true
                    activeJobs[i] = job
                    gameLog("Package picked up for job \(job.id)")
                }
            }

            // Check if package was delivered
            if job.isPickedUp && !job.isCompleted {
                if let deliveryZone = worldScene.findDeliveryZone(withID: job.deliveryZoneID),
                   deliveryZone.targetDeliveries.isEmpty {
                    completeJob(job)
                    activeJobs.remove(at: i)
                }
            }
        }

        // Start new jobs if we have capacity
        while activeJobs.count < maxConcurrentJobs && sessionActive {
            startNextJob()
        }
    }

    public func attemptDelivery(package: PackageEntity, at deliveryZone: DeliveryZoneEntity) -> Bool {
        // Find the job that matches this package delivery
        guard activeJobs.contains(where: { job in
            job.deliveryZoneID == deliveryZone.zoneID &&
            job.pickupZoneID != deliveryZone.zoneID && // Can't deliver to cargo zone
            deliveryZone.canAcceptPackage(packageID: package.packageID)
        }) else {
            return false
        }

        // Complete the delivery
        deliveryZone.completeDelivery(packageID: package.packageID)
        package.deliver()

        // Remove package from world
        worldScene?.removePackage(package)

        gameLog("Package \(package.packageID) delivered to zone \(deliveryZone.zoneID)")
        return true
    }

    private func completeJob(_ job: Job) {
        var completedJob = job
        completedJob.isCompleted = true
        completedJobs.append(completedJob)

        gameLog("Job \(job.id) completed successfully!")

        // No need to schedule next job - checkJobProgress will handle it
    }

    private func failJob(_ job: Job, reason: String) {
        failedJobs.append(job)

        gameLog("Job \(job.id) failed: \(reason)")

        // Clean up any remaining packages/targets
        if let worldScene = worldScene,
           let deliveryZone = worldScene.findDeliveryZone(withID: job.deliveryZoneID) {
            deliveryZone.targetDeliveries.removeAll()
        }

        // No need to schedule next job - checkJobProgress will handle it
    }

    // Step 3: Session results generation
    public func generateSessionResults() -> SessionResults {
        let completedDeliveries = completedJobs.map { job in
            // Map job to completed delivery (simplified for now)
            CompletedDelivery(
                packageType: .generic, // TODO: Store package type in Job
                deliveryTime: job.timeLimit - job.remainingTime,
                wasPriority: false // TODO: Store priority flag in Job
            )
        }

        return SessionResults(
            levelID: "current_session",
            completedDeliveries: completedDeliveries,
            totalJobs: completedJobs.count + failedJobs.count,
            sessionDuration: sessionDuration
        )
    }

    public func getCurrentTarget() -> SIMD3<Float>? {
        guard let job = activeJob,
              let worldScene = worldScene else { return nil }

        if !job.isPickedUp {
            // Target is cargo zone
            return worldScene.findCargoZone(withID: job.pickupZoneID)?.transform.translation
        } else {
            // Target is delivery zone
            return worldScene.findDeliveryZone(withID: job.deliveryZoneID)?.transform.translation
        }
    }

    public func getCurrentTargetLabel() -> String? {
        guard let job = activeJob else { return nil }

        if !job.isPickedUp {
            return "Get Cargo"
        } else {
            return "Deliver"
        }
    }

    public var jobStats: (completed: Int, failed: Int) {
        return (completedJobs.count, failedJobs.count)
    }
}