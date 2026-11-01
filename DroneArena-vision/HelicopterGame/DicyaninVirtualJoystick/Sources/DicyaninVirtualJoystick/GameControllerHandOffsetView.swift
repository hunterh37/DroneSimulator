//
//  GameControllerHandOffsetView.swift
//  HelicopterGame
//
//  Debug panel: live-adjust the X/Y/Z position of the right-hand-anchored 3D
//  game controller. Each axis has a slider plus a readout of the current value.
//  Changes apply immediately to the rig in the immersive scene (via
//  GamepadHandOffsetSettings) and are persisted across launches.
//

import SwiftUI

public struct GameControllerHandOffsetView: View {
    @Binding var isPresented: Bool

    /// Bindable so SwiftUI re-renders the readouts as the offset changes.
    @State private var settings = GamepadHandOffsetSettings.shared

    /// Comfortable adjustment window around the palm anchor (metres).
    private let range: ClosedRange<Float> = -0.5...0.5

    public init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
    }

    public var body: some View {
        VStack(spacing: 24) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Controller Hand Offset")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    Text("Position of the 3D controller relative to your right hand")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.6))
                }
                Spacer()
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 26))
                        .foregroundColor(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
            }

            axisSlider(label: "X", subtitle: "left / right", value: $settings.x, tint: .red)
            axisSlider(label: "Y", subtitle: "down / up", value: $settings.y, tint: .green)
            axisSlider(label: "Z", subtitle: "forward / back", value: $settings.z, tint: .blue)

            HStack(spacing: 12) {
                Text(String(format: "( %.3f, %.3f, %.3f )", settings.x, settings.y, settings.z))
                    .font(.system(size: 15, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.85))

                Spacer()

                Button {
                    settings.reset()
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white.opacity(0.18))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(28)
        .frame(width: 460)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private func axisSlider(label: String, subtitle: String, value: Binding<Float>, tint: Color) -> some View {
        VStack(spacing: 6) {
            HStack {
                Text(label)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(tint)
                    .frame(width: 22, alignment: .leading)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
                Text(String(format: "%+.3f m", value.wrappedValue))
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
            }
            Slider(value: value, in: range)
                .tint(tint)
        }
    }
}
