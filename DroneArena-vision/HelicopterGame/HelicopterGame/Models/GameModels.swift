//
//  GameModels.swift
//  HelicopterGame
//
//  Created by Hunter Harris on 10/1/25.
//

import Foundation
import simd
import QuartzCore

// MARK: - Control Intent
public enum ControlIntent {
    case move(SIMD3<Float>, yaw: Float)
    case boost
    case interact
    case toggleMap
}

extension ControlIntent: CustomStringConvertible {
    public var description: String {
        switch self {
        case .move(let movement, let yaw):
            return "move(movement: \(movement), yaw: \(yaw))"
        case .boost:
            return "boost"
        case .interact:
            return "interact"
        case .toggleMap:
            return "toggleMap"
        }
    }
}

// MARK: - Claw System
public enum ClawState: Equatable {
    case stowed
    case extending
    case attached(packageID: String)
    case releasing
    case retracting

    public static func == (lhs: ClawState, rhs: ClawState) -> Bool {
        switch (lhs, rhs) {
        case (.stowed, .stowed), (.extending, .extending), (.releasing, .releasing), (.retracting, .retracting):
            return true
        case (.attached(let lhsID), .attached(let rhsID)):
            return lhsID == rhsID
        default:
            return false
        }
    }
}

public enum ClawIntent {
    case extendOrGrab
    case release
}

// MARK: - Battery Model
public struct BatteryModel {
    public var percent: Double
    public var drainPerSec: Double
    public var rechargePerSec: Double
    public var isRecharging: Bool = false

    public init(percent: Double = 100.0, drainPerSec: Double = 5.0, rechargePerSec: Double = 20.0) {
        self.percent = max(0.0, min(100.0, percent))
        self.drainPerSec = drainPerSec
        self.rechargePerSec = rechargePerSec
    }

    public mutating func drain(dt: Double) {
        guard !isRecharging else { return }
        percent = max(0.0, percent - (drainPerSec * dt))
    }

    public mutating func recharge(dt: Double) {
        guard isRecharging else { return }
        percent = min(100.0, percent + (rechargePerSec * dt))
    }

    public mutating func startRecharging() {
        isRecharging = true
    }

    public mutating func stopRecharging() {
        isRecharging = false
    }

    public var isEmpty: Bool {
        return percent <= 0.0
    }

    public var isFull: Bool {
        return percent >= 100.0
    }
}

// MARK: - Level & Medal Types
public typealias LevelID = String

public enum Medal: String, CaseIterable, Codable {
    case bronze = "bronze"
    case silver = "silver"
    case gold = "gold"
}

// MARK: - Player Stats (Legacy - use PlayerProfile instead)
public struct PlayerStats {
    public var coins: Int
    public var deliveries: Int
    public var medals: [LevelID: Medal]

    public init(coins: Int = 0, deliveries: Int = 0, medals: [LevelID: Medal] = [:]) {
        self.coins = coins
        self.deliveries = deliveries
        self.medals = medals
    }

    public mutating func addCoins(_ amount: Int) {
        coins += amount
    }

    public mutating func incrementDeliveries() {
        deliveries += 1
    }

    public mutating func awardMedal(_ medal: Medal, for level: LevelID) {
        if let currentMedal = medals[level] {
            // Only update if new medal is better
            let medalValues: [Medal: Int] = [.bronze: 1, .silver: 2, .gold: 3]
            if medalValues[medal, default: 0] > medalValues[currentMedal, default: 0] {
                medals[level] = medal
            }
        } else {
            medals[level] = medal
        }
    }
}

// MARK: - Step 3 Progression System

/// Main player profile that persists progression data
public struct PlayerProfile: Codable {
    public var coins: Int
    public var medals: [LevelID: Medal]
    public var unlockedZones: Int
    public var layouts: [LevelLayout]
    public var unlockedSkins: Set<String>
    public var unlockedCrateTypes: Set<String>
    public var bestTimes: [LevelID: TimeInterval]
    public var totalDeliveries: Int
    public var totalSandboxTime: TimeInterval

