//
//  CodableExtensions.swift
//  HelicopterGame
//
//  Created by Hunter Harris on 10/2/25.
//

import Foundation
import simd

// MARK: - SIMD3<Float> Codable Support
extension SIMD3<Float>: Codable {
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let x = try container.decode(Float.self)
        let y = try container.decode(Float.self)
        let z = try container.decode(Float.self)
        self.init(x, y, z)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(self.x)
        try container.encode(self.y)
        try container.encode(self.z)
    }
}

// MARK: - simd_quatf Codable Support
extension simd_quatf: Codable {
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let x = try container.decode(Float.self)
        let y = try container.decode(Float.self)
        let z = try container.decode(Float.self)
        let w = try container.decode(Float.self)
        self.init(ix: x, iy: y, iz: z, r: w)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(self.imag.x)
        try container.encode(self.imag.y)
        try container.encode(self.imag.z)
        try container.encode(self.real)
    }
}

// MARK: - DroneState Codable Support
extension DroneState: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)

        switch rawValue {
        case "idle":
            self = .idle
        case "flying":
            self = .flying
        case "carryingParcel":
            self = .carryingParcel
        case "recharging":
            self = .recharging
        case "emergency":
            self = .emergency
        default:
            self = .idle
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        let rawValue: String
        switch self {
        case .idle:
            rawValue = "idle"
        case .flying:
            rawValue = "flying"
        case .carryingParcel:
            rawValue = "carryingParcel"
        case .recharging:
            rawValue = "recharging"
        case .emergency:
            rawValue = "emergency"
        }

        try container.encode(rawValue)
    }
}