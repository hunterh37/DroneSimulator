//
//  RaceLeagueManager.swift
//  HelicopterGame
//
//  Mini Drone Race League: setup (track, laps, difficulty, field size, season or quick race),
//  grid + countdown, live race vs CPU pilots, results, league points and season standings.
//

import Foundation
import Observation
import QuartzCore
import RealityKit
import simd

@MainActor
@Observable
final class RaceLeagueManager {
    static let shared = RaceLeagueManager()

    enum Phase: Equatable { case idle, setup, countdown, racing, finished }
    enum RaceType: String, CaseIterable, Identifiable { case season, quickRace; var id: String { rawValue } }

    struct LiveStanding: Identifiable, Equatable {
        let id: String
        let tag: String
        let isPlayer: Bool
        let lap: Int
        let finished: Bool
    }

    // MARK: Setup options
    var raceType: RaceType = .season { didSet { if oldValue != raceType { rebuildArena() } } }
    var quickTrack: RaceTrackID = .neonOval { didSet { if oldValue != quickTrack { rebuildArena() } } }
    var laps = 3
    var difficulty: RaceDifficulty = .hard
    var opponentCount = 5 { didSet { if oldValue != opponentCount { rebuildArena() } } }
    /// Race Practice: quick race with a tracking arrow over the player drone.
    var isPractice = false
    static let lapOptions = [1, 3, 5, 10]
    static let opponentOptions = [3, 5, 7]

    // MARK: Live state
    private(set) var phase: Phase = .idle
    private(set) var countdown = 0
    private(set) var raceTime: TimeInterval = 0
    private(set) var currentLapTime: TimeInterval = 0
    private(set) var lastLapTime: TimeInterval?
    private(set) var bestLapTime: TimeInterval?
    private(set) var lap = 0
    private(set) var position = 1
    private(set) var nextGate = 0
    private(set) var wrongWay = false
    private(set) var newTrackRecord = false
    private(set) var standings: [LiveStanding] = []
    private(set) var results: [RaceResultEntry] = []
    private(set) var season = RaceLeagueSeason.load()
    private(set) var lastRoundTrack: RaceTrackID?
    private(set) var seasonJustCompleted = false

    var track: RaceTrackID { raceType == .season ? season.currentTrack : quickTrack }
    var fieldSize: Int { opponentCount + 1 }
    var pilots: [RacePilot] { Array(RacePilot.cpuRoster.prefix(opponentCount)) + [player] }

    @ObservationIgnored private var player = RacePilot.player(name: "You")
    @ObservationIgnored private weak var parent: Entity?
    @ObservationIgnored private weak var drone: PlayerDroneEntity?
    @ObservationIgnored private var arena: RaceArena?
    @ObservationIgnored private var raceTrack: RaceTrack?
    @ObservationIgnored private var cpuEntities: [Entity] = []
    @ObservationIgnored private var tickTimer: Timer?
    @ObservationIgnored private var raceStart: CFTimeInterval = 0
    @ObservationIgnored private var countdownEnd: CFTimeInterval = 0
    @ObservationIgnored private var lapStart: TimeInterval = 0
    @ObservationIgnored private var gatesPassed = 0
    @ObservationIgnored private var prevGateSide: Float?
    @ObservationIgnored private var lastPlayerPos: SIMD3<Float>?
    @ObservationIgnored private var wrongWayTime: Float = 0
    @ObservationIgnored private var playerFinishTime: TimeInterval?
    @ObservationIgnored private var litGate = -1
    @ObservationIgnored private let tickRate: TimeInterval = 1.0 / 45.0

    private init() {}

    static func registerECS() {
        RaceAIComponent.registerComponent()
        RaceAISystem.registerSystem()
        LowPolyDroneFactory.registerECS()
        PlayerMarkerComponent.registerComponent()
        PlayerMarkerSystem.registerSystem()
    }

    // MARK: - Lifecycle