    public init() {
        self.coins = 0
        self.medals = [:]
        self.unlockedZones = 1
        self.layouts = []
        self.unlockedSkins = ["default"]
        self.unlockedCrateTypes = ["medium", "large"]
        self.bestTimes = [:]
        self.totalDeliveries = 0
        self.totalSandboxTime = 0
    }

    public mutating func addCoins(_ amount: Int) {
        coins = max(0, coins + amount)
    }

    public mutating func spendCoins(_ amount: Int) -> Bool {
        guard coins >= amount else { return false }
        coins -= amount
        return true
    }

    public mutating func awardMedal(_ medal: Medal, for level: LevelID) {
        if let currentMedal = medals[level] {
            let medalValues: [Medal: Int] = [.bronze: 1, .silver: 2, .gold: 3]
            if medalValues[medal, default: 0] > medalValues[currentMedal, default: 0] {
                medals[level] = medal
            }
        } else {
            medals[level] = medal
        }
    }

    public mutating func setBestTime(_ time: TimeInterval, for level: LevelID) {
        if let currentBest = bestTimes[level] {
            if time < currentBest {
                bestTimes[level] = time
            }
        } else {
            bestTimes[level] = time
        }
    }

    public mutating func unlockSkin(_ skinID: String) {
        unlockedSkins.insert(skinID)
    }

    public mutating func unlockCrateType(_ crateType: String) {
        unlockedCrateTypes.insert(crateType)
    }

    public mutating func saveLayout(_ layout: LevelLayout) {
        layouts.append(layout)
    }

    public func hasUnlockedSkin(_ skinID: String) -> Bool {
        return unlockedSkins.contains(skinID)
    }

    public func hasUnlockedCrateType(_ crateType: String) -> Bool {
        return unlockedCrateTypes.contains(crateType)
    }
}

/// Economy controller for managing coins and unlocks
@MainActor
@Observable
public class EconomyModel {
    public var playerProfile = PlayerProfile()
    private let userDefaults = UserDefaults.standard
    private let profileKey = "PlayerProfile"

    public init() {
        loadProfile()
    }

    public func saveProfile() {
        do {
            let data = try JSONEncoder().encode(playerProfile)
            userDefaults.set(data, forKey: profileKey)
        } catch {
            gameLog("Failed to save player profile: \(error)")
        }
    }

    public func loadProfile() {
        guard let data = userDefaults.data(forKey: profileKey) else {
            gameLog("No saved profile found, using default")
            return
        }

        do {
            playerProfile = try JSONDecoder().decode(PlayerProfile.self, from: data)
        } catch {
            gameLog("Failed to load player profile: \(error)")
            playerProfile = PlayerProfile()
        }
    }

    public func awardCoins(_ amount: Int, reason: String = "") {
        playerProfile.addCoins(amount)
        saveProfile()
        gameLog("Awarded \(amount) coins: \(reason)")
    }

    public func spendCoins(_ amount: Int, on item: String = "") -> Bool {
        let success = playerProfile.spendCoins(amount)
        if success {
            saveProfile()
            gameLog("Spent \(amount) coins on: \(item)")
        }
        return success
    }

    public func awardMedal(_ medal: Medal, for level: LevelID) {
        playerProfile.awardMedal(medal, for: level)

        // Award coins based on medal type
        let coinReward: Int
        switch medal {
        case .bronze: coinReward = 50
        case .silver: coinReward = 100
        case .gold: coinReward = 200
        }

        awardCoins(coinReward, reason: "\(medal.rawValue) medal for \(level)")
        checkForUnlocks()
    }

