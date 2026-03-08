import XCTest
@testable import Jasonette

/// Cross-platform consistency tests that read shared JSON fixtures
/// from the monorepo root `test-fixtures/` directory. The same fixtures
/// are consumed by the Android test suite so that both engines are
/// validated against identical inputs and expected outputs.
final class CrossPlatformTests: XCTestCase {

    // MARK: - Fixture loading

    private func loadFixture(_ name: String) -> [String: Any] {
        let testDir = URL(fileURLWithPath: #file).deletingLastPathComponent()
        let fixturesDir = testDir
            .deletingLastPathComponent() // JasonetteTests/ -> Tests/
            .deletingLastPathComponent() // Tests/ -> JasonetteApp/
            .deletingLastPathComponent() // JasonetteApp/ -> JASONETTE-iOS/
            .deletingLastPathComponent() // JASONETTE-iOS/ -> JASONETTE-Reborn/
            .appendingPathComponent("test-fixtures")
        let url = fixturesDir.appendingPathComponent(name)
        guard let data = try? Data(contentsOf: url) else {
            XCTFail("Fixture not found: \(url.path)")
            return [:]
        }
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            XCTFail("Fixture is not a JSON object: \(name)")
            return [:]
        }
        return obj
    }

    // MARK: - Template simple interpolation

    func testSimpleInterpolation() {
        let fixture = loadFixture("template-simple.json")
        guard let template = fixture["template"],
              let context = fixture["context"] as? [String: Any],
              let expected = fixture["expected"] as? String else {
            XCTFail("Bad fixture shape"); return
        }
        let result = TemplateEngine.render(template, context: context)
        XCTAssertEqual(result as? String, expected)
    }

    // MARK: - Template #each

    func testEachDirective() {
        let fixture = loadFixture("template-each.json")
        guard let template = fixture["template"],
              let context = fixture["context"] as? [String: Any],
              let expected = fixture["expected"] else {
            XCTFail("Bad fixture shape"); return
        }
        let result = TemplateEngine.render(template, context: context)
        let resultData = try? JSONSerialization.data(
            withJSONObject: result, options: .sortedKeys)
        let expectedData = try? JSONSerialization.data(
            withJSONObject: expected, options: .sortedKeys)
        XCTAssertNotNil(resultData, "Result is not serializable")
        XCTAssertNotNil(expectedData, "Expected is not serializable")
        XCTAssertEqual(resultData, expectedData)
    }

    // MARK: - Template #if true

    func testIfTrue() {
        let fixture = loadFixture("template-if.json")
        guard let template = fixture["template"],
              let contextTrue = fixture["context_true"] as? [String: Any],
              let expectedTrue = fixture["expected_true"] else {
            XCTFail("Bad fixture shape"); return
        }
        let result = TemplateEngine.render(template, context: contextTrue)
        let resultData = try? JSONSerialization.data(
            withJSONObject: result, options: .sortedKeys)
        let expectedData = try? JSONSerialization.data(
            withJSONObject: expectedTrue, options: .sortedKeys)
        XCTAssertNotNil(resultData, "Result is not serializable")
        XCTAssertNotNil(expectedData, "Expected is not serializable")
        XCTAssertEqual(resultData, expectedData)
    }

    // MARK: - Template #if false

    func testIfFalse() {
        let fixture = loadFixture("template-if.json")
        guard let template = fixture["template"],
              let contextFalse = fixture["context_false"] as? [String: Any] else {
            XCTFail("Bad fixture shape"); return
        }
        let result = TemplateEngine.render(template, context: contextFalse)
        // When condition is false, the engine returns an empty array
        if let arr = result as? [Any] {
            XCTAssertTrue(arr.isEmpty, "Expected empty array for #if false, got \(arr)")
        } else {
            XCTFail("Expected empty array for #if false, got \(type(of: result)): \(result)")
        }
    }

    // MARK: - Expression evaluation

    func testExpressions() {
        let fixture = loadFixture("template-expressions.json")
        guard let expressions = fixture["expressions"] as? [[String: Any]] else {
            XCTFail("Bad fixture shape"); return
        }
        for expr in expressions {
            guard let template = expr["expression"] as? String,
                  let context = expr["context"] as? [String: Any] else {
                XCTFail("Bad expression entry"); continue
            }
            let result = TemplateEngine.render(template, context: context)

            if let expectedInt = expr["expected_int"] as? Int {
                XCTAssertEqual(
                    result as? Int, expectedInt,
                    "Failed for \(template): got \(String(describing: result))")
            } else if let expectedDouble = expr["expected_double"] as? Double {
                guard let resultDouble = result as? Double else {
                    XCTFail("Expected Double for \(template), got \(type(of: result)): \(String(describing: result))")
                    continue
                }
                XCTAssertEqual(
                    resultDouble, expectedDouble, accuracy: 0.001,
                    "Failed for \(template): got \(resultDouble)")
            } else if let expectedString = expr["expected_string"] as? String {
                XCTAssertEqual(
                    result as? String, expectedString,
                    "Failed for \(template): got \(String(describing: result))")
            } else {
                XCTFail("Expression entry missing expected_int/expected_double/expected_string")
            }
        }
    }

    // MARK: - Document decoding

    func testDocumentDecoding() {
        let fixture = loadFixture("document-full.json")
        guard let data = try? JSONSerialization.data(withJSONObject: fixture) else {
            XCTFail("Could not serialize fixture"); return
        }
        let doc: JasonDocument
        do {
            doc = try JSONDecoder().decode(JasonDocument.self, from: data)
        } catch {
            XCTFail("Decoding failed: \(error)"); return
        }
        XCTAssertEqual(doc.jason.head?.title, "Test")
        XCTAssertEqual(doc.jason.body?.sections?.count, 1)

        let items = doc.jason.body?.sections?.first?.items
        XCTAssertEqual(items?.count, 7)
        XCTAssertEqual(items?[0].type, "label")
        XCTAssertEqual(items?[1].type, "image")
        XCTAssertEqual(items?[2].type, "button")
        XCTAssertEqual(items?[3].type, "textfield")
        XCTAssertEqual(items?[3].keyboard, "email")
        XCTAssertEqual(items?[4].type, "slider")
        XCTAssertEqual(items?[5].type, "switch")
        XCTAssertEqual(items?[6].type, "space")
    }
}
