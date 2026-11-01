//
//  PlatformColor.swift
//  DicyaninVirtualJoystick
//
//  Cross-platform color shim. The rig's materials are authored against `UIColor`;
//  on macOS (where this package can be used to preview/screenshot the rigs) we map
//  that to `NSColor` so the same source compiles everywhere.
//

#if !canImport(UIKit) && canImport(AppKit)
import AppKit

/// On macOS, `UIColor` is aliased to `NSColor` so the shared material code compiles
/// unchanged. The two share the initializers and accessors this package relies on
/// (`init(white:alpha:)`, `init(red:green:blue:alpha:)`, the system color factories,
/// `withAlphaComponent`, and `getRed`).
public typealias UIColor = NSColor
#endif
