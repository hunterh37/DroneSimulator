//
//  MobileVirtualJoystick.swift
//  HelicopterGame
//
//  Created by Hunter Harris on 10/13/25.
//

import Foundation
import SwiftUI

// MARK: - Virtual Joystick Component

/// Touch stick. The knob tracks the finger's offset from the base center, so a
/// touch anywhere on the base moves the stick immediately (no drag threshold).
struct VirtualJoystick: View {
    let position: CGPoint
    let isActive: Bool
    let onPositionChanged: (CGPoint, Bool) -> Void
    let isLeftJoystick: Bool // true for left channel (throttle + yaw), false for right (pitch + roll)
    var tint: Color = Arena.volt

    @State private var knobPosition: CGSize = .zero
    @State private var isDragging: Bool = false
    @State private var settings = GameContext.shared.joystickSensitivity

    private let joystickSize: CGFloat = 130
    private let knobSize: CGFloat = 52
    private let maxDistance: CGFloat = 45

    var body: some View {
        ZStack {
            Circle()
                .fill(Arena.ink.opacity(0.78))
                .overlay(Circle().stroke(isDragging ? tint.opacity(0.9) : Arena.lineStrong, lineWidth: isDragging ? 2 : 1))
                .overlay(Circle().inset(by: 14).stroke(Arena.line, lineWidth: 1))
                .overlay(crosshair)
                .frame(width: joystickSize, height: joystickSize)

            Circle()
                .fill(isDragging ? tint : Arena.carbonHi)
                .overlay(Circle().stroke(tint, lineWidth: 2))
                .overlay(Circle().fill(isDragging ? Arena.ink : tint).frame(width: 10, height: 10))
                .frame(width: knobSize, height: knobSize)
                .offset(knobPosition)
                .scaleEffect(isDragging ? 1.08 : 1.0)
                .animation(Arena.snap, value: isDragging)
        }
        .frame(width: joystickSize, height: joystickSize)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { value in
                    if !isDragging { SteelHaptics.lightTap() }
                    isDragging = true

                    let center = CGPoint(x: joystickSize / 2, y: joystickSize / 2)
                    let dx = value.location.x - center.x
                    let dy = value.location.y - center.y
                    let distance = hypot(dx, dy)
                    let scale = distance > maxDistance ? maxDistance / distance : 1
                    knobPosition = CGSize(width: dx * scale, height: dy * scale)

                    // Normalize to -1...1 and invert Y (screen Y grows downward, world Y grows upward)
                    let normalizedPosition = CGPoint(
                        x: knobPosition.width / maxDistance,
                        y: -knobPosition.height / maxDistance
                    )

                    let sensitizedPosition = isLeftJoystick
                        ? settings.applyLeftJoystickSensitivity(position: normalizedPosition)
                        : settings.applyRightJoystickSensitivity(position: normalizedPosition)

                    onPositionChanged(sensitizedPosition, true)
                }
                .onEnded { _ in
                    isDragging = false
                    withAnimation(Arena.snap) {
                        knobPosition = .zero
                    }
                    onPositionChanged(.zero, false)
                }
        )
    }

    private var crosshair: some View {
        ZStack {
            Rectangle().fill(Arena.line).frame(width: 1, height: joystickSize - 28)
            Rectangle().fill(Arena.line).frame(width: joystickSize - 28, height: 1)
        }
    }
}
