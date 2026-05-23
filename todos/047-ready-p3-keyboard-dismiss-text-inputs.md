---
id: "019e53ff-7aed-7b45-9040-95bd934de5ee"
status: ready
priority: p3
issue_id: "047"
tags: [ios, components, textfield, textarea, keyboard, ux, qa]
dependencies: []
---

# Add keyboard dismissal behavior for text inputs

## Problem Statement

The handoff Phase C audit still lists keyboard dismissal on text inputs as a
missing iOS renderer UX fix. Textfield, secure textfield, textarea, and footer
input flows need a consistent way to dismiss the software keyboard after entry.

## Evidence

- Handoff Phase C: keyboard dismiss on text inputs remains listed as not implemented.
- Renderer files:
  - `JASONETTE-iOS/JasonetteApp/Sources/Jasonette/Components/TextFieldComponent.swift`
  - `JASONETTE-iOS/JasonetteApp/Sources/Jasonette/Components/TextAreaComponent.swift`
  - `JASONETTE-iOS/JasonetteApp/Sources/Jasonette/Rendering/JasonetteView.swift` (`FooterInputView`)

## Recommended Action

1. Inventory current text input focus behavior in simulator.
2. Add a SwiftUI focus/dismiss pattern that works for normal textfields, secure
   textfields, textareas, and footer input.
3. Prefer modern SwiftUI APIs where available while preserving the iOS 16
   deployment target.
4. Add tests where practical for focus/dismiss wiring, plus simulator QA for the
   Jasonpedia textfield fixture.

## Acceptance Criteria

- [ ] Return/done behavior dismisses the keyboard where appropriate
- [ ] Tapping outside input dismisses the keyboard in scrolling forms where appropriate
- [ ] Secure textfield masking remains correct
- [ ] Footer input still binds/sends text correctly
- [ ] Simulator QA confirms keyboard dismissal on representative textfield and
      footer input flows

## Notes

Coordinate with `todos/029` (`onChange` iOS 17 modernization`) if focus or input
state changes touch related SwiftUI API modernization work.