    private func checkForUnlocks() {
        let totalMedals = playerProfile.medals.count
        let goldMedals = playerProfile.medals.values.filter { $0 == .gold }.count

        // Unlock new zones based on total medals
        let newUnlockedZones = min(5, (totalMedals / 3) + 1)
        if newUnlockedZones > playerProfile.unlockedZones {
            playerProfile.unlockedZones = newUnlockedZones
            gameLog("Unlocked zone \(newUnlockedZones)!")
        }

        // Unlock skins based on achievements
        if goldMedals >= 3 && !playerProfile.hasUnlockedSkin("gold") {
            playerProfile.unlockSkin("gold")
            gameLog("Unlocked gold skin!")
        }

        if playerProfile.totalDeliveries >= 50 && !playerProfile.hasUnlockedSkin("veteran") {
            playerProfile.unlockSkin("veteran")
            gameLog("Unlocked veteran skin!")
        }

        saveProfile()
    }
}

// MARK: - Package Types for Step 3
public enum PackageType: String, CaseIterable, Codable {
    case generic = "generic"
    case energyPod = "energy_pod"
    case toyCrate = "toy_crate"
    case priorityCargo = "priority_cargo"

    public var displayName: String {
        switch self {
        case .generic: return "Generic Package"
        case .energyPod: return "Energy Pod"
        case .toyCrate: return "Toy Crate"
        case .priorityCargo: return "Priority Cargo"
        }
    }

    public var coinMultiplier: Float {
        switch self {
        case .generic: return 1.0
        case .energyPod: return 1.5
        case .toyCrate: return 1.2
        case .priorityCargo: return 2.0
        }
    }
}

// MARK: - Game Job
public struct Job {
    public let id: UUID
    public let pickupZoneID: String
    public let deliveryZoneID: String
    public let timeLimit: TimeInterval
    public let packageSpec: PackageSpec
    public var isCompleted: Bool = false
    public var isPickedUp: Bool = false
    public var startTime: TimeInterval?

    public init(id: UUID = UUID(), pickupZoneID: String, deliveryZoneID: String, timeLimit: TimeInterval, packageSpec: PackageSpec) {
        self.id = id
        self.pickupZoneID = pickupZoneID
        self.deliveryZoneID = deliveryZoneID
        self.timeLimit = timeLimit
        self.packageSpec = packageSpec
    }

    public var remainingTime: TimeInterval {
        guard let startTime = startTime else { return timeLimit }
        let elapsed = CACurrentMediaTime() - startTime
        return max(0, timeLimit - elapsed)
    }

    public var isExpired: Bool {
        return remainingTime <= 0
    }

    public mutating func start() {
        startTime = CACurrentMediaTime()
    }
}

// Legacy support - can be removed if no longer needed
public struct GameJob {
    public let id: String
    public let pickupLocation: SIMD3<Float>
    public let deliveryLocation: SIMD3<Float>
    public let reward: Int
    public let timeLimit: TimeInterval?
    public var isCompleted: Bool = false
    public var isPickedUp: Bool = false

    public init(id: String, pickupLocation: SIMD3<Float>, deliveryLocation: SIMD3<Float>, reward: Int, timeLimit: TimeInterval? = nil) {
        self.id = id
        self.pickupLocation = pickupLocation
        self.deliveryLocation = deliveryLocation
        self.reward = reward
        self.timeLimit = timeLimit
    }
}

// MARK: - Drone State
public enum DroneState {
    case idle
    case flying
    case carryingParcel
    case recharging
    case emergency
}

// MARK: - Interaction Type
public enum InteractionType {
    case pickup
    case drop
    case dock
    case none
}

// MARK: - Player Ranking System

public struct PlayerRank: Codable {
    public var level: Int
    public var xp: Int
    public var kills: Int
    public var deaths: Int

    public init(level: Int = 1, xp: Int = 0, kills: Int = 0, deaths: Int = 0) {
        self.level = max(1, min(10, level))
        self.xp = max(0, xp)
        self.kills = max(0, kills)
        self.deaths = max(0, deaths)
    }

    public var kdr: Float {
        guard deaths > 0 else { return Float(kills) }
        return Float(kills) / Float(deaths)
    }

    public var xpForCurrentLevel: Int {
        return PlayerRank.xpRequiredForLevel(level)
    }

