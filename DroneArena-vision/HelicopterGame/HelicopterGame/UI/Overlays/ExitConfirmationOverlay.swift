//
//  ExitConfirmationOverlay.swift
//  HelicopterGame
//
//  Created by Hunter Harris on 10/3/25.
//

import SwiftUI

struct ExitConfirmationOverlay: View {
    @Binding var isPresented: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void
    var body: some View {
        ZStack {
            Color.night.opacity(0.85)
                .edgesIgnoringSafeArea(.all)
            SteelCard(hasHeaderStripe: true, variant: .overlay) {
                VStack(spacing: SteelLayout.xl) {
                    ZStack {
                        Circle()
                            .fill(Color.warning.opacity(0.15))
                            .frame(width: 80, height: 80)
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40, weight: .semibold))
                            .foregroundColor(.warning)
                    }
                    Text("Forfeit Match?")
                        .font(SteelTypography.headline)
                        .foregroundColor(.textPrimary)
                    Text("Are you sure you want to exit? You will forfeit this multiplayer match.")
                        .font(SteelTypography.body)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: SteelLayout.md) {
                        GlassButton("Cancel", icon: "xmark.circle") {
                            SteelHaptics.lightTap()
                            onCancel()
                        }
                        Button(action: {
                            SteelHaptics.lightTap()
                            onConfirm()
                        }) {
                            HStack(spacing: SteelLayout.xs) {
                                Image(systemName: "checkmark.circle")
                                    .font(SteelTypography.button.weight(.semibold))
                                Text("Confirm")
                                    .font(SteelTypography.button)
                            }
                            .foregroundColor(.night)
                            .padding(.horizontal, SteelLayout.lg)
                            .padding(.vertical, SteelLayout.md)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.warning)
                            )
                        }
                    }
                }
                .padding(SteelLayout.lg)
            }
            .frame(maxWidth: 400)
            .shadow(color: .warning.opacity(0.3), radius: 20, x: 0, y: 10)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
        .animation(SteelMotion.mediumEaseOut, value: isPresented)
    }
}
