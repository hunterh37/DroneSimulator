import Testing
@testable import DroneLink

private let sps: [UInt8] = [0x67, 0x42, 0x00, 0x1F]
private let pps: [UInt8] = [0x68, 0xCE, 0x3C, 0x80]
private let idr: [UInt8] = [0x65, 0x88, 0x84, 0x00, 0x01]
private let sc3: [UInt8] = [0, 0, 1]
private let sc4: [UInt8] = [0, 0, 0, 1]

@Test func splitsMixedStartCodes() {
    var p = H264NALParser()
    let out = p.feed(sc4 + sps + sc4 + pps + sc3 + idr + sc4)
    #expect(out.map(\.bytes) == [sps, pps, idr])
    #expect(out.map(\.type) == [7, 8, 5])
}

@Test func holdsLastNALUntilNextStartCode() {
    var p = H264NALParser()
    #expect(p.feed(sc4 + idr).isEmpty)
    #expect(p.flush().map(\.bytes) == [idr])
}

@Test func nalSplitAcrossChunks() {
    var p = H264NALParser()
    let stream = sc4 + sps + sc4 + idr + sc4 + pps + sc3
    var got: [NALUnit] = []
    for b in stream { got += p.feed([b]) }
    #expect(got.map(\.bytes) == [sps, idr, pps])
}

@Test func startCodeSplitAcrossChunks() {
    var p = H264NALParser()
    var got = p.feed(sc4 + sps + [0, 0])
    got += p.feed([0, 1] + pps + [0])
    got += p.feed([0, 1, 0x41, 0x01])
    #expect(got.map(\.bytes) == [sps, pps])
    #expect(p.flush().map(\.type) == [1])
}

@Test func typeExtraction() {
    #expect(NALUnit(bytes: [0x67]).type == 7)
    #expect(NALUnit(bytes: [0x68]).type == 8)
    #expect(NALUnit(bytes: [0x65]).type == 5)
    #expect(NALUnit(bytes: [0x41]).type == 1)
    #expect(NALUnit(bytes: []).type == 0)
}
