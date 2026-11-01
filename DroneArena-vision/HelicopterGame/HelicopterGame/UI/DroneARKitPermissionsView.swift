//
//  DroneARKitPermissionsView.swift
//  HelicopterGame
//
//  Pre-flight permissions gate. Requests ONLY the visionOS authorizations the
//  drone arena needs: hand tracking (gesture controls) and world sensing (room
//  mapping so drones collide with your space). No location / map access.
//
//  Adapted from ZombieShooter's ARKitPermissionsView, restyled with CyberTheme
//  and trimmed to the two ARKit authorizations this game actually uses.
//

#if os(visionOS)
import SwiftUI
import ARKit

struct DroneARKitPermissionsView: View {
    let onContinue: () -> Void

    @State private var handStatus: ARKitSession.AuthorizationStatus = .notDetermined
    @State private var worldStatus: ARKitSession.AuthorizationStatus = .notDetermined
    @State private var isRequesting = false

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "sensor.tag.radiowaves.forward.fill")
                .font(CyberTheme.font(56))
                .foregroundStyle(CyberTheme.green)
                .shadow(color: CyberTheme.green.opacity(0.7), radius: 14)

            Text("ENABLE TRACKING")
                .font(CyberTheme.monospaced(22, weight: .black))
                .foregroundStyle(CyberTheme.green)
                .tracking(2)

            Text("Drone Arena uses hand tracking and world sensing for gesture flight and room mapping.")
                .font(CyberTheme.monospaced(12))
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)

            VStack(spacing: 10) {
                permissionRow(
                    icon: "hand.raised.fill",
                    label: "HAND TRACKING",
                    detail: "Detects your hands to fly and fire",
                    status: handStatus
                )
                permissionRow(
                    icon: "cube.transparent.fill",
                    label: "WORLD SENSING",
                    detail: "Maps your room so drones interact with it",
                    status: worldStatus
                )
            }
            .padding(.horizontal, 28)

            Button {
                guard !isRequesting else { return }
                isRequesting = true
                Task { await requestPermissions() }
            } label: {
                HStack {
                    if isRequesting {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.black)
                            .scaleEffect(0.8)
                    }
                    Text("Continue")
                        .font(CyberTheme.monospaced(16, weight: .black))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(CyberTheme.green)
            .disabled(isRequesting)
            .padding(.horizontal, 36)
            .padding(.top, 6)
        }
        .padding(32)
        .frame(maxWidth: 460)
        .background(CyberTheme.panelGray.opacity(0.95), in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(CyberTheme.green.opacity(0.45), lineWidth: 1)
        )
        .shadow(color: CyberTheme.green.opacity(0.2), radius: 24)
        .task { await refreshStatuses() }
    }

    // MARK: - Row

    private func permissionRow(icon: String, label: String, detail: String, status: ARKitSession.AuthorizationStatus) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(CyberTheme.font(18))
                .foregroundStyle(CyberTheme.green)
                .frame(width: 36, height: 36)
                .background(CyberTheme.green.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(CyberTheme.green.opacity(0.25), lineWidth: 1))

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(CyberTheme.monospaced(13, weight: .bold))
                    .foregroundStyle(.white)
                Text(detail)
                    .font(CyberTheme.monospaced(10))
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()

            statusBadge(status)
        }
        .padding(10)
        .background(CyberTheme.panelGray, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(statusBorderColor(status), lineWidth: 1))
    }

    @ViewBuilder
    private func statusBadge(_ status: ARKitSession.AuthorizationStatus) -> some View {
        switch status {
        case .allowed:
            Label("Allowed", systemImage: "checkmark.circle.fill")
                .font(CyberTheme.monospaced(10, weight: .bold))
                .foregroundStyle(CyberTheme.green)
        case .denied:
            Label("Denied", systemImage: "xmark.circle.fill")
                .font(CyberTheme.monospaced(10, weight: .bold))
                .foregroundStyle(.red)
        default:
            Label("Not Set", systemImage: "circle.dotted")
                .font(CyberTheme.monospaced(10, weight: .bold))
                .foregroundStyle(.white.opacity(0.45))
        }
    }

    private func statusBorderColor(_ status: ARKitSession.AuthorizationStatus) -> Color {
        switch status {
        case .allowed: return CyberTheme.green.opacity(0.4)
        case .denied: return .red.opacity(0.4)
        default: return .white.opacity(0.1)
        }
    }

    // MARK: - Authorization

    /// Reflect the current authorization state without prompting (so a returning
    /// returning player sees current status).
    private func refreshStatuses() async {
        let session = ARKitSession()
        let results = await session.queryAuthorization(for: [.handTracking, .worldSensing])
        handStatus = results[.handTracking] ?? .notDetermined
        worldStatus = results[.worldSensing] ?? .notDetermined
    }

    private func requestPermissions() async {
        let session = ARKitSession()
        let results = await session.requestAuthorization(for: [.handTracking, .worldSensing])
        handStatus = results[.handTracking] ?? .notDetermined
        worldStatus = results[.worldSensing] ?? .notDetermined
        isRequesting = false
        onContinue()
    }
}

#Preview {
    DroneARKitPermissionsView(onContinue: {})
}
#endif