    func start(in parent: Entity, drone: PlayerDroneEntity?) {
        stop()
        self.parent = parent
        self.drone = drone
        let name = GameContext.shared.playerProfile.playerName.trimmingCharacters(in: .whitespaces)
        player = RacePilot.player(name: name.isEmpty ? "You" : name)
        season = RaceLeagueSeason.load()
        if season.isComplete { season.round = 0; season.points = [:] }
        if isPractice { raceType = .quickRace }
        phase = .setup
        rebuildArena()
        if isPractice { PlayerMarker.attach(to: parent, tracking: drone) }
        tickTimer = Timer.scheduledTimer(withTimeInterval: tickRate, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        gameLog("[RaceLeague] started")
    }

    func stop() {
        tickTimer?.invalidate()
        tickTimer = nil
        RaceAISystem.isRacing = false
        RaceAISystem.track = nil
        PlayerMarker.detach()
        arena?.root.removeFromParent()
        arena = nil
        cpuEntities = []
        if let drone {
            drone.isCrashActive = false
            drone.setPosition([0, 0.3, -1.3], relativeTo: parent)
            drone.orientation = simd_quatf(angle: 0, axis: [0, 1, 0])
        }
        phase = .idle
    }

    /// Back to the setup screen on the same arena.
    func returnToSetup() {
        seasonJustCompleted = false
        if season.isComplete { season.round = 0; season.points = [:]; season.save() }
        phase = .setup
        rebuildArena()
    }

    func resetSeason() {
        season = RaceLeagueSeason()
        season.save()
        rebuildArena()
    }

    // MARK: - Arena + grid

    private func rebuildArena() {
        guard phase == .setup, let parent else { return }
        arena?.root.removeFromParent()
        let t = RaceTrack(track)
        let a = RaceArenaBuilder.build(track: t)

        // Keep the whole venue in front of the pilot: centered on x, far edge ahead.
        var lo = t.bounds.min, hi = t.bounds.max
        for slot in a.gridSlots { lo = simd_min(lo, slot.position); hi = simd_max(hi, slot.position) }
        a.root.position = [-(lo.x + hi.x) * 0.5, 0, -2.2 - hi.z]
        parent.addChild(a.root)

        arena = a
        raceTrack = t
        RaceAISystem.track = t
        RaceAISystem.isRacing = false
        litGate = -1
        placeGrid()
    }

    private func placeGrid() {
        guard let arena, let raceTrack else { return }
        cpuEntities.forEach { $0.removeFromParent() }
        cpuEntities = []
        let cpus = Array(RacePilot.cpuRoster.prefix(opponentCount))
        let finishS = raceTrack.length * Float(laps)
        for (i, pilot) in cpus.enumerated() {
            let slot = arena.gridSlots[i]
            let e = LowPolyDroneFactory.make(pilot.style, livery: DroneLivery.presets[pilot.liveryIndex % DroneLivery.presets.count])
            e.name = "CPU.\(pilot.id)"
            // Grid slot expressed as distance behind the start gate.
            let back = simd_distance(SIMD2(slot.position.x, slot.position.z), SIMD2(raceTrack.gates[0].position.x, raceTrack.gates[0].position.z))
            let skill = pilot.skill * pilot.style.raceSpeedFactor
            var ai = RaceAIComponent(pilotID: pilot.id, s: -back, topSpeed: difficulty.topSpeed * skill,
                                     grip: difficulty.grip * skill, accel: difficulty.acceleration * skill,
                                     mistakeRate: difficulty.mistakeRate, rubberBand: difficulty.rubberBand)
            ai.lane = (i % 2 == 0 ? -0.55 : 0.55)
            ai.laneTarget = ai.lane
            ai.heightOffset = Float.random(in: -0.12...0.12)
            ai.finishS = finishS
            ai.bobPhase = Float(i)
            e.components.set(ai)
            arena.root.addChild(e)
            cpuEntities.append(e)
        }
        // Player takes the next slot.
        if let drone {
            let slot = arena.gridSlots[min(cpus.count, arena.gridSlots.count - 1)]
            drone.isCrashActive = true
            drone.setPosition(slot.position, relativeTo: arena.root)
            drone.setOrientation(simd_quatf(angle: slot.yaw, axis: [0, 1, 0]), relativeTo: arena.root)
        }
        gatesPassed = 0
        prevGateSide = nil
        lastPlayerPos = nil
        playerFinishTime = nil
        lap = 0; nextGate = 0; position = fieldSize
        raceTime = 0; currentLapTime = 0; lastLapTime = nil; bestLapTime = nil
        wrongWay = false; newTrackRecord = false
        updateGateHighlight()
        refreshStandings()
    }

    // MARK: - Race flow

    func beginRace() {
        guard phase == .setup else { return }
        results = []
        placeGrid()
        countdownEnd = CACurrentMediaTime() + 3
        countdown = 3
        phase = .countdown
    }

    func restartRace() {
        phase = .setup
        rebuildArena()
        beginRace()
    }

    /// Teleport behind the last gate cleared, facing the next one.
    func resetToLastGate() {
        guard phase == .racing, let arena, let raceTrack, let drone else { return }
        let n = raceTrack.gates.count
        let last = raceTrack.gates[(max(gatesPassed, 1) - 1) % n]
        let g = gatesPassed == 0 ? raceTrack.gates[0] : last
        let p = g.position - g.forward * (gatesPassed == 0 ? 1.2 : -0.6)
        drone.setPosition(p, relativeTo: arena.root)
        let f = simd_normalize(SIMD3(g.forward.x, 0, g.forward.z))
        drone.setOrientation(simd_quatf(angle: atan2(-f.x, -f.z), axis: [0, 1, 0]), relativeTo: arena.root)
        prevGateSide = nil
        lastPlayerPos = nil
    }

    func retire() {
        guard phase == .racing || phase == .countdown else { return }
        finishRace(playerDNF: true)
    }

    // MARK: - Tick

    private func tick() {
        switch phase {
        case .countdown:
            let remaining = countdownEnd - CACurrentMediaTime()
            let c = Int(ceil(remaining))
            if c != countdown { countdown = max(0, c) }
            if remaining <= 0 { go() }
        case .racing:
            raceTime = CACurrentMediaTime() - raceStart
            RaceAISystem.raceClock = raceTime
            trackPlayer()
            refreshStandings()
            if playerFinishTime != nil { finishRace(playerDNF: false) }
            else if cpuEntities.allSatisfy({ $0.components[RaceAIComponent.self]?.finishTime != nil }),
                    let lastCPU = cpuEntities.compactMap({ $0.components[RaceAIComponent.self]?.finishTime }).max(),
                    raceTime - lastCPU > 45 {
                finishRace(playerDNF: true)
            }
        default:
            break
        }
    }

    private func go() {
        countdown = 0
        phase = .racing
        raceStart = CACurrentMediaTime()
        lapStart = 0
        RaceAISystem.raceClock = 0
        RaceAISystem.isRacing = true
        drone?.isCrashActive = false
        if let gate = arena?.root.children.first(where: { $0.name == "RaceGate_0" }) {
            GameContext.shared.sound.playWaveStartSound(entity: gate)
        }
    }

    private func trackPlayer() {
        guard let arena, let raceTrack, let drone else { return }
        let p = drone.position(relativeTo: arena.root)
        let n = raceTrack.gates.count
        let gate = raceTrack.gates[gatesPassed % n]
        let rel = p - gate.position
        let side = simd_dot(rel, gate.forward)

        if let prev = prevGateSide, prev < 0, side >= 0 {
            let flatF = simd_normalize(SIMD3(gate.forward.x, 0, gate.forward.z))
            let right = simd_normalize(simd_cross(flatF, [0, 1, 0]))
            let slack: Float = 0.2
            if abs(simd_dot(rel, right)) < gate.halfSize + slack && abs(rel.y) < gate.halfSize + slack {
                passGate(gate)
            }
        }
        prevGateSide = gatesPassed % n == gate.index ? side : nil

        // Wrong way: moving away from the next gate while facing against the track.
        if let last = lastPlayerPos {
            let v = (p - last) / Float(tickRate)
            let target = raceTrack.gates[gatesPassed % n]
            let toGate = simd_normalize(target.position - p)
            if simd_length(v) > 0.8 && simd_dot(simd_normalize(v), toGate) < -0.35 {
                wrongWayTime += Float(tickRate)
            } else {
                wrongWayTime = max(0, wrongWayTime - Float(tickRate) * 2)
            }
            wrongWay = wrongWayTime > 1.2
        }
        lastPlayerPos = p

        currentLapTime = gatesPassed == 0 ? 0 : raceTime - lapStart
        RaceAISystem.playerS = playerDistance(p)
        let g = raceTrack.gates[gatesPassed % n]
        arena.nextGateBeacon.position = g.position + [0, g.halfSize + 0.35 + sin(Float(raceTime) * 4) * 0.05, 0]
    }

    /// Demo/test surface: a point just past the next gate plane, in `root` space.
    func demoNextGate(relativeTo root: Entity) -> SIMD3<Float>? {
        guard let arena, let raceTrack, !raceTrack.gates.isEmpty else { return nil }
        let g = raceTrack.gates[gatesPassed % raceTrack.gates.count]
        return arena.root.convert(position: g.position + g.forward * 0.35, to: root)
    }

    private func passGate(_ gate: RaceGate) {
        guard let raceTrack else { return }
        let n = raceTrack.gates.count
        gatesPassed += 1
        prevGateSide = nil
        if let e = arena?.root.children.first(where: { $0.name == "RaceGate_\(gate.index)" }) {
            GameContext.shared.sound.playRingCollectSound(entity: e)
        }
        if gatesPassed == 1 {
            lapStart = raceTime
            lap = 1
        } else if (gatesPassed - 1) % n == 0 {
            let lt = raceTime - lapStart
            lastLapTime = lt
            if bestLapTime.map({ lt < $0 }) ?? true { bestLapTime = lt }
            if RaceRecords.submitLap(lt, track: track) { newTrackRecord = true }
            lapStart = raceTime
            if gatesPassed >= laps * n + 1 {
                playerFinishTime = raceTime
            } else {
                lap += 1
            }
        }
        nextGate = gatesPassed % n
        updateGateHighlight()
    }

    private func playerDistance(_ p: SIMD3<Float>) -> Float {
        guard let raceTrack else { return 0 }
        let n = raceTrack.gates.count
        let next = raceTrack.gates[gatesPassed % n]
        if gatesPassed == 0 { return -simd_distance(p, next.position) }
        let prevIndex = (gatesPassed - 1) % n
        let prev = raceTrack.gates[prevIndex]
        let lapsDone = Float((gatesPassed - 1) / n)
        let base = lapsDone * raceTrack.length + prev.s
        let seg = next.index == 0 ? raceTrack.length - prev.s : next.s - prev.s
        let segDirect = max(0.1, simd_distance(prev.position, next.position))
        let frac = max(0, min(1, 1 - simd_distance(p, next.position) / segDirect))
        return base + frac * seg
    }

    private func updateGateHighlight() {
        guard let arena, litGate != nextGate || litGate < 0 else { return }
        for (i, g) in arena.gateGlows.enumerated() {
            let color = i == nextGate ? RaceArenaBuilder.gateNext : (i == 0 ? RaceArenaBuilder.gateStart : RaceArenaBuilder.gateIdle)
            g.model?.materials = [RaceArenaBuilder.glow(color, i == nextGate ? 1 : 0.55)]
        }
        litGate = nextGate
    }

    private func refreshStandings() {
        guard let raceTrack else { return }
        struct Row { let pilot: RacePilot; let s: Float; let finish: Double? }
        var rows: [Row] = []
        let byID = Dictionary(uniqueKeysWithValues: pilots.map { ($0.id, $0) })
        for e in cpuEntities {
            guard let ai = e.components[RaceAIComponent.self], let pilot = byID[ai.pilotID] else { continue }
            rows.append(Row(pilot: pilot, s: ai.s, finish: ai.finishTime))
        }
        rows.append(Row(pilot: player, s: RaceAISystem.playerS, finish: playerFinishTime))
        rows.sort { a, b in
            switch (a.finish, b.finish) {
            case let (x?, y?): return x < y
            case (.some, nil): return true
            case (nil, .some): return false
            default: return a.s > b.s
            }
        }
        let L = raceTrack.length
        let new = rows.map { r in
            LiveStanding(id: r.pilot.id, tag: r.pilot.tag, isPlayer: r.pilot.isPlayer,
                         lap: max(0, min(laps, Int(floor(max(0, r.s) / L)) + 1)), finished: r.finish != nil)
        }
        if new != standings { standings = new }
        position = (rows.firstIndex { $0.pilot.isPlayer } ?? 0) + 1
    }

    // MARK: - Results

    private func finishRace(playerDNF: Bool) {
        guard let raceTrack else { return }
        RaceAISystem.isRacing = true // CPU keep flying their cool-down lap
        let finishS = raceTrack.length * Float(laps)
        var times: [(RacePilot, TimeInterval, TimeInterval, Bool)] = []
        let byID = Dictionary(uniqueKeysWithValues: pilots.map { ($0.id, $0) })
        for e in cpuEntities {
            guard let ai = e.components[RaceAIComponent.self], let pilot = byID[ai.pilotID] else { continue }
            let t = ai.finishTime ?? raceTime + Double(max(0, finishS - ai.s) / max(1, ai.topSpeed * 0.82))
            let best = ai.bestLap < .greatestFiniteMagnitude ? ai.bestLap : t / Double(laps)
            times.append((pilot, t, best, false))
        }
        let playerTime = playerDNF ? .greatestFiniteMagnitude : (playerFinishTime ?? raceTime)
        times.append((player, playerTime, bestLapTime ?? 0, playerDNF))
        times.sort { $0.1 < $1.1 }

        results = times.enumerated().map { i, row in
            let pts = row.3 ? 0 : RaceLeaguePoints.points(forPosition: i + 1)
            return RaceResultEntry(pilot: row.0, position: i + 1, totalTime: row.3 ? 0 : row.1, bestLap: row.2, points: pts)
        }

        let playerPos = results.first { $0.pilot.isPlayer }?.position ?? fieldSize
        var xp = playerDNF ? 5 : (fieldSize - playerPos + 1) * 12 * difficulty.xpMultiplier + laps * 4
        if playerPos == 1 && !playerDNF { xp += 50 * difficulty.xpMultiplier }

        lastRoundTrack = track
        if raceType == .season {
            for r in results { season.points[r.pilot.id, default: 0] += r.points }
            season.round += 1
            if season.isComplete {
                seasonJustCompleted = true
                if seasonStandings.first?.pilot.isPlayer == true {
                    season.seasonsWon += 1
                    xp += 200 * difficulty.xpMultiplier
                }
            }
            season.save()
        }
        let rank = PlayerRankManager()
        rank.localPlayerRank.addXP(xp)
        rank.saveRank()

        drone?.isCrashActive = false
        phase = .finished
        gameLog("[RaceLeague] finished P\(playerPos) of \(fieldSize) on \(track.displayName)")
    }

    /// Season table sorted by points (all pilots in the current field).
    var seasonStandings: [(pilot: RacePilot, points: Int)] {
        pilots.map { ($0, season.points[$0.id] ?? 0) }.sorted { $0.1 > $1.1 }
    }

    func nextRound() {
        returnToSetup()
    }
}
