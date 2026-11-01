//
//  KillNotificationView.swift
//  HelicopterGame
//
//  Created by Hunter Harris on 10/3/25.
//

import SwiftUI

struct KillNotificationView: View {
    let killedPlayerName: String
    let opacity: Double
    var body: some View {
        VStack {
            Spacer()
            ZStack {
                Image("Killframe1")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 380)
                Text("You killed \(killedPlayerName)")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.8), radius: 4, x: 0, y: 2)
            }
            .opacity(opacity)
            .padding(.bottom, 180)
        }
    }
}
