#if os(visionOS)
import SwiftUI

/// Settings row for the pinch stick visuals.
struct PinchVisualsToggle: View {
    @State private var on = PinchStickRouter.shared.visualsEnabled

    var body: some View {
        Toggle("Pinch stick visuals", isOn: $on)
            .onChange(of: on) { _, v in PinchStickRouter.shared.visualsEnabled = v }
    }
}
#endif
