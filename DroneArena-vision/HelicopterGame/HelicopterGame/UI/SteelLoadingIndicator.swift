//
//  SteelLoadingIndicator.swift
//  HelicopterGame
//
//  Created by Hunter Harris on 10/13/25.
//

import Foundation
import SwiftUI


// MARK: - Steel Loading Indicator

struct SteelLoadingIndicator: View {
    @State private var rotationAngle: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.3

    var body: some View {
        ZStack {
            // Full screen background
            Color.night.opacity(0.95)
                .edgesIgnoringSafeArea(.all)

            // Loading content
            SteelCard(hasHeaderStripe: true, variant: .overlay) {
                VStack(spacing: SteelLayout.xl) {
                    // Animated reticle scope icon
                    ZStack {
                        // Outer glow ring
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [.neonBlue, .coreBlue, .iceCyan],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 3
                            )
                            .frame(width: 80, height: 80)
                            .scaleEffect(pulseScale)
                            .opacity(glowOpacity)
                            .rotationEffect(.degrees(rotationAngle))

                        // Inner chrome ring
                        Circle()
                            .stroke(ChromeBlockGradient.gradient, lineWidth: 4)
                            .frame(width: 60, height: 60)
                            .rotationEffect(.degrees(-rotationAngle * 0.7))

                        // Center reticle icon
                        Image(systemName: "scope")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.coreBlue)
                            .shadow(color: .neonBlue, radius: 8)

                        // Crosshairs
                        VStack {
                            Rectangle()
                                .fill(Color.iceCyan)
                                .frame(width: 2, height: 20)
                                .offset(y: -25)
                            Spacer()
                            Rectangle()
                                .fill(Color.iceCyan)
                                .frame(width: 2, height: 20)
                                .offset(y: 25)
                        }
                        .frame(height: 80)
                        .rotationEffect(.degrees(rotationAngle * 0.5))

                        HStack {
                            Rectangle()
                                .fill(Color.iceCyan)
                                .frame(width: 20, height: 2)
                                .offset(x: -25)
                            Spacer()
                            Rectangle()
                                .fill(Color.iceCyan)
                                .frame(width: 20, height: 2)
                                .offset(x: 25)
                        }
                        .frame(width: 80)
                        .rotationEffect(.degrees(-rotationAngle * 0.3))
                    }
                    .frame(width: 100, height: 100)

                    // Loading text
                    VStack(spacing: SteelLayout.sm) {
                        Text("Initializing...")
                            .font(SteelTypography.headline)
                            .foregroundColor(.textPrimary)
                            .kerning(1.2)

                        // Animated dots
                        HStack(spacing: SteelLayout.xs) {
                            ForEach(0..<3, id: \.self) { index in
                                Circle()
                                    .fill(Color.coreBlue)
                                    .frame(width: 6, height: 6)
                                    .scaleEffect(pulseScale)
                                    .animation(
                                        SteelMotion.neonPulse
                                            .repeatForever(autoreverses: true)
                                            .delay(Double(index) * 0.2),
                                        value: pulseScale
                                    )
                            }
                        }
                        .padding(.top, SteelLayout.sm)
                    }
                }
            }
            .frame(maxWidth: 320)
            .shadow(color: .neonBlue.opacity(0.3), radius: 20, x: 0, y: 10)
        }
        .onAppear {
            startAnimations()
        }
    }

    private func startAnimations() {
        // Continuous rotation
        withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
            rotationAngle = 360
        }

        // Pulsing scale
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            pulseScale = 1.2
        }

        // Glow opacity
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            glowOpacity = 0.8
        }
    }
}

