//
//  JoystickTipsOverlay.swift
//  HelicopterGame
//
//  Created by Hunter Harris on 10/3/25.
//

import SwiftUI

struct JoystickTipsOverlay: View {
    var body: some View {
        VStack {
            Spacer()
            HStack {
                VStack(spacing: 8) {
                    Text("THROTTLE + YAW")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.8))
                        .cornerRadius(8)
                        .padding(.bottom, 30)
                    ZStack {
                        Circle()
                            .fill(.black.opacity(0.3))
                            .frame(width: 120, height: 120)
                            .overlay(
                                Circle()
                                    .stroke(.white.opacity(0.5), lineWidth: 1)
                            )
                        VStack {
                            VStack(spacing: 2) {
                                Image(systemName: "arrow.up")
                                    .font(.caption2)
                                Text("Fly Up")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.white)
                            .offset(y: -35)
                            Spacer()
                            VStack(spacing: 2) {
                                Text("Fly Down")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                Image(systemName: "arrow.down")
                                    .font(.caption2)
                            }
                            .foregroundColor(.white)
                            .offset(y: 35)
                        }
                        .frame(height: 120)
                        HStack {
                            HStack(spacing: 2) {
                                Image(systemName: "arrow.left")
                                    .font(.caption2)
                                Text("Turn Left")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.white)
                            .offset(x: -45)
                            Spacer()
                            HStack(spacing: 2) {
                                Text("Turn Right")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                Image(systemName: "arrow.right")
                                    .font(.caption2)
                            }
                            .foregroundColor(.white)
                            .offset(x: 45)
                        }
                        .frame(width: 120)
                    }
                }
                Spacer()
                VStack(spacing: 8) {
                    Text("MOVEMENT")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.8))
                        .cornerRadius(8)
                        .padding(.bottom, 30)
                    ZStack {
                        Circle()
                            .fill(.black.opacity(0.3))
                            .frame(width: 120, height: 120)
                            .overlay(
                                Circle()
                                    .stroke(.white.opacity(0.5), lineWidth: 1)
                            )
                        VStack {
                            VStack(spacing: 2) {
                                Image(systemName: "arrow.up")
                                    .font(.caption2)
                                Text("Forward")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.white)
                            .offset(y: -35)
                            Spacer()
                            VStack(spacing: 2) {
                                Text("Backward")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                Image(systemName: "arrow.down")
                                    .font(.caption2)
                            }
                            .foregroundColor(.white)
                            .offset(y: 35)
                        }
                        .frame(height: 120)
                        HStack {
                            HStack(spacing: 2) {
                                Image(systemName: "arrow.left")
                                    .font(.caption2)
                                Text("Strafe Left")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.white)
                            .offset(x: -45)
                            Spacer()
                            HStack(spacing: 2) {
                                Text("Strafe Right")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                Image(systemName: "arrow.right")
                                    .font(.caption2)
                            }
                            .foregroundColor(.white)
                            .offset(x: 45)
                        }
                        .frame(width: 120)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
    }
}
