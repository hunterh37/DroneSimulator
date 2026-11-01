//
//  RaceLeagueModels.swift
//  HelicopterGame
//
//  Difficulty, pilots, results and persisted league season for Mini Drone Race League.
//

import Foundation

enum RaceDifficulty: String, CaseIterable, Identifiable, Codable {
    case rookie, pro, hard, elite

    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }

    /// CPU straight-line top speed (player max is 4.0 m/s).
    var topSpeed: Float {
        switch self {
        case .rookie: return 2.7
        case .pro: return 3.25
        case .hard: return 3.75
        case .elite: return 4.15
        }
    }

    /// Lateral grip in m/s^2: cornering speed = sqrt(grip / curvature).
    var grip: Float {
        switch self {
        case .rookie: return 3.2
        case .pro: return 4.5
        case .hard: return 6.0
        case .elite: return 7.5
        }
    }

    var acceleration: Float {
        switch self {
        case .rookie: return 1.8
        case .pro: return 2.4
        case .hard: return 3.0
        case .elite: return 3.5
        }
    }

    /// Chance per second of a small wobble / lift-off mistake.
    var mistakeRate: Float {
        switch self {
        case .rookie: return 0.12
        case .pro: return 0.06
        case .hard: return 0.025
        case .elite: return 0.01
        }
    }

    /// Catch-up assist when far behind the player (fraction of top speed).
    var rubberBand: Float {
        switch self {
        case .rookie: return 0.04
        case .pro: return 0.06
        case .hard: return 0.08
        case .elite: return 0.10
        }
    }

    var xpMultiplier: Int {
        switch self {
        case .rookie: return 1
        case .pro: return 2
        case .hard: return 3
        case .elite: return 4
        }
    }
}

struct RacePilot: Identifiable, Hashable {
    let id: String
    let name: String
    let tag: String
    let style: LowPolyDroneStyle
    let liveryIndex: Int
    /// Per-pilot skill spread around difficulty (0.95...1.03).
    let skill: Float
    let isPlayer: Bool

    static let cpuRoster: [RacePilot] = [
        RacePilot(id: "vex", name: "Vex Marlow", tag: "VEX", style: .wasp, liveryIndex: 0, skill: 1.03, isPlayer: false),
        RacePilot(id: "kai", name: "Kai Tanaka", tag: "KAI", style: .hornet, liveryIndex: 1, skill: 1.02, isPlayer: false),
        RacePilot(id: "juno", name: "Juno Reyes", tag: "JNO", style: .razor, liveryIndex: 2, skill: 1.01, isPlayer: false),
        RacePilot(id: "bolt", name: "Bolt Okafor", tag: "BLT", style: .razor, liveryIndex: 3, skill: 0.995, isPlayer: false),
        RacePilot(id: "nyx", name: "Nyx Varga", tag: "NYX", style: .hornet, liveryIndex: 4, skill: 0.985, isPlayer: false),
        RacePilot(id: "ghost", name: "Ghost Lindqvist", tag: "GST", style: .falcon, liveryIndex: 5, skill: 0.975, isPlayer: false),
        RacePilot(id: "rook", name: "Rook Adeyemi", tag: "ROK", style: .cinewhoop, liveryIndex: 6, skill: 0.965, isPlayer: false)
    ]

    static func player(name: String) -> RacePilot {
        RacePilot(id: "player", name: name, tag: String(name.prefix(3)).uppercased(), style: .razor, liveryIndex: 7, skill: 1, isPlayer: true)
    }
}

struct RaceResultEntry: Identifiable {
    var id: String { pilot.id }
    let pilot: RacePilot
    let position: Int
    let totalTime: TimeInterval
    let bestLap: TimeInterval
    let points: Int
}

enum RaceLeaguePoints {
    static let table = [25, 18, 15, 12, 10, 8, 6, 4]
    static func points(forPosition p: Int) -> Int { p >= 1 && p <= table.count ? table[p - 1] : 0 }
}

/// Persisted season: 3 rounds, one per track; points carried across rounds.
struct RaceLeagueSeason: Codable {
    var round: Int = 0
    var points: [String: Int] = [:]
    var seasonsWon: Int = 0

    static let rounds = RaceTrackID.allCases
    var currentTrack: RaceTrackID { Self.rounds[min(round, Self.rounds.count - 1)] }
    var isComplete: Bool { round >= Self.rounds.count }

    private static let key = "raceLeague.season"

    static func load() -> RaceLeagueSeason {
        guard let data = UserDefaults.standard.data(forKey: key),
              let s = try? JSONDecoder().decode(RaceLeagueSeason.self, from: data) else { return RaceLeagueSeason() }
        return s
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) { UserDefaults.standard.set(data, forKey: Self.key) }
    }
}

enum RaceRecords {
    private static func key(_ track: RaceTrackID) -> String { "raceLeague.bestLap.\(track.rawValue)" }

    static func bestLap(_ track: RaceTrackID) -> TimeInterval? {
        let v = UserDefaults.standard.double(forKey: key(track))
        return v > 0 ? v : nil
    }

    @discardableResult
    static func submitLap(_ time: TimeInterval, track: RaceTrackID) -> Bool {
        if let best = bestLap(track), best <= time { return false }
        UserDefaults.standard.set(time, forKey: key(track))
        return true
    }
}

extension TimeInterval {
    var raceClock: String {
        let t = max(0, self)
        let m = Int(t) / 60, s = Int(t) % 60, ms = Int((t - floor(t)) * 1000)
        return String(format: "%d:%02d.%03d", m, s, ms)
    }
}
