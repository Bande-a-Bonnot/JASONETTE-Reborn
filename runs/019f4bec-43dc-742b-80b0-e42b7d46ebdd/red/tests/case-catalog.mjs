export const TRANSFORM_EXACT_CASES = [
  { title: "transform exact: body mode preserves HTML text and transforms nested style", vector: "literal-html" },
  { title: "transform exact: resolved type and text keys preserve HTML text", vector: "resolved-both" },
  { title: "transform exact: resolved type key classifies authored text", vector: "resolved-type" },
  { title: "transform exact: duplicate resolved text uses the authored last value", vector: "duplicate-text" },
  { title: "transform exact: label text interpolates in body mode", vector: "label" },
  { title: "transform exact: omitted body option interpolates HTML text", vector: "generic" },
  { title: "transform exact: explicit false option interpolates HTML text", vector: "explicit-false" },
];

export const TYPE_COLLISION_CASES = [
  { title: "classification collision: final label type disables raw text protection", finalType: "label", expected: "VISIBLE" },
  { title: "classification collision: final HTML type enables raw text protection", finalType: "html", expected: "{{secret}}" },
];

export const NON_PROTECTING_TYPE_CASES = [
  { title: "classification negative: missing type does not protect text", kind: "missing", expected: "VISIBLE" },
  { title: "classification negative: unresolved type does not protect text", kind: "unresolved", expected: "VISIBLE" },
  { title: "classification negative: non-string type does not protect text", kind: "non-string", expected: "VISIBLE" },
];

export const BODY_RECURSION_CASES = [
  { title: "body recursion path: root HTML shape preserves raw text", path: "root" },
  { title: "body recursion path: header HTML shape preserves raw text", path: "header" },
  { title: "body recursion path: footer HTML shape preserves raw text", path: "footer" },
  { title: "body recursion path: section HTML shape preserves raw text", path: "section" },
  { title: "body recursion path: layout HTML shape preserves raw text", path: "layout" },
  { title: "body recursion path: layer HTML shape preserves raw text", path: "layer" },
  { title: "body recursion path: background HTML shape preserves raw text", path: "background" },
  { title: "body recursion path: nested array HTML shape preserves raw text", path: "array" },
  { title: "body recursion path: action options HTML shape preserves raw text", path: "action-options" },
  { title: "body recursion path: action payload HTML shape preserves raw text", path: "action-payload" },
];

export const DIRECTIVE_CASES = [
  { title: "directive recursion: #if result preserves HTML text", directive: "if" },
  { title: "directive recursion: #elseif result preserves HTML text", directive: "elseif" },
  { title: "directive recursion: #else result preserves HTML text", directive: "else" },
  { title: "directive recursion: #each results preserve HTML text", directive: "each" },
];

export const DANGEROUS_TRANSFORM_CASES = [
  ...["__proto__", "constructor", "prototype"].flatMap((key) => [
    { title: `dangerous transform: body mode defines inert own ${key}`, key, mode: "body" },
    { title: `dangerous transform: off mode defines inert own ${key}`, key, mode: "off" },
  ]),
];

export const DANGEROUS_ORDER_CASES = [
  ...["__proto__", "constructor", "prototype"].flatMap((key) => [
    { title: `dangerous ordering: body mode ${key} getters stop at the thrown error`, key, mode: "body" },
    { title: `dangerous ordering: off mode ${key} getters stop at the thrown error`, key, mode: "off" },
  ]),
];

export const SINK_CASES = [
  { title: "safe state sink: $set retains dangerous own descriptors", actionType: "$set", destination: "local" },
  { title: "safe state sink: $cache.set retains dangerous own descriptors", actionType: "$cache.set", destination: "cache" },
  { title: "safe state sink: $global.set retains dangerous own descriptors", actionType: "$global.set", destination: "global" },
];

export const SESSION_DOMAIN_CASES = [
  { title: "session registry: reachable __proto__ domain is an inert own property", domain: "__proto__" },
  { title: "session registry: reachable constructor domain is an inert own property", domain: "constructor" },
  { title: "session registry: reachable prototype domain is an inert own property", domain: "prototype" },
];

export const COMPONENT_TYPE_CASES = [
  { title: "component type: missing type uses the label default without an iframe", kind: "missing", outcome: "label" },
  { title: "component type: inherited HTML type uses the label default without an iframe", kind: "inherited-html", outcome: "label" },
  { title: "component type: non-string type uses the label default without an iframe", kind: "non-string", outcome: "label" },
  { title: "component type: own label type renders without an iframe", kind: "label", outcome: "label" },
  { title: "component type: own __proto__ type is a visible unknown component", kind: "__proto__", outcome: "unknown" },
  { title: "component type: own constructor type is a visible unknown component", kind: "constructor", outcome: "unknown" },
  { title: "component type: own prototype type is a visible unknown component", kind: "prototype", outcome: "unknown" },
  { title: "component type: own toString type is a visible unknown component", kind: "toString", outcome: "unknown" },
];

export const COMPONENT_SOURCE_CASES = [
  { title: "component source: inline text wins over a URL", kind: "dual", source: "srcdoc", expected: "<p>inline</p>" },
  { title: "component source: whitespace text is a valid inline source", kind: "whitespace", source: "srcdoc", expected: " \t\n" },
  { title: "component source: empty text falls back to a URL", kind: "empty-text-url", source: "src", expected: "https://example.com/fallback.html" },
  { title: "component source: numeric text and object URL are not coerced", kind: "coercion", source: "none", expected: null },
  { title: "component source: inherited-only text and URL are ignored", kind: "inherited-only", source: "none", expected: null },
  { title: "component source: inherited text yields to an own URL", kind: "inherited-text-own-url", source: "src", expected: "https://example.com/own.html" },
  { title: "component source: inherited URL yields to own text", kind: "inherited-url-own-text", source: "srcdoc", expected: "<p>own</p>" },
  { title: "component source: missing text and URL creates no iframe", kind: "missing", source: "none", expected: null },
  { title: "component source: invalid HTML is assigned byte-for-byte", kind: "invalid", source: "srcdoc", expected: "<p><b>unterminated & raw" },
];

export const INHERITED_COMPONENT_CALLABLE_CASES = [
  "redInheritedComponentCallable", "toString", "constructor", "__proto__", "prototype",
].map((name) => ({
  title: `component registry inherited callable: ${name} is not invoked and a non-empty visible fallback is returned`,
  name,
}));

export const TRANSFORM_RENDER_INHERITANCE_CASES = [
  { title: "transform-to-render ownership: inherited text URL and CSS create no iframe", kind: "all-inherited", source: "none", expected: null },
  { title: "transform-to-render ownership: inherited text plus own URL selects URL", kind: "inherited-text", source: "src", expected: "https://example.com/transformed-own.html" },
  { title: "transform-to-render ownership: inherited URL plus own text selects inline", kind: "inherited-url", source: "srcdoc", expected: "<p>transformed own</p>" },
  { title: "transform-to-render ownership: inherited CSS plus own text omits CSS", kind: "inherited-css", source: "srcdoc", expected: "<p>transformed cssless</p>" },
];