    public var xpForNextLevel: Int {
        guard level < 10 else { return xpForCurrentLevel }
        return PlayerRank.xpRequiredForLevel(level + 1)
    }

    public var progressToNextLevel: Float {
        guard level < 10 else { return 1.0 }
        let currentLevelXP = xpForCurrentLevel
        let nextLevelXP = xpForNextLevel
        let progressXP = xp - currentLevelXP
        let totalXPNeeded = nextLevelXP - currentLevelXP
        return Float(progressXP) / Float(totalXPNeeded)
    }

    public var rankIconName: String {
        return "Rank\(level)"
    }

    public static func xpRequiredForLevel(_ level: Int) -> Int {
        guard level >= 1 && level <= 10 else { return 0 }

        switch level {
        case 1: return 0
        case 2: return 100
        case 3: return 250
        case 4: return 450
        case 5: return 700
        case 6: return 1000
        case 7: return 1350
        case 8: return 1750
        case 9: return 2200
        case 10: return 2700
        default: return 0
        }
    }

    public mutating func addXP(_ amount: Int) {
        xp += amount
        updateLevel()
    }

    public mutating func addKill() {
        kills += 1
    }

    public mutating func addDeath() {
        deaths += 1
    }

    private mutating func updateLevel() {
        while level < 10 && xp >= PlayerRank.xpRequiredForLevel(level + 1) {
            level += 1
        }
    }

    public static func xpForWin() -> Int { return 50 }
    public static func xpForLoss() -> Int { return 20 }
    public static func xpForKill() -> Int { return 10 }
}

@MainActor
@Observable
public class PlayerRankManager {
    public var localPlayerRank = PlayerRank()
    private let userDefaults = UserDefaults.standard
    private let rankKey = "LocalPlayerRank"

    public init() {
        loadRank()
    }

    public func saveRank() {
        do {
            let data = try JSONEncoder().encode(localPlayerRank)
            userDefaults.set(data, forKey: rankKey)
        } catch {
            gameLog("Failed to save player rank: \(error)")
        }
    }

    public func loadRank() {
        guard let data = userDefaults.data(forKey: rankKey) else {
            gameLog("No saved rank found, using default")
            return
        }

        do {
            localPlayerRank = try JSONDecoder().decode(PlayerRank.self, from: data)
        } catch {
            gameLog("Failed to load player rank: \(error)")
            localPlayerRank = PlayerRank()
        }
    }

    public func awardGameWin() {
        let oldLevel = localPlayerRank.level
        localPlayerRank.addXP(PlayerRank.xpForWin())
        saveRank()

        if localPlayerRank.level > oldLevel {
            gameLog("Level up! Now level \(localPlayerRank.level)")
        }
        gameLog("Awarded \(PlayerRank.xpForWin()) XP for winning (Total: \(localPlayerRank.xp))")
    }

    public func awardGameLoss() {
        let oldLevel = localPlayerRank.level
        localPlayerRank.addXP(PlayerRank.xpForLoss())
        saveRank()

        if localPlayerRank.level > oldLevel {
            gameLog("Level up! Now level \(localPlayerRank.level)")
        }
        gameLog("Awarded \(PlayerRank.xpForLoss()) XP for participation (Total: \(localPlayerRank.xp))")
    }

    public func awardKill() {
        let oldLevel = localPlayerRank.level
        localPlayerRank.addKill()
        localPlayerRank.addXP(PlayerRank.xpForKill())
        saveRank()

        if localPlayerRank.level > oldLevel {
            gameLog("Level up! Now level \(localPlayerRank.level)")
        }
        gameLog("Kill recorded! Awarded \(PlayerRank.xpForKill()) XP (Total: \(localPlayerRank.xp))")
    }

    public func recordDeath() {
        localPlayerRank.addDeath()
        saveRank()
        gameLog("Death recorded. K/D ratio: \(String(format: "%.2f", localPlayerRank.kdr))")
    }
}
