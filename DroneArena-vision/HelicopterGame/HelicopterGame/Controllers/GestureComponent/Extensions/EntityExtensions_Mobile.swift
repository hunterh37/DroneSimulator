//
//  EntityExtensions_Mobile.swift
//  HelicopterGame
//
//  Created by Hunter Harris on 10/3/25.
//

import Foundation
import RealityKit

public extension Entity {
    
    /// Configures collision shapes and input handling for interactive entities
    func configureCollision() {
        self.generateCollisionShapes(recursive: true)
        self.components.set(InputTargetComponent(allowedInputTypes: .all))
    #if os(visionOS)
        self.components.set(GestureComponent())
    #endif
    }
}
