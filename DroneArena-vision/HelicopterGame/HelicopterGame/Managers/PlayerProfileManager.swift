import SwiftUI
import Foundation

@MainActor
@Observable
public class PlayerProfileManager {
    // Backing store for GameContext — fileprivate so this is the only file
    // that can reach `PlayerProfileManager.shared` directly; everyone else
    // must go through GameContext.shared.playerProfile.
    fileprivate static let shared = PlayerProfileManager()

    public var playerName: String {
        didSet {
            UserDefaults.standard.set(playerName, forKey: "multiplayer_player_name")
        }
    }

    public var selectedColorIndex: Int {
        didSet {
            UserDefaults.standard.set(selectedColorIndex, forKey: "multiplayer_color_index")
        }
    }

    public var playerColor: Color {
        presetColors[selectedColorIndex]
    }

    public var playerColorHex: String {
        presetColorHexValues[selectedColorIndex]
    }

    public let presetColors: [Color] = [
        Color(red: 1.0, green: 0.42, blue: 0.21),    // #FF6B35 - Vibrant Orange
        Color(red: 0.31, green: 0.80, blue: 0.77),   // #4ECDC4 - Turquoise
        Color(red: 1.0, green: 0.35, blue: 0.35),    // #FF5959 - Red
        Color(red: 0.20, green: 0.80, blue: 0.20),   // #33CC33 - Green
        Color(red: 0.26, green: 0.65, blue: 1.0),    // #42A5FF - Blue
        Color(red: 0.86, green: 0.20, blue: 0.86),   // #DC33DC - Magenta
        Color(red: 1.0, green: 0.84, blue: 0.0),     // #FFD700 - Gold
        Color(red: 0.85, green: 0.44, blue: 0.84),   // #D970D4 - Pink
        Color(red: 0.50, green: 0.20, blue: 0.80),   // #8033CC - Purple
        Color(red: 1.0, green: 0.50, blue: 0.0),     // #FF8000 - Orange
        Color(red: 0.20, green: 0.60, blue: 0.80),   // #3399CC - Light Blue
        Color(red: 0.60, green: 0.80, blue: 0.20)    // #99CC33 - Lime Green
    ]

    public let presetColorHexValues: [String] = [
        "#FF6B35", "#4ECDC4", "#FF5959", "#33CC33",
        "#42A5FF", "#DC33DC", "#FFD700", "#D970D4",
        "#8033CC", "#FF8000", "#3399CC", "#99CC33"
    ]

    private init() {
        // Load cached values or use defaults
        self.playerName = UserDefaults.standard.string(forKey: "multiplayer_player_name") ?? ""
        self.selectedColorIndex = UserDefaults.standard.integer(forKey: "multiplayer_color_index") // defaults to 0

        // Validate color index is within bounds
        if selectedColorIndex >= presetColors.count {
            selectedColorIndex = 0
        }

        gameLog("🎨 [PlayerProfileManager] Loaded profile: '\(playerName)' with color \(playerColorHex)")
    }

    public func isProfileComplete() -> Bool {
        return !playerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public func validatePlayerName(_ name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "Please enter a username"
        }
        if trimmed.count > 20 {
            return "Username must be 20 characters or less"
        }
        if trimmed.count < 2 {
            return "Username must be at least 2 characters"
        }
        return nil
    }
}

extension GameContext {
    public var playerProfile: PlayerProfileManager { PlayerProfileManager.shared }
}