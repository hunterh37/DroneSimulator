//
//  PlayerListOverlay.swift
//  HelicopterGame
//
//  Created by Hunter Harris on 10/3/25.
//

import SwiftUI

struct PlayerListOverlay: View {
    @Binding var isPresented: Bool
    @Environment(GameUIModel.self) var gameUIModel
    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        isPresented = false
                    }
                }
            VStack(spacing: 20) {
                GlassButton("Close", icon: "xmark") {
                    SteelHaptics.lightTap()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        isPresented = false
                    }
                }
                .frame(width: 120)
            }
        }
    }
}
