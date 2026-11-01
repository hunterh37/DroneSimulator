
## Stage 1 done
DroneLink video, package only. Tests: 9 pass. App build succeeds.
- `TelloLink.video: TelloVideoStream`, `startVideo()` (listener on 11111 + `streamon`), `stopVideo()` (`streamoff` + stop)
- `@MainActor @Observable TelloVideoStream`: `init(port: UInt16 = 11111)`, `start()`, `stop()`, `ingest(_ data: Data)`, `displayLayer: AVSampleBufferDisplayLayer`, `fps: Double`, `framesDecoded: Int`, `lastFrameAt: Date?`, `isListening: Bool`
- `TelloVideoView(stream: TelloVideoStream)`: UIViewRepresentable, UIKit only
- `NALUnit(bytes:)` with `type`; `H264NALParser`: `feed(_ [UInt8]) -> [NALUnit]`, `flush() -> [NALUnit]`
