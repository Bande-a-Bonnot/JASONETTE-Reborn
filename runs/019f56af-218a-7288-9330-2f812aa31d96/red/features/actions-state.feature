Feature: Action dispatch and safe state boundaries
  Public-package black-box evidence only; no browser-enforcement claim is made.

  Scenario Outline: <title>
    Given <setup>
    When <action>
    Then <expected>

    Examples: concrete sink_cases vectors
      | title | setup | action | expected |
      | safe state sink: $set retains dangerous own descriptors | "$set" options own __proto__="proto-data", constructor="constructor-data", and prototype="prototype-data" | execute "$set" through the public action API | "local" has Object.prototype and own descriptors __proto__={value:"proto-data", enumerable:true, writable:true, configurable:true}, constructor={value:"constructor-data", enumerable:true, writable:true, configurable:true}, and prototype={value:"prototype-data", enumerable:true, writable:true, configurable:true} |
      | safe state sink: $cache.set retains dangerous own descriptors | "$cache.set" options own __proto__="proto-data", constructor="constructor-data", and prototype="prototype-data" | execute "$cache.set" through the public action API | "cache" has Object.prototype and own descriptors __proto__={value:"proto-data", enumerable:true, writable:true, configurable:true}, constructor={value:"constructor-data", enumerable:true, writable:true, configurable:true}, and prototype={value:"prototype-data", enumerable:true, writable:true, configurable:true} |
      | safe state sink: $global.set retains dangerous own descriptors | "$global.set" options own __proto__="proto-data", constructor="constructor-data", and prototype="prototype-data" | execute "$global.set" through the public action API | "global" has Object.prototype and own descriptors __proto__={value:"proto-data", enumerable:true, writable:true, configurable:true}, constructor={value:"constructor-data", enumerable:true, writable:true, configurable:true}, and prototype={value:"prototype-data", enumerable:true, writable:true, configurable:true} |

  Scenario Outline: <title>
    Given <setup>
    When <action>
    Then <expected>

    Examples: concrete session_domain_cases vectors
      | title | setup | action | expected |
      | session registry: reachable __proto__ domain is an inert own property | $session.set options {domain:"__proto__", marker:"stored-__proto__"} | execute the session action through the public action API | sessions and sessions["__proto__"] have Object.prototype; sessions owns descriptor "__proto__" with enumerable, writable, configurable all true; stored marker equals "stored-__proto__" |
      | session registry: reachable constructor domain is an inert own property | $session.set options {domain:"constructor", marker:"stored-constructor"} | execute the session action through the public action API | sessions and sessions["constructor"] have Object.prototype; sessions owns descriptor "constructor" with enumerable, writable, configurable all true; stored marker equals "stored-constructor" |
      | session registry: reachable prototype domain is an inert own property | $session.set options {domain:"prototype", marker:"stored-prototype"} | execute the session action through the public action API | sessions and sessions["prototype"] have Object.prototype; sessions owns descriptor "prototype" with enumerable, writable, configurable all true; stored marker equals "stored-prototype" |

  Scenario Outline: <title>
    Given <setup>
    When <action>
    Then <expected>

    Examples: concrete action_type_cases vectors
      | title | setup | action | expected |
      | action type: missing type with no trigger returns undefined | a missing own type with success {$set continuationWasCalled:true} and no own trigger | execute the action through the public action API | result is undefined, inherited handler calls are zero, and continuationWasCalled is not true |
      | action type: inherited handler type is ignored | an inherited redInheritedAction type with success {$set continuationWasCalled:true} and no own trigger | execute the action through the public action API | result is undefined, inherited handler calls are zero, and continuationWasCalled is not true |
      | action type: non-string type returns undefined | own numeric type 7 with success {$set continuationWasCalled:true} and no own trigger | execute the action through the public action API | result is undefined, inherited handler calls are zero, and continuationWasCalled is not true |
      | action type: own unknown non-HTML type returns undefined | own type "redUnknownAction" with success {$set continuationWasCalled:true} and no own trigger | execute the action through the public action API | result is undefined, inherited handler calls are zero, and continuationWasCalled is not true |
      | action type: own custom type with only an inherited callable returns undefined | own type "redInheritedOnlyAction" and Object.prototype["redInheritedOnlyAction"] is a same-key observable inherited callable with success {$set continuationWasCalled:true} and no own trigger | execute the action through the public action API | result is undefined, inherited "redInheritedOnlyAction" callable calls are zero, and continuationWasCalled is not true |
      | action type: own __proto__ type returns undefined without continuation | own type "__proto__" and Object.prototype["__proto__"] is a same-key observable inherited callable with success {$set continuationWasCalled:true} and no own trigger | execute the action through the public action API | result is undefined, inherited "__proto__" callable calls are zero, and continuationWasCalled is not true |
      | action type: own constructor type returns undefined without continuation | own type "constructor" and Object.prototype["constructor"] is a same-key observable inherited callable with success {$set continuationWasCalled:true} and no own trigger | execute the action through the public action API | result is undefined, inherited "constructor" callable calls are zero, and continuationWasCalled is not true |
      | action type: own prototype type returns undefined without continuation | own type "prototype" and Object.prototype["prototype"] is a same-key observable inherited callable with success {$set continuationWasCalled:true} and no own trigger | execute the action through the public action API | result is undefined, inherited "prototype" callable calls are zero, and continuationWasCalled is not true |
      | action type: own toString type returns undefined without continuation | own type "toString" and Object.prototype["toString"] is a same-key observable inherited callable with success {$set continuationWasCalled:true} and no own trigger | execute the action through the public action API | result is undefined, inherited "toString" callable calls are zero, and continuationWasCalled is not true |

  Scenario Outline: <title>
    Given <setup>
    When <action>
    Then <expected>

    Examples: concrete non_string_own_trigger_cases vectors
      | title | setup | action | expected |
      | non-string action type with own toString trigger executes | action has own numeric type 17 and trigger "toString"; state.actions owns "toString"={$set options {nonStringTriggerResult:"toString"}} | execute the action through the public action API | local.nonStringTriggerResult equals "toString" |
      | non-string action type with own constructor trigger executes | action has own numeric type 17 and trigger "constructor"; state.actions owns "constructor"={$set options {nonStringTriggerResult:"constructor"}} | execute the action through the public action API | local.nonStringTriggerResult equals "constructor" |
      | non-string action type with own __proto__ trigger executes | action has own numeric type 17 and trigger "__proto__"; state.actions owns "__proto__"={$set options {nonStringTriggerResult:"__proto__"}} | execute the action through the public action API | local.nonStringTriggerResult equals "__proto__" |
      | non-string action type with own prototype trigger executes | action has own numeric type 17 and trigger "prototype"; state.actions owns "prototype"={$set options {nonStringTriggerResult:"prototype"}} | execute the action through the public action API | local.nonStringTriggerResult equals "prototype" |

  Scenario Outline: <title>
    Given <setup>
    When <action>
    Then <expected>

    Examples: concrete inherited_trigger_cases vectors
      | title | setup | action | expected |
      | inherited toString trigger is ignored | action inherits trigger "toString"; state.actions owns "toString"={$set options {inheritedTriggerRan:"toString"}} | execute the action through the public action API | result and local.inheritedTriggerRan are both undefined |
      | inherited constructor trigger is ignored | action inherits trigger "constructor"; state.actions owns "constructor"={$set options {inheritedTriggerRan:"constructor"}} | execute the action through the public action API | result and local.inheritedTriggerRan are both undefined |
      | inherited __proto__ trigger is ignored | action inherits trigger "__proto__"; state.actions owns "__proto__"={$set options {inheritedTriggerRan:"__proto__"}} | execute the action through the public action API | result and local.inheritedTriggerRan are both undefined |
      | inherited prototype trigger is ignored | action inherits trigger "prototype"; state.actions owns "prototype"={$set options {inheritedTriggerRan:"prototype"}} | execute the action through the public action API | result and local.inheritedTriggerRan are both undefined |

  Scenario Outline: <title>
    Given <setup>
    When <action>
    Then <expected>

    Examples: concrete named_action_cases vectors
      | title | setup | action | expected |
      | named trigger: own toString entry executes | state.actions owns "toString"={$set options {namedDispatchResult:"trigger-toString"}} and action is {trigger:"toString"} | dispatch the named action through trigger | local.namedDispatchResult equals "trigger-toString" and inherited handler calls are zero |
      | named trigger: inherited toString entry is ignored | state.actions inherits "toString"={type:"redInheritedNamed"} and action is {trigger:"toString"} | dispatch the named action through trigger | result and local.namedDispatchResult are undefined and inherited handler calls are zero |
      | named lambda: own toString entry executes | state.actions owns "toString"={$set options {namedDispatchResult:"lambda-toString"}} and action is {$lambda options {name:"toString"}} | dispatch the named action through lambda | local.namedDispatchResult equals "lambda-toString" and inherited handler calls are zero |
      | named lambda: inherited toString entry is ignored | state.actions inherits "toString"={type:"redInheritedNamed"} and action is {$lambda options {name:"toString"}} | dispatch the named action through lambda | result and local.namedDispatchResult are undefined and inherited handler calls are zero |
      | named trigger: own constructor entry executes | state.actions owns "constructor"={$set options {namedDispatchResult:"trigger-constructor"}} and action is {trigger:"constructor"} | dispatch the named action through trigger | local.namedDispatchResult equals "trigger-constructor" and inherited handler calls are zero |
      | named trigger: inherited constructor entry is ignored | state.actions inherits "constructor"={type:"redInheritedNamed"} and action is {trigger:"constructor"} | dispatch the named action through trigger | result and local.namedDispatchResult are undefined and inherited handler calls are zero |
      | named lambda: own constructor entry executes | state.actions owns "constructor"={$set options {namedDispatchResult:"lambda-constructor"}} and action is {$lambda options {name:"constructor"}} | dispatch the named action through lambda | local.namedDispatchResult equals "lambda-constructor" and inherited handler calls are zero |
      | named lambda: inherited constructor entry is ignored | state.actions inherits "constructor"={type:"redInheritedNamed"} and action is {$lambda options {name:"constructor"}} | dispatch the named action through lambda | result and local.namedDispatchResult are undefined and inherited handler calls are zero |
      | named trigger: own __proto__ entry executes | state.actions owns "__proto__"={$set options {namedDispatchResult:"trigger-__proto__"}} and action is {trigger:"__proto__"} | dispatch the named action through trigger | local.namedDispatchResult equals "trigger-__proto__" and inherited handler calls are zero |
      | named trigger: inherited __proto__ entry is ignored | state.actions inherits "__proto__"={type:"redInheritedNamed"} and action is {trigger:"__proto__"} | dispatch the named action through trigger | result and local.namedDispatchResult are undefined and inherited handler calls are zero |
      | named lambda: own __proto__ entry executes | state.actions owns "__proto__"={$set options {namedDispatchResult:"lambda-__proto__"}} and action is {$lambda options {name:"__proto__"}} | dispatch the named action through lambda | local.namedDispatchResult equals "lambda-__proto__" and inherited handler calls are zero |
      | named lambda: inherited __proto__ entry is ignored | state.actions inherits "__proto__"={type:"redInheritedNamed"} and action is {$lambda options {name:"__proto__"}} | dispatch the named action through lambda | result and local.namedDispatchResult are undefined and inherited handler calls are zero |
      | named trigger: own prototype entry executes | state.actions owns "prototype"={$set options {namedDispatchResult:"trigger-prototype"}} and action is {trigger:"prototype"} | dispatch the named action through trigger | local.namedDispatchResult equals "trigger-prototype" and inherited handler calls are zero |
      | named trigger: inherited prototype entry is ignored | state.actions inherits "prototype"={type:"redInheritedNamed"} and action is {trigger:"prototype"} | dispatch the named action through trigger | result and local.namedDispatchResult are undefined and inherited handler calls are zero |
      | named lambda: own prototype entry executes | state.actions owns "prototype"={$set options {namedDispatchResult:"lambda-prototype"}} and action is {$lambda options {name:"prototype"}} | dispatch the named action through lambda | local.namedDispatchResult equals "lambda-prototype" and inherited handler calls are zero |
      | named lambda: inherited prototype entry is ignored | state.actions inherits "prototype"={type:"redInheritedNamed"} and action is {$lambda options {name:"prototype"}} | dispatch the named action through lambda | result and local.namedDispatchResult are undefined and inherited handler calls are zero |

  Scenario: production $set action options use generic interpolation at action time
    Given state plus $set options probe {type:"html", text:"{{$jason.value}}"} and context value "ACTION"
    When execute the $set action
    Then local.probe.text equals "ACTION"

  Scenario: an embedded raw body action interpolates when its separate action phase executes
    Given embedded $set options probe {type:"html", text:"{{$jason.value}}"}, body context value "BODY", and action context value "LATER"
    When body-transform the action, observe its raw text, then execute that exact transformed action
    Then immediate transformed text equals "{{$jason.value}}" and local.probe equals {type:"html", text:"LATER"}

  Scenario: controlled success continuation transforms HTML-shaped options generically in key/value order
    Given state.actions owns redControlledSuccess as a network action whose mocked JSON handler returns controlled destinationKey, typeKey, kind, textKey, secret, heightKey, and height getters; its success is an HTML-shaped $set continuation
    When trigger the test-registered redControlledSuccess action
    Then fetch occurs once; getter order is ["destinationKey","typeKey","kind","textKey","secret","heightKey","height"]; continuation probe is {type:"html", text:"<p>CONTINUED</p>", style:{height:12}}

  Scenario: safe state sinks accept a null-prototype options object
    Given null-prototype $set options with nullPrototypeProbe="supported"
    When execute the $set action
    Then local.nullPrototypeProbe is "supported" and local has Object.prototype

  Scenario: session storage safely copies dangerous option keys into a fresh ordinary object
    Given session options domain="safe.example.com", header X-Probe="stored", own __proto__="proto-data", constructor="constructor-data", and prototype="prototype-data"
    When execute $session.set
    Then stored session differs from options; dangerous own descriptors retain their values with enumerable, writable, configurable all true; sessions has Object.prototype

  Scenario: session storage accepts null-prototype transformed options
    Given null-prototype session options domain="null-options.example.com" and header X-Null="accepted"
    When execute $session.set
    Then stored header equals {"X-Null":"accepted"} and stored session has Object.prototype

  Scenario: own session decorates a request through a concrete Headers instance
    Given own api.example.com session header X-Session="own-value" and request header X-Request="request-value"
    When execute GET https://api.example.com/resource
    Then fetch occurs once; RequestInit.headers is Headers with X-Session="own-value" and X-Request="request-value"

  Scenario: inherited session domain cannot decorate request headers or body
    Given inherited api.example.com session has forbidden header and body sentinels; own POST has X-Own-Request="kept-exactly" and data {own:"kept"}
    When execute POST https://api.example.com/resource
    Then fetch occurs once; own header remains, inherited header is absent, and the existing request body contains the own data marker "kept" but neither "inheritedBodySentinel" nor "must-not-appear"

  Scenario: inherited action type plus own trigger falls through to the own named action
    Given action inherits type "redInheritedAction" and owns trigger "runOwnTrigger" naming $set triggerFallback="called"
    When execute the action
    Then inherited handler call count is zero and local.triggerFallback equals "called"

  Scenario Outline: <title>
    Given <setup>
    When <action>
    Then <expected>

    Examples: concrete named_action_array_cases vectors
      | title | setup | action | expected |
      | own named action arrays execute every authored entry through trigger | state.actions owns arrayAction with two $set entries producing distinct namedArrayFirstEffect and namedArraySecondEffect values; invocation uses {trigger:"arrayAction"} | dispatch the own named action array | namedArrayFirstEffect equals "first-authored-entry" and namedArraySecondEffect equals "second-authored-entry" |
      | own named action arrays execute every authored entry through lambda | state.actions owns arrayAction with two $set entries producing distinct namedArrayFirstEffect and namedArraySecondEffect values; invocation uses {$lambda options {name:"arrayAction"}} | dispatch the own named action array | namedArrayFirstEffect equals "first-authored-entry" and namedArraySecondEffect equals "second-authored-entry" |

