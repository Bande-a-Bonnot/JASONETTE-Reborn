import SwiftUI

/// Registry mapping Jasonette component type strings to SwiftUI views.
@MainActor
public struct ComponentView: View {
    let component: JasonComponent
    let headStyles: [String: JasonStyle]
    let onHref: ((JasonHref) -> Void)?
    let onAction: ((JasonAction) -> Void)?

    public init(
        _ component: JasonComponent,
        headStyles: [String: JasonStyle] = [:],
        onHref: ((JasonHref) -> Void)? = nil,
        onAction: ((JasonAction) -> Void)? = nil
    ) {
        self.component = component
        self.headStyles = headStyles
        self.onHref = onHref
        self.onAction = onAction
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
            ImageComponent(url: component.url, style: component.style)
        case "button":
            ButtonComponent(text: component.text, url: component.url)
        case "textfield":
            TextFieldComponent(
                name: component.name ?? "",
                placeholder: component.placeholder ?? "",
                keyboard: component.keyboard
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
        case "vertical":
            LayoutView(
                direction: .vertical,
                components: component.components ?? [],
                headStyles: headStyles,
                style: component.style,
                onHref: onHref,
                onAction: onAction
            )
        case "horizontal":
            LayoutView(
                direction: .horizontal,
                components: component.components ?? [],
                headStyles: headStyles,
                style: component.style,
                onHref: onHref,
                onAction: onAction
            )
        default:
            Text("[Unknown: \(component.type ?? "nil")]")
                .foregroundColor(.secondary)
        }
    }
}