export const CSS_CASES = [
  { title: "component CSS: absent CSS leaves srcdoc unchanged", kind: "absent", css: null, expected: "<p>x</p>" },
  { title: "component CSS: empty CSS leaves srcdoc unchanged", kind: "empty", css: "", expected: "<p>x</p>" },
  { title: "component CSS: null CSS leaves srcdoc unchanged", kind: "null", css: null, expected: "<p>x</p>" },
  { title: "component CSS: undefined CSS leaves srcdoc unchanged", kind: "undefined", expected: "<p>x</p>" },
  { title: "component CSS: non-string CSS is not coerced", kind: "coercion", expected: "<p>x</p>" },
  { title: "component CSS: inherited CSS is ignored", kind: "inherited", expected: "<p>x</p>" },
  { title: "component CSS: one space is retained exactly", kind: "space", css: " ", expected: "<style> </style><p>x</p>" },
  { title: "component CSS: tab and newline are retained exactly", kind: "tab-newline", css: "\t\n", expected: "<style>\t\n</style><p>x</p>" },
  { title: "component CSS: mixed-case closing style is escaped with U+005C", kind: "mixed", css: "</STYLE>", expected: "<style><\\/style></style><p>x</p>" },
  { title: "component CSS: repeated closing styles are escaped with U+005C", kind: "repeated", css: "a</style>b</StYlE>c", expected: "<style>a<\\/style>b<\\/style>c</style><p>x</p>" },
];

export const ACTION_TYPE_CASES = [
  { title: "action type: missing type with no trigger returns undefined", kind: "missing" },
  { title: "action type: inherited handler type is ignored", kind: "inherited" },
  { title: "action type: non-string type returns undefined", kind: "non-string" },
  { title: "action type: own unknown non-HTML type returns undefined", kind: "redUnknownAction" },
  { title: "action type: own custom type with only an inherited callable returns undefined", kind: "redInheritedOnlyAction" },
  { title: "action type: own __proto__ type returns undefined without continuation", kind: "__proto__" },
  { title: "action type: own constructor type returns undefined without continuation", kind: "constructor" },
  { title: "action type: own prototype type returns undefined without continuation", kind: "prototype" },
  { title: "action type: own toString type returns undefined without continuation", kind: "toString" },
];

export const NON_STRING_OWN_TRIGGER_CASES = [
  "toString", "constructor", "__proto__", "prototype",
].map((name) => ({ title: `non-string action type with own ${name} trigger executes`, name }));

export const INHERITED_TRIGGER_CASES = [
  "toString", "constructor", "__proto__", "prototype",
].map((name) => ({ title: `inherited ${name} trigger is ignored`, name }));

export const NAMED_ACTION_CASES = [
  ...["toString", "constructor", "__proto__"].flatMap((name) => [
    { title: `named trigger: own ${name} entry executes`, dispatch: "trigger", ownership: "own", name },
    { title: `named trigger: inherited ${name} entry is ignored`, dispatch: "trigger", ownership: "inherited", name },
    { title: `named lambda: own ${name} entry executes`, dispatch: "lambda", ownership: "own", name },
    { title: `named lambda: inherited ${name} entry is ignored`, dispatch: "lambda", ownership: "inherited", name },
  ]),
];

export const NAMED_ACTION_ARRAY_CASES = [
  { title: "own named action arrays execute async non-commutative authored order through trigger", dispatch: "trigger" },
  { title: "own named action arrays execute async non-commutative authored order through lambda", dispatch: "lambda" },
];

export const STATIC_BACKGROUND_CASES = [
  { title: "background authored path: static canonical inline source and CSS render exactly", vector: "static-canonical" },
  { title: "background authored path: static legacy URL renders exclusively", vector: "static-legacy" },
  { title: "background authored path: templated canonical keeps text raw and transforms CSS", vector: "template-canonical" },
  { title: "background authored path: templated legacy transforms its URL", vector: "template-legacy" },
  { title: "background authored path: selected HTML without a source creates no iframe", vector: "no-source" },
];

export const BACKGROUND_PRECEDENCE_CASES = [
  { title: "background precedence: false canonical blocks a valid legacy fallback", kind: "false-canonical", expected: "none" },
  { title: "background precedence: malformed canonical blocks a valid legacy fallback", kind: "malformed-canonical", expected: "none" },
  { title: "background precedence: source-less canonical blocks a valid legacy fallback", kind: "source-less-canonical", expected: "none" },
  { title: "background precedence: null canonical selects own legacy background", kind: "null-canonical", expected: "legacy" },
  { title: "background precedence: undefined canonical selects own legacy background", kind: "undefined-canonical", expected: "legacy" },
  { title: "background precedence: inherited canonical selects own legacy background", kind: "inherited-canonical", expected: "legacy" },
  { title: "background precedence: inherited style is ignored without canonical", kind: "inherited-style", expected: "none" },
  { title: "background precedence: inherited legacy background inside own style is ignored", kind: "inherited-legacy", expected: "none" },
  { title: "background precedence: inherited canonical without fallback selects nothing", kind: "inherited-canonical-none", expected: "none" },
  { title: "background precedence: missing canonical and legacy selects nothing", kind: "missing", expected: "none" },
];

const BACKGROUND_VECTORS = [
  { id: "inline", source: "srcdoc", expected: "<p>inline</p>" },
  { id: "URL", source: "src", expected: "https://example.com/background.html" },
  { id: "dual source text precedence", source: "srcdoc", expected: "<p>dual</p>" },
  { id: "whitespace inline source", source: "srcdoc", expected: " \t\n" },
  { id: "empty own text with valid URL fallback", source: "src", expected: "https://example.com/empty-text-fallback.html" },
  { id: "non-string own text with valid URL fallback", source: "src", expected: "https://example.com/non-string-text-fallback.html" },
  { id: "invalid inline HTML exact preservation", source: "srcdoc", expected: "<p><b>unterminated & raw" },
  { id: "empty sources", source: "none", expected: null },
  { id: "non-string coercion sentinels", source: "none", expected: null },
  { id: "empty CSS", source: "srcdoc", expected: "<p>css</p>" },
  { id: "null CSS", source: "srcdoc", expected: "<p>css</p>" },
  { id: "undefined CSS", source: "srcdoc", expected: "<p>css</p>" },
  { id: "non-string CSS coercion sentinel", source: "srcdoc", expected: "<p>css</p>" },
  { id: "one-space CSS", source: "srcdoc", expected: "<style> </style><p>css</p>" },
  { id: "tab-newline CSS", source: "srcdoc", expected: "<style>\t\n</style><p>css</p>" },
  { id: "mixed-case CSS escape", source: "srcdoc", expected: "<style><\\/style></style><p>css</p>" },
  { id: "repeated mixed-case CSS escape", source: "srcdoc", expected: "<style>a<\\/style>b<\\/style>c</style><p>css</p>" },
  { id: "inherited-only source fields", source: "none", expected: null },
  { id: "inherited text with own URL", source: "src", expected: "https://example.com/own-background.html" },
  { id: "inherited URL with own text", source: "srcdoc", expected: "<p>own background</p>" },
  { id: "inherited CSS with own text", source: "srcdoc", expected: "<p>own cssless</p>" },
  { id: "missing type", source: "none", expected: null },
  { id: "inherited HTML type", source: "none", expected: null },
  { id: "non-string type", source: "none", expected: null },
  { id: "non-HTML type", source: "none", expected: null },
  { id: "__proto__ type collision", source: "none", expected: null },
  { id: "constructor type collision", source: "none", expected: null },
  { id: "prototype type collision", source: "none", expected: null },
  { id: "toString type collision", source: "none", expected: null },
  { id: "HTML type without source", source: "none", expected: null },
];

