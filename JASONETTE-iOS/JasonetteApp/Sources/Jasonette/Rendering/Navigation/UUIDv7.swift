import Foundation

/// RFC 9562 UUIDv7: 48-bit millisecond timestamp + version + random.
/// Time-ordered so IDs generated later sort after earlier ones — useful for
/// stable tab ordering and any other insertion-order-sensitive identity.
enum UUIDv7 {
    static func generate() -> UUID {
        var bytes = [UInt8](repeating: 0, count: 16)

        let ms = UInt64(Date().timeIntervalSince1970 * 1000)
        bytes[0] = UInt8((ms >> 40) & 0xFF)
        bytes[1] = UInt8((ms >> 32) & 0xFF)
        bytes[2] = UInt8((ms >> 24) & 0xFF)
        bytes[3] = UInt8((ms >> 16) & 0xFF)
        bytes[4] = UInt8((ms >> 8) & 0xFF)
        bytes[5] = UInt8(ms & 0xFF)

        var randBytes = [UInt8](repeating: 0, count: 10)
        _ = randBytes.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 10, $0.baseAddress!) }

        bytes[6] = (randBytes[0] & 0x0F) | 0x70   // version 7
        bytes[7] = randBytes[1]
        bytes[8] = (randBytes[2] & 0x3F) | 0x80   // variant RFC 4122
        for i in 0..<7 { bytes[9 + i] = randBytes[3 + i] }

        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}
