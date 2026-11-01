//
//  ArenaHomeView.swift
//  HelicopterGame
//
//  Step 01, the start grid. Title lockup, then the two events as big
//  broadcast cards. Picking an event is the first decision, so it is the
//  first thing on screen. Pilot record sits underneath as a compact strip.
//

import SwiftUI

struct ArenaEvent: Identifiable, Equatable {
    let mode: GameMode
    let name: String
    let strap: String
    let brief: String
    let icon: String
    let tint: Color
    let number: String
    var isPractice = false
    var id: String { number }

    static let race = ArenaEvent(mode: .playRaceLeague, name: "Race League", strap: "Armed stadium racing",
                                 brief: "Full-scale circuit vs CPU pilots. Three-round season.",
                                 icon: "flag.checkered", tint: Arena.volt, number: "01")
    static let safari = ArenaEvent(mode: .playSafari, name: "Safari", strap: "Island hunt, against the clock",
                                   brief: "Five zones. Pop critters, chain combos, beat the timer.",
                                   icon: "pawprint.fill", tint: Arena.go, number: "02")
    static let practice = ArenaEvent(mode: .playRaceLeague, name: "Race Practice", strap: "Solo laps, marked drone",
                                     brief: "Quick race with your drone flagged by an arrow. Easy to track.",
                                     icon: "arrowtriangle.down.fill", tint: Arena.heat, number: "04", isPractice: true)
    static let crates = ArenaEvent(mode: .playCrateDelivery, name: "Fold Freight", strap: "Endless crate sort, in your room",
                                   brief: "Hook falling crates, sort them by realm. Stack for multipliers.",
                                   icon: "shippingbox.fill", tint: Arena.ice, number: "03")
    static let all = [race, safari, crates, practice]
}

struct ArenaHomeView: View {
    let multiplayerManager: MultiplayerManager
    let onPick: (ArenaEvent) -> Void
    let onRankHelp: () -> Void

    @State private var health = GameContext.shared.health
    @State private var appeared = false
    private var rank: PlayerRank { health.localPlayerRank }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            lockup.padding(.top, 30)
            VStack(spacing: 14) {
                ForEach(Array(ArenaEvent.all.enumerated()), id: \.element.id) { i, e in
                    eventCard(e)
                        .opacity(appeared ? 1 : 0)
                        .offset(x: appeared ? 0 : 60)
                        .animation(Arena.snap.delay(0.08 * Double(i) + 0.1), value: appeared)
                }
            }
            .padding(.top, 26)
            Spacer(minLength: 14)
            pilotStrip
            footer.padding(.top, 12).padding(.bottom, 18)
        }
        .padding(.horizontal, Arena.gutter)
        .onAppear { appeared = true }
    }

    // MARK: Lockup

    private var lockup: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                CheckerStrip(cell: 5).frame(width: 40, height: 10)
                Text("Battle Racing").arenaLabel(12, color: Arena.volt)
                Spacer()
                OnlinePlayerCountView(multiplayerManager: multiplayerManager)
            }
            Text("DRONE").font(Arena.display(74)).foregroundStyle(Arena.text).padding(.bottom, -22)
            HStack(alignment: .lastTextBaseline, spacing: 10) {
                Text("ARENA").font(Arena.display(74)).foregroundStyle(Arena.volt)
                Chevrons(count: 3, size: 26, color: Arena.heat).padding(.bottom, 14)
            }
        }
    }

    // MARK: Event card

    private func eventCard(_ e: ArenaEvent) -> some View {
        Button {
            ArenaSound.shared.play(.select, volume: 0.7)
            onPick(e)
        } label: {
            ZStack(alignment: .leading) {
                CutRect(cut: 22).fill(Arena.carbon)
                // Huge ghost number, broadcast style.
                Text(e.number)
                    .font(Arena.num(170))
                    .foregroundStyle(e.tint.opacity(0.1))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .offset(x: 10, y: 8)
                // Tint slab on the leading edge.
                Slant(lean: 0.3).fill(e.tint).frame(width: 14).padding(.leading, 18).padding(.vertical, 18)
                HStack(spacing: 18) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(e.strap).arenaLabel(11, color: e.tint)
                        Text(e.name).font(Arena.display(38)).foregroundStyle(Arena.text).textCase(.uppercase)
                    }
                    Spacer(minLength: 0)
                    VStack(spacing: 10) {
                        Image(systemName: e.icon).font(.system(size: 30, weight: .black)).foregroundStyle(e.tint)
                        Chevrons(count: 3, size: 14, color: e.tint)
                    }
                }
                .padding(.leading, 52)
                .padding(.trailing, 24)
            }
            .frame(height: 150)
            .overlay(CutRect(cut: 22).stroke(e.tint.opacity(0.35), lineWidth: 1.5))
            .contentShape(CutRect(cut: 22))
        }
        .buttonStyle(.plain)
        .hoverEffect(.lift)
    }

    // MARK: Pilot strip

    private var pilotStrip: some View {
        HStack(spacing: 16) {
            ZStack {
                Slant().fill(Arena.volt)
                Text("\(rank.level)").font(Arena.num(26)).foregroundStyle(Arena.ink)
            }
            .frame(width: 58, height: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text(pilotName).font(Arena.display(18)).foregroundStyle(Arena.text).textCase(.uppercase).lineLimit(1)
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Slant(lean: 1).fill(Arena.line)
                        Slant(lean: 1).fill(Arena.volt).frame(width: g.size.width * CGFloat(max(0, min(1, rank.progressToNextLevel))))
                    }
                }
                .frame(height: 5)
            }
            ArenaReadout(label: "K/D", value: String(format: "%.2f", rank.kdr), size: 22).frame(width: 56)
            ArenaReadout(label: "XP", value: "\(rank.xp)", size: 22).frame(width: 64)
            ArenaIconButton(icon: "info", size: 34, tint: Arena.textDim, action: onRankHelp)
        }
        .padding(14)
        .background(CutRect(cut: 12).fill(Arena.carbon))
        .overlay(CutRect(cut: 12).stroke(Arena.line, lineWidth: 1))
    }

    private var pilotName: String {
        let n = GameContext.shared.playerProfile.playerName
        return n.isEmpty ? "Rookie Pilot" : n
    }

    private var footer: some View {
        HStack {
            Text("Season 1").arenaLabel(10, color: Arena.textMute)
            Spacer()
            Button {
                if let url = URL(string: "https://dicyaninlabs.com") { UIApplication.shared.open(url) }
            } label: { Text("DicyaninLabs").arenaLabel(10, color: Arena.textMute) }
            .buttonStyle(.plain)
        }
    }
}
