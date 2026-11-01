//
//  RaceLeagueHUDView.swift
//  HelicopterGame
//
//  Race League overlay in BATTLE GRID style: setup sheet, start lights,
//  broadcast-style live tower, results classification.
//

import SwiftUI

struct RaceLeagueHUDView: View {
    @State private var league = RaceLeagueManager.shared
    var onMainMenu: () -> Void

    var body: some View {
        ZStack {
            switch league.phase {
            case .setup: RaceSetupPanel(league: league, onMainMenu: onMainMenu)
            case .countdown: StartLights(league: league)
            case .racing: RaceLiveHUD(league: league)
            case .finished: RaceResultsPanel(league: league, onMainMenu: onMainMenu)
            case .idle: EmptyView()
            }
        }
        .animation(Arena.snap, value: league.phase)
    }
}

// MARK: - Start lights

private struct StartLights: View {
    let league: RaceLeagueManager

    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { i in
                    let lit = league.countdown <= 3 - i || league.countdown == 0
                    Circle()
                        .fill(league.countdown == 0 ? Arena.go : (lit ? Arena.hostile : Arena.carbonHi))
                        .frame(width: 34, height: 34)
                        .overlay(Circle().stroke(Arena.lineStrong, lineWidth: 1))
                }
            }
            Text(league.countdown > 0 ? "\(league.countdown)" : "GO")
                .font(Arena.num(120))
                .foregroundStyle(league.countdown > 0 ? Arena.text : Arena.go)
                .contentTransition(.numericText())
            Text("\(league.track.displayName)  /  \(league.laps) laps  /  \(league.difficulty.displayName)")
                .arenaLabel(12, color: Arena.textDim)
        }
        .padding(30)
        .background(CutRect(cut: 20).fill(Arena.ink.opacity(0.9)))
        .overlay(CutRect(cut: 20).stroke(Arena.line, lineWidth: 1))
        .animation(Arena.punch, value: league.countdown)
    }
}

// MARK: - Setup

private struct RaceSetupPanel: View {
    @Bindable var league: RaceLeagueManager
    var onMainMenu: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(league.raceType == .season
                         ? "Round \(min(league.season.round + 1, RaceLeagueSeason.rounds.count)) of \(RaceLeagueSeason.rounds.count)"
                         : "Quick race").arenaLabel(12, color: Arena.volt)
                    Text("Race League").font(Arena.display(40)).foregroundStyle(Arena.text).textCase(.uppercase)
                }
                Spacer()
                if league.season.seasonsWon > 0 {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("Titles").arenaLabel(10, color: Arena.textMute)
                        Text("\(league.season.seasonsWon)").font(Arena.num(34)).foregroundStyle(Arena.volt)
                    }
                }
            }

            ArenaSegmented(options: [RaceLeagueManager.RaceType.season, .quickRace], selection: $league.raceType) {
                $0 == .season ? "Season" : "Quick Race"
            }

            if league.raceType == .quickRace {
                row("Track") {
                    ArenaSegmented(options: Array(RaceTrackID.allCases), selection: $league.quickTrack) { $0.displayName }
                }
            }

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(league.track.displayName).font(Arena.display(22)).foregroundStyle(Arena.text).textCase(.uppercase)
                    Text("\(league.track.subtitle)  /  \(league.track.gateCount) gates").font(Arena.body(12)).foregroundStyle(Arena.textDim)
                }
                Spacer()
                if let best = RaceRecords.bestLap(league.track) {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("Record").arenaLabel(10, color: Arena.textMute)
                        Text(best.raceClock).font(Arena.num(22)).foregroundStyle(Arena.volt)
                    }
                }
            }
            .padding(12)
            .background(CutRect(cut: 10).fill(Arena.carbonHi))

            row("Laps") {
                ArenaSegmented(options: RaceLeagueManager.lapOptions, selection: $league.laps) { "\($0)" }
            }
            row("CPU") {
                ArenaSegmented(options: Array(RaceDifficulty.allCases), selection: $league.difficulty) { $0.displayName }
            }
            row("Field") {
                ArenaSegmented(options: RaceLeagueManager.opponentOptions, selection: $league.opponentCount) { "\($0 + 1)" }
            }

            if league.raceType == .season && !league.season.points.isEmpty {
                SeasonTable(rows: league.seasonStandings).frame(maxHeight: 130)
            }

            ArenaPrimaryButton(title: "Race", icon: "flag.checkered", tint: Arena.volt) { league.beginRace() }
            HStack(spacing: 8) {
                if league.raceType == .season && league.season.round > 0 {
                    ArenaGhostButton(title: "Reset Season", tint: Arena.hostile) { league.resetSeason() }
                }
                Spacer()
                ArenaGhostButton(title: "Exit", icon: "xmark", action: onMainMenu)
            }
        }
        .padding(22)
        .frame(maxWidth: 560)
        .background(CutRect(cut: 22).fill(Arena.carbon.opacity(0.97)))
        .overlay(CutRect(cut: 22).stroke(Arena.volt.opacity(0.35), lineWidth: 1.5))
        .padding(.horizontal, 16)
    }

    private func row<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        HStack(spacing: 12) {
            Text(title).arenaLabel(12, color: Arena.textDim).frame(width: 46, alignment: .leading)
            content()
        }
    }
}