export const BACKGROUND_MATRIX_CASES = ["canonical", "legacy"].flatMap((path) =>
  BACKGROUND_VECTORS.map((entry) => ({
    ...entry,
    path,
    title: `background ${path} matrix: ${entry.id}`,
  })),
);

export const INSERTION_OBSERVER_CASES = [
  "Element appendChild", "DocumentFragment appendChild", "insertBefore", "replaceChild",
  "Element append", "Element prepend", "replaceChildren", "before", "after", "replaceWith",
  "insertAdjacentElement",
].map((route) => ({ title: `observer insertion self-test: detects ${route} before sandbox`, route }));

export const OBSERVER_CREATION_CASES = [
  { title: "observer creation self-test: detects createElementNS exactly", route: "createElementNS", unsafe: false },
  { title: "observer creation self-test: detects Element innerHTML parser exactly", route: "Element innerHTML", unsafe: false },
  { title: "observer creation self-test: detects template fragment parser exactly", route: "template innerHTML", unsafe: false },
  { title: "observer creation self-test: detects insertAdjacentHTML parser exactly", route: "insertAdjacentHTML", unsafe: false },
  { title: "observer creation self-test: detects Range contextual fragment exactly", route: "Range contextual fragment", unsafe: false },
  { title: "observer creation self-test: detects DOMParser document exactly", route: "DOMParser", unsafe: false },
  { title: "observer parser self-test: rejects source before sandbox in authored parser order", route: "source-first innerHTML", unsafe: true },
];

export const SANDBOX_OBSERVER_CASES = [
  "setAttribute", "setAttributeNS", "removeAttribute", "removeAttributeNS", "toggleAttribute",
  "setAttributeNode", "setAttributeNodeNS", "removeAttributeNode", "NamedNodeMap setNamedItem",
  "NamedNodeMap setNamedItemNS", "NamedNodeMap removeNamedItem", "NamedNodeMap removeNamedItemNS",
  "Attr value", "Attr nodeValue", "Attr textContent", "sandbox value", "sandbox add",
  "sandbox remove", "sandbox toggle", "sandbox replace",
].map((route) => ({ title: `observer sandbox self-test: detects ${route} mutation`, route }));

export const SOURCE_OBSERVER_CASES = [
  "src property", "srcdoc property", "setAttribute src", "setAttribute srcdoc",
  "setAttributeNS src", "removeAttribute src", "removeAttributeNS srcdoc", "toggleAttribute srcdoc",
  "setAttributeNode srcdoc", "setAttributeNodeNS src", "removeAttributeNode srcdoc",
  "NamedNodeMap setNamedItem src", "NamedNodeMap setNamedItemNS srcdoc",
  "NamedNodeMap removeNamedItem src", "NamedNodeMap removeNamedItemNS srcdoc",
  "Attr value srcdoc", "Attr nodeValue src", "Attr textContent srcdoc",
].map((route) => ({ title: `observer source self-test: detects ${route} mutation`, route }));

// Authored Gherkin data. The verifier requires every expanded case to reproduce these
// concrete setup/action/expected values in steps; a matching title is not evidence.
const c = (setup, action, expected) => ({ setup, action, expected });
const q = (value) => JSON.stringify(value);
const contracts = {};
const add = (rows, make) => rows.forEach((row) => { contracts[row.title] = make(row); });

const exactContracts = {
  "literal-html": c('input {type:"html", text:"<p>{{secret}}</p>", style:{height:"{{height}}"}}, context {secret:"LEAK", height:40}, preserveHtmlText true', "transform the input through the public template API", 'output equals {type:"html", text:"<p>{{secret}}</p>", style:{height:40}}'),
  "resolved-both": c('input {type:"{{kind}}", "{{slot}}":"<p>{{secret}}</p>"}, context {kind:"html", slot:"text", secret:"LEAK"}, preserveHtmlText true', "transform the input through the public template API", 'output equals {type:"html", text:"<p>{{secret}}</p>"}'),
  "resolved-type": c('input {"{{typeKey}}":"{{kind}}", text:"{{secret}}"}, context {typeKey:"type", kind:"html", secret:"LEAK"}, preserveHtmlText true', "transform the input through the public template API", 'output equals {type:"html", text:"{{secret}}"}'),
  "duplicate-text": c('input {type:"html", "{{slot}}":"first", text:"second"}, context {slot:"text"}, preserveHtmlText true', "transform the duplicate resolved text keys", 'output equals {type:"html", text:"second"}'),
  "label": c('input {type:"label", text:"{{secret}}"}, context {secret:"OK"}, preserveHtmlText true', "transform the input through the public template API", 'output equals {type:"label", text:"OK"}'),
  "generic": c('input {type:"html", text:"{{secret}}"}, context {secret:"GENERIC"}, with options omitted', "transform the input through the public template API", 'output equals {type:"html", text:"GENERIC"}'),
  "explicit-false": c('input {type:"html", text:"{{secret}}"}, context {secret:"EXPLICIT-FALSE"}, preserveHtmlText false', "transform the input through the public template API", 'output equals {type:"html", text:"EXPLICIT-FALSE"}'),
};
add(TRANSFORM_EXACT_CASES, ({ vector }) => exactContracts[vector]);
add(TYPE_COLLISION_CASES, ({ finalType, expected }) => c(
  `authored type is ${q(finalType === "label" ? "html" : "label")}, resolved duplicate type is ${q(finalType)}, text is "{{secret}}", and secret is "VISIBLE" in body mode`,
  "transform the colliding type keys",
  `output equals {type:${q(finalType)}, text:${q(expected)}}`,
));
const nonProtectingSetups = {
  missing: 'input {text:"{{secret}}"} has no type, context secret is "VISIBLE", and preserveHtmlText is true',
  unresolved: 'input {type:"{{unknownKind}}", text:"{{secret}}"}, context has secret "VISIBLE" but no unknownKind, and preserveHtmlText is true',
  "non-string": 'input {type:{value:"html"}, text:"{{secret}}"}, context secret is "VISIBLE", and preserveHtmlText is true',
};
add(NON_PROTECTING_TYPE_CASES, ({ kind, expected }) => c(
  nonProtectingSetups[kind],
  "transform the input through the public template API",
  `text equals ${q(expected)}`,
));
add(BODY_RECURSION_CASES, ({ path }) => c(
  `a body-mode template with {type:"html", text:"{{secret}}"} at the ${q(path)} recursion path and context secret "LEAK"`,
  "render the template synchronously",
  'exactly one HTML shape is found and its text equals "{{secret}}"',
));
const directiveSetups = {
  if: 'body-mode input maps "{{#if enabled}}" to {type:"html", text:"{{secret}}"}; context enabled=true and secret="LEAK"',
  elseif: 'body-mode input maps false first #if to a wrong label and true second #elseif to {type:"html", text:"{{secret}}"}; context first=false, second=true, secret="LEAK"',
  else: 'body-mode input maps #if enabled to a wrong label and #else to {type:"html", text:"{{secret}}"}; context enabled=false and secret="LEAK"',
  each: 'body-mode input maps "{{#each rows}}" to {type:"html", text:"{{secret}}"}; context rows=[1,2] and secret="LEAK"',
};
add(DIRECTIVE_CASES, ({ directive }) => c(
  directiveSetups[directive],
  "render the directive through the public template API",
  `${directive === "each" ? "exactly two HTML shapes are" : "exactly one HTML shape is"} returned and every text equals "{{secret}}"`,
));
add(DANGEROUS_TRANSFORM_CASES, ({ key, mode }) => c(
  `two resolved keys both become ${q(key)} with values "first" then "last" in ${q(mode)} mode`,
  "transform the duplicate dangerous keys",
  `output has Object.prototype and own descriptor ${q(key)}={value:"last", enumerable:true, writable:true, configurable:true}`, 
));
add(DANGEROUS_ORDER_CASES, ({ key, mode }) => c(
  `keys firstKey, dangerousKey, lastKey all resolve to ${q(key)} and the dangerous value getter throws ${q(`dangerous-${key}`)} in ${q(mode)} mode`,
  "transform while recording every context getter",
  `the thrown message is ${q(`dangerous-${key}`)} and getter order equals ${q(mode === "body" ? ["firstKey", "dangerousKey", "lastKey", "firstValue", "boom"] : ["firstKey", "firstValue", "dangerousKey", "boom"])}`,
));

