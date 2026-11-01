#if os(visionOS)
import SwiftUI

/// Vertical altitude tape, 0 to 10 ft.
struct LiveAltitudeTape: View {
    let heightCM: Int?
    var ceilingFt: Double = 10
    private var ft: Double? { heightCM.map { Double($0) / 30.48 } }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            LiveLabel(ft.map { String(format: "%.1f FT", $0) } ?? "- FT", size: 12,
                      color: ft == nil ? LiveTheme.textFaint : LiveTheme.text)
            GeometryReader { geo in
                let h = geo.size.height
                let y: (Double) -> CGFloat = { v in h - CGFloat(min(max(v, 0), ceilingFt) / ceilingFt) * h }
                ZStack(alignment: .topLeading) {
                    Rectangle().fill(LiveTheme.hairline).frame(width: 1).offset(x: 20)
                    ForEach(0...Int(ceilingFt), id: \.self) { i in
                        Rectangle().fill(LiveTheme.text.opacity(i == Int(ceilingFt) ? 0 : 0.6))
                            .frame(width: 8, height: 1).offset(x: 16, y: y(Double(i)))
                    }
                    Rectangle().fill(LiveTheme.danger).frame(width: 28, height: 1)
                        .offset(x: 12, y: y(ceilingFt))
                    if let ft {
                        Rectangle().fill(LiveTheme.text).frame(width: 22, height: 2)
                            .offset(x: 9, y: y(ft) - 1)
                            .animation(LiveTheme.spring, value: ft)
                    }
                }
            }
            .frame(width: 40)
        }
    }
}
#endif
