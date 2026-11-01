import Darwin
import Foundation

/// Plain BSD UDP socket read off the main thread. Rebinds instantly after close
/// (SO_REUSEADDR/SO_REUSEPORT), so a second stream session gets a fresh socket.
final class UDPSocketReceiver: @unchecked Sendable {
    private let fd: Int32
    private let source: DispatchSourceRead
    private var buffer = [UInt8](repeating: 0, count: 65_536)

    init?(port: UInt16, queue: DispatchQueue, onData: @escaping @Sendable ([UInt8]) -> Void) {
        let s = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard s >= 0 else { return nil }
        var one: Int32 = 1
        setsockopt(s, SOL_SOCKET, SO_REUSEADDR, &one, socklen_t(MemoryLayout<Int32>.size))
        setsockopt(s, SOL_SOCKET, SO_REUSEPORT, &one, socklen_t(MemoryLayout<Int32>.size))
        var rcv: Int32 = 2 * 1024 * 1024
        setsockopt(s, SOL_SOCKET, SO_RCVBUF, &rcv, socklen_t(MemoryLayout<Int32>.size))
        _ = fcntl(s, F_SETFL, fcntl(s, F_GETFL) | O_NONBLOCK)
        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr = in_addr(s_addr: INADDR_ANY)
        let bound = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(s, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
        }
        guard bound == 0 else { close(s); return nil }
        fd = s
        source = DispatchSource.makeReadSource(fileDescriptor: s, queue: queue)
        source.setEventHandler { [unowned self] in
            while true {
                let n = self.buffer.withUnsafeMutableBytes { recv(self.fd, $0.baseAddress, $0.count, 0) }
                if n <= 0 { break }
                onData(Array(self.buffer[0..<n]))
            }
        }
        source.setCancelHandler { close(s) }
        source.resume()
    }

    func cancel() { source.cancel() }
}
