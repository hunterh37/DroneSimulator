#if canImport(UIKit)
import SwiftUI
import UIKit

/// Hosts `TelloVideoStream.displayLayer` in SwiftUI.
public struct TelloVideoView: UIViewRepresentable {
    public let stream: TelloVideoStream
    public init(stream: TelloVideoStream) { self.stream = stream }

    public func makeUIView(context: Context) -> LayerHostView { LayerHostView(stream: stream) }
    public func updateUIView(_ view: LayerHostView, context: Context) {}

    public final class LayerHostView: UIView {
        private let hosted: CALayer
        init(stream: TelloVideoStream) {
            hosted = stream.displayLayer
            super.init(frame: .zero)
            backgroundColor = .black
            layer.addSublayer(hosted)
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) unavailable") }
        public override func layoutSubviews() {
            super.layoutSubviews()
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            hosted.frame = bounds
            CATransaction.commit()
        }
    }
}
#endif
