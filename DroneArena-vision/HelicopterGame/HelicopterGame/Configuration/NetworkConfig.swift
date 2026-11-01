//
//  NetworkConfig.swift
//  HelicopterGame
//
//  Central configuration for all networking endpoints
//

import Foundation

public struct NetworkConfig {
    /// The production backend server host
    public static let backendHost = "helicoptergamebackend2-production.up.railway.app"

    /// The production backend server base URL
    public static let backendBaseURL = "https://\(backendHost)"

    /// Default WebSocket port (443 for HTTPS/WSS)
    public static let defaultPort: UInt16 = 443
}
