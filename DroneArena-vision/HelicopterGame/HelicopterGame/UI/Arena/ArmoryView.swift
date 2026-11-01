//
//  ArmoryView.swift
//  HelicopterGame
//
//  Step 03, the armory. Two hardpoints on top (A primary, B secondary);
//  tap a hardpoint to target it, tap a missile to mount it. Mounting A
//  auto-targets B, so a full loadout is two taps. Launch lives here: the
//  last setup step and the start button are the same screen.
//

import SwiftUI

struct ArmoryView: View {
    let event: ArenaEvent
    let onBack: () -> Void
    let onLaunch: () -> Void

    @State private var registry = WeaponRegistry()
    @State private var loadout = GameContext.shared.loadout
    @State private var target = 1

    var body: some View {
        ZStack {
            ArenaBackdrop(tint: Arena.heat)
            VStack(alignment: .leading, spacing: 16) {
                ArenaStepHeader(step: 3, total: 3, kicker: "Arm the frame", title: "Armory", tint: Arena.heat, onBack: onBack)

                HStack(spacing: 10) {
                    hardpoint(1, loadout.selectedWeapon)
                    hardpoint(2, loadout.selectedWeapon2)
                }

                ScrollView(showsIndicators: false) {
                    MissileGrid(
                        weapons: registry.allWeapons,
                        slotA: loadout.selectedWeapon?.id,
                        slotB: loadout.selectedWeapon2?.id,
                        focusTint: target == 1 ? Arena.heat : Arena.volt
                    ) { mount($0) }
                    .padding(.vertical, 12)
                }

                ArenaPrimaryButton(title: "Grid Up: \(event.name)", tint: event.tint) {
                    ArenaSound.shared.play(.launch, volume: 0.8)
                    onLaunch()
                }
            }
            .padding(.horizontal, Arena.gutter)
            .padding(.top, 26)
            .padding(.bottom, 22)
        }
    }

    private func hardpoint(_ slot: Int, _ w: MissileWeapon?) -> some View {
        let on = target == slot
        let tint = slot == 1 ? Arena.heat : Arena.volt
        return Button {
            SteelHaptics.lightTap()
            withAnimation(Arena.snap) { target = slot }
        } label: {
            HStack(spacing: 10) {
                Text(slot == 1 ? "A" : "B").font(Arena.num(40)).foregroundStyle(on ? Arena.ink : tint)
                    .frame(width: 44, height: 64)
                    .background(Slant().fill(on ? tint : Arena.carbonHi))
                VStack(alignment: .leading, spacing: 2) {
                    Text(slot == 1 ? "Primary" : "Secondary").arenaLabel(10, color: tint)
                    Text(w?.displayName ?? "Empty").font(Arena.display(18)).foregroundStyle(Arena.text).textCase(.uppercase)
                        .lineLimit(1).minimumScaleFactor(0.6)
                    Text(w.map { "DMG \($0.damage)  x\($0.missileCount)" } ?? "Tap a missile").font(Arena.num(13)).foregroundStyle(Arena.textDim)
                }
                Spacer(minLength: 0)
            }
            .padding(8)
            .frame(maxWidth: .infinity)
            .background(CutRect(cut: 12).fill(Arena.carbon))
            .overlay(CutRect(cut: 12).stroke(on ? tint : Arena.line, lineWidth: on ? 2 : 1))
            .contentShape(CutRect(cut: 12))
        }
        .buttonStyle(.plain)
        .hoverEffect(.lift)
    }

    private func mount(_ w: MissileWeapon) {
        ArenaSound.shared.play(.confirm, volume: 0.55)
        withAnimation(Arena.punch) {
            if target == 1 {
                loadout.selectWeapon(w)
                target = 2
            } else {
                loadout.selectWeapon2(w)
            }
        }
    }
}
