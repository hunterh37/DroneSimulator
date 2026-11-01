//
//  PlayerSettings.swift
//  HelicopterGame
//
//  Created by Hunter Harris on 10/1/25.
//

import Foundation
import Combine

// MARK: - Player Settings
@MainActor
public class PlayerSettings: ObservableObject {
    @Published public var controlSensitivity: Float = 1.0
    @Published public var turningSensitivity: Float = 1.0
    @Published public var comfortMode: Bool = false
    @Published public var snapTurning: Bool = false
    @Published public var reducedMotion: Bool = false
    @Published public var hapticFeedback: Bool = true

    public init() {}

    // Comfort settings for motion sensitivity
    public var motionDamping: Float {
        return comfortMode ? 0.5 : 1.0
    }

    public var accelerationLimit: Float {
        return comfortMode ? 5.0 : 10.0
    }
}