add(SINK_CASES, ({ actionType, destination }) => c(
  `${q(actionType)} options own __proto__="proto-data", constructor="constructor-data", and prototype="prototype-data"`,
  `execute ${q(actionType)} through the public action API`,
  `${q(destination)} has Object.prototype and own descriptors __proto__={value:"proto-data", enumerable:true, writable:true, configurable:true}, constructor={value:"constructor-data", enumerable:true, writable:true, configurable:true}, and prototype={value:"prototype-data", enumerable:true, writable:true, configurable:true}`, 
));
add(SESSION_DOMAIN_CASES, ({ domain }) => c(
  `$session.set options {domain:${q(domain)}, marker:${q(`stored-${domain}`)}}`,
  "execute the session action through the public action API",
  `sessions and sessions[${q(domain)}] have Object.prototype; sessions owns descriptor ${q(domain)} with enumerable, writable, configurable all true; stored marker equals ${q(`stored-${domain}`)}`, 
));
add(ACTION_TYPE_CASES, ({ kind }) => {
  const collision = ["toString", "constructor", "__proto__", "prototype"].includes(kind);
  const customInherited = kind === "redInheritedOnlyAction";
  const base = kind === "missing" ? "a missing own type"
    : kind === "inherited" ? "an inherited redInheritedAction type"
      : kind === "non-string" ? "own numeric type 7"
        : `own type ${q(kind)}`;
  const candidate = collision || customInherited
    ? ` and Object.prototype[${q(kind)}] is a same-key observable inherited callable`
    : "";
  return c(
    `${base}${candidate} with success {$set continuationWasCalled:true} and no own trigger`,
    "execute the action through the public action API",
    `result is undefined, ${collision || customInherited ? `inherited ${q(kind)} callable calls are zero` : "inherited handler calls are zero"}, and continuationWasCalled is not true`,
  );
});
add(NON_STRING_OWN_TRIGGER_CASES, ({ name }) => c(
  `action has own numeric type 17 and trigger ${q(name)}; state.actions owns ${q(name)}={$set options {nonStringTriggerResult:${q(name)}}}`,
  "execute the action through the public action API",
  `local.nonStringTriggerResult equals ${q(name)}`,
));
add(INHERITED_TRIGGER_CASES, ({ name }) => c(
  `action inherits trigger ${q(name)}; state.actions owns ${q(name)}={$set options {inheritedTriggerRan:${q(name)}}}`,
  "execute the action through the public action API",
  "result and local.inheritedTriggerRan are both undefined",
));
add(NAMED_ACTION_CASES, ({ dispatch, ownership, name }) => c(
  `${ownership === "own" ? `state.actions owns ${q(name)}={$set options {namedDispatchResult:${q(`${dispatch}-${name}`)}}}` : `state.actions inherits ${q(name)}={type:"redInheritedNamed"}`} and ${dispatch === "trigger" ? `action is {trigger:${q(name)}}` : `action is {$lambda options {name:${q(name)}}}`}`,
  `dispatch the named action through ${dispatch}`,
  ownership === "own"
    ? `local.namedDispatchResult equals ${q(`${dispatch}-${name}`)} and inherited handler calls are zero`
    : "result and local.namedDispatchResult are undefined and inherited handler calls are zero",
));
add(NAMED_ACTION_ARRAY_CASES, ({ dispatch }) => c(
  `own arrayAction contains GET https://order.example.com/first then success write "first", followed by GET https://order.example.com/second then success write previous+"->second"; invocation uses ${dispatch === "trigger" ? '{trigger:"arrayAction"}' : '{$lambda options {name:"arrayAction"}}'}`,
  "await the named array dispatch",
  'two fetches occur; log equals ["first-request-start","first-request-resolved","first-write","second-request-start","second-request-resolved","second-write-after-first"] and final value is "first->second"',
));

const componentSetups = {
  dual: 'HTML component owns text "<p>inline</p>" and URL "https://example.com/ignored.html"',
  whitespace: 'HTML component owns text " \\t\\n"',
  "empty-text-url": 'HTML component owns empty text and URL "https://example.com/fallback.html"',
  coercion: "HTML component owns object-valued text and URL with observable toString spies",
  "inherited-only": 'HTML component inherits text "<p>inherited</p>" and URL "https://example.com/inherited.html" and owns neither source',
  "inherited-text-own-url": 'HTML component inherits text and owns URL "https://example.com/own.html"',
  "inherited-url-own-text": 'HTML component inherits URL and owns text "<p>own</p>"',
  missing: "HTML component owns neither text nor URL",
  invalid: 'HTML component owns text "<p><b>unterminated & raw"',
};
const sourceExpected = (source, expected, kind = "") => source === "none"
  ? `no iframe and no observer trace${kind === "coercion" ? "; toString call counts are zero" : ""}`
  : `one iframe has sandbox="allow-scripts", only ${source}="${expected}", and events [CREATE(component), SANDBOX("allow-scripts"), SOURCE("${source}"), APPEND, RETURN]`; 
