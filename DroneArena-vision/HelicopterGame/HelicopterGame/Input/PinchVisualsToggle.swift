#if os(visionOS)
import PinchStickCore
import SwiftUI

/// Settings row for the pinch stick visuals.
struct PinchVisualsToggle: View {
    @State private var on = PinchStickRouter.shared.visualsEnabled

    @State private var mode = PinchStickRouter.shared.mode

    var body: some View {
        Picker("Sticks", selection: $mode) {
            Text("Pinch").tag(StickMode.pinch)
            Text("Thumb").tag(StickMode.thumb)
        }
        .pickerStyle(.segmented)
        .onChange(of: mode) { _, v in PinchStickRouter.shared.mode = v }
        Toggle("Stick visuals", isOn: $on)
            .onChange(of: on) { _, v in PinchStickRouter.shared.visualsEnabled = v }
    }
}
#endif