// MARK: - Live

private struct RaceLiveHUD: View {
    let league: RaceLeagueManager

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                // Position block: the single most important number.
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text("P").font(Arena.num(28)).foregroundStyle(Arena.ink)
                    Text("\(league.position)").font(Arena.num(64)).foregroundStyle(Arena.ink).contentTransition(.numericText())
                    Text("/\(league.fieldSize)").font(Arena.num(18)).foregroundStyle(Arena.ink.opacity(0.6))
                }
                .padding(.horizontal, 22)
                .frame(height: 84)
                .background(Slant().fill(Arena.volt))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Lap \(max(1, league.lap))/\(league.laps)").arenaLabel(12, color: Arena.volt)
                    Text(league.currentLapTime.raceClock).font(Arena.num(30)).foregroundStyle(Arena.text)
                    HStack(spacing: 10) {
                        if let last = league.lastLapTime { Text("LST \(last.raceClock)").font(Arena.num(13)).foregroundStyle(Arena.textDim) }
                        if let best = league.bestLapTime { Text("BST \(best.raceClock)").font(Arena.num(13)).foregroundStyle(Arena.go) }
                    }
                }
                .padding(.horizontal, 14)
                .frame(height: 84)
                .background(CutRect(cut: 10).fill(Arena.ink.opacity(0.88)))

                Spacer(minLength: 0)
            }
            .padding(.top, 120)
            .padding(.horizontal, 18)

            if league.wrongWay {
                Text("WRONG WAY")
                    .font(Arena.display(34)).foregroundStyle(Arena.text)
                    .padding(.horizontal, 30).frame(height: 52)
                    .background(Slant().fill(Arena.hostile))
                    .transition(.scale.combined(with: .opacity))
            } else {
                HStack(spacing: 8) {
                    Chevrons(count: 3, size: 12, color: Arena.volt)
                    Text("Gate \(league.nextGate + 1)").font(Arena.display(18)).foregroundStyle(Arena.text).textCase(.uppercase)
                }
                .padding(.horizontal, 18).frame(height: 36)
                .background(Slant().fill(Arena.ink.opacity(0.88)))
            }

            HStack(alignment: .top) {
                Spacer()
                tower
            }
            .padding(.horizontal, 18)

            Spacer()

            HStack(spacing: 8) {
                ArenaGhostButton(title: "Reset", icon: "arrow.uturn.backward", height: 38) { league.resetToLastGate() }
                ArenaGhostButton(title: "Retire", icon: "flag.slash", tint: Arena.hostile, height: 38) { league.retire() }
            }
            .padding(.bottom, 130)
        }
        .animation(Arena.snap, value: league.wrongWay)
    }

    /// Timing tower, broadcast style.
    private var tower: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(league.standings.enumerated()), id: \.element.id) { i, row in
                HStack(spacing: 8) {
                    Text("\(i + 1)").font(Arena.num(15)).foregroundStyle(row.isPlayer ? Arena.ink : Arena.textDim).frame(width: 18)
                    Text(row.tag).font(Arena.display(14)).foregroundStyle(row.isPlayer ? Arena.ink : Arena.text).textCase(.uppercase)
                    Spacer(minLength: 6)
                    Text(row.finished ? "FIN" : "L\(row.lap)").font(Arena.num(13)).foregroundStyle(row.isPlayer ? Arena.ink.opacity(0.7) : Arena.textMute)
                }
                .padding(.horizontal, 10).frame(height: 24)
                .background(Slant(lean: 0.3).fill(row.isPlayer ? Arena.volt : Arena.ink.opacity(0.88)))
            }
        }
        .frame(width: 150)
    }
}

