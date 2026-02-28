# $jason Protocol Specification v2.0

**Status:** Draft
**Date:** 2026-02-28
**Authors:** Jasonette Reborn Contributors

---

## Table of Contents

1. [Overview](#1-overview)
2. [Document Structure](#2-document-structure)
3. [Head](#3-head)
4. [Body](#4-body)
5. [Components](#5-components)
6. [Layouts](#6-layouts)
7. [Style System](#7-style-system)
8. [Template Engine](#8-template-engine)
9. [Actions](#9-actions)
10. [Navigation](#10-navigation)
11. [State Management](#11-state-management)
12. [Mixin System](#12-mixin-system)
13. [Lifecycle Hooks](#13-lifecycle-hooks)
14. [Security Model](#14-security-model)
15. [App Configuration](#15-app-configuration)
16. [v1.x Compatibility](#16-v1x-compatibility)

---

## 1. Overview

The `$jason` protocol defines a JSON markup language for building native mobile and web applications. A `$jason` document describes a single screen: its appearance (body), behavior (actions), data (templates), and metadata (head).

Every `$jason` document is a JSON object with a single root key: `$jason`.

```json
{
  "$jason": {
    "head": { ... },
    "body": { ... }
  }
}
```

### 1.1 Conformance Levels

- **MUST** / **REQUIRED** — absolute requirement
- **SHOULD** / **RECOMMENDED** — may be omitted with good reason
- **MAY** / **OPTIONAL** — truly optional

### 1.2 Notational Conventions

- Property names use `snake_case` (v2.0 canonical form)
- Template expressions appear inside `{{` and `}}`
- Action types are prefixed with `$` (e.g., `$render`, `$network.request`)
- The `@` character denotes a mixin reference

---

## 2. Document Structure

A `$jason` document MUST be a JSON object with exactly one top-level key: `"$jason"`.

```json
{
  "$jason": {
    "head": { ... },
    "body": { ... }
  }
}
```

| Property | Type | Required | Description |
|---|---|---|---|
| `head` | object | REQUIRED | Metadata, actions, templates, data, styles |
| `body` | object | OPTIONAL | Visual content: header, footer, sections, layers |

---

## 3. Head

The `head` object contains metadata and non-visual configuration.

| Property | Type | Required | Description |
|---|---|---|---|
| `title` | string | REQUIRED | Screen title displayed in navigation bar |
| `description` | string | OPTIONAL | Screen description (metadata only) |
| `icon` | string (URL) | OPTIONAL | App icon URL |
| `offline` | boolean | OPTIONAL | Enable offline caching of this document |
| `styles` | object | OPTIONAL | Named style class definitions |
| `actions` | object | OPTIONAL | Named action definitions |
| `templates` | object | OPTIONAL | Named template definitions |
| `data` | object | OPTIONAL | Static data for template rendering |
| `agents` | object | RESERVED | Web container agent configuration (Tier 2) |

### 3.1 styles

Defines named style classes referenced by components via the `class` property.

```json
{
  "head": {
    "styles": {
      "bold_label": {
        "font": "HelveticaNeue-Bold",
        "size": "14",
        "color": "#000000"
      }
    }
  }
}
```

### 3.2 actions

Defines named actions that can be invoked via `trigger`.

```json
{
  "head": {
    "actions": {
      "refresh_data": {
        "type": "$network.request",
        "options": { "url": "https://api.example.com/data" },
        "success": { "type": "$render" }
      },
      "$load": { "trigger": "refresh_data" },
      "$show": { "trigger": "refresh_data" }
    }
  }
}
```

Lifecycle hooks (`$load`, `$show`, `$foreground`, `$background`, `$pull`) are defined as named actions in `head.actions`.

### 3.3 templates

Defines named templates for `$render`.

```json
{
  "head": {
    "templates": {
      "body": {
        "sections": [
          {
            "items": [
              {
                "type": "label",
                "text": "{{name}}"
              }
            ]
          }
        ]
      }
    }
  }
}
```

The default template key is `"body"`. Use `$render` with `options.template` to select a specific template.

### 3.4 data

Static data available to templates. Template expressions like `{{$jason.name}}` reference properties of the current data context. When `head.data` is present, it becomes the default data context for template rendering.

---

## 4. Body

The `body` object defines the visual layout of the screen.

| Property | Type | Required | Description |
|---|---|---|---|
| `header` | object | OPTIONAL | Navigation bar configuration |
| `footer` | object | OPTIONAL | Footer with tabs or input |
| `sections` | array or object | OPTIONAL | Content sections with items |
| `layers` | array | OPTIONAL | Absolute-positioned overlay components |
| `background` | object | OPTIONAL | Background configuration |
| `style` | object | OPTIONAL | Screen-level styles |

### 4.1 Header

The navigation bar at the top of the screen.

| Property | Type | Description |
|---|---|---|
| `title` | string | Navigation bar title (overrides `head.title` if both present) |
| `style` | object | Header styling (`background`, `color`, `font`, `size`) |
| `menu` | object | Left and right navigation bar buttons |
| `search` | object | Search bar configuration |

#### 4.1.1 menu

```json
{
  "menu": {
    "left": [
      {
        "text": "Back",
        "action": { "type": "$back" }
      }
    ],
    "right": [
      {
        "image": "https://...",
        "action": { "type": "$href", "options": { "url": "..." } }
      }
    ]
  }
}
```

Menu items accept: `text`, `image` (URL), `style`, `action`, `href`, `badge`.

#### 4.1.2 search

```json
{
  "search": {
    "name": "query",
    "placeholder": "Search...",
    "action": { "type": "$reload" },
    "style": { "background": "#ffffff" }
  }
}
```

### 4.2 Footer

| Property | Type | Description |
|---|---|---|
| `tabs` | object | Tab bar configuration |
| `input` | object | Input bar at bottom of screen |
| `style` | object | Footer styling |

#### 4.2.1 tabs

```json
{
  "tabs": {
    "style": { "background": "#ffffff", "color": "#999999", "color:active": "#ff0000" },
    "items": [
      {
        "text": "Home",
        "image": "https://...",
        "url": "https://...",
        "badge": "3",
        "action": { ... }
      }
    ]
  }
}
```

Tab items accept: `text`, `image`, `url`, `badge`, `style`, `action`.

#### 4.2.2 input

```json
{
  "input": {
    "left": { "image": "https://..." },
    "right": { "text": "Send", "action": { ... } },
    "textfield": {
      "name": "message",
      "placeholder": "Type a message..."
    }
  }
}
```

### 4.3 Sections

Sections define the scrollable content area. Each section contains `items`.

`sections` MAY be either:
- An **array** of section objects (static content)
- A **template object** using `{{#each}}` (dynamic content)

#### Array form

```json
{
  "sections": [
    {
      "header": { "type": "label", "text": "Section Title" },
      "items": [
        { "type": "label", "text": "Item 1" }
      ]
    }
  ]
}
```

#### Template object form

```json
{
  "sections": {
    "{{#each $jason}}": {
      "items": [
        { "type": "label", "text": "{{name}}" }
      ]
    }
  }
}
```

#### Section properties

| Property | Type | Description |
|---|---|---|
| `header` | component | Section header component |
| `items` | array | Array of item components or layouts |
| `type` | string | Section type: `"vertical"` (default), `"horizontal"` |

### 4.4 Layers

Absolute-positioned components overlaid on the screen. Each layer component requires explicit positioning (`top`, `left`, `bottom`, `right`) and optionally a `name` for dynamic targeting.

```json
{
  "layers": [
    {
      "type": "image",
      "url": "https://...",
      "style": {
        "top": "50",
        "left": "50",
        "width": "100",
        "height": "100",
        "z_index": "1"
      },
      "name": "overlay_image"
    }
  ]
}
```

### 4.5 Background

```json
{
  "background": {
    "type": "camera",
    "options": { ... }
  }
}
```

Background types: `"camera"`, `"html"`, `"color"`.

---

## 5. Components

Components are the visual building blocks. Every component has a `type` property.

### 5.1 Common Properties

All components accept these optional properties:

| Property | Type | Description |
|---|---|---|
| `type` | string | REQUIRED. Component type identifier |
| `style` | object | Inline style properties |
| `class` | string | Space-separated style class names from `head.styles` |
| `action` | object | Action to execute on tap |
| `href` | object | Navigation on tap (distinct from `$href` action) |
| `name` | string | Component identifier for dynamic targeting |

### 5.2 label

Displays text.

| Property | Type | Description |
|---|---|---|
| `text` | string | REQUIRED. Text content (supports template expressions) |

```json
{
  "type": "label",
  "text": "Hello {{name}}",
  "style": {
    "font": "HelveticaNeue-Bold",
    "size": "18",
    "color": "#000000",
    "padding": "10",
    "corner_radius": "5",
    "background": "#f0f0f0",
    "width": "100",
    "height": "50",
    "align": "center"
  }
}
```

### 5.3 image

Displays an image from a URL.

| Property | Type | Description |
|---|---|---|
| `url` | string (URL) | REQUIRED. Image source URL |

```json
{
  "type": "image",
  "url": "https://example.com/photo.jpg",
  "style": {
    "width": "100",
    "height": "100",
    "corner_radius": "50",
    "color": "#cccccc"
  }
}
```

The `color` style on images sets a placeholder/tint color.

### 5.4 button

Displays a tappable button.

| Property | Type | Description |
|---|---|---|
| `text` | string | Button label |
| `url` | string (URL) | Button image URL |
| `image` | string (URL) | Alternative to `url` for button image |

```json
{
  "type": "button",
  "text": "Submit",
  "style": {
    "width": "200",
    "height": "50",
    "background": "#007AFF",
    "color": "#ffffff",
    "font": "HelveticaNeue-Bold",
    "size": "16",
    "corner_radius": "25"
  },
  "action": { "type": "$network.request", "options": { ... } }
}
```

### 5.5 textfield

Single-line text input.

| Property | Type | Description |
|---|---|---|
| `name` | string | REQUIRED. Form field name for `$get` access |
| `placeholder` | string | Placeholder text |
| `value` | string | Pre-filled value |
| `keyboard` | string | Keyboard type: `"default"`, `"number"`, `"phone"`, `"email"`, `"url"` |
| `secure` | boolean | Secure (password) entry |

```json
{
  "type": "textfield",
  "name": "username",
  "placeholder": "Enter username",
  "style": {
    "background": "#ffffff",
    "color": "#000000",
    "font": "HelveticaNeue",
    "size": "14",
    "corner_radius": "5",
    "width": "200",
    "height": "40",
    "padding": "10",
    "placeholder_color": "#999999"
  },
  "action": { "type": "$reload" }
}
```

The `action` on a textfield triggers on return key press.

### 5.6 textarea

Multi-line text input.

| Property | Type | Description |
|---|---|---|
| `name` | string | REQUIRED. Form field name |
| `placeholder` | string | Placeholder text |
| `value` | string | Pre-filled value |

Same style properties as `textfield`.

### 5.7 html

Renders HTML content.

| Property | Type | Description |
|---|---|---|
| `text` | string | REQUIRED. Raw HTML content |
| `css` | string | OPTIONAL. CSS rules for styling HTML content |

> **Security Warning:** The `html` component renders arbitrary HTML. Template expressions MUST NOT be evaluated inside the `text` field value. Treat as a privileged component.

```json
{
  "type": "html",
  "text": "<h1>Hello</h1><p>World</p>",
  "css": "h1 { color: blue; } p { font-family: Helvetica; font-size: 14px; }",
  "style": { "width": "300", "height": "200" }
}
```

### 5.8 map

Displays a map with optional pins.

| Property | Type | Description |
|---|---|---|
| `region` | object | Map center and zoom: `{ "coord": "lat,lng", "width": "0.1", "height": "0.1" }` |
| `pins` | array | Array of pin objects: `{ "coord": "lat,lng", "title": "...", "description": "..." }` |

```json
{
  "type": "map",
  "region": { "coord": "37.7749,-122.4194", "width": "0.05", "height": "0.05" },
  "pins": [
    { "coord": "37.7749,-122.4194", "title": "San Francisco", "description": "City by the Bay" }
  ],
  "style": { "width": "100%", "height": "300" }
}
```

### 5.9 slider

Horizontal slider control.

| Property | Type | Description |
|---|---|---|
| `name` | string | REQUIRED. Form field name |
| `value` | number | Initial value (0-1 range) |

```json
{
  "type": "slider",
  "name": "volume",
  "value": 0.5,
  "action": { "type": "$render" }
}
```

### 5.10 switch

Toggle switch control.

| Property | Type | Description |
|---|---|---|
| `name` | string | REQUIRED. Form field name |
| `value` | boolean | Initial state |

```json
{
  "type": "switch",
  "name": "enabled",
  "value": true,
  "action": { "type": "$render" }
}
```

### 5.11 space

Empty space component for layout purposes.

```json
{
  "type": "space",
  "style": { "height": "20" }
}
```

---

## 6. Layouts

Layouts arrange child components within an item.

### 6.1 vertical

Arranges `components` in a vertical stack.

```json
{
  "type": "vertical",
  "components": [
    { "type": "label", "text": "Title" },
    { "type": "label", "text": "Subtitle" }
  ],
  "style": { "spacing": "10", "padding": "15" }
}
```

### 6.2 horizontal

Arranges `components` in a horizontal row.

```json
{
  "type": "horizontal",
  "components": [
    { "type": "image", "url": "...", "style": { "width": "50", "height": "50" } },
    {
      "type": "vertical",
      "components": [
        { "type": "label", "text": "{{name}}" },
        { "type": "label", "text": "{{description}}" }
      ]
    }
  ],
  "style": { "spacing": "10", "padding": "10", "distribution": "equalsize" }
}
```

Layout style properties include `distribution` which accepts `"equalsize"` for equal-width components.
```

### 6.3 Key Distinction: `components` vs `items`

- **`components`** — children of a layout element (vertical/horizontal). Used for composing within a single row.
- **`items`** — direct children of a section. Each item is a full-width row in the list.

Layouts can be nested: a section item can contain a horizontal layout, which itself contains vertical layouts.

---

## 7. Style System

### 7.1 Inline Styles

Every component accepts a `style` object with platform-native style properties.

> **Important:** Jasonette styles are NOT CSS. They are Jasonette-specific property names with string values.

### 7.2 Style Properties

| Property | Type | Description |
|---|---|---|
| `color` | string | Text/foreground color (hex: `"#RRGGBB"` or `"#RRGGBBAA"`) |
| `background` | string | Background color (hex) or background image URL |
| `font` | string | Font name (e.g., `"HelveticaNeue-Bold"`) |
| `size` | string | Font size in points |
| `padding` | string | Uniform padding |
| `padding_top` | string | Top padding |
| `padding_bottom` | string | Bottom padding |
| `padding_left` | string | Left padding |
| `padding_right` | string | Right padding |
| `corner_radius` | string | Corner rounding radius |
| `width` | string | Component width (points or `"100%"`) |
| `height` | string | Component height |
| `opacity` | string | Opacity (`"0"` to `"1"`) |
| `align` | string | Text/content alignment: `"left"`, `"center"`, `"right"` |
| `spacing` | string | Inter-component spacing in layouts |
| `z_index` | string | Z-ordering for layers |
| `border` | string | Border color (hex) |
| `border_width` | string | Border width |
| `top` | string | Absolute position from top (layers) |
| `bottom` | string | Absolute position from bottom |
| `left` | string | Absolute position from left |
| `right` | string | Absolute position from right |
| `shy` | boolean | Hide header on scroll |
| `theme` | string | `"dark"` or `"light"` for status bar style |
| `placeholder_color` | string | Textfield placeholder color |
| `autocorrect` | string | `"true"` / `"false"` for textfield |
| `autocapitalize` | string | `"true"` / `"false"` for textfield |
| `color:active` | string | Active state color (used in tab bars) |
| `move` | string | Drag gesture support |
| `resize` | string | Resize gesture support |
| `rotate` | string | Rotation support |
| `dark` | object | Dark mode style overrides |

### 7.3 Style Classes

Define reusable style sets in `head.styles` and reference via `class`.

```json
{
  "head": {
    "styles": {
      "title": { "font": "HelveticaNeue-Bold", "size": "20", "color": "#000" },
      "subtitle": { "font": "HelveticaNeue", "size": "14", "color": "#666" }
    }
  },
  "body": {
    "sections": [{
      "items": [{
        "type": "label",
        "text": "Hello",
        "class": "title"
      }]
    }]
  }
}
```

Multiple classes are space-separated: `"class": "title centered"`.

---

## 8. Template Engine

The template engine transforms a `$jason` document by evaluating template expressions and structural directives.

### 8.1 Template Expressions

Template expressions are enclosed in `{{ }}` within string values.

```
{{$jason.name}}
{{$jason.items.length}}
{{$jason.price > 0 ? "$" + $jason.price : "Free"}}
```

#### 8.1.1 Expression Grammar (v2.0)

Valid expressions (JSEP-parseable):

- **Identifiers:** `name`, `$jason`, `$get`, `$params`, `$env`, `$root`, `$index`
- **Member access:** `$jason.name`, `$jason["name"]`, `$jason.items[0]`
- **Literals:** strings (`"hello"`), numbers (`42`, `3.14`), booleans (`true`, `false`), `null`
- **Binary operators:** `+`, `-`, `*`, `/`, `%`, `==`, `!=`, `===`, `!==`, `<`, `>`, `<=`, `>=`, `&&`, `||`
- **Unary operators:** `!`, `-`, `+`
- **Ternary operator:** `condition ? then : else`
- **Function calls** (allowlist only): `Math.floor`, `Math.ceil`, `Math.round`, `Math.random`, `Math.abs`, `Math.min`, `Math.max`, `JSON.stringify`, `JSON.parse`, `parseInt`, `parseFloat`, `String`, `Number`, `encodeURIComponent`, `decodeURIComponent`

**NOT valid in v2.0** (breaking change from v1.x):
- Statements: `var`, `let`, `const`, `function`, `return`
- Control flow: `for`, `while`, `if` (statement form)
- Operators: `new`, `typeof`, `void`, `delete`
- Comma operator, assignment operators (`=`, `+=`, etc.)

Use `$script.include` (Tier 3) for multi-statement logic.

#### 8.1.2 Context Variables

| Variable | Description |
|---|---|
| `$jason` | Current data context (from `head.data`, `$network.request` response, or `$render` data) |
| `$get` | Local screen state set via `$set` or form field values |
| `$params` | Parameters passed via `href.options` |
| `$env` | Environment variables (see 8.1.4) |
| `$root` | Parent data context (accessible from nested `{{#each}}` loops) |
| `$index` | Current iteration index inside `{{#each}}` |
| `$cache` | Cached data (read-only in expressions; use `$cache.get` action) |
| `$keys` | App configuration keys (from Settings.plist / config) |

#### 8.1.4 Environment Variables (`$env`)

| Path | Description |
|---|---|
| `$env.device.width` | Screen width in points |
| `$env.device.height` | Screen height in points |
| `$env.device.os.name` | OS name (`"ios"`, `"android"`, `"web"`) |
| `$env.device.os.version` | OS version string |
| `$env.device.language` | Device language code |
| `$env.app.version` | App version string |
| `$env.app.build` | Build number |
| `$env.view.url` | Current document URL |
| `$env.url_scheme` | App URL scheme |

#### 8.1.3 Security: MemberExpression Blocklist

For both computed (`obj["key"]`) and non-computed (`obj.key`) member access, the following property names MUST be blocked:

- `__proto__`
- `constructor`
- `prototype`

### 8.2 Structural Directives

Structural directives use JSON object keys (not Handlebars-style string tags).

#### 8.2.1 `{{#each}}`

Iterates over an array, rendering the template once per element.

```json
{
  "items": {
    "{{#each $jason.users}}": {
      "type": "label",
      "text": "{{name}}"
    }
  }
}
```

Inside an `{{#each}}` block:
- The current item becomes the data context
- `$root` references the parent context
- `$index` is the zero-based iteration index

**There is no closing tag.** The `{{#each expr}}` string is the key of a JSON object whose value is the template.

#### 8.2.2 `{{#if}}`

Conditionally includes content.

```json
{
  "{{#if $jason.premium}}": {
    "type": "label",
    "text": "Premium Member"
  },
  "{{#elseif $jason.trial}}": {
    "type": "label",
    "text": "Trial Member"
  },
  "{{#else}}": {
    "type": "label",
    "text": "Free Member"
  }
}
```

`{{#elseif}}` and `{{#else}}` are sibling keys in the same JSON object.

### 8.3 Template Rendering

1. `$render` evaluates the named template (default: `"body"`) against the current data context
2. Template expressions in string values are evaluated
3. `{{#each}}` keys produce arrays
4. `{{#if}}` keys conditionally include/exclude content
5. The result replaces the current `body`

---

## 9. Actions

Actions define behavior. They execute in response to user interaction, lifecycle events, or as continuations in action chains.

### 9.1 Action Structure

```json
{
  "type": "$action_name",
  "options": { ... },
  "success": { ... },
  "error": { ... }
}
```

| Property | Type | Description |
|---|---|---|
| `type` | string | REQUIRED. Action type (prefixed with `$`) |
| `options` | object | Action-specific parameters |
| `success` | object or array | Continuation on success |
| `error` | object or array | Continuation on failure |

`success` and `error` MAY be:
- A single action object
- An array of action objects (conditional branching)

### 9.2 Action Chaining

Actions chain via `success` and `error`. The return value of one action becomes `$jason` in the next.

```json
{
  "type": "$network.request",
  "options": { "url": "https://api.example.com/users" },
  "success": {
    "type": "$render"
  },
  "error": {
    "type": "$util.alert",
    "options": { "title": "Error", "description": "Failed to load data" }
  }
}
```

### 9.3 Named Actions and Triggers

Define actions in `head.actions` and invoke via `trigger`:

```json
{
  "head": {
    "actions": {
      "fetch_data": {
        "type": "$network.request",
        "options": { "url": "https://..." },
        "success": { "type": "$render" }
      }
    }
  },
  "body": {
    "sections": [{
      "items": [{
        "type": "button",
        "text": "Refresh",
        "action": { "trigger": "fetch_data" }
      }]
    }]
  }
}
```

`trigger` is the recommended form. The underlying mechanism is `$lambda`:

```json
{ "type": "$lambda", "options": { "name": "fetch_data" } }
```

### 9.4 `$return.success` / `$return.error`

Return a value from a named action to its caller's success/error handler.

```json
{
  "head": {
    "actions": {
      "validate": {
        "type": "$util.alert",
        "options": { "title": "Valid!" },
        "success": { "type": "$return.success", "options": { "data": "validated" } }
      }
    }
  }
}
```

### 9.5 Concurrency

- Actions within a chain execute **serially**
- Independent triggers execute **concurrently**
- Navigating away from a screen cancels all in-flight actions for that screen

### 9.6 Tier 1 Actions (v1.0)

#### `$render`

Re-render body with current or specified data.

| Option | Type | Description |
|---|---|---|
| `template` | string | Named template from `head.templates` (default: `"body"`) |
| `data` | object | Override render data (default: current `$jason`) |
| `type` | string | Render type: `"html"`, `"json"` |

#### `$reload`

Re-fetch the JSON document from its URL and re-render.

No options.

#### `$network.request`

HTTP request.

| Option | Type | Description |
|---|---|---|
| `url` | string (URL) | REQUIRED. Request URL (HTTPS required per AD-10) |
| `method` | string | HTTP method: `"GET"` (default), `"POST"`, `"PUT"`, `"DELETE"` |
| `data` | object | Request body (form-encoded by default) |
| `data_type` | string | Body encoding: `"json"`, `"html"`, `"raw"` |
| `header` | object | HTTP headers (key-value pairs) |
| `timeout` | number | Request timeout in seconds |

Returns response as `$jason` for the success handler.

#### `$set`

Set local screen state variables.

```json
{
  "type": "$set",
  "options": {
    "selected_id": "{{$jason.id}}",
    "count": "{{$get.count + 1}}"
  }
}
```

Variables are accessible via `$get.variable_name` in template expressions.

#### `$cache.set` / `$cache.get` / `$cache.reset`

Persistent per-URL storage.

```json
{ "type": "$cache.set", "options": { "items": "{{$jason}}" } }
{ "type": "$cache.get" }
{ "type": "$cache.reset" }
```

`$cache.get` returns the cached data as `$jason`.

#### `$session.set` / `$session.get` / `$session.reset`

HTTP session/cookie management.

```json
{
  "type": "$session.set",
  "options": {
    "domain": "api.example.com",
    "header": { "Authorization": "Bearer {{$jason.token}}" },
    "body": { "api_key": "..." }
  }
}
```

`$session` values are attached to subsequent `$network.request` calls matching the domain.

#### `$flush`

Per-URL cache reset shorthand. Clears cached data for the current screen's URL.

```json
{ "type": "$flush" }
```

#### `$util.alert`

Display an alert dialog.

| Option | Type | Description |
|---|---|---|
| `title` | string | Alert title |
| `description` | string | Alert message |
| `form` | array | Form fields in the alert (textfields) |

Returns form values as `$jason` on OK.

#### `$util.banner`

Display a notification banner.

| Option | Type | Description |
|---|---|---|
| `title` | string | Banner title |
| `description` | string | Banner message |
| `type` | string | `"info"`, `"success"`, `"warning"`, `"error"` |

#### `$util.toast`

Display a toast message.

| Option | Type | Description |
|---|---|---|
| `title` | string | Toast text |

#### `$util.picker`

Display a selection picker.

| Option | Type | Description |
|---|---|---|
| `items` | array | Array of `{ "text": "...", "value": "..." }` |

Returns selected item as `$jason`.

#### `$util.datepicker`

Display a date picker.

Returns selected date as `$jason`.

#### `$util.share`

Display the system share sheet.

| Option | Type | Description |
|---|---|---|
| `items` | array | Array of `{ "type": "...", "text": "...", "url": "..." }` |

#### `$timer.start` / `$timer.stop`

Start/stop a repeating timer.

| Option | Type | Description |
|---|---|---|
| `interval` | number | Repeat interval in seconds |
| `name` | string | Timer identifier |
| `action` | object | Action to execute on each tick |
| `repeats` | boolean | Whether to repeat (default: true) |

#### `$log` / `$log.info` / `$log.debug` / `$log.error`

Debug output.

```json
{ "type": "$log", "options": { "text": "Debug: {{$jason}}" } }
```

---

## 10. Navigation

### 10.1 Component `href` Property

Any component can include an `href` object for navigation on tap.

```json
{
  "type": "label",
  "text": "Go to Profile",
  "href": {
    "url": "https://example.com/profile.json",
    "view": "jason",
    "transition": "push",
    "options": { "user_id": "123" }
  }
}
```

| Property | Type | Description |
|---|---|---|
| `url` | string (URL) | REQUIRED. Target URL |
| `view` | string | View type: `"jason"` (default), `"web"`, `"app"` |
| `transition` | string | Transition: `"push"` (default), `"modal"`, `"replace"`, `"fullscreen"` |
| `options` | object | Parameters passed as `$params` to the target |
| `fresh` | boolean | Force fresh load (ignore cache) |
| `preload` | object | Pre-rendered content to display immediately while loading |

### 10.2 `$href` Action

Programmatic navigation from an action chain.

```json
{
  "type": "$href",
  "options": {
    "url": "https://example.com/detail.json",
    "view": "jason",
    "transition": "modal",
    "options": { "id": "{{$jason.id}}" }
  }
}
```

### 10.3 `$back`

Pop the navigation stack (go back one screen).

```json
{ "type": "$back" }
```

### 10.4 `$close`

Dismiss a modal screen.

```json
{ "type": "$close" }
```

### 10.5 Tab Navigation

Configure tab-based navigation in the root document's `footer.tabs`:

```json
{
  "$jason": {
    "head": { "title": "App" },
    "body": {
      "footer": {
        "tabs": {
          "items": [
            { "text": "Home", "url": "https://example.com/home.json", "image": "..." },
            { "text": "Settings", "url": "https://example.com/settings.json", "image": "..." }
          ]
        }
      }
    }
  }
}
```

---

## 11. State Management

### 11.1 Form State (`$get`)

`$get` is a context namespace (not a callable action). It contains:

1. Values from form fields (`textfield`, `textarea`, `slider`, `switch`) keyed by their `name` property
2. Values explicitly set via `$set`

Access in template expressions: `{{$get.username}}`, `{{$get.count}}`.

### 11.2 Local State (`$set`)

Set screen-local state variables:

```json
{ "type": "$set", "options": { "page": "2", "loading": "true" } }
```

### 11.3 Cache (`$cache`)

Persistent storage scoped to the document URL.

- `$cache.set` — store data
- `$cache.get` — retrieve data (returns as `$jason`)
- `$cache.reset` — clear cached data

### 11.4 Session (`$session`)

HTTP session management. Session data (headers, body) are attached to outgoing `$network.request` calls.

- `$session.set` — store session data for a domain
- `$session.get` — retrieve session data
- `$session.reset` — clear session data

### 11.5 Global State (`$global`) — Tier 2

Cross-screen state shared across all screens.

- `$global.set` — store global data
- `$global.get` — retrieve global data
- `$global.reset` — clear global data

---

## 12. Mixin System

Mixins allow including content from other JSON sources using the `@` key.

### 12.1 Form A: Local Document Reference

Reference a key from the same document using `$document`:

```json
{
  "@": "$document.components.user_row"
}
```

The referenced value replaces the containing object.

### 12.2 Form B: Remote Full-Document

Include content from a remote URL:

```json
{
  "@": "https://example.com/component.json"
}
```

The fetched JSON replaces the containing object. Subject to mixin origin policy (AD-11).

### 12.3 Form C: Remote with Key Selector (Tier 2)

Include a specific key from a remote JSON document:

```json
{
  "@": "user_row@https://example.com/components.json"
}
```

### 12.4 Merge Semantics

When a `"+"` key is present alongside `"@"`, the `"+"` value is merged into the mixin result:

```json
{
  "@": "$document.components.base_row",
  "+": {
    "text": "Custom text"
  }
}
```

### 12.5 Recursion Limit

Mixins can reference other mixins. Maximum recursion depth: **5 levels**.

### 12.6 Size Limit

Maximum mixin payload size: **1 MB**.

### 12.7 Error Behavior

If a remote mixin URL is unreachable, the containing object is replaced with an empty object `{}`.

---

## 13. Lifecycle Hooks

Lifecycle hooks are defined as named actions in `head.actions`.

| Hook | Fires When |
|---|---|
| `$load` | Screen first renders (once) |
| `$show` | Screen becomes visible (see rules below) |
| `$foreground` | App returns from background |
| `$background` | App enters background |
| `$pull` | Pull-to-refresh gesture |

**`$load` / `$show` interaction rules:**

- If both `$load` and `$show` are defined: `$load` fires on first load only; `$show` fires on subsequent appearances only (e.g., returning via back navigation).
- If only `$show` is defined: `$show` fires on both initial load and subsequent appearances.
- If only `$load` is defined: `$load` fires once on initial load.

```json
{
  "head": {
    "actions": {
      "$load": {
        "type": "$network.request",
        "options": { "url": "https://api.example.com/init" },
        "success": { "type": "$render" }
      },
      "$pull": {
        "type": "$reload"
      }
    }
  }
}
```

---

## 14. Security Model

### 14.1 Trust Model

- **Root JSON server:** Trusted source. The document URL origin is the trust anchor.
- **Mixins:** Secondary trust. Remote mixins are restricted to same-origin by default (AD-11).
- **`$params`:** Untrusted input from the calling screen. Must be treated as user input.
- **`$network.request` responses:** Untrusted. Data flows through the template engine.
- **`$get`/`$set` state:** Tainted by user input (form fields). Expression evaluation must sanitize.

### 14.2 Expression Sandbox (AD-8, AD-9)

Two distinct execution contexts with no cross-contamination:

1. **JSEP expression context** — Template expressions. Access: `$jason`, `$get`, `$params`, `$root`, `$index`, function allowlist. NO access to `$script.include` functions.
2. **Script engine context** — `$script.*` actions only. Access: loaded libraries, `$get`/`$set`, `$cache`. Sandboxed from native APIs.

### 14.3 URL Validation (AD-10)

All network-facing operations (`$network.request`, `@` mixin, `$script.include`, `$href`):

1. **Scheme allowlist:** `https:` only. `http:` opt-in requires `debug: true` + `allow_http: true`.
2. **Post-DNS-resolution blocking:** Block RFC1918, loopback, link-local, documentation ranges, carrier-grade NAT, `0.0.0.0`.
3. **Redirect policy:** Max 1 redirect. Target must pass validation.
4. **Scheme blocklist:** `file://`, `javascript:`, `data:` always blocked.

### 14.4 Mixin Origin Policy (AD-11)

- Local `$document` references: always allowed
- Remote URLs: same-origin only by default
- Cross-origin: requires `allowed_mixin_origins` in `jasonette.config.json`

### 14.5 `html` Component

The `html` component renders raw HTML. Template expressions MUST NOT be evaluated within `html.text` values. Implementations SHOULD sandbox HTML rendering (e.g., WKWebView with JavaScript disabled).

### 14.6 MemberExpression Blocklist

Property access to `__proto__`, `constructor`, and `prototype` MUST be blocked for both computed and non-computed member expressions.

---

## 15. App Configuration

The `jasonette.config.json` file configures runtime behavior.

```json
{
  "url": "https://example.com/app.json",
  "debug": false,
  "enforce_https": true,
  "allow_http": false,
  "json_size_limit_mb": 5,
  "allowed_mixin_origins": [],
  "certificate_pins": {}
}
```

| Property | Type | Default | Description |
|---|---|---|---|
| `url` | string | REQUIRED | Root document URL |
| `debug` | boolean | `false` | Enable debug mode |
| `enforce_https` | boolean | `true` | Require HTTPS for all URLs |
| `allow_http` | boolean | `false` | Allow HTTP (requires `debug: true`) |
| `json_size_limit_mb` | number | `5` | Maximum JSON document size in MB |
| `allowed_mixin_origins` | array | `[]` | Allowed cross-origin mixin domains (empty = same-origin only) |
| `certificate_pins` | object | `{}` | Domain-to-pin-hash mapping |

---

## 16. v1.x Compatibility

### 16.1 Breaking Changes

| Change | v1.x Behavior | v2.0 Behavior | Migration |
|---|---|---|---|
| Multi-statement expressions | Allowed (`var x = 1; return x`) | Blocked | Use `$script.include` (Tier 3) |
| Expression grammar | Full JavaScript eval | JSEP subset only | Simplify expressions or use `$script.include` |
| Mixin origin | Unrestricted | Same-origin default | Add origins to `allowed_mixin_origins` |
| `$script.include` context | Shared with templates | Isolated (AD-9) | Functions not accessible from `{{}}` expressions |
| Property naming | Mixed case (`dataType`) | `snake_case` (`data_type`) | Both accepted for `data_type` only |

### 16.2 v1.x Exclusion List

Files that use v1.x-only features are documented in `spec/schema/v1-exclusions.json`. These files are excluded from v2.0 schema validation.

### 16.3 Case Sensitivity

v2.0 canonical form is lowercase. Implementations SHOULD accept mixed case for view types (`"Jason"` → `"jason"`) and action types.
