import XCTest
@testable import Jasonette

final class JasonDocumentTests: XCTestCase {
    func testDecodeMinimalDocument() throws {
        let json = """
        {
            "$jason": {
                "head": { "title": "Test" },
                "body": {
                    "sections": [{
                        "items": [
                            { "type": "label", "text": "Hello" }
                        ]
                    }]
                }
            }
        }
        """
        let doc = try DocumentLoader().decode(json)
        XCTAssertEqual(doc.jason.head?.title, "Test")
        XCTAssertEqual(doc.jason.body?.sections?.count, 1)
        XCTAssertEqual(doc.jason.body?.sections?.first?.items?.first?.type, "label")
        XCTAssertEqual(doc.jason.body?.sections?.first?.items?.first?.text, "Hello")
    }

    func testDecodeWithStyles() throws {
        let json = """
        {
            "$jason": {
                "head": {
                    "title": "Styled",
                    "styles": {
                        "bold_label": {
                            "size": 18,
                            "font": "bold",
                            "color": "#FF0000"
                        }
                    }
                },
                "body": {
                    "sections": [{
                        "items": [
                            { "type": "label", "text": "Red", "class": "bold_label" }
                        ]
                    }]
                }
            }
        }
        """
        let doc = try DocumentLoader().decode(json)
        let styles = doc.jason.head?.styles
        XCTAssertNotNil(styles?["bold_label"])
        XCTAssertEqual(styles?["bold_label"]?.color, "#FF0000")
        XCTAssertEqual(styles?["bold_label"]?.size?.cgFloat, 18)
    }

    func testDecodeWithActions() throws {
        let json = """
        {
            "$jason": {
                "head": {
                    "actions": {
                        "$load": {
                            "type": "$network.request",
                            "options": {
                                "url": "https://example.com/api"
                            },
                            "success": {
                                "type": "$render"
                            }
                        }
                    }
                }
            }
        }
        """
        let doc = try DocumentLoader().decode(json)
        let load = doc.jason.head?.actions?["$load"]
        XCTAssertEqual(load?.type, "$network.request")
        XCTAssertEqual(load?.options?["url"]?.string, "https://example.com/api")
        XCTAssertEqual(load?.success?.type, "$render")
    }

    func testDecodeWithHref() throws {
        let json = """
        {
            "$jason": {
                "body": {
                    "sections": [{
                        "items": [{
                            "type": "label",
                            "text": "Go",
                            "href": {
                                "url": "https://example.com",
                                "view": "web",
                                "transition": "push"
                            }
                        }]
                    }]
                }
            }
        }
        """
        let doc = try DocumentLoader().decode(json)
        let href = doc.jason.body?.sections?.first?.items?.first?.href
        XCTAssertEqual(href?.url, "https://example.com")
        XCTAssertEqual(href?.view, "web")
        XCTAssertEqual(href?.transition, "push")
    }

    func testDecodeWithNestedComponents() throws {
        let json = """
        {
            "$jason": {
                "body": {
                    "sections": [{
                        "items": [{
                            "type": "horizontal",
                            "components": [
                                { "type": "image", "url": "https://example.com/pic.jpg" },
                                { "type": "label", "text": "Caption" }
                            ]
                        }]
                    }]
                }
            }
        }
        """
        let doc = try DocumentLoader().decode(json)
        let item = doc.jason.body?.sections?.first?.items?.first
        XCTAssertEqual(item?.type, "horizontal")
        XCTAssertEqual(item?.components?.count, 2)
        XCTAssertEqual(item?.components?[0].type, "image")
        XCTAssertEqual(item?.components?[1].text, "Caption")
    }

    func testDecodeWithFooterTabs() throws {
        let json = """
        {
            "$jason": {
                "body": {
                    "footer": {
                        "tabs": {
                            "items": [
                                { "text": "Home", "url": "https://a.com" },
                                { "text": "Settings", "url": "https://b.com" }
                            ]
                        }
                    }
                }
            }
        }
        """
        let doc = try DocumentLoader().decode(json)
        let tabs = doc.jason.body?.footer?.tabs?.items
        XCTAssertEqual(tabs?.count, 2)
        XCTAssertEqual(tabs?[0].text, "Home")
        XCTAssertEqual(tabs?[1].text, "Settings")
    }
}
