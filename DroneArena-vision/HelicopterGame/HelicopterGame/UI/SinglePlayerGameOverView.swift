//
//  SinglePlayerGameOverView.swift
//  HelicopterGame
//
//  Created by Claude on 10/14/25.
//

import SwiftUI

struct SinglePlayerGameOverView: View {
    let enemiesDefeated: Int
    let xpEarned: Int
    let oldRank: PlayerRank
    let newRank: PlayerRank
    let onContinue: () -> Void
    let onPlayAgain: () -> Void

    @State private var displayedXP: Int = 0
    @State private var currentProgress: Float = 0.0
    @State private var showLevelUp: Bool = false
    @State private var displayedRank: PlayerRank
    @State private var animateXPNumber: Bool = false
    @State private var animateResults = false

    init(enemiesDefeated: Int, xpEarned: Int, oldRank: PlayerRank, newRank: PlayerRank, onContinue: @escaping () -> Void, onPlayAgain: @escaping () -> Void) {
        self.enemiesDefeated = enemiesDefeated
        self.xpEarned = xpEarned
        self.oldRank = oldRank
        self.newRank = newRank
        self.onContinue = onContinue
        self.onPlayAgain = onPlayAgain
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

            VStack(spacing: 0) {
                // Scrollable content area
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 4) {

                        // Game Over Header
                        gameOverHeader

                        // Stats Card
                        statsCard

                        // XP Earned Section
                        xpSection

                        // Rank Display
                        rankSection

                        // Bottom padding for scroll content
                        Spacer()
                            .frame(height: 20)
                    }
                }

