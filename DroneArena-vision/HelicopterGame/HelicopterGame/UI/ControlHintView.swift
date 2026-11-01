//
//  ControlHintView.swift
//  HelicopterGame
//
//  HUD attachment shown in front of the player when an immersive game mode
//  starts, illustrating how to drive the drone. The hint adapts to the
//  selected scheme (hand joystick or joystick stand).
//

import SwiftUI

struct ControlHintView: View {
    /// Called when the hint should be dismissed (auto-timeout or tap).
    var onDismiss: () -> Void

    /// Which input scheme to illustrate. Defaults to the currently selected
    /// scheme so the hint always matches what's actually driving the drone.
    var scheme: DroneControlScheme = ControlSchemeConfig.current

    private var hint: ControlHintContent { ControlHintContent(scheme: scheme) }

    var body: some View {
        VStack(spacing: 16) {
            Text(hint.title)
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .tracking(2)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Image(systemName: scheme.symbolName)
                .font(.system(size: 72, weight: .semibold))
                .foregroundStyle(.cyan)
                .frame(height: 120)

            Text(hint.instructions)
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.85))

            Button(action: onDismiss) {
                Text("Got it")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 28)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(.white.opacity(0.18))
            .padding(.top, 4)
        }
        .padding(28)
        .frame(width: 440)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.15), lineWidth: 1)
        )
    }
}

/// Per-scheme copy + artwork for the control hint card.
private struct ControlHintContent {
    let title: String
    let instructions: String

    init(scheme: DroneControlScheme) {
        switch scheme {
        case .handJoystick:
            title = "HAND JOYSTICK"
            instructions = "Hold both hands forward, thumbs up.\nLeft thumb: height and turn. Right thumb: fly.\nTouch index fingers to fire."
        case .physicalJoystick:
            title = "JOYSTICK STAND"
            instructions = "Pinch and hold both sticks.\nLeft stick: height and turn. Right stick: fly.\nPress the red buttons to fire."
        }
    }
}

#Preview("Hand") {
    ControlHintView(onDismiss: {}, scheme: .handJoystick)
}

#Preview("Stand") {
    ControlHintView(onDismiss: {}, scheme: .physicalJoystick)
}
