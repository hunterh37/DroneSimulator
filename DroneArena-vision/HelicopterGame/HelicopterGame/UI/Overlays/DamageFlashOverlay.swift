//
//  DamageFlashOverlay.swift
//  HelicopterGame
//
//  Created by Hunter Harris on 10/3/25.
//

import SwiftUI

struct DamageFlashOverlay: View {
    let opacity: Double
    var body: some View {
        RadialGradient(
            gradient: Gradient(stops: [
                .init(color: .clear, location: 0.0),
                .init(color: .clear, location: 0.3),
                .init(color: .red.opacity(0.3), location: 0.6),
                .init(color: .red.opacity(0.8), location: 1.0)
            ]),
            center: .center,
            startRadius: 0,
            endRadius: 500
        )
        .opacity(opacity)
        .allowsHitTesting(false)
        .edgesIgnoringSafeArea(.all)
    }
}