add(COMPONENT_SOURCE_CASES, ({ kind, source, expected }) => c(componentSetups[kind], "render the component through the public component API", sourceExpected(source, expected, kind)));
add(CSS_CASES, ({ kind, css, expected }) => c(
  `HTML component text is "<p>x</p>" and CSS is ${kind === "absent" ? "absent" : kind === "inherited" ? "inherited p{color:inherited}" : kind === "coercion" ? "an object with an observable toString" : q(css)}`,
  "render the component through the public component API",
  `iframe srcdoc and srcdoc attribute equal "${expected}"${kind === "coercion" ? " and toString call count is zero" : ""}${kind === "mixed" || kind === "repeated" ? " with escape code point U+005C" : ""}`, 
));
add(COMPONENT_TYPE_CASES, ({ kind, outcome }) => c(
  `${kind === "missing" ? "component has no type and text \"fallback label\"" : kind === "inherited-html" ? "component inherits type \"html\" and owns text \"fallback label\"" : kind === "non-string" ? "component owns numeric type 9 and text \"fallback label\"" : `component owns type ${q(kind)} and text "visible value"`}`,
  "render the component through the public component API",
  outcome === "unknown" ? `no throw, iframe, or trace; a non-empty visible fallback is returned and data-jasonette-type is ${q(kind)}` : `no throw, iframe, or trace; visible text is ${kind === "label" ? '"visible value"' : '"fallback label"'}`,
));
add(INHERITED_COMPONENT_CALLABLE_CASES, ({ name }) => c(
  `Object.prototype[${q(name)}] is an observable iframe-producing callable and component owns type ${q(name)}`,
  "render the component through the public component API",
  `call count is zero, no iframe or trace exists, a non-empty visible fallback is returned, and data-jasonette-type is ${q(name)}`,
));
const transformRenderSetups = {
  "all-inherited": 'HTML object owns only type="html" and inherits text="<p>bad</p>", URL="https://example.com/bad", and CSS="bad{}"',
  "inherited-text": 'HTML object owns type="html" and URL="https://example.com/transformed-own.html" but inherits text="<p>bad</p>"',
  "inherited-url": 'HTML object owns type="html" and text="<p>transformed own</p>" but inherits URL="https://example.com/bad"',
  "inherited-css": 'HTML object owns type="html" and text="<p>transformed cssless</p>" but inherits CSS="bad{}"',
};
add(TRANSFORM_RENDER_INHERITANCE_CASES, ({ kind, source, expected }) => c(
  transformRenderSetups[kind],
  "body-transform the authored object then render the component",
  sourceExpected(source, expected),
));

const backgroundOutcome = (source, expected, extra = "") => `one root-child iframe whose class list contains "jasonette-background-web" and aria-hidden="true" precedes foreground, has sandbox="allow-scripts", only ${source}="${expected}", and events [CREATE(background), SANDBOX("allow-scripts"), SOURCE("${source}"), APPEND, RETURN]${extra}`;
const staticBackgroundContracts = {
  "static-canonical": c('body.background is {type:"html", text:"<p>static</p>", css:"p{color:red}"}', "render the static document", backgroundOutcome("srcdoc", "<style>p{color:red}</style><p>static</p>")),
  "static-legacy": c('body.style.background is {type:"html", url:"https://example.com/bg.html"}', "render the static document", backgroundOutcome("src", "https://example.com/bg.html")),
  "template-canonical": c('templated body.background has raw text "<p>{{$jason.secret}}</p>", CSS "p{color:{{$jason.color}}}", and context secret="LEAK", color="red"', "render the templated document", backgroundOutcome("srcdoc", "<style>p{color:red}</style><p>{{$jason.secret}}</p>")),
  "template-legacy": c('templated body.style.background URL is "{{$jason.url}}" and context URL is "https://example.com/dynamic.html"', "render the templated document", backgroundOutcome("src", "https://example.com/dynamic.html")),
  "no-source": c('body.background is {type:"html"} with no text or URL', "render the static document", "no iframe and no observer trace"),
};
add(STATIC_BACKGROUND_CASES, ({ vector }) => staticBackgroundContracts[vector]);
const precedenceSetups = {
  "false-canonical": 'body owns background=false and style.background={type:"html", text:"<p>legacy fallback</p>"}',
  "malformed-canonical": 'body owns background={type:"label", text:"bad"} and style.background={type:"html", text:"<p>legacy fallback</p>"}',
  "source-less-canonical": 'body owns background={type:"html"} and style.background={type:"html", text:"<p>legacy fallback</p>"}',
  "null-canonical": 'body owns background=null and style.background={type:"html", text:"<p>legacy fallback</p>"}',
  "undefined-canonical": 'body owns background=undefined and style.background={type:"html", text:"<p>legacy fallback</p>"}',
  "inherited-canonical": 'body inherits background={type:"html", text:"bad"} and owns style.background={type:"html", text:"<p>legacy fallback</p>"}',
  "inherited-style": 'body inherits style.background={type:"html", text:"<p>legacy fallback</p>"} and owns no background or style',
  "inherited-legacy": 'body owns style that inherits background={type:"html", text:"<p>legacy fallback</p>"} and owns no canonical background',
  "inherited-canonical-none": 'body inherits background={type:"html", text:"bad"} and has no legacy fallback',
  missing: "body owns neither canonical background nor legacy style.background",
};
add(BACKGROUND_PRECEDENCE_CASES, ({ kind, expected }) => c(
  precedenceSetups[kind],
  "render the selected background",
  expected === "legacy" ? backgroundOutcome("srcdoc", "<p>legacy fallback</p>") : "no background iframe and no observer trace",
));
const backgroundSetups = {
  inline: 'type "html" and own text "<p>inline</p>"', URL: 'type "html" and own URL "https://example.com/background.html"',
  "dual source text precedence": 'type "html", own text "<p>dual</p>", and own URL "https://example.com/ignored.html"',
  "whitespace inline source": 'type "html" and own text " \\t\\n"',
  "empty own text with valid URL fallback": 'type "html", own text "", and own URL "https://example.com/empty-text-fallback.html"',
  "non-string own text with valid URL fallback": 'type "html", own object-valued text with observable toString, and own URL "https://example.com/non-string-text-fallback.html"',
  "invalid inline HTML exact preservation": 'type "html" and own text "<p><b>unterminated & raw"',
  "empty sources": 'type "html", own text "", and own URL ""',
  "non-string coercion sentinels": 'type "html" with object-valued text, URL, and CSS observable toString sentinels',
  "empty CSS": 'type "html", text "<p>css</p>", CSS ""', "null CSS": 'type "html", text "<p>css</p>", CSS null',
  "undefined CSS": 'type "html", text "<p>css</p>", CSS undefined', "non-string CSS coercion sentinel": 'type "html", text "<p>css</p>", object-valued CSS with observable toString',
  "one-space CSS": 'type "html", text "<p>css</p>", CSS " "', "tab-newline CSS": 'type "html", text "<p>css</p>", CSS "\\t\\n"',
  "mixed-case CSS escape": 'type "html", text "<p>css</p>", CSS "</STYLE>"', "repeated mixed-case CSS escape": 'type "html", text "<p>css</p>", CSS "a</style>b</StYlE>c"',
  "inherited-only source fields": 'own type "html" with inherited text, URL, and CSS only', "inherited text with own URL": 'own type "html" and URL "https://example.com/own-background.html" with inherited text',
  "inherited URL with own text": 'own type "html" and text "<p>own background</p>" with inherited URL', "inherited CSS with own text": 'own type "html" and text "<p>own cssless</p>" with inherited CSS',
  "missing type": 'own text "<p>bad</p>" with no type', "inherited HTML type": 'inherited type "html" and own text "<p>bad</p>"',
  "non-string type": 'own numeric type 5 and text "<p>bad</p>"', "non-HTML type": 'own type "label" and text "<p>bad</p>"',
  "__proto__ type collision": 'inert own type "__proto__" and text "<p>bad</p>"', "constructor type collision": 'own type "constructor" and text "<p>bad</p>"',
  "prototype type collision": 'own type "prototype" and text "<p>bad</p>"', "toString type collision": 'own type "toString" and text "<p>bad</p>"',
  "HTML type without source": 'own type "html" with no text or URL',
};
add(BACKGROUND_MATRIX_CASES, ({ path, id, source, expected }) => c(
  `${path === "canonical" ? "body.background" : "body.style.background"} has ${backgroundSetups[id]}`,
  `render the ${path} background path`,
  source === "none" ? `no background iframe and no observer trace${id.includes("coercion") ? "; all toString call counts are zero" : ""}` : backgroundOutcome(source, expected, `${id.includes("CSS escape") ? ", and the first escape is code point U+005C" : ""}${id.includes("coercion") ? "; all toString call counts are zero" : ""}${id === "non-string own text with valid URL fallback" ? "; text toString call count is zero" : ""}`), 
));