// MARK: - Results

private struct RaceResultsPanel: View {
    let league: RaceLeagueManager
    var onMainMenu: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CheckerStrip(cell: 7).frame(height: 14)
            VStack(alignment: .leading, spacing: 0) {
                Text((league.lastRoundTrack ?? league.track).displayName + "  /  \(league.laps) laps  /  \(league.difficulty.displayName)")
                    .arenaLabel(11, color: Arena.textDim)
                Text(headline).font(Arena.display(48)).foregroundStyle(Arena.volt).textCase(.uppercase)
            }
            if league.newTrackRecord { ArenaTag(text: "New track record", tint: Arena.volt) }

            VStack(spacing: 3) {
                ForEach(league.results) { r in
                    let me = r.pilot.isPlayer
                    HStack(spacing: 10) {
                        Text("\(r.position)").font(Arena.num(20)).frame(width: 24)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(r.pilot.name).font(Arena.display(15)).textCase(.uppercase).lineLimit(1)
                            Text(r.pilot.style.displayName).font(Arena.body(10)).opacity(0.6).lineLimit(1)
                        }
                        Spacer()
                        Text(r.totalTime > 0 ? r.totalTime.raceClock : "DNF").font(Arena.num(16))
                        Text(r.bestLap > 0 ? r.bestLap.raceClock : "-").font(Arena.num(13)).opacity(0.6).frame(width: 66, alignment: .trailing)
                        Text("+\(r.points)").font(Arena.num(16)).frame(width: 38, alignment: .trailing)
                    }
                    .foregroundStyle(me ? Arena.ink : Arena.text)
                    .padding(.horizontal, 12).frame(height: 36)
                    .background(Slant(lean: 0.1).fill(me ? Arena.volt : Arena.carbonHi))
                }
            }

            if league.raceType == .season {
                Text(league.seasonJustCompleted ? "Final standings" : "Season standings").arenaLabel(11, color: Arena.textDim)
                SeasonTable(rows: league.seasonStandings).frame(maxHeight: 140)
            }

            if league.raceType == .season && !league.seasonJustCompleted {
                ArenaPrimaryButton(title: "Next Round", tint: Arena.volt) { league.nextRound() }
            } else if league.raceType == .season {
                ArenaPrimaryButton(title: "New Season", tint: Arena.volt) { league.nextRound() }
            } else {
                ArenaPrimaryButton(title: "Race Again", tint: Arena.volt) { league.restartRace() }
            }
            HStack(spacing: 8) {
                ArenaGhostButton(title: "Setup", icon: "slider.horizontal.3") { league.returnToSetup() }
                Spacer()
                ArenaGhostButton(title: "Menu", icon: "house.fill", action: onMainMenu)
            }
        }
        .padding(22)
        .frame(maxWidth: 580)
        .background(CutRect(cut: 22).fill(Arena.carbon.opacity(0.97)))
        .overlay(CutRect(cut: 22).stroke(Arena.volt.opacity(0.35), lineWidth: 1.5))
        .padding(.horizontal, 12)
    }

    private var headline: String {
        if league.seasonJustCompleted {
            return league.seasonStandings.first?.pilot.isPlayer == true ? "Champion" : "Season Over"
        }
        guard let p = league.results.first(where: { $0.pilot.isPlayer }), p.totalTime > 0 else { return "Retired" }
        switch p.position {
        case 1: return "Victory"
        case 2, 3: return "Podium P\(p.position)"
        default: return "Finished P\(p.position)"
        }
    }
}

private struct SeasonTable: View {
    let rows: [(pilot: RacePilot, points: Int)]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 2) {
                ForEach(Array(rows.enumerated()), id: \.element.pilot.id) { i, row in
                    let me = row.pilot.isPlayer
                    HStack {
                        Text("\(i + 1)").font(Arena.num(14)).frame(width: 20)
                        Text(row.pilot.name).font(Arena.display(13)).textCase(.uppercase)
                        Spacer()
                        Text("\(row.points)").font(Arena.num(15))
                        Text("PTS").arenaLabel(9, color: me ? Arena.ink.opacity(0.6) : Arena.textMute)
                    }
                    .foregroundStyle(me ? Arena.ink : Arena.text)
                    .padding(.horizontal, 10).frame(height: 26)
                    .background(Slant(lean: 0.15).fill(me ? Arena.volt : Arena.carbonHi))
                }
            }
        }
    }
}
