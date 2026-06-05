import XCTest
#if canImport(Contacts) && !os(tvOS)
import Contacts
#endif
@testable import Jasonette

#if canImport(Contacts) && !os(tvOS)
final class AddressBookContactPayloadTests: XCTestCase {
    func testPayloadFormatsNameFromExplicitlyFetchedNameKeysOnly() {
        let contact = CNMutableContact()
        contact.givenName = "Alice"
        contact.familyName = "Appleseed"
        contact.organizationName = "Example Org"
        contact.phoneNumbers = [
            CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: "555-0100"))
        ]
        contact.emailAddresses = [
            CNLabeledValue(label: CNLabelHome, value: "alice@example.com" as NSString)
        ]

        let payload = AddressBookContactPayloadBuilder.payload(for: contact)

        XCTAssertEqual(payload["name"] as? String, "Alice Appleseed")
        let phones = payload["phone"] as? [[String: String]]
        XCTAssertEqual(phones?.first?["type"], "mobile")
        XCTAssertEqual(phones?.first?["text"], "555-0100")
        XCTAssertEqual(payload["email"] as? [String], ["alice@example.com"])
    }

    func testDisplayNameFallsBackToOrganizationThenUntitled() {
        XCTAssertEqual(
            AddressBookContactPayloadBuilder.displayName(
                givenName: "",
                familyName: "",
                organizationName: "Example Org"
            ),
            "Example Org"
        )
        XCTAssertEqual(
            AddressBookContactPayloadBuilder.displayName(
                givenName: "",
                familyName: "",
                organizationName: ""
            ),
            "Untitled"
        )
    }
}
#endif
