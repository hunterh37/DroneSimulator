//
//  ThumbJoystickHelpView.swift
//  HelicopterGame
//
//  Created by Claude Code on 10/18/25.
//

import SwiftUI

struct ThumbJoystickHelpView: View {
    @Binding var isPresented: Bool
    @State private var animateInstructions = false

    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.9)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    dismissHelp()
                }

            VStack(spacing: 32) {
                // Header
                HStack {
                    Text("Hand Tracking Controls")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)

                    Spacer()

                    Button(action: { dismissHelp() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal, 32)
                .padding(.top, 60)

                ScrollView {
                    VStack(spacing: 32) {
                        // Image placeholder section
                        imageSection

                        // Main instruction card
                        mainInstructionCard

                        // Controls breakdown
                        controlsBreakdownCard

                        // Tips card
                        tipsCard
                    }
                    .padding(.horizontal, 32)
                }

                Spacer()

                // Got it button
                gotItButton
                    .padding(.horizontal, 32)
                    .padding(.bottom, 40)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
                animateInstructions = true
            }
        }
    }

    private func dismissHelp() {
        isPresented = false
    }

    // MARK: - Image Section

    private var imageSection: some View {
        VStack(spacing: 16) {
            HandControlsIllustration()

            Text("Raise both hands in front of you, thumbs up, and keep them in view")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
        }
        .scaleEffect(animateInstructions ? 1.0 : 0.95)
        .opacity(animateInstructions ? 1.0 : 0.0)
    }

    // MARK: - Main Instruction Card

    private var mainInstructionCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: "hands.sparkles.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.cyan)

                Text("How It Works")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 16) {
                Text("Position your hands in front of you with thumbs pointing upward, as if you're holding two invisible joysticks.")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)

                Text("Move your thumbs to control your drone - just like you would tilt physical joystick sticks!")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.cyan.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.cyan.opacity(0.4), lineWidth: 2)
                )
        )
        .scaleEffect(animateInstructions ? 1.0 : 0.95)
        .opacity(animateInstructions ? 1.0 : 0.0)
    }

    // MARK: - Controls Breakdown Card

    private var controlsBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Controls")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)

            VStack(spacing: 20) {
                // Left thumb control
                controlDetailRow(
                    icon: "hand.thumbsup.fill",
                    iconColor: .blue,
                    title: "Left Thumb - YAW Control",
                    movements: [
                        ("Move Left/Right", "Rotate drone left/right"),
                        ("Move Up/Down", "Adjust altitude (throttle)"),
                    ]
                )

                Divider()
                    .background(Color.white.opacity(0.2))

                // Right thumb control
                controlDetailRow(
                    icon: "hand.thumbsup.fill",
                    iconColor: .green,
                    title: "Right Thumb - Movement",
                    movements: [
                        ("Move Left/Right", "Strafe left/right"),
                        ("Move Forward/Back", "Fly forward/backward"),
                    ]
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1.5)
                )
        )
        .scaleEffect(animateInstructions ? 1.0 : 0.95)
        .opacity(animateInstructions ? 1.0 : 0.0)
    }

    private func controlDetailRow(icon: String, iconColor: Color, title: String, movements: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(iconColor)

                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(movements, id: \.0) { movement in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(iconColor.opacity(0.6))
                            .frame(width: 20)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(movement.0)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white)

                            Text(movement.1)
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                }
            }
            .padding(.leading, 8)
        }
    }

    // MARK: - Tips Card

    private var tipsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.yellow)

                Text("Pro Tips")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 12) {
                tipRow(icon: "eye.fill", text: "Keep your hands within your field of view for reliable tracking")
                tipRow(icon: "hand.raised.fill", text: "Hold thumbs steady and upright for best control response")
                tipRow(icon: "arrow.triangle.2.circlepath", text: "Small thumb movements = precise control")
                tipRow(icon: "star.fill", text: "Practice in a safe area to get comfortable with the controls")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.yellow.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.yellow.opacity(0.3), lineWidth: 2)
                )
        )
        .scaleEffect(animateInstructions ? 1.0 : 0.95)
        .opacity(animateInstructions ? 1.0 : 0.0)
    }

    private func tipRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.yellow.opacity(0.8))
                .frame(width: 24)

            Text(text)
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Got It Button

    private var gotItButton: some View {
        Button(action: { dismissHelp() }) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))

                Text("Got It!")
                    .font(.system(size: 18, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
        }
        .scaleEffect(animateInstructions ? 1.0 : 0.95)
        .opacity(animateInstructions ? 1.0 : 0.0)
    }
}

#Preview {
    ThumbJoystickHelpView(isPresented: .constant(true))
}
