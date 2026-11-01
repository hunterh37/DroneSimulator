//
//  BetaDisclaimerView.swift
//  HelicopterGame
//
//  Created by Claude on 10/6/25.
//

import SwiftUI

public struct BetaDisclaimerView: View {
    @Binding var isPresented: Bool

    public init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
    }

    public var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            // Main disclaimer card
            VStack(spacing: 30) {
                // Title
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)

                    Text("DroneArena")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("BETA VERSION")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.orange.opacity(0.2))
                                .stroke(.orange.opacity(0.5), lineWidth: 1)
                        )
                }

                // Disclaimer message
                VStack(spacing: 16) {
                    Text("DroneArena is still in beta.")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    Text("Please submit your feedback and bug reports using TestFlight feedback.")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                }
                .padding(.horizontal, 24)

                // Understand button
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isPresented = false
                    }
                    // Store that user has seen the disclaimer
                    UserDefaults.standard.set(true, forKey: "HasSeenBetaDisclaimer")
                }) {
                    Text("I Understand")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(.blue)
                        )
                }
                .padding(.horizontal, 24)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.black.opacity(0.9))
                    .stroke(.white.opacity(0.2), lineWidth: 1)
            )
            .padding(.horizontal, 32)
        }
        .animation(.easeInOut(duration: 0.3), value: isPresented)
    }
}

// MARK: - Preview

#Preview {
    BetaDisclaimerView(isPresented: .constant(true))
}