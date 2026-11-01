#if os(visionOS)
import SwiftUI
import RealityKit
import CoreText

// MARK: - Theme Constants
public enum CyberTheme {
    public static let green = Color(red: 0.02, green: 1.0, blue: 0.38)//Color(red: 0.05, green: 1.0, blue: 0.65)
    public static let darkGreen = Color(red: 0.0, green: 0.15, blue: 0.03)
    public static let background = Color(red: 0.02, green: 0.02, blue: 0.03)
    public static let panelGray = Color(red: 0.08, green: 0.08, blue: 0.1)
    public static let alertRed = Color(red: 1.0, green: 0.1, blue: 0.2)
    public static let purple = Color(red: 0.7, green: 0.3, blue: 1.0)
    public static let glowRadius: CGFloat = 8

    // MARK: - Typography (single source of truth)
    //
    // Swap the entire app's font by changing `fontName` to any bundled font's
    // PostScript name (e.g. "VT323-Regular"). Set to nil to fall back to the
    // system monospaced font. Every UI font in the app flows through here.
    //
    // Bundled options:
    //   "ShareTechMono-Regular"  — clean readable terminal/Matrix style (default)
    //   "VT323-Regular"          — chunky pixel terminal style
    public static let fontName: String? = "ShareTechMono-Regular"

    /// Bundled font files to register at launch. Add new `.ttf`/`.otf` names here.
    private static let bundledFonts = ["ShareTechMono-Regular", "VT323-Regular"]

    /// Registers all bundled custom fonts with CoreText so they're resolvable by
    /// PostScript name in SwiftUI (`Font.custom`), UIKit (`UIFont(name:)`), and
    /// RealityKit (`MeshResource.Font(name:)`). Call once at app launch.
    public static func registerFonts() {
        for name in bundledFonts {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else {
                print("⚠️ CyberTheme: missing bundled font \(name).ttf")
                continue
            }
            var error: Unmanaged<CFError>?
            if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                // Already-registered is not a real failure.
                print("ℹ️ CyberTheme: font \(name) register note: \(String(describing: error))")
            }
        }
    }

    /// The canonical app font. Use this everywhere instead of `.system(...)`.
    public static func font(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        if let name = fontName {
            // Custom display fonts are single-weight; weight is honored for the
            // system fallback only. Size maps 1:1.
            return .custom(name, fixedSize: size)
        }
        return .system(size: size, weight: weight, design: .monospaced)
    }

    /// Back-compat alias — existing call sites keep working and now use the
    /// bundled Matrix font automatically.
    public static func monospaced(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        font(size, weight: weight)
    }

    /// UIKit font for RealityKit 3D text & anywhere a `UIFont` is required.
    /// Flows through the same `fontName` source of truth.
    public static func uiFont(_ size: CGFloat, weight: UIFont.Weight = .bold) -> UIFont {
        if let name = fontName, let f = UIFont(name: name, size: size) {
            return f
        }
        return .monospacedSystemFont(ofSize: size, weight: weight)
    }

    /// RealityKit mesh font (extruded 3D text). Same source of truth.
    public static func meshFont(_ size: CGFloat, weight: UIFont.Weight = .bold) -> MeshResource.Font {
        if let name = fontName, let f = MeshResource.Font(name: name, size: size) {
            return f
        }
        return MeshResource.Font.monospacedSystemFont(ofSize: size, weight: weight)
    }
}

// MARK: - Cyber Components

public struct CyberPanel<Content: View>: View {
    let title: String
    let content: Content
    
    public init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(title)
                    .font(CyberTheme.monospaced(10, weight: .black))
                    .foregroundStyle(CyberTheme.background)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(CyberTheme.green)
                
                Spacer()
                
                Rectangle()
                    .fill(CyberTheme.green.opacity(0.3))
                    .frame(height: 1)
            }
            
            content
                .background(CyberTheme.panelGray.opacity(0.7))
                .pulsingGreenBorder(opacity: 0.2)
        }
    }
}

public struct StatusTag: View {
    let text: String
    let color: Color
    
    public init(text: String, color: Color) {
        self.text = text
        self.color = color
    }
    
    public var body: some View {
        Text(text)
            .font(CyberTheme.monospaced(9, weight: .black))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .overlay(Rectangle().stroke(color.opacity(0.5), lineWidth: 1))
    }
}

public struct DigitalGrid: View {
    @State private var pulse = false

    public init() {}
    public var body: some View {
        Canvas { context, size in
            let step: CGFloat = 30
            for x in stride(from: 0, through: size.width, by: step) {
                context.stroke(Path(CGRect(x: x, y: 0, width: 0.3, height: size.height)), with: .color(CyberTheme.green.opacity(0.15)))
            }
            for y in stride(from: 0, through: size.height, by: step) {
                context.stroke(Path(CGRect(x: 0, y: y, width: size.width, height: 0.3)), with: .color(CyberTheme.green.opacity(0.15)))
            }
        }
        .opacity(pulse ? 0.75 : 0.4)
        .animation(
            .easeInOut(duration: 2.8).repeatForever(autoreverses: true),
            value: pulse
        )
        .onAppear { pulse = true }
    }
}

public struct ScanlineOverlay: View {
    public init() {}
    public var body: some View {
        GeometryReader { geo in
            Path { path in
                let step: CGFloat = 4
                for y in stride(from: 0, through: geo.size.height, by: step) {
                    path.addRect(CGRect(x: 0, y: y, width: geo.size.width, height: 1))
                }
            }
            .fill(Color.black.opacity(0.5))
        }
    }
}

// MARK: - Pulsing Green Border Modifier

public struct PulsingGreenBorder: ViewModifier {
    var baseOpacity: Double
    var lineWidth: CGFloat
    var glowRadius: CGFloat

    public func body(content: Content) -> some View {
        content
//            .overlay(
//                Rectangle()
//                    .stroke(CyberTheme.green.opacity(baseOpacity), lineWidth: lineWidth)
//                    .shadow(color: CyberTheme.green.opacity(baseOpacity * 0.4), radius: glowRadius)
//            )
    }
}

public extension View {
    func pulsingGreenBorder(opacity: Double = 0.25, lineWidth: CGFloat = 1, glowRadius: CGFloat = 6) -> some View {
        modifier(PulsingGreenBorder(baseOpacity: opacity, lineWidth: lineWidth, glowRadius: glowRadius))
    }
}

#endif
