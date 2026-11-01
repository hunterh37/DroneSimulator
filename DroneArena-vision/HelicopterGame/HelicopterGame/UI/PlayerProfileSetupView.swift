import SwiftUI

struct PlayerProfileSetupView: View {
    @State private var profileManager = GameContext.shared.playerProfile
    @State private var tempPlayerName: String = ""
    @State private var validationError: String?
    @FocusState private var isTextFieldFocused: Bool

    let onComplete: () -> Void

    init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
    }

    var body: some View {
        VStack(spacing: 30) {
            headerSection
            usernameSection
            colorSelectionSection
            actionButtons
        }
        .padding(40)
        .background(Color.black.opacity(0.3))
        .cornerRadius(20)
        .onAppear {
            tempPlayerName = profileManager.playerName
        }
    }

    private var headerSection: some View {
        VStack(spacing: 10) {
            Text("🎮 Player Profile")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text("Set your multiplayer identity")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.gray)
        }
    }

    private var usernameSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Username")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)

            TextField("Enter your username", text: $tempPlayerName)
                .font(.system(size: 24, weight: .medium, design: .rounded))
                .padding(16)
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
                .foregroundColor(.white)
                .focused($isTextFieldFocused)
                .onChange(of: tempPlayerName) { _, newValue in
                    validationError = profileManager.validatePlayerName(newValue)
                }
                .onSubmit {
                    handleSave()
                }

            if let error = validationError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }

    private var colorSelectionSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Player Color")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6), spacing: 10) {
                ForEach(0..<profileManager.presetColors.count, id: \.self) { index in
                    colorButton(for: index)
                }
            }
        }
    }

    private func colorButton(for index: Int) -> some View {
        Button(action: {
            profileManager.selectedColorIndex = index
        }) {
            Circle()
                .fill(profileManager.presetColors[index])
                .frame(width: 50, height: 50)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: profileManager.selectedColorIndex == index ? 4 : 0)
                )
                .scaleEffect(profileManager.selectedColorIndex == index ? 1.1 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: profileManager.selectedColorIndex)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var actionButtons: some View {
        HStack(spacing: 20) {
            if profileManager.playerName != tempPlayerName {
                Button("Cancel") {
                    tempPlayerName = profileManager.playerName
                    validationError = nil
                }
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.gray)
            }

            Button(action: handleSave) {
                Text(profileManager.isProfileComplete() ? "Continue" : "Save Profile")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 15)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(canSave ? profileManager.playerColor : Color.gray)
                    )
            }
            .disabled(!canSave)
        }
    }

    private var canSave: Bool {
        validationError == nil && !tempPlayerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func handleSave() {
        guard canSave else { return }

        profileManager.playerName = tempPlayerName.trimmingCharacters(in: .whitespacesAndNewlines)
        gameLog("🎨 [PlayerProfileSetupView] Saved profile: '\(profileManager.playerName)' with color \(profileManager.playerColorHex)")

        if profileManager.isProfileComplete() {
            onComplete()
        }
    }
}

#Preview {
    ZStack {
        Color.black
        PlayerProfileSetupView {
            gameLog("Profile setup complete")
        }
    }
    .ignoresSafeArea()
}