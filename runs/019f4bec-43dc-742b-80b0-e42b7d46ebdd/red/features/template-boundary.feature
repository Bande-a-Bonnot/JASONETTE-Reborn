Feature: Body-scoped HTML template transformation
  Public-package black-box evidence only; no browser-enforcement claim is made.

  Scenario Outline: <title>
    Given <setup>
    When <action>
    Then <expected>

    Examples: concrete transform_exact_cases vectors
      | title | setup | action | expected |
      | transform exact: body mode preserves HTML text and transforms nested style | input {type:"html", text:"<p>{{secret}}</p>", style:{height:"{{height}}"}}, context {secret:"LEAK", height:40}, preserveHtmlText true | transform the input through the public template API | output equals {type:"html", text:"<p>{{secret}}</p>", style:{height:40}} |
      | transform exact: resolved type and text keys preserve HTML text | input {type:"{{kind}}", "{{slot}}":"<p>{{secret}}</p>"}, context {kind:"html", slot:"text", secret:"LEAK"}, preserveHtmlText true | transform the input through the public template API | output equals {type:"html", text:"<p>{{secret}}</p>"} |
      | transform exact: resolved type key classifies authored text | input {"{{typeKey}}":"{{kind}}", text:"{{secret}}"}, context {typeKey:"type", kind:"html", secret:"LEAK"}, preserveHtmlText true | transform the input through the public template API | output equals {type:"html", text:"{{secret}}"} |
      | transform exact: duplicate resolved text uses the authored last value | input {type:"html", "{{slot}}":"first", text:"second"}, context {slot:"text"}, preserveHtmlText true | transform the duplicate resolved text keys | output equals {type:"html", text:"second"} |
      | transform exact: label text interpolates in body mode | input {type:"label", text:"{{secret}}"}, context {secret:"OK"}, preserveHtmlText true | transform the input through the public template API | output equals {type:"label", text:"OK"} |
      | transform exact: omitted body option interpolates HTML text | input {type:"html", text:"{{secret}}"}, context {secret:"GENERIC"}, with options omitted | transform the input through the public template API | output equals {type:"html", text:"GENERIC"} |
      | transform exact: explicit false option interpolates HTML text | input {type:"html", text:"{{secret}}"}, context {secret:"EXPLICIT-FALSE"}, preserveHtmlText false | transform the input through the public template API | output equals {type:"html", text:"EXPLICIT-FALSE"} |

  Scenario Outline: <title>
    Given <setup>
    When <action>
    Then <expected>

    Examples: concrete type_collision_cases vectors
      | title | setup | action | expected |
      | classification collision: final label type disables raw text protection | authored type is "html", resolved duplicate type is "label", text is "{{secret}}", and secret is "VISIBLE" in body mode | transform the colliding type keys | output equals {type:"label", text:"VISIBLE"} |
      | classification collision: final HTML type enables raw text protection | authored type is "label", resolved duplicate type is "html", text is "{{secret}}", and secret is "VISIBLE" in body mode | transform the colliding type keys | output equals {type:"html", text:"{{secret}}"} |

  Scenario Outline: <title>
    Given <setup>
    When <action>
    Then <expected>

    Examples: concrete non_protecting_type_cases vectors
      | title | setup | action | expected |
      | classification negative: missing type does not protect text | input {text:"{{secret}}"} has no type, context secret is "VISIBLE", and preserveHtmlText is true | transform the input through the public template API | text equals "VISIBLE" |
      | classification negative: unresolved type does not protect text | input {type:"{{unknownKind}}", text:"{{secret}}"}, context has secret "VISIBLE" but no unknownKind, and preserveHtmlText is true | transform the input through the public template API | text equals "VISIBLE" |
      | classification negative: non-string type does not protect text | input {type:{value:"html"}, text:"{{secret}}"}, context secret is "VISIBLE", and preserveHtmlText is true | transform the input through the public template API | text equals "VISIBLE" |

  Scenario Outline: <title>
    Given <setup>
    When <action>
    Then <expected>

    Examples: concrete body_recursion_cases vectors
      | title | setup | action | expected |
      | body recursion path: root HTML shape preserves raw text | a body-mode template with {type:"html", text:"{{secret}}"} at the "root" recursion path and context secret "LEAK" | render the template synchronously | exactly one HTML shape is found and its text equals "{{secret}}" |
      | body recursion path: header HTML shape preserves raw text | a body-mode template with {type:"html", text:"{{secret}}"} at the "header" recursion path and context secret "LEAK" | render the template synchronously | exactly one HTML shape is found and its text equals "{{secret}}" |
      | body recursion path: footer HTML shape preserves raw text | a body-mode template with {type:"html", text:"{{secret}}"} at the "footer" recursion path and context secret "LEAK" | render the template synchronously | exactly one HTML shape is found and its text equals "{{secret}}" |
      | body recursion path: section HTML shape preserves raw text | a body-mode template with {type:"html", text:"{{secret}}"} at the "section" recursion path and context secret "LEAK" | render the template synchronously | exactly one HTML shape is found and its text equals "{{secret}}" |
      | body recursion path: layout HTML shape preserves raw text | a body-mode template with {type:"html", text:"{{secret}}"} at the "layout" recursion path and context secret "LEAK" | render the template synchronously | exactly one HTML shape is found and its text equals "{{secret}}" |
      | body recursion path: layer HTML shape preserves raw text | a body-mode template with {type:"html", text:"{{secret}}"} at the "layer" recursion path and context secret "LEAK" | render the template synchronously | exactly one HTML shape is found and its text equals "{{secret}}" |
      | body recursion path: background HTML shape preserves raw text | a body-mode template with {type:"html", text:"{{secret}}"} at the "background" recursion path and context secret "LEAK" | render the template synchronously | exactly one HTML shape is found and its text equals "{{secret}}" |
      | body recursion path: nested array HTML shape preserves raw text | a body-mode template with {type:"html", text:"{{secret}}"} at the "array" recursion path and context secret "LEAK" | render the template synchronously | exactly one HTML shape is found and its text equals "{{secret}}" |
      | body recursion path: action options HTML shape preserves raw text | a body-mode template with {type:"html", text:"{{secret}}"} at the "action-options" recursion path and context secret "LEAK" | render the template synchronously | exactly one HTML shape is found and its text equals "{{secret}}" |
      | body recursion path: action payload HTML shape preserves raw text | a body-mode template with {type:"html", text:"{{secret}}"} at the "action-payload" recursion path and context secret "LEAK" | render the template synchronously | exactly one HTML shape is found and its text equals "{{secret}}" |

  Scenario Outline: <title>
    Given <setup>
    When <action>
    Then <expected>

    Examples: concrete directive_cases vectors
      | title | setup | action | expected |
      | directive recursion: #if result preserves HTML text | body-mode input maps "{{#if enabled}}" to {type:"html", text:"{{secret}}"}; context enabled=true and secret="LEAK" | render the directive through the public template API | exactly one HTML shape is returned and every text equals "{{secret}}" |
      | directive recursion: #elseif result preserves HTML text | body-mode input maps false first #if to a wrong label and true second #elseif to {type:"html", text:"{{secret}}"}; context first=false, second=true, secret="LEAK" | render the directive through the public template API | exactly one HTML shape is returned and every text equals "{{secret}}" |
      | directive recursion: #else result preserves HTML text | body-mode input maps #if enabled to a wrong label and #else to {type:"html", text:"{{secret}}"}; context enabled=false and secret="LEAK" | render the directive through the public template API | exactly one HTML shape is returned and every text equals "{{secret}}" |
      | directive recursion: #each results preserve HTML text | body-mode input maps "{{#each rows}}" to {type:"html", text:"{{secret}}"}; context rows=[1,2] and secret="LEAK" | render the directive through the public template API | exactly two HTML shapes are returned and every text equals "{{secret}}" |

  Scenario Outline: <title>
    Given <setup>
    When <action>
    Then <expected>

    Examples: concrete dangerous_transform_cases vectors
      | title | setup | action | expected |
      | dangerous transform: body mode defines inert own __proto__ | two resolved keys both become "__proto__" with values "first" then "last" in "body" mode | transform the duplicate dangerous keys | output has Object.prototype and own descriptor "__proto__"={value:"last", enumerable:true, writable:true, configurable:true} |
      | dangerous transform: off mode defines inert own __proto__ | two resolved keys both become "__proto__" with values "first" then "last" in "off" mode | transform the duplicate dangerous keys | output has Object.prototype and own descriptor "__proto__"={value:"last", enumerable:true, writable:true, configurable:true} |
      | dangerous transform: body mode defines inert own constructor | two resolved keys both become "constructor" with values "first" then "last" in "body" mode | transform the duplicate dangerous keys | output has Object.prototype and own descriptor "constructor"={value:"last", enumerable:true, writable:true, configurable:true} |
      | dangerous transform: off mode defines inert own constructor | two resolved keys both become "constructor" with values "first" then "last" in "off" mode | transform the duplicate dangerous keys | output has Object.prototype and own descriptor "constructor"={value:"last", enumerable:true, writable:true, configurable:true} |
      | dangerous transform: body mode defines inert own prototype | two resolved keys both become "prototype" with values "first" then "last" in "body" mode | transform the duplicate dangerous keys | output has Object.prototype and own descriptor "prototype"={value:"last", enumerable:true, writable:true, configurable:true} |
      | dangerous transform: off mode defines inert own prototype | two resolved keys both become "prototype" with values "first" then "last" in "off" mode | transform the duplicate dangerous keys | output has Object.prototype and own descriptor "prototype"={value:"last", enumerable:true, writable:true, configurable:true} |

  Scenario Outline: <title>
    Given <setup>
    When <action>
    Then <expected>

    Examples: concrete dangerous_order_cases vectors
      | title | setup | action | expected |
      | dangerous ordering: body mode __proto__ getters stop at the thrown error | keys firstKey, dangerousKey, lastKey all resolve to "__proto__" and the dangerous value getter throws "dangerous-__proto__" in "body" mode | transform while recording every context getter | the thrown message is "dangerous-__proto__" and getter order equals ["firstKey","dangerousKey","lastKey","firstValue","boom"] |
      | dangerous ordering: off mode __proto__ getters stop at the thrown error | keys firstKey, dangerousKey, lastKey all resolve to "__proto__" and the dangerous value getter throws "dangerous-__proto__" in "off" mode | transform while recording every context getter | the thrown message is "dangerous-__proto__" and getter order equals ["firstKey","firstValue","dangerousKey","boom"] |
      | dangerous ordering: body mode constructor getters stop at the thrown error | keys firstKey, dangerousKey, lastKey all resolve to "constructor" and the dangerous value getter throws "dangerous-constructor" in "body" mode | transform while recording every context getter | the thrown message is "dangerous-constructor" and getter order equals ["firstKey","dangerousKey","lastKey","firstValue","boom"] |
      | dangerous ordering: off mode constructor getters stop at the thrown error | keys firstKey, dangerousKey, lastKey all resolve to "constructor" and the dangerous value getter throws "dangerous-constructor" in "off" mode | transform while recording every context getter | the thrown message is "dangerous-constructor" and getter order equals ["firstKey","firstValue","dangerousKey","boom"] |
      | dangerous ordering: body mode prototype getters stop at the thrown error | keys firstKey, dangerousKey, lastKey all resolve to "prototype" and the dangerous value getter throws "dangerous-prototype" in "body" mode | transform while recording every context getter | the thrown message is "dangerous-prototype" and getter order equals ["firstKey","dangerousKey","lastKey","firstValue","boom"] |
      | dangerous ordering: off mode prototype getters stop at the thrown error | keys firstKey, dangerousKey, lastKey all resolve to "prototype" and the dangerous value getter throws "dangerous-prototype" in "off" mode | transform while recording every context getter | the thrown message is "dangerous-prototype" and getter order equals ["firstKey","firstValue","dangerousKey","boom"] |

  Scenario: protected raw string output is strictly equal to its input
    Given HTML text code units equal <script>window.x = "{{secret}}"</script> with secret "LEAK" in body mode
    When transform the HTML shape
    Then output text is strictly equal to the authored string

  Scenario: protected raw object output retains the identical reference without recursion
    Given HTML text is an object {nested:"{{secret}}"} with an observable probe getter in body mode
    When transform the HTML shape
    Then output text is the identical object reference and probe getter call count is zero

  Scenario: duplicate raw text entries are never evaluated and the last authored value wins
    Given body-mode HTML has resolved text "{{first}}" then authored text "{{second}}" with observable first and second getters
    When transform the duplicate text entries
    Then output text equals "{{second}}" and both getter call counts are zero

  Scenario: embedded body action options are raw immediately after body transformation
    Given embedded $set option probe {type:"html", text:"{{secret}}"} with secret "BODY" and body mode
    When render the embedded action shape
    Then result.options.probe.text equals "{{secret}}"

  Scenario: standalone transform with an unrelated option remains generic
    Given HTML text "{{secret}}", secret "GENERIC", and only unrelated option preserveFalsy=true
    When transform through the standalone public API
    Then output text equals "GENERIC"

  Scenario: body mode resolves all flat keys before type and ordinary value expressions exactly once
    Given three resolved keys and context getters keyA, typeKey, keyB, kind, valueA, valueB in body mode
    When transform while logging getter access
    Then log equals ["keyA","typeKey","keyB","kind","valueA","valueB"] and every getter count is one

  Scenario: body mode applies all-keys-first ordering independently in each nested frame
    Given resolved outer child and tail keys plus resolved inner value and type keys in body mode
    When transform while logging nested getter access
    Then log equals ["outerKey","tailKey","innerKey","innerTypeKey","innerKind","innerValue","tailValue"]

  Scenario: off mode preserves per-entry key-then-value getter ordering
    Given three resolved entries with key and value getters and options omitted
    When transform while logging getter access
    Then log equals ["keyA","valueA","typeKey","kind","keyB","valueB"]

  Scenario: explicit false option preserves per-entry key-then-value getter ordering
    Given three resolved entries with context kind html and preserveHtmlText=false
    When transform while logging getter access
    Then log equals ["keyA","valueA","typeKey","kind","keyB","valueB"] and output equals {alpha:"A", type:"html", omega:"B"}

  Scenario: public RenderOptions type accepts preserveHtmlText
    Given public RenderOptions assignments with preserveHtmlText false and true
    When typecheck and read both assigned properties
    Then values are exactly false and true without suppression

  Scenario: numeric own keys transform in ECMAScript order 1 then 2 then alpha
    Given input insertion order is numeric "2", numeric "1", then alpha with observable value getters
    When transform in body mode
    Then getter log equals ["one","two","alpha"]

  Scenario: transformation enumerates only own enumerable string keys
    Given input inherits enumerable inherited, owns enumerable visible, owns non-enumerable hidden, and owns a Symbol key
    When transform with secret "VALUE" in body mode
    Then output equals {visible:"VALUE"} and has Object.prototype

  Scenario: unresolved expression output remains the exact authored string
    Given authored string "prefix {{missing.deep.value}} suffix" and empty context
    When transform with generic options
    Then output strictly equals "prefix {{missing.deep.value}} suffix"

