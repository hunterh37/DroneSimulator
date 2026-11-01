//
//  MultiplayerXPRewardsView.swift
//  HelicopterGame
//
//  Created by Claude on 10/13/25.
//

import SwiftUI

struct MultiplayerXPRewardsView: View {
    let xpEarned: Int
    let oldRank: PlayerRank
    let newRank: PlayerRank
    let onContinue: () -> Void

    @State private var displayedXP: Int = 0
    @State private var currentProgress: Float = 0.0
    @State private var showLevelUp: Bool = false
    @State private var displayedRank: PlayerRank
    @State private var animateXPNumber: Bool = false
    @State private var shouldAnimateProgressBar: Bool = false

    init(xpEarned: Int, oldRank: PlayerRank, newRank: PlayerRank, onContinue: @escaping () -> Void) {
        self.xpEarned = xpEarned
        self.oldRank = oldRank
        self.newRank = newRank
        self.onContinue = onContinue
        _displayedRank = State(initialValue: oldRank)
        _currentProgress = State(initialValue: oldRank.progressToNextLevel)
    }

    private var didLevelUp: Bool {
        return newRank.level > oldRank.level
    }

    var body: some View {
        ZStack {
            // Dark background
            Color.black.opacity(0.9)
                .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // XP Earned Header
                VStack(spacing: 12) {
                    Text("MATCH COMPLETE")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))

                    HStack(spacing: 8) {
                        Text("+")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(.warning)

                        Text("\(displayedXP)")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(.warning)
                            .monospacedDigit()
                            .scaleEffect(animateXPNumber ? 1.2 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: animateXPNumber)

                        Text("XP")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }

                // Current Rank Display
                VStack(spacing: 24) {
                    // Rank Icon
                    ZStack {
                        if let _ = UIImage(named: displayedRank.rankIconName) {
                            Image(displayedRank.rankIconName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 120, height: 120)
                        } else {
                            // Fallback gradient circle
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(
                                        colors: [.coreBlue, .warning],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))
                                    .frame(width: 120, height: 120)

                                Text("\(displayedRank.level)")
                                    .font(.system(size: 48, weight: .black))
                                    .foregroundColor(.white)
                            }
                        }

                        // Level up animation overlay
                        if showLevelUp {
                            levelUpOverlay
                        }
                    }

                    // Rank Level Text
                    Text("RANK \(displayedRank.level)")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)

                    // XP Progress Bar
                    VStack(spacing: 8) {
                        // Progress bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.1))
                                    .frame(height: 24)

                                // Progress fill
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(LinearGradient(
                                        colors: [.coreBlue, .warning],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ))
                                    .frame(width: geometry.size.width * CGFloat(currentProgress), height: 24)
                                    .animation(.easeInOut(duration: 1.5), value: currentProgress)
                            }
                        }
                        .frame(height: 24)
                        .frame(maxWidth: 400)

                        // XP Text
                        if displayedRank.level < 10 {
                            HStack {
                                Text("\(displayedRank.xp) XP")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))

                                Spacer()

                                Text("\(displayedRank.xpForNextLevel) XP")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .frame(maxWidth: 400)
                        } else {
                            Text("MAX RANK")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.warning)
                        }
                    }
                    .padding(.horizontal, 32)
                }

                Spacer()

                // Continue Button
                Button(action: onContinue) {
                    Text("Continue")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 48)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.coreBlue)
                                .stroke(Color.white.opacity(0.3), lineWidth: 2)
                        )
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            startXPAnimation()
        }
    }

    // MARK: - Level Up Overlay

    private var levelUpOverlay: some View {
        ZStack {
            // Sliding rank icon from top
            if let _ = UIImage(named: newRank.rankIconName) {
                Image(newRank.rankIconName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 140, height: 140)
                    .offset(y: showLevelUp ? 0 : -200)
                    .opacity(showLevelUp ? 1.0 : 0.0)
                    .animation(.spring(response: 0.8, dampingFraction: 0.6), value: showLevelUp)
            } else {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [.coreBlue, .warning],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 140, height: 140)

                    Text("\(newRank.level)")
                        .font(.system(size: 56, weight: .black))
                        .foregroundColor(.white)
                }
                .offset(y: showLevelUp ? 0 : -200)
                .opacity(showLevelUp ? 1.0 : 0.0)
                .animation(.spring(response: 0.8, dampingFraction: 0.6), value: showLevelUp)
            }

            // "RANK UP!" text
            VStack {
                Spacer()
                    .frame(height: 160)

                Text("RANK UP!")
                    .font(.system(size: 32, weight: .black))
                    .foregroundColor(.warning)
                    .shadow(color: .black, radius: 4)
                    .scaleEffect(showLevelUp ? 1.0 : 0.5)
                    .opacity(showLevelUp ? 1.0 : 0.0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.5).delay(0.3), value: showLevelUp)
            }
        }
    }

    // MARK: - Animations

    private func startXPAnimation() {
        // Animate XP number counting up
        let animationDuration: Double = 1.5
        let steps = 30
        let xpPerStep = xpEarned / steps

        for i in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + (animationDuration / Double(steps)) * Double(i)) {
                if i == steps {
                    displayedXP = xpEarned
                } else {
                    displayedXP = xpPerStep * i
                }

                // Pulse effect every few steps
                if i % 5 == 0 {
                    animateXPNumber = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        animateXPNumber = false
                    }
                }
            }
        }

        // Start progress bar animation after XP counting
        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) {
            shouldAnimateProgressBar = true
            startProgressBarAnimation()
        }
    }

    private func startProgressBarAnimation() {
        // If we leveled up, animate to full, then show level up, then reset to new progress
        if didLevelUp {
            // Animate to 100%
            withAnimation(.easeInOut(duration: 0.8)) {
                currentProgress = 1.0
            }

            // Show level up after reaching 100%
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation {
                    showLevelUp = true
                    displayedRank = newRank
                }

                // Reset progress bar to new level progress
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    currentProgress = 0.0

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        withAnimation(.easeInOut(duration: 0.8)) {
                            currentProgress = newRank.progressToNextLevel
                        }
                    }
                }
            }
        } else {
            // No level up, just animate to new progress
            withAnimation(.easeInOut(duration: 1.2)) {
                currentProgress = newRank.progressToNextLevel
            }
        }
    }
}

// MARK: - Preview

#Preview {
    MultiplayerXPRewardsView(
        xpEarned: 75,
        oldRank: PlayerRank(level: 4, xp: 620, kills: 15, deaths: 8),
        newRank: PlayerRank(level: 5, xp: 710, kills: 18, deaths: 8),
        onContinue: {}
    )
}