add(INSERTION_OBSERVER_CASES, ({ route }) => c(
  `a tracked unsandboxed iframe and insertion route ${q(route)}`,
  `insert the iframe using ${route}`,
  'the sole trace is ["CREATE(self-test)","APPEND"] and safety assertion throws "source/insertion occurred before exact sandbox"',
));
const sandboxNull = new Set(["removeAttribute", "removeAttributeNS", "removeAttributeNode", "NamedNodeMap removeNamedItem", "NamedNodeMap removeNamedItemNS"]);
const sandboxEmpty = new Set(["toggleAttribute", "sandbox remove"]);
const sandboxMutationDetails = {
  setAttribute: 'setAttribute("sandbox","allow-scripts")', setAttributeNS: 'setAttributeNS(null,"sandbox","allow-scripts")',
  removeAttribute: 'prepare sandbox="allow-scripts", reset events, then removeAttribute("sandbox")', removeAttributeNS: 'prepare sandbox="allow-scripts", reset events, then removeAttributeNS(null,"sandbox")',
  toggleAttribute: 'toggleAttribute("sandbox",true)', setAttributeNode: 'setAttributeNode of sandbox="allow-scripts"', setAttributeNodeNS: 'setAttributeNodeNS of sandbox="allow-scripts"',
  removeAttributeNode: 'prepare sandbox="allow-scripts", reset events, then removeAttributeNode', "NamedNodeMap setNamedItem": 'attributes.setNamedItem sandbox="allow-scripts"',
  "NamedNodeMap setNamedItemNS": 'attributes.setNamedItemNS sandbox="allow-scripts"', "NamedNodeMap removeNamedItem": 'prepare sandbox="allow-scripts", reset events, then attributes.removeNamedItem',
  "NamedNodeMap removeNamedItemNS": 'prepare sandbox="allow-scripts", reset events, then attributes.removeNamedItemNS', "Attr value": 'change prepared sandbox Attr from "allow-forms" to "allow-scripts" after reset',
  "Attr nodeValue": 'change prepared sandbox Attr.nodeValue from "allow-forms" to "allow-scripts" after reset', "Attr textContent": 'change prepared sandbox Attr.textContent from "allow-forms" to "allow-scripts" after reset',
  "sandbox value": 'set sandbox.value="allow-scripts"', "sandbox add": 'sandbox.add("allow-scripts")', "sandbox remove": 'add allow-scripts, reset events, then sandbox.remove("allow-scripts")',
  "sandbox toggle": 'sandbox.toggle("allow-scripts")', "sandbox replace": 'add allow-forms, reset events, then sandbox.replace("allow-forms","allow-scripts")',
};
add(SANDBOX_OBSERVER_CASES, ({ route }) => c(
  `a tracked iframe prepared for ${sandboxMutationDetails[route]}`,
  `apply ${sandboxMutationDetails[route]}`,
  `the sole post-reset event is SANDBOX(${sandboxNull.has(route) ? "null" : sandboxEmpty.has(route) ? '\"\"' : '\"allow-scripts\"'})`,
));
const sourceMutationDetails = {
  "src property": 'set src="https://example.com/a"', "srcdoc property": 'set srcdoc="<p>a</p>"', "setAttribute src": 'setAttribute src="https://example.com/a"',
  "setAttribute srcdoc": 'setAttribute srcdoc="<p>a</p>"', "setAttributeNS src": 'setAttributeNS src="https://example.com/a"', "removeAttribute src": 'prepare src="https://example.com/a", reset, then remove it',
  "removeAttributeNS srcdoc": 'prepare srcdoc="<p>a</p>", reset, then remove it with namespace null', "toggleAttribute srcdoc": 'toggleAttribute("srcdoc",true)',
  "setAttributeNode srcdoc": 'setAttributeNode srcdoc="<p>a</p>"', "setAttributeNodeNS src": 'setAttributeNodeNS src="https://example.com/a"',
  "removeAttributeNode srcdoc": 'prepare srcdoc="<p>a</p>", reset, then remove its Attr', "NamedNodeMap setNamedItem src": 'attributes.setNamedItem src="https://example.com/a"',
  "NamedNodeMap setNamedItemNS srcdoc": 'attributes.setNamedItemNS srcdoc="<p>a</p>"', "NamedNodeMap removeNamedItem src": 'prepare src="https://example.com/a", reset, then removeNamedItem',
  "NamedNodeMap removeNamedItemNS srcdoc": 'prepare srcdoc="<p>a</p>", reset, then removeNamedItemNS', "Attr value srcdoc": 'change srcdoc Attr.value from "<p>before</p>" to "<p>after</p>" after reset',
  "Attr nodeValue src": 'change src Attr.nodeValue from "https://example.com/before" to "https://example.com/after" after reset', "Attr textContent srcdoc": 'change srcdoc Attr.textContent from "<p>before</p>" to "<p>after</p>" after reset',
};
add(SOURCE_OBSERVER_CASES, ({ route }) => {
  const name = route.includes("srcdoc") ? "srcdoc" : "src";
  return c(
    `a tracked unsandboxed iframe prepared to ${sourceMutationDetails[route]}`,
    `apply mutation: ${sourceMutationDetails[route]}`,
    `the sole post-reset event is SOURCE("${name}") and safety assertion throws "source/insertion occurred before exact sandbox"`,
  );
});
const creationSetups = {
  createElementNS: 'observer kind "self-test" and XHTML namespace createElementNS("iframe")',
  "source-first innerHTML": 'observer kind "self-test" and parser markup <iframe srcdoc="<p>a</p>" sandbox="allow-scripts"></iframe>',
};
add(OBSERVER_CREATION_CASES, ({ route, unsafe }) => c(
  creationSetups[route] ?? `observer kind "self-test", route ${q(route)}, and markup <iframe sandbox="allow-scripts" srcdoc="<p>a</p>"></iframe>`,
  `create an iframe using ${route}`,
  route === "createElementNS" ? 'one trace equals [CREATE(self-test)] and passes the no-source-before-sandbox assertion' : unsafe
    ? 'one trace equals [CREATE(self-test), SOURCE("srcdoc"), SANDBOX("allow-scripts"), APPEND] and safety assertion throws "source/insertion occurred before exact sandbox"'
    : 'one trace equals [CREATE(self-test), SANDBOX("allow-scripts"), SOURCE("srcdoc"), APPEND] and passes the safety assertion',
));

