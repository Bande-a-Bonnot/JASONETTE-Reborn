import XCTest
@testable import Jasonette

final class AnyCodableTests: XCTestCase {
    func testDecodeString() throws {
        let json = Data(#""hello""#.utf8)
        let value = try JSONDecoder().decode(AnyCodable.self, from: json)
        XCTAssertEqual(value.string, "hello")
    }

    func testDecodeInt() throws {
        let json = Data("42".utf8)
        let value = try JSONDecoder().decode(AnyCodable.self, from: json)
        XCTAssertEqual(value.int, 42)
    }

    func testDecodeBool() throws {
        let json = Data("true".utf8)
        let value = try JSONDecoder().decode(AnyCodable.self, from: json)
        XCTAssertEqual(value.bool, true)
    }

    func testDecodeDouble() throws {
        let json = Data("3.14".utf8)
        let value = try JSONDecoder().decode(AnyCodable.self, from: json)
        guard let d = value.double else {
            XCTFail("Expected Double")
            return
        }
        XCTAssertEqual(d, 3.14, accuracy: 0.001)
    }

    func testDecodeArray() throws {
        let json = Data("[1, 2, 3]".utf8)
        let value = try JSONDecoder().decode(AnyCodable.self, from: json)
        XCTAssertEqual(value.array?.count, 3)
    }

    func testDecodeDictionary() throws {
        let json = Data(#"{"key": "value"}"#.utf8)
        let value = try JSONDecoder().decode(AnyCodable.self, from: json)
        XCTAssertNotNil(value.dictionary)
    }

    func testCGFloat() throws {
        let json = Data("16".utf8)
        let value = try JSONDecoder().decode(AnyCodable.self, from: json)
        XCTAssertEqual(value.cgFloat, 16)
    }

    func testEncode() throws {
        let value = AnyCodable("test")
        let data = try JSONEncoder().encode(value)
        let str = String(data: data, encoding: .utf8)
        XCTAssertEqual(str, #""test""#)
    }

    func testEquatable() {
        XCTAssertEqual(AnyCodable(42), AnyCodable(42))
        XCTAssertNotEqual(AnyCodable(42), AnyCodable("42"))
    }
}