                // Action Buttons - fixed at bottom
                HStack(spacing: 16) {
                    // Play Again Button
                    Button(action: onPlayAgain) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 18, weight: .bold))
                            Text("Play Again")
                                .font(.system(size: 18, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.coreBlue)
                                .stroke(Color.white.opacity(0.3), lineWidth: 2)
                        )
                    }

                    // Main Menu Button
                    Button(action: onContinue) {
                        HStack(spacing: 8) {
                            Image(systemName: "house.fill")
                                .font(.system(size: 18, weight: .bold))
                            Text("Main Menu")
                                .font(.system(size: 18, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.danger)
                                .stroke(Color.white.opacity(0.3), lineWidth: 2)
                        )
                    }
                }
                .padding(.vertical, 24)
                .padding(.bottom, 20)
                .opacity(animateResults ? 1.0 : 0.0)
                .background(
                    // Gradient fade to make buttons stand out
                    LinearGradient(
                        colors: [Color.clear, Color.black.opacity(0.9)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 100)
                    .offset(y: -50)
                )
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.3)) {
                animateResults = true
            }
            startXPAnimation()
        }
    }

    // MARK: - Game Over Header

    private var gameOverHeader: some View {
        VStack(spacing: 12) {
            // Defeat image
            Image("defeat")
                .resizable()
                .scaledToFit()
                .frame(height: 180)
                .shadow(color: .red.opacity(0.6), radius: 20)
                .opacity(animateResults ? 1.0 : 0.0)
                .scaleEffect(animateResults ? 1.0 : 0.8)
                .animation(.spring(response: 0.8, dampingFraction: 0.7), value: animateResults)

            // Game Over text
            Text("GAME OVER")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
                .opacity(animateResults ? 1.0 : 0.0)
                .offset(y: animateResults ? 0 : 20)
                .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2), value: animateResults)
        }
    }

    // MARK: - Stats Card

    private var statsCard: some View {
        VStack(spacing: 16) {
            Text("Performance")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)

            HStack(spacing: 32) {
                // Enemies Defeated
                StatColumn(
                    icon: "scope",
                    value: "\(enemiesDefeated)",
                    label: "Defeated"
                )
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.6))
                .stroke(Color.danger.opacity(0.5), lineWidth: 2)
        )
        .opacity(animateResults ? 1.0 : 0.0)
        .offset(y: animateResults ? 0 : 30)
        .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.3), value: animateResults)
    }

    // MARK: - XP Section

    private var xpSection: some View {
        VStack(spacing: 12) {
            Text("EXPERIENCE EARNED")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))

            HStack(spacing: 8) {
                Text("+")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundColor(.warning)

                Text("\(displayedXP)")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundColor(.warning)
                    .monospacedDigit()
                    .scaleEffect(animateXPNumber ? 1.2 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: animateXPNumber)

                Text("XP")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .opacity(animateResults ? 1.0 : 0.0)
        .offset(y: animateResults ? 0 : 30)
        .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.4), value: animateResults)
    }

    // MARK: - Rank Section

    private var rankSection: some View {
        VStack(spacing: 24) {
            // Rank Icon
            ZStack {
                if let _ = UIImage(named: displayedRank.rankIconName) {
                    Image(displayedRank.rankIconName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                } else {
                    // Fallback gradient circle
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [.danger, .warning],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 100, height: 100)

                        Text("\(displayedRank.level)")
                            .font(.system(size: 40, weight: .black))
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
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)

            // XP Progress Bar
            VStack(spacing: 8) {
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 20)

                        // Progress fill
                        RoundedRectangle(cornerRadius: 12)
                            .fill(LinearGradient(
                                colors: [.danger, .warning],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                            .frame(width: geometry.size.width * CGFloat(currentProgress), height: 20)
                            .animation(.easeInOut(duration: 1.5), value: currentProgress)
                    }
                }
                .frame(height: 20)
                .frame(maxWidth: 350)

                // XP Text
                if displayedRank.level < 10 {
                    HStack {
                        Text("\(displayedRank.xp) XP")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))

                        Spacer()

                        Text("\(displayedRank.xpForNextLevel) XP")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .frame(maxWidth: 350)
                } else {
                    Text("MAX RANK")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.warning)
                }
            }
            .padding(.horizontal, 32)
        }
        .opacity(animateResults ? 1.0 : 0.0)
        .offset(y: animateResults ? 0 : 30)
        .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.5), value: animateResults)
    }

    // MARK: - Level Up Overlay

    private var levelUpOverlay: some View {
        ZStack {
            // Sliding rank icon from top
            if let _ = UIImage(named: newRank.rankIconName) {
                Image(newRank.rankIconName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .offset(y: showLevelUp ? 0 : -200)
                    .opacity(showLevelUp ? 1.0 : 0.0)
                    .animation(.spring(response: 0.8, dampingFraction: 0.6), value: showLevelUp)
            } else {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [.danger, .warning],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 120, height: 120)

                    Text("\(newRank.level)")
                        .font(.system(size: 48, weight: .black))
                        .foregroundColor(.white)
                }
                .offset(y: showLevelUp ? 0 : -200)
                .opacity(showLevelUp ? 1.0 : 0.0)
                .animation(.spring(response: 0.8, dampingFraction: 0.6), value: showLevelUp)
            }

            // "RANK UP!" text
            VStack {
                Spacer()
                    .frame(height: 140)

                Text("RANK UP!")
                    .font(.system(size: 28, weight: .black))
                    .foregroundColor(.warning)
                    .shadow(color: .black, radius: 4)
                    .scaleEffect(showLevelUp ? 1.0 : 0.5)
                    .opacity(showLevelUp ? 1.0 : 0.0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.5).delay(0.3), value: showLevelUp)
            }
        }
    }

    // MARK: - Stat Column

    private struct StatColumn: View {
        let icon: String
        let value: String
        let label: String

        var body: some View {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(.white.opacity(0.8))

                Text(value)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .monospacedDigit()

                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            .frame(minWidth: 70)
        }
    }

    // MARK: - Animations

    private func startXPAnimation() {
        // Animate XP number counting up
        let animationDuration: Double = 1.5
        let steps = 30
        let xpPerStep = max(xpEarned / steps, 1)

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
    SinglePlayerGameOverView(
        enemiesDefeated: 12,
        xpEarned: 120,
        oldRank: PlayerRank(level: 3, xp: 450, kills: 25, deaths: 10),
        newRank: PlayerRank(level: 4, xp: 570, kills: 37, deaths: 10),
        onContinue: {},
        onPlayAgain: {}
    )
}
