import CoreMedia
import Foundation

/// Turns raw Annex B bytes into display-ready sample buffers. Not thread safe; the owner serializes calls.
final class H264FrameAssembler: @unchecked Sendable {
    private var parser = H264NALParser()
    private var sps: [UInt8]?
    private var pps: [UInt8]?
    private var format: CMVideoFormatDescription?
    private var pendingSlices: [[UInt8]] = []
    private(set) var nalCounts: [Int: Int] = [:]
    private(set) var framesBuilt = 0

    func reset() {
        parser = H264NALParser()
        sps = nil; pps = nil; format = nil
        pendingSlices.removeAll()
    }

    func feed(_ bytes: [UInt8]) -> [CMSampleBuffer] {
        var out: [CMSampleBuffer] = []
        for nal in parser.feed(bytes) { handle(nal, &out) }
        return out
    }

    func flush() -> [CMSampleBuffer] {
        var out: [CMSampleBuffer] = []
        for nal in parser.flush() { handle(nal, &out) }
        flushFrame(&out)
        return out
    }

    private func handle(_ nal: NALUnit, _ out: inout [CMSampleBuffer]) {
        nalCounts[Int(nal.type), default: 0] += 1
        switch nal.type {
        case 7:
            flushFrame(&out)
            if sps != nal.bytes { sps = nal.bytes; format = nil }
        case 8:
            flushFrame(&out)
            if pps != nal.bytes { pps = nal.bytes; format = nil }
        case 1, 5:
            // first_mb_in_slice == 0 (ue(v) "1" bit) starts a new picture.
            if nal.bytes.count > 1, nal.bytes[1] & 0x80 != 0 { flushFrame(&out) }
            pendingSlices.append(nal.bytes)
        case 9:
            flushFrame(&out)
        default:
            break
        }
    }

    private func flushFrame(_ out: inout [CMSampleBuffer]) {
        guard !pendingSlices.isEmpty else { return }
        let slices = pendingSlices
        pendingSlices.removeAll()
        if format == nil { format = makeFormat() }
        guard let format else {
            if framesBuilt == 0 { FileLog.shared.write("video", "no SPS/PPS yet, frame dropped") }
            return
        }
        guard let sb = makeSample(slices, format: format) else {
            FileLog.shared.write("video", "sample build failed")
            return
        }
        if framesBuilt == 0 { FileLog.shared.write("video", "first frame") }
        framesBuilt += 1
        out.append(sb)
    }

    private func makeFormat() -> CMVideoFormatDescription? {
        guard let sps, let pps else { return nil }
        var fd: CMFormatDescription?
        let status = sps.withUnsafeBufferPointer { s in
            pps.withUnsafeBufferPointer { p in
                let ptrs = [s.baseAddress!, p.baseAddress!]
                let sizes = [s.count, p.count]
                return CMVideoFormatDescriptionCreateFromH264ParameterSets(
                    allocator: nil, parameterSetCount: 2,
                    parameterSetPointers: ptrs, parameterSetSizes: sizes,
                    nalUnitHeaderLength: 4, formatDescriptionOut: &fd)
            }
        }
        return status == noErr ? fd : nil
    }

    private func makeSample(_ slices: [[UInt8]], format: CMVideoFormatDescription) -> CMSampleBuffer? {
        var avcc: [UInt8] = []
        avcc.reserveCapacity(slices.reduce(0) { $0 + $1.count + 4 })
        for nal in slices {
            withUnsafeBytes(of: UInt32(nal.count).bigEndian) { avcc.append(contentsOf: $0) }
            avcc.append(contentsOf: nal)
        }
        var block: CMBlockBuffer?
        guard CMBlockBufferCreateWithMemoryBlock(
            allocator: nil, memoryBlock: nil, blockLength: avcc.count, blockAllocator: nil,
            customBlockSource: nil, offsetToData: 0, dataLength: avcc.count, flags: 0,
            blockBufferOut: &block) == noErr, let block else { return nil }
        guard avcc.withUnsafeBytes({
            CMBlockBufferReplaceDataBytes(with: $0.baseAddress!, blockBuffer: block, offsetIntoDestination: 0, dataLength: avcc.count)
        }) == noErr else { return nil }

        var sample: CMSampleBuffer?
        var size = avcc.count
        var timing = CMSampleTimingInfo(
            duration: .invalid,
            presentationTimeStamp: CMClockGetTime(CMClockGetHostTimeClock()),
            decodeTimeStamp: .invalid)
        guard CMSampleBufferCreateReady(
            allocator: nil, dataBuffer: block, formatDescription: format, sampleCount: 1,
            sampleTimingEntryCount: 1, sampleTimingArray: &timing,
            sampleSizeEntryCount: 1, sampleSizeArray: &size, sampleBufferOut: &sample) == noErr,
              let sample else { return nil }
        if let arr = CMSampleBufferGetSampleAttachmentsArray(sample, createIfNecessary: true),
           CFArrayGetCount(arr) > 0 {
            let d = unsafeBitCast(CFArrayGetValueAtIndex(arr, 0), to: CFMutableDictionary.self)
            CFDictionarySetValue(d, Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque(),
                                 Unmanaged.passUnretained(kCFBooleanTrue).toOpaque())
        }
        return sample
    }
}
