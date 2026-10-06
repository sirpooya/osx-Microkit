/// One raw HID connection to a VIA keyboard.
///
/// `exchange` must be atomic: send one report, then return the first incoming report that
/// `matches` accepts, discarding any others. Two exchanges never overlap; implementations
/// serialize them. The request is at most `VIAClient.reportSize` bytes and is zero-padded
/// by the transport.
public protocol ReportTransport: Sendable {
    func exchange(
        _ request: [UInt8],
        timeout: Duration,
        matches: @escaping @Sendable ([UInt8]) -> Bool
    ) async throws -> [UInt8]
}