const literalContracts = {
  "production $set action options use generic interpolation at action time": c('state plus $set options probe {type:"html", text:"{{$jason.value}}"} and context value "ACTION"', "execute the $set action", 'local.probe.text equals "ACTION"'),
  "an embedded raw body action interpolates when its separate action phase executes": c('embedded $set options probe {type:"html", text:"{{$jason.value}}"} and action context value "LATER"', "execute the separately phased action", 'local.probe equals {type:"html", text:"LATER"}'),
  "controlled success continuation transforms HTML-shaped options generically in key/value order": c('state.actions owns redControlledSuccess as a network action whose mocked JSON handler returns controlled destinationKey, typeKey, kind, textKey, secret, heightKey, and height getters; its success is an HTML-shaped $set continuation', "trigger the test-registered redControlledSuccess action", 'fetch occurs once; getter order is ["destinationKey","typeKey","kind","textKey","secret","heightKey","height"]; continuation probe is {type:"html", text:"<p>CONTINUED</p>", style:{height:12}}'),
  "safe state sinks accept a null-prototype options object": c('null-prototype $set options with nullPrototypeProbe="supported"', "execute the $set action", 'local.nullPrototypeProbe is "supported" and local has Object.prototype'),
  "session storage safely copies dangerous option keys into a fresh ordinary object": c('session options domain="safe.example.com", header X-Probe="stored", own __proto__="proto-data", constructor="constructor-data", and prototype="prototype-data"', "execute $session.set", 'stored session differs from options; dangerous own descriptors retain their values with enumerable, writable, configurable all true; sessions has Object.prototype'),
  "session storage accepts null-prototype transformed options": c('null-prototype session options domain="null-options.example.com" and header X-Null="accepted"', "execute $session.set", 'stored header equals {"X-Null":"accepted"} and stored session has Object.prototype'),
  "own session decorates a request through a concrete Headers instance": c('own api.example.com session header X-Session="own-value" and request header X-Request="request-value"', "execute GET https://api.example.com/resource", 'fetch occurs once; RequestInit.headers is Headers with X-Session="own-value" and X-Request="request-value"'),
  "inherited session domain cannot decorate request headers or body": c('inherited api.example.com session has forbidden header and body sentinels; own POST has X-Own-Request="kept-exactly" and data {own:"kept"}', "execute POST https://api.example.com/resource", 'fetch occurs once; own header remains, inherited header is absent, and the existing request body contains the own data marker "kept" but neither "inheritedBodySentinel" nor "must-not-appear"'),
  "inherited action type plus own trigger falls through to the own named action": c('action inherits type "redInheritedAction" and owns trigger "runOwnTrigger" naming $set triggerFallback="called"', "execute the action", 'inherited handler call count is zero and local.triggerFallback equals "called"'),
  "background RETURN is captured at the runtime-wrapped renderBodyBackground method boundary": c('canonical background {type:"html", text:"<p>boundary</p>"} with runtime-wrapped background boundary', "render the document", 'the background trace ends in RETURN and equals CREATE, SANDBOX("allow-scripts"), SOURCE("srcdoc"), APPEND, RETURN'),
  "malformed selected background never creates a transient iframe": c('canonical background {type:"html", text:17, url:{href:"bad"}}', "render the selected background", "no iframe and no observer trace exist at any observed point"),
  "component inline iframe trace installs sandbox before source insertion and return": c('component {type:"html", text:"<p>inline</p>"}', "render through the directly observed component boundary", 'iframe has sandbox="allow-scripts", only srcdoc="<p>inline</p>", and trace CREATE, SANDBOX, SOURCE, APPEND, RETURN'),
  "component URL iframe trace installs sandbox before source insertion and return": c('component {type:"html", url:"https://example.com/page.html"}', "render through the directly observed component boundary", 'iframe has sandbox="allow-scripts", only src="https://example.com/page.html", and trace CREATE, SANDBOX, SOURCE, APPEND, RETURN'),
  "component wrapper return topology and legacy class size border contract remain exact": c('component {type:"html", text:"<p>x</p>"}', "render through the directly observed component boundary", 'detached wrapper class list contains "jasonette-html", data type is "html", iframe parent is wrapper, width is "100%", CSSOM borderStyle is "none", and events are [CREATE(component), SANDBOX("allow-scripts"), SOURCE("srcdoc"), APPEND, RETURN]'),
  "component registry never invokes an inherited callable renderer": c('Object.prototype.redInheritedComponent is an observable iframe renderer and component owns that type', "render the component", 'call count is zero; no iframe or trace; a non-empty visible fallback is returned and data type is "redInheritedComponent"'),
  "integration smoke: initial render actual $render generic action and all iframe traces stay live": c('HTML template raw script with secret "LEAK", height 40, label "first"; then $render data secret "SECOND", height 80, label "second"; then generic transform and $set contexts', "render initially, execute actual $render, generic transform, and $set", 'first then replacement iframes retain raw {{$jason.secret}}, heights are 40px then 80px, labels first then second, old iframe disconnects, both sandbox endpoints remain, each trace is [CREATE(component), SANDBOX("allow-scripts"), SOURCE("srcdoc"), APPEND, RETURN] with RETURN from wrapper data-jasonette-type="html" completion and no later iframe event through the containing public render/action return, generic text is GENERIC, and $set text is ACTION'),
  "Jasonpedia fixture renders actual iframe srcdoc with authored CSS and Nexus content": c("the public fixture support/fixtures/jasonpedia-html-index.json", "render the fixture through the public renderer API", 'actual iframe srcdoc contains "img{width: 100%;}" and "Nexus devices", sandbox is "allow-scripts", and events are [CREATE(component), SANDBOX("allow-scripts"), SOURCE("srcdoc"), APPEND, RETURN] with RETURN from wrapper data-jasonette-type="html" completion and no later iframe event through public render return' ),
  "rendered HTML keeps authored script and CSS while an ordinary sibling interpolates": c('background and component HTML contain {{$jason.secret}}, CSS uses color red and height 7, and label context is "ordinary"', "render the templated document", 'background srcdoc is "<style>body{color:red}</style><script>window.raw=\'{{$jason.secret}}\'</script>", component srcdoc is "<style>p{height:7px}</style><p>{{$jason.secret}}</p>", label is "ordinary"; background events are [CREATE(background), SANDBOX("allow-scripts"), SOURCE("srcdoc"), APPEND, RETURN] and component events are [CREATE(component), SANDBOX("allow-scripts"), SOURCE("srcdoc"), APPEND, RETURN] with RETURN from wrapper data-jasonette-type="html" completion and no later iframe event through public render return' ),
  "actual $render replaces a background iframe while old and new sandbox endpoints remain exact": c('templated background URL starts "https://example.com/first-background.html" and $render data changes it to "https://example.com/second-background.html"', "render initially then execute actual $render", 'new iframe differs from disconnected old iframe, both retain sandbox="allow-scripts", new iframe has only src="https://example.com/second-background.html", and each trace is [CREATE(background), SANDBOX("allow-scripts"), SOURCE("src"), APPEND, RETURN]'),
  "emitted iframe policy is exact and makes no browser-enforcement assertion": c('HTML integration component with context kind="html", secret="LEAK", height=40, label="first"', "render the document under the finite observer", 'emitted sandbox tokens equal only ["allow-scripts"] and events are [CREATE(component), SANDBOX("allow-scripts"), SOURCE("srcdoc"), APPEND, RETURN] with RETURN from wrapper data-jasonette-type="html" completion and no later iframe event through public render return; no browser-enforcement outcome is asserted' ),
  "component RETURN observer self-test marks only after direct renderComponent returns": c('direct component {type:"html", text:"<p>timing</p>"} and a markComponentReturn interception', "render through the direct component boundary", 'before the one return mark events are [CREATE(component), SANDBOX("allow-scripts"), SOURCE("srcdoc"), APPEND]; afterward events are [CREATE(component), SANDBOX("allow-scripts"), SOURCE("srcdoc"), APPEND, RETURN]'),
  "integrated component marker completes before public return and later iframe events are rejected": c('integrated wrapper iframe receives sandbox, source, append, data-jasonette-type="html", then a later source mutation before the containing public return', "run the containing integrated component boundary", 'trace equals [CREATE(component), SANDBOX("allow-scripts"), SOURCE("srcdoc"), APPEND, RETURN, SOURCE("srcdoc")] and the boundary rejects "iframe event occurred after integrated component completion"'),
  "public RenderOptions type accepts preserveHtmlText": c("public RenderOptions assignments with preserveHtmlText false and true", "typecheck and read both assigned properties", "values are exactly false and true without suppression"),
  "protected raw string output is strictly equal to its input": c('HTML text code units equal <script>window.x = "{{secret}}"</script> with secret "LEAK" in body mode', "transform the HTML shape", "output text is strictly equal to the authored string"),
  "protected raw object output retains the identical reference without recursion": c('HTML text is an object {nested:"{{secret}}"} with an observable probe getter in body mode', "transform the HTML shape", "output text is the identical object reference and probe getter call count is zero"),
  "duplicate raw text entries are never evaluated and the last authored value wins": c('body-mode HTML has resolved text "{{first}}" then authored text "{{second}}" with observable first and second getters', "transform the duplicate text entries", 'output text equals "{{second}}" and both getter call counts are zero'),
  "embedded body action options are raw immediately after body transformation": c('embedded $set option probe {type:"html", text:"{{secret}}"} with secret "BODY" and body mode', "render the embedded action shape", 'result.options.probe.text equals "{{secret}}"'),
  "standalone transform with an unrelated option remains generic": c('HTML text "{{secret}}", secret "GENERIC", and only unrelated option preserveFalsy=true', "transform through the standalone public API", 'output text equals "GENERIC"'),
  "body mode resolves all flat keys before type and ordinary value expressions exactly once": c("three resolved keys and context getters keyA, typeKey, keyB, kind, valueA, valueB in body mode", "transform while logging getter access", 'log equals ["keyA","typeKey","keyB","kind","valueA","valueB"] and every getter count is one'),
  "body mode applies all-keys-first ordering independently in each nested frame": c("resolved outer child and tail keys plus resolved inner value and type keys in body mode", "transform while logging nested getter access", 'log equals ["outerKey","tailKey","innerKey","innerTypeKey","innerKind","innerValue","tailValue"]'),
  "off mode preserves per-entry key-then-value getter ordering": c("three resolved entries with key and value getters and options omitted", "transform while logging getter access", 'log equals ["keyA","valueA","typeKey","kind","keyB","valueB"]'),
  "explicit false option preserves per-entry key-then-value getter ordering": c("three resolved entries with context kind html and preserveHtmlText=false", "transform while logging getter access", 'log equals ["keyA","valueA","typeKey","kind","keyB","valueB"] and output equals {alpha:"A", type:"html", omega:"B"}'),
  "numeric own keys transform in ECMAScript order 1 then 2 then alpha": c('input insertion order is numeric "2", numeric "1", then alpha with observable value getters', "transform in body mode", 'getter log equals ["one","two","alpha"]'),
  "transformation enumerates only own enumerable string keys": c('input inherits enumerable inherited, owns enumerable visible, owns non-enumerable hidden, and owns a Symbol key', 'transform with secret "VALUE" in body mode', 'output equals {visible:"VALUE"} and has Object.prototype'),
  "unresolved expression output remains the exact authored string": c('authored string "prefix {{missing.deep.value}} suffix" and empty context', "transform with generic options", 'output strictly equals "prefix {{missing.deep.value}} suffix"'),
};
Object.assign(contracts, literalContracts);
export const GHERKIN_CONTRACTS = Object.freeze(contracts);
