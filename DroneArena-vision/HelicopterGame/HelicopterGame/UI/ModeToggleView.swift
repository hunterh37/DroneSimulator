//
//  ModeToggleView.swift
//  HelicopterGame
//
//  Created by Hunter Harris on 10/1/25.
//

import SwiftUI

struct ModeToggleView: View {
    @Bindable var buildModeManager: BuildModeManager
    let onModeChanged: (GameMode) -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text("Game Mode")
                .font(.caption)
                .foregroundColor(.white)

            HStack(spacing: 4) {
                // Build Mode Button
                Button(action: {
                    buildModeManager.switchToMode(.build)
                    onModeChanged(.build)
                }) {
                    Text("Build")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(buildModeManager.currentMode == .build ? .black : .white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(buildModeManager.currentMode == .build ? Color.yellow : Color.clear)
                        )
                }

                // Play Mode Button
                Button(action: {
                    buildModeManager.switchToMode(.play)
                    onModeChanged(.play)
                }) {
                    Text("Play")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(buildModeManager.currentMode == .play ? .black : .white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(buildModeManager.currentMode == .play ? Color.green : Color.clear)
                        )
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white, lineWidth: 1)
            )

            // Layout status
            if buildModeManager.currentMode == .build {
                Text(buildModeManager.isLayoutValid ? "Layout Ready" : "Layout Incomplete")
                    .font(.caption2)
                    .foregroundColor(buildModeManager.isLayoutValid ? .green : .orange)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black)
                .opacity(0.7)
        )
    }
}

#Preview {
    ModeToggleView(
        buildModeManager: BuildModeManager(),
        onModeChanged: { _ in }
    )
}