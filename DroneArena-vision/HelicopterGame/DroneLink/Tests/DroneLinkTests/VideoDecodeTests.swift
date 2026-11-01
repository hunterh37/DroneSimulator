import CoreMedia
import Foundation
import Testing
import VideoToolbox
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
