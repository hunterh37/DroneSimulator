//
//  MissileGrid.swift
//  HelicopterGame
//
//  The whole missile catalogue on one board. No paging: comparing
//  ordnance is the point, so every option and its numbers are visible at
//  once. Slot badges (A / B) show where each missile is mounted.
//

import SwiftUI

struct MissileGrid: View {
    let weapons: [MissileWeapon]
    var slotA: String? = nil
    var slotB: String? = nil
    var focusTint: Color = Arena.heat
    let onPick: (MissileWeapon) -> Void

    private let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(weapons) { w in cell(w) }
        }
    }

    private func cell(_ w: MissileWeapon) -> some View {
        let mountedA = w.id == slotA
        let mountedB = w.id == slotB
        let mounted = mountedA || mountedB
        let color = Color(hex: w.primaryColor)
        return Button {
            SteelHaptics.lightTap()
            onPick(w)
        } label: {
            HStack(spacing: 10) {
                Group {
                    if UIImage(named: w.imageName) != nil {
                        Image(w.imageName).resizable().scaledToFit()
                    } else {
                        Image(systemName: w.iconName).font(.system(size: 26, weight: .black)).foregroundStyle(color)
                    }
                }
                .frame(width: 44, height: 58)
                .rotationEffect(.degrees(35))

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 4) {
                        Text(w.displayName).font(Arena.display(15)).foregroundStyle(Arena.text).textCase(.uppercase)
                            .lineLimit(1).minimumScaleFactor(0.6)
                        Spacer(minLength: 0)
                        Text("x\(w.missileCount)").font(Arena.num(15)).foregroundStyle(Arena.textDim)
                    }
                    mini("DMG", w.damage, Arena.heat)
                    mini("SPD", w.speed, Arena.volt)
                    mini("BLS", w.collisionSize, Arena.ice)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 78)
            .frame(maxWidth: .infinity)
            .background(CutRect(cut: 10).fill(mounted ? Arena.carbonHi : Arena.carbon))
            .overlay(CutRect(cut: 10).stroke(mounted ? focusTint : Arena.line, lineWidth: mounted ? 2 : 1))
            .overlay(alignment: .topTrailing) {
                HStack(spacing: 2) {
                    if mountedA { ArenaTag(text: "A", tint: Arena.heat) }
                    if mountedB { ArenaTag(text: "B", tint: Arena.volt) }
                }
                .offset(x: -6, y: -15)
            }
            .contentShape(CutRect(cut: 10))
        }
        .buttonStyle(.plain)
        .hoverEffect(.lift)
        .animation(Arena.punch, value: mounted)
    }

    private func mini(_ label: String, _ value: Int, _ tint: Color) -> some View {
        HStack(spacing: 6) {
            Text(label).font(Arena.label(9)).foregroundStyle(Arena.textMute).frame(width: 22, alignment: .leading)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Slant(lean: 1).fill(Color.white.opacity(0.07))
                    Slant(lean: 1).fill(tint).frame(width: g.size.width * CGFloat(value) / 100)
                }
            }
            .frame(height: 4)
        }
    }
}
