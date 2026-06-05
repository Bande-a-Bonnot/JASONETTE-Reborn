#if canImport(Contacts) && !os(tvOS)
import Contacts
import Foundation

enum AddressBookContactPayloadBuilder {
    static let keysToFetch: [CNKeyDescriptor] = [
        CNContactGivenNameKey as CNKeyDescriptor,
        CNContactFamilyNameKey as CNKeyDescriptor,
        CNContactOrganizationNameKey as CNKeyDescriptor,
        CNContactPhoneNumbersKey as CNKeyDescriptor,
        CNContactEmailAddressesKey as CNKeyDescriptor
    ]

    static func payload(for contact: CNContact) -> [String: Any] {
        [
            "name": displayName(
                givenName: contact.givenName,
                familyName: contact.familyName,
                organizationName: contact.organizationName
            ),
            "phone": contact.phoneNumbers.map { labeledValue in
                [
                    "type": labeledValue.label.map(CNLabeledValue<CNPhoneNumber>.localizedString(forLabel:)) ?? "",
                    "text": labeledValue.value.stringValue
                ]
            },
            "email": contact.emailAddresses.map { String($0.value) }
        ]
    }

    static func displayName(givenName: String, familyName: String, organizationName: String) -> String {
        let personalName = [givenName, familyName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        if !personalName.isEmpty {
            return personalName
        }

        let organization = organizationName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !organization.isEmpty {
            return organization
        }

        return "Untitled"
    }
}
#endif
