//
//  BattleAnnouncementView.swift
//  HelicopterGame
//
//  Created by Hunter Harris on 10/3/25.
//

import SwiftUI

struct BattleAnnouncementView: View {
    let scale: CGFloat
    let opacity: Double
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
            Image("Battle")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 400, maxHeight: 200)
                .scaleEffect(scale)
                .opacity(opacity)
                .shadow(color: .red.opacity(0.8), radius: 20, x: 0, y: 0)
                .shadow(color: .orange.opacity(0.6), radius: 40, x: 0, y: 0)
        }
    }
}
