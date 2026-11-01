//
//  CrateDeliveryHUDView.swift
//  HelicopterGame
//
//  Fold Freight HUD: briefing card, tutorial coach, live shift readout,
//  end-of-shift report. BATTLE GRID styling, ICE is the event color.
//

import SwiftUI

struct CrateDeliveryHUDView: View {
    @State private var fold = CrateDeliveryManager.shared
    var onMainMenu: () -> Void

    private let tint = Arena.ice

    var body: some View {
        ZStack {
            switch fold.phase {
            case .briefing: briefing
            case .tutorial: tutorial
            case .playing: live
            case .finished: finished
            case .idle: EmptyView()
            }
        }
        .animation(Arena.snap, value: fold.phase)
    }

    // MARK: Briefing

    private var briefing: some View {
        VStack(alignment: .leading, spacing: 14) {
            CheckerStrip(cell: 7, color: tint).frame(height: 12)
            Text(CrateLore.kicker).arenaLabel(11, color: tint)
            Text(CrateLore.title).font(Arena.display(46)).foregroundStyle(Arena.text).textCase(.uppercase)
            Text(CrateLore.briefing).font(Arena.body(15)).foregroundStyle(Arena.textDim).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                ForEach(CrateColor.allCases, id: \.rawValue) { c in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(c.realm).font(Arena.display(15)).foregroundStyle(Color(c.ui)).textCase(.uppercase)
                        Text(c.manifest).arenaLabel(8, color: Arena.textMute)
                    }
                    .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Slant(lean: 0.1).fill(Arena.ink.opacity(0.9)))
                }
            }
            ArenaPrimaryButton(title: "Training Run", icon: "graduationcap.fill", tint: tint) { fold.beginTutorial() }
            HStack {
                ArenaGhostButton(title: fold.hasSeenTutorial ? "Start Shift" : "Skip Tutorial", icon: "forward.fill") { fold.skipTutorial() }
                Spacer()
                ArenaGhostButton(title: "Menu", icon: "house.fill", action: onMainMenu)
            }
        }
        .padding(24)
        .frame(maxWidth: 560)
        .background(CutRect(cut: 22).fill(Arena.carbon.opacity(0.97)))
        .overlay(CutRect(cut: 22).stroke(tint.opacity(0.4), lineWidth: 1.5))
        .padding(.horizontal, 16)
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }

    // MARK: Tutorial

    private var tutorial: some View {
        VStack(spacing: 10) {
            let steps = CrateTutorialStep.allCases.filter { $0 != .done }
            HStack(spacing: 6) {
                ForEach(steps, id: \.rawValue) { s in
                    Slant(lean: 0.3)
                        .fill(s.rawValue <= fold.tutorialStep.rawValue ? tint : Arena.carbonHi)
                        .frame(width: 44, height: 8)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Training \(min(fold.tutorialStep.rawValue + 1, steps.count))/\(steps.count)").arenaLabel(10, color: tint)
                Text(fold.tutorialStep.headline).font(Arena.display(30)).foregroundStyle(Arena.text).textCase(.uppercase)
                Text(fold.tutorialStep.detail).font(Arena.body(14)).foregroundStyle(Arena.textDim)
                    .fixedSize(horizontal: false, vertical: true)
                if let e = fold.lastEvent {
                    Text(e).arenaLabel(11, color: Arena.heat).transition(.opacity)
                }
                HStack {
                    Spacer()
                    ArenaGhostButton(title: "Skip", icon: "forward.end.fill", height: 38) { fold.skipTutorial() }
                }
            }
            .padding(18)
            .frame(maxWidth: 480)
            .background(CutRect(cut: 16).fill(Arena.carbon.opacity(0.95)))
            .overlay(CutRect(cut: 16).stroke(tint.opacity(0.35), lineWidth: 1.2))
            .id(fold.tutorialStep)
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            Spacer()
        }
        .padding(.top, 110)
        .animation(Arena.punch, value: fold.tutorialStep)
    }

    // MARK: Live shift

    private var live: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Text(String(format: "%.1f", max(0, fold.timeRemaining)))
                    .font(Arena.num(44)).foregroundStyle(Arena.ink)
                    .padding(.horizontal, 18).frame(height: 64)
                    .background(Slant().fill(fold.timeRemaining < 10 ? Arena.hostile : tint))
                    .contentTransition(.numericText())
                stat("Score", "\(fold.score)")
                stat("Level", "\(fold.level)")
                stat("Sorted", "\(fold.delivered)")
                if fold.streak >= 2 {
                    Text("x\(fold.streak)")
                        .font(Arena.num(32)).foregroundStyle(Arena.ink)
                        .padding(.horizontal, 14).frame(height: 64)
                        .background(Slant().fill(Arena.heat))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Slant(lean: 0.4).fill(Arena.ink.opacity(0.8))
                    Slant(lean: 0.4).fill(fold.timeRemaining < 10 ? Arena.hostile : tint)
                        .frame(width: geo.size.width * fold.timeFraction)
                }
            }
            .frame(width: 420, height: 8)
            HStack(spacing: 8) {
                Text(fold.rankTitle).arenaLabel(10, color: Arena.textDim)
                if let c = fold.carrying {
                    Text("Hooked: \(c.realm)").arenaLabel(10, color: Color(c.ui))
                }
            }
            if let e = fold.lastEvent {
                Text(e).font(Arena.display(18)).foregroundStyle(Arena.ink).textCase(.uppercase)
                    .padding(.horizontal, 20).frame(height: 38)
                    .background(Slant().fill(tint))
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            Spacer()
        }
        .padding(.top, 110)
        .animation(Arena.punch, value: fold.streak)
        .animation(Arena.snap, value: fold.lastEvent)
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label).arenaLabel(9, color: Arena.textMute)
            Text(value).font(Arena.num(24)).foregroundStyle(Arena.text).contentTransition(.numericText())
        }
        .padding(.horizontal, 14).frame(height: 64)
        .background(Slant(lean: 0.15).fill(Arena.ink.opacity(0.88)))
    }

    // MARK: Finished

    private var finished: some View {
        VStack(alignment: .leading, spacing: 14) {
            CheckerStrip(cell: 7, color: tint).frame(height: 14)
            VStack(alignment: .leading, spacing: 0) {
                Text("The Fold closed").arenaLabel(12, color: tint)
                Text("\(fold.score)").font(Arena.num(84)).foregroundStyle(Arena.text)
                if fold.score >= fold.highScore && fold.score > 0 {
                    ArenaTag(text: "New Guild record", tint: tint)
                } else {
                    Text("Best \(fold.highScore)").arenaLabel(11, color: Arena.textMute)
                }
            }
            HStack(spacing: 0) {
                ArenaReadout(label: "Sorted", value: "\(fold.delivered)")
                ArenaReadout(label: "Level", value: "\(fold.level)", tint: tint)
                ArenaReadout(label: "Streak", value: "x\(fold.bestStreak)", tint: Arena.heat)
                ArenaReadout(label: "Misroutes", value: "\(fold.misroutes)", tint: Arena.hostile)
            }
            Text("Rank reached: \(fold.rankTitle)").arenaLabel(11, color: Arena.textDim)
            ArenaPrimaryButton(title: "New Shift", icon: "arrow.clockwise", tint: tint) { fold.restart() }
            HStack {
                Spacer()
                ArenaGhostButton(title: "Menu", icon: "house.fill", action: onMainMenu)
            }
        }
        .padding(24)
        .frame(maxWidth: 520)
        .background(CutRect(cut: 22).fill(Arena.carbon.opacity(0.97)))
        .overlay(CutRect(cut: 22).stroke(tint.opacity(0.4), lineWidth: 1.5))
        .padding(.horizontal, 16)
    }
}
