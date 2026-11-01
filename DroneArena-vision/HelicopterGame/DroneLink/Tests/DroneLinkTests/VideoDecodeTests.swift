import CoreMedia
import Foundation
import Testing
import VideoToolbox
import Network
@testable import DroneLink

/// Feeds a real multi-slice H.264 stream in UDP-sized chunks and decodes every
/// sample with VideoToolbox, the same decoder AVSampleBufferDisplayLayer uses.
@MainActor
@Test func multiSliceStreamDecodesEveryFrame() throws {
    let url = try #require(Bundle.module.url(forResource: "tello_like", withExtension: "h264", subdirectory: "Fixtures"))
    let data = try Data(contentsOf: url)
    let stream = TelloVideoStream(port: 0)
    var samples: [CMSampleBuffer] = []
    stream.onSample = { samples.append($0) }

    var i = 0
    while i < data.count {
        let n = min(1460, data.count - i)
        stream.ingest(data.subdata(in: i..<(i + n)))
        i += n
    }
    stream.flushPending()

    #expect(samples.count == 30)
    #expect(stream.framesDecoded == 30)

    let fmt = try #require(CMSampleBufferGetFormatDescription(samples[0]))
    let dims = CMVideoFormatDescriptionGetDimensions(fmt)
    #expect(dims.width == 960 && dims.height == 720)

    var session: VTDecompressionSession?
    #expect(VTDecompressionSessionCreate(allocator: nil, formatDescription: fmt, decoderSpecification: nil,
                                         imageBufferAttributes: nil, outputCallback: nil,
                                         decompressionSessionOut: &session) == noErr)
    let s = try #require(session)
    var decoded = 0
    for sb in samples {
        let st = VTDecompressionSessionDecodeFrame(s, sampleBuffer: sb, flags: [], infoFlagsOut: nil) { status, _, image, _, _ in
            if status == noErr, image != nil { decoded += 1 }
        }
        #expect(st == noErr)
    }
    VTDecompressionSessionWaitForAsynchronousFrames(s)
    VTDecompressionSessionInvalidate(s)
    #expect(decoded == 30)
}

/// UDP end to end: real H.264 sent in 1460 byte datagrams to the listener port,
/// with a listener restart in the middle (the reconnect path that used to break video).
@MainActor
@Test func udpStreamSurvivesRestart() async throws {
    let url = try #require(Bundle.module.url(forResource: "tello_like", withExtension: "h264", subdirectory: "Fixtures"))
    let data = try Data(contentsOf: url)
    let port = UInt16.random(in: 42000...48000)
    let stream = TelloVideoStream(port: port)
    stream.start()
    stream.start()   // second call must keep the live listener
    try? await Task.sleep(for: .milliseconds(200))

    let conn = NWConnection(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: port)!, using: .udp)
    conn.start(queue: .main)
    var i = 0
    while i < data.count {
        let n = min(1460, data.count - i)
        conn.send(content: data.subdata(in: i..<(i + n)), completion: .contentProcessed { _ in })
        i += n
        try? await Task.sleep(for: .milliseconds(2))
    }
    for _ in 0..<100 where stream.framesDecoded < 25 { try? await Task.sleep(for: .milliseconds(20)) }
    #expect(stream.framesDecoded >= 25)
    #expect(stream.isListening)
    conn.cancel()
    stream.stop()
}
