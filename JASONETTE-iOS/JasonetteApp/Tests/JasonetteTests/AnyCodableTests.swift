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

    // MARK: - unwrapped

    func testUnwrappedPreservesString() {
        let v = AnyCodable("hello")
        XCTAssertEqual(v.unwrapped as? String, "hello")
    }

    func testUnwrappedPreservesInt() {
        let v = AnyCodable(42)
        XCTAssertEqual(v.unwrapped as? Int, 42)
    }

    func testUnwrappedPreservesBool() {
        let v = AnyCodable(true)
        XCTAssertEqual(v.unwrapped as? Bool, true)
    }

    func testUnwrappedConvertsAnyCodableArray() throws {
        // Decode a JSON array — value is [AnyCodable]
        let data = Data("[1, \"two\", 3]".utf8)
        let v = try JSONDecoder().decode(AnyCodable.self, from: data)
        let result = v.unwrapped
        // Should be [Any] with native types, not [AnyCodable]
        XCTAssertNil(result as? [AnyCodable], "Should be unwrapped to [Any]")
        guard let arr = result as? [Any] else {
            XCTFail("Expected [Any]"); return
        }
        XCTAssertEqual(arr[0] as? Int, 1)
        XCTAssertEqual(arr[1] as? String, "two")
        XCTAssertEqual(arr[2] as? Int, 3)
    }

    func testUnwrappedConvertsAnyCodableDict() throws {
        // Decode a JSON object — value is [String: AnyCodable]
        let data = Data(#"{"name":"Alice","age":30}"#.utf8)
        let v = try JSONDecoder().decode(AnyCodable.self, from: data)
        let result = v.unwrapped
        XCTAssertNil(result as? [String: AnyCodable], "Should be unwrapped to [String: Any]")
        guard let dict = result as? [String: Any] else {
            XCTFail("Expected [String: Any]"); return
        }
        XCTAssertEqual(dict["name"] as? String, "Alice")
        XCTAssertEqual(dict["age"] as? Int, 30)
    }

    func testUnwrappedHandlesDeeplyNestedStructures() throws {
        let json = Data(#"{"users":[{"name":"Alice","scores":[1,2,3]}]}"#.utf8)
        let v = try JSONDecoder().decode(AnyCodable.self, from: json)
        let result = v.unwrapped
        guard let dict = result as? [String: Any],
              let users = dict["users"] as? [Any],
              let user = users.first as? [String: Any],
              let scores = user["scores"] as? [Any] else {
            XCTFail("Deep unwrap failed"); return
        }
        XCTAssertEqual(user["name"] as? String, "Alice")
        XCTAssertEqual(scores.count, 3)
        XCTAssertEqual(scores[0] as? Int, 1)
    }

    func testUnwrappedResultIsJSONSerializable() throws {
        let json = Data(#"{"key":"value","nested":{"n":1},"arr":[true,false]}"#.utf8)
        let v = try JSONDecoder().decode(AnyCodable.self, from: json)
        let result = v.unwrapped
        // Before fix: this would throw ObjC NSInvalidArgumentException
        XCTAssertTrue(JSONSerialization.isValidJSONObject(result),
                      "unwrapped must produce a JSONSerialization-safe value")
        XCTAssertNoThrow(try JSONSerialization.data(withJSONObject: result))
    }

    func testUnwrappedHandlesMaxDepthWithoutCrash() {
        // Build a deeply nested AnyCodable (> 64 levels) via manual construction
        var nested: AnyCodable = AnyCodable("leaf")
        for _ in 0..<70 {
            nested = AnyCodable(["deep": nested])
        }
        // Should not crash
        let result = nested.unwrapped
        XCTAssertNotNil(result)
    }

    func testUnwrappedNestedArrayIsNotAnyCodableArray() throws {
        // Simulate what happens in render(): head.data has [String: AnyCodable] values
        let json = Data(#"{"items":["a","b","c"]}"#.utf8)
        let v = try JSONDecoder().decode(AnyCodable.self, from: json)
        let dict = v.unwrapped as? [String: Any]
        let items = dict?["items"]
        XCTAssertNil(items as? [AnyCodable], "Inner array must not be [AnyCodable]")
        XCTAssertNotNil(items as? [Any])
    }
}
