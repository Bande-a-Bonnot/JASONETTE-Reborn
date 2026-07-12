Feature: HTML component source and iframe policy
  Public-package black-box evidence only; no browser-enforcement claim is made.

  Scenario Outline: <title>
    Given <setup>
    When <action>
    Then <expected>

    Examples: concrete component_source_cases vectors
      | title | setup | action | expected |
      | component source: inline text wins over a URL | HTML component owns text "<p>inline</p>" and URL "https://example.com/ignored.html" | render the component through the public component API | one iframe has sandbox="allow-scripts", only srcdoc="<p>inline</p>", and events [CREATE(component), SANDBOX("allow-scripts"), SOURCE("srcdoc"), APPEND, RETURN] |
      | component source: whitespace text is a valid inline source | HTML component owns text " \\t\\n" | render the component through the public component API | one iframe has sandbox="allow-scripts", only srcdoc=" 	\n", and events [CREATE(component), SANDBOX("allow-scripts"), SOURCE("srcdoc"), APPEND, RETURN] |
      | component source: empty text falls back to a URL | HTML component owns empty text and URL "https://example.com/fallback.html" | render the component through the public component API | one iframe has sandbox="allow-scripts", only src="https://example.com/fallback.html", and events [CREATE(component), SANDBOX("allow-scripts"), SOURCE("src"), APPEND, RETURN] |
      | component source: own non-string text yields to an own valid URL without coercion | HTML component owns an accessor text returning an object with observable toString and owns URL "https://example.com/non-string-text.html" | render the component through the public component API | one iframe has sandbox="allow-scripts", only src="https://example.com/non-string-text.html", and events [CREATE(component), SANDBOX("allow-scripts"), SOURCE("src"), APPEND, RETURN]; own text getter read count is one and text toString call count is zero |
      | component source: numeric text and object URL are not coerced | HTML component owns numeric text 17 and an object URL with an observable toString spy | render the component through the public component API | no iframe and no observer trace; toString call counts are zero |
      | component source: inherited-only text and URL are ignored | HTML component has observable inherited text and URL getters and owns neither source | render the component through the public component API | no iframe and no observer trace; all inherited getter read counts are zero |
      | component source: inherited text yields to an own URL | HTML component has an observable inherited text getter and owns URL "https://example.com/own.html" | render the component through the public component API | one iframe has sandbox="allow-scripts", only src="https://example.com/own.html", and events [CREATE(component), SANDBOX("allow-scripts"), SOURCE("src"), APPEND, RETURN]; all inherited getter read counts are zero |
      | component source: inherited URL yields to own text | HTML component has an observable inherited URL getter and owns text "<p>own</p>" | render the component through the public component API | one iframe has sandbox="allow-scripts", only srcdoc="<p>own</p>", and events [CREATE(component), SANDBOX("allow-scripts"), SOURCE("srcdoc"), APPEND, RETURN]; all inherited getter read counts are zero |
      | component source: missing text and URL creates no iframe | HTML component owns neither text nor URL | render the component through the public component API | no iframe and no observer trace |
      | component source: invalid HTML is assigned byte-for-byte | HTML component owns text "<p><b>unterminated & raw" | render the component through the public component API | one iframe has sandbox="allow-scripts", only srcdoc="<p><b>unterminated & raw", and events [CREATE(component), SANDBOX("allow-scripts"), SOURCE("srcdoc"), APPEND, RETURN] |

  Scenario Outline: <title>
    Given <setup>
    When <action>
    Then <expected>

    Examples: concrete css_cases vectors
      | title | setup | action | expected |
      | component CSS: absent CSS leaves srcdoc unchanged | HTML component text is "<p>x</p>" and CSS is absent | render the component through the public component API | iframe srcdoc and srcdoc attribute equal "<p>x</p>" |
      | component CSS: empty CSS leaves srcdoc unchanged | HTML component text is "<p>x</p>" and CSS is "" | render the component through the public component API | iframe srcdoc and srcdoc attribute equal "<p>x</p>" |
      | component CSS: null CSS leaves srcdoc unchanged | HTML component text is "<p>x</p>" and CSS is null | render the component through the public component API | iframe srcdoc and srcdoc attribute equal "<p>x</p>" |
      | component CSS: undefined CSS leaves srcdoc unchanged | HTML component text is "<p>x</p>" and CSS is undefined | render the component through the public component API | iframe srcdoc and srcdoc attribute equal "<p>x</p>" |
      | component CSS: non-string CSS is not coerced | HTML component text is "<p>x</p>" and CSS is an object with an observable toString | render the component through the public component API | iframe srcdoc and srcdoc attribute equal "<p>x</p>" and toString call count is zero |
      | component CSS: inherited CSS is ignored | HTML component text is "<p>x</p>" and CSS is an observable inherited getter returning p{color:inherited} | render the component through the public component API | iframe srcdoc and srcdoc attribute equal "<p>x</p>" and inherited CSS getter read count is zero |
      | component CSS: one space is retained exactly | HTML component text is "<p>x</p>" and CSS is " " | render the component through the public component API | iframe srcdoc and srcdoc attribute equal "<style> </style><p>x</p>" |
      | component CSS: tab and newline are retained exactly | HTML component text is "<p>x</p>" and CSS is "\\t\\n" | render the component through the public component API | iframe srcdoc and srcdoc attribute equal "<style>	\n</style><p>x</p>" |
      | component CSS: mixed-case closing style is escaped with U+005C | HTML component text is "<p>x</p>" and CSS is "</STYLE>" | render the component through the public component API | iframe srcdoc and srcdoc attribute equal "<style><\\/style></style><p>x</p>" with escape code point U+005C |
      | component CSS: repeated closing styles are escaped with U+005C | HTML component text is "<p>x</p>" and CSS is "a</style>b</StYlE>c" | render the component through the public component API | iframe srcdoc and srcdoc attribute equal "<style>a<\\/style>b<\\/style>c</style><p>x</p>" with escape code point U+005C |

  Scenario Outline: <title>
    Given <setup>
    When <action>
    Then <expected>

    Examples: concrete component_type_cases vectors
      | title | setup | action | expected |
      | component type: missing type uses the label default without an iframe | component has no type and text "fallback label" | render the component through the public component API | no throw, iframe, or trace; result is a P with jasonette-label class, data-jasonette-type="label", and visible text "fallback label" |
      | component type: inherited HTML type uses the label default without an iframe | component has an observable inherited type getter returning "html" and owns text "fallback label" | render the component through the public component API | no throw, iframe, or trace; result is a P with jasonette-label class, data-jasonette-type="label", and visible text "fallback label"; inherited type getter read count is zero |
      | component type: non-string type uses the label default without an iframe | component owns numeric type 9 and text "fallback label" | render the component through the public component API | no throw, iframe, or trace; result is a P with jasonette-label class, data-jasonette-type="label", and visible text "fallback label" |
      | component type: own label type renders without an iframe | component owns type "label" and text "visible value" | render the component through the public component API | no throw, iframe, or trace; result is a P with jasonette-label class, data-jasonette-type="label", and visible text "visible value" |
      | component type: own __proto__ type is a visible unknown component | component owns type "__proto__" and text "visible value" | render the component through the public component API | no throw, iframe, or trace; fallback is a visible DIV with non-empty text, no jasonette-label class, and data-jasonette-type is "__proto__" |
      | component type: own constructor type is a visible unknown component | component owns type "constructor" and text "visible value" | render the component through the public component API | no throw, iframe, or trace; fallback is a visible DIV with non-empty text, no jasonette-label class, and data-jasonette-type is "constructor" |
      | component type: own prototype type is a visible unknown component | component owns type "prototype" and text "visible value" | render the component through the public component API | no throw, iframe, or trace; fallback is a visible DIV with non-empty text, no jasonette-label class, and data-jasonette-type is "prototype" |
      | component type: own toString type is a visible unknown component | component owns type "toString" and text "visible value" | render the component through the public component API | no throw, iframe, or trace; fallback is a visible DIV with non-empty text, no jasonette-label class, and data-jasonette-type is "toString" |

  Scenario Outline: <title>
    Given <setup>
    When <action>
    Then <expected>

    Examples: concrete inherited_component_callable_cases vectors
      | title | setup | action | expected |
      | component registry inherited callable: redInheritedComponentCallable is not invoked and a non-empty visible fallback is returned | Object.prototype["redInheritedComponentCallable"] is an observable iframe-producing callable and component owns type "redInheritedComponentCallable" | render the component through the public component API | call count is zero, no throw, iframe, or trace; fallback is a visible DIV with non-empty text, no jasonette-label class, and data-jasonette-type "redInheritedComponentCallable" |
      | component registry inherited callable: toString is not invoked and a non-empty visible fallback is returned | Object.prototype["toString"] is an observable iframe-producing callable and component owns type "toString" | render the component through the public component API | call count is zero, no throw, iframe, or trace; fallback is a visible DIV with non-empty text, no jasonette-label class, and data-jasonette-type "toString" |
      | component registry inherited callable: constructor is not invoked and a non-empty visible fallback is returned | Object.prototype["constructor"] is an observable iframe-producing callable and component owns type "constructor" | render the component through the public component API | call count is zero, no throw, iframe, or trace; fallback is a visible DIV with non-empty text, no jasonette-label class, and data-jasonette-type "constructor" |
      | component registry inherited callable: __proto__ is not invoked and a non-empty visible fallback is returned | Object.prototype["__proto__"] is an observable iframe-producing callable and component owns type "__proto__" | render the component through the public component API | call count is zero, no throw, iframe, or trace; fallback is a visible DIV with non-empty text, no jasonette-label class, and data-jasonette-type "__proto__" |
      | component registry inherited callable: prototype is not invoked and a non-empty visible fallback is returned | Object.prototype["prototype"] is an observable iframe-producing callable and component owns type "prototype" | render the component through the public component API | call count is zero, no throw, iframe, or trace; fallback is a visible DIV with non-empty text, no jasonette-label class, and data-jasonette-type "prototype" |

  Scenario Outline: <title>
    Given <setup>
    When <action>
    Then <expected>

    Examples: concrete transform_render_inheritance_cases vectors
      | title | setup | action | expected |
      | transform-to-render ownership: inherited text URL and CSS create no iframe | HTML object owns only type="html" and has observable inherited text, URL, and CSS getters | body-transform the authored object then render the component | no iframe and no observer trace; all inherited getter read counts are zero |
      | transform-to-render ownership: inherited text plus own URL selects URL | HTML object owns type="html" and URL="https://example.com/transformed-own.html" but has an observable inherited text getter | body-transform the authored object then render the component | one iframe has sandbox="allow-scripts", only src="https://example.com/transformed-own.html", and events [CREATE(component), SANDBOX("allow-scripts"), SOURCE("src"), APPEND, RETURN]; all inherited getter read counts are zero |
      | transform-to-render ownership: inherited URL plus own text selects inline | HTML object owns type="html" and text="<p>transformed own</p>" but has an observable inherited URL getter | body-transform the authored object then render the component | one iframe has sandbox="allow-scripts", only srcdoc="<p>transformed own</p>", and events [CREATE(component), SANDBOX("allow-scripts"), SOURCE("srcdoc"), APPEND, RETURN]; all inherited getter read counts are zero |
      | transform-to-render ownership: inherited CSS plus own text omits CSS | HTML object owns type="html" and text="<p>transformed cssless</p>" but has an observable inherited CSS getter | body-transform the authored object then render the component | one iframe has sandbox="allow-scripts", only srcdoc="<p>transformed cssless</p>", and events [CREATE(component), SANDBOX("allow-scripts"), SOURCE("srcdoc"), APPEND, RETURN]; all inherited getter read counts are zero |

  Scenario: component inline iframe trace installs sandbox before source insertion and return
    Given component {type:"html", text:"<p>inline</p>"}
    When render through the directly observed component boundary
    Then iframe has sandbox="allow-scripts", only srcdoc="<p>inline</p>", and trace CREATE, SANDBOX, SOURCE, APPEND, RETURN

  Scenario: component URL iframe trace installs sandbox before source insertion and return
    Given component {type:"html", url:"https://example.com/page.html"}
    When render through the directly observed component boundary
    Then iframe has sandbox="allow-scripts", only src="https://example.com/page.html", and trace CREATE, SANDBOX, SOURCE, APPEND, RETURN

  Scenario: component wrapper return topology and legacy class size border contract remain exact
    Given component {type:"html", text:"<p>x</p>"}
    When render through the directly observed component boundary
    Then detached wrapper class list contains "jasonette-html", data type is "html", iframe parent is wrapper, width is "100%", CSSOM borderTopStyle, borderRightStyle, borderBottomStyle, and borderLeftStyle are each "none", and events are [CREATE(component), SANDBOX("allow-scripts"), SOURCE("srcdoc"), APPEND, RETURN]

  Scenario: component registry never invokes an inherited callable renderer
    Given Object.prototype.redInheritedComponent is an observable iframe renderer and component owns that type
    When render the component
    Then call count is zero; no throw, iframe, or trace; fallback is a visible DIV with non-empty text, no jasonette-label class, and data type is "redInheritedComponent"

