//
//  WeaponSelectionView.swift
//  HelicopterGame
//
//  Mid-flight hardpoint swap (long-press a weapon slot in the HUD).
//  Same missile board as the armory, scoped to one slot.
//

import SwiftUI

struct WeaponSelectionView: View {
    @State private var registry = WeaponRegistry()
    @State private var loadout = GameContext.shared.loadout

    let slot: Int
    let onWeaponSelected: (MissileWeapon, Int) -> Void
    let onCancel: () -> Void

    private var tint: Color { slot == 1 ? Arena.heat : Arena.volt }

    var body: some View {
        ZStack {
            ArenaBackdrop(tint: tint)
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(slot == 1 ? "Hardpoint A" : "Hardpoint B").arenaLabel(12, color: tint)
                        Text("Swap Missile").font(Arena.display(36)).foregroundStyle(Arena.text).textCase(.uppercase)
                    }
                    Spacer()
                    ArenaIconButton(icon: "xmark", size: 40, action: onCancel)
                }
                ScrollView(showsIndicators: false) {
                    MissileGrid(
                        weapons: registry.allWeapons,
                        slotA: slot == 1 ? loadout.selectedWeapon?.id : nil,
                        slotB: slot == 2 ? loadout.selectedWeapon2?.id : nil,
                        focusTint: tint
                    ) { w in
                        SteelHaptics.successFeedback()
                        ArenaSound.shared.play(.confirm, volume: 0.6)
                        onWeaponSelected(w, slot)
                    }
                    .padding(.vertical, 12)
                }
            }
            .padding(Arena.gutter)
        }
        .frame(minWidth: 560, minHeight: 620)
    }
}
