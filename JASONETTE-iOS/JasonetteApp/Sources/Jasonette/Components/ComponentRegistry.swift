import SwiftUI

/// Registry mapping Jasonette component type strings to SwiftUI views.
@MainActor
public struct ComponentView: View {
    static let knownComponentTypes: Set<String> = [
        "button", "horizontal", "html", "image", "label", "map", "secure",
        "slider", "space", "switch", "textarea", "textfield", "vertical"
    ]

    let component: JasonComponent
    let headStyles: [String: JasonStyle]
    let onHref: ((JasonHref) -> Void)?
    let onAction: ((JasonAction) -> Void)?
    let documentURL: URL?

    public init(
        _ component: JasonComponent,
        headStyles: [String: JasonStyle] = [:],
        onHref: ((JasonHref) -> Void)? = nil,
        onAction: ((JasonAction) -> Void)? = nil,
        documentURL: URL? = nil
    ) {
        self.component = component
        self.headStyles = headStyles
        self.onHref = onHref
        self.onAction = onAction
        self.documentURL = documentURL
    }

    public var body: some View {
        let content = componentContent
            .modifier(JasonStyleModifier(style: component.style, headStyles: headStyles, className: component.class))

        if let href = component.href {
            Button {
                onHref?(href)
            } label: {
                content
            }
            .buttonStyle(.plain)
        } else if let action = component.action {
            Button {
                onAction?(action)
            } label: {
                content
            }
            .buttonStyle(.plain)
        } else {
            content
        }
    }

    @ViewBuilder
    private var componentContent: some View {
        switch component.type {
        case "label":
            LabelComponent(text: component.text ?? "")
        case "image":
            ImageComponent(url: component.imageURL, style: component.style, documentURL: documentURL)
        case "button":
            ButtonComponent(text: component.text, url: component.url, documentURL: documentURL)
        case "textfield", "secure":
            TextFieldComponent(
                name: component.name ?? "",
                placeholder: component.placeholder ?? "",
                keyboard: component.keyboard,
                initialValue: component.value?.string,
                kind: TextFieldComponent.fieldKind(componentType: component.type, style: component.style)
            )
        case "textarea":
            TextAreaComponent(
                name: component.name ?? "",
                placeholder: component.placeholder ?? ""
            )
        case "slider":
            SliderComponent(
                name: component.name ?? "",
                value: component.value?.double ?? 50
            )
        case "space":
            SpaceComponent(height: component.style?.height?.cgFloat)
        case "switch":
            SwitchComponent(name: component.name ?? "", isOn: component.value?.bool ?? false)
        case "map":
            MapStubComponent()
        case "html":
            HTMLComponent(
                text: component.text,
                css: component.css,
                url: component.url,
                documentURL: documentURL
            )
        case "vertical":
            LayoutView(
                direction: .vertical,
                components: component.components ?? [],
                headStyles: headStyles,
                style: component.style,
                onHref: onHref,
                onAction: onAction,
                documentURL: documentURL
            )
        case "horizontal":
            LayoutView(
                direction: .horizontal,
                components: component.components ?? [],
                headStyles: headStyles,
                style: component.style,
                onHref: onHref,
                onAction: onAction,
                documentURL: documentURL
            )
        default:
            Text("[Unknown: \(component.type ?? "nil")]")
                .foregroundColor(.secondary)
        }
    }
}
