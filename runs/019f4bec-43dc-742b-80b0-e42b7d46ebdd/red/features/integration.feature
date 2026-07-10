Feature: Initial render and actual render-action integration
  Public-package black-box evidence only; no browser-enforcement claim is made.

  Scenario: integration smoke: initial render actual $render generic action and all iframe traces stay live
    Given HTML template raw script with secret "LEAK", height 40, label "first"; then $render data secret "SECOND", height 80, label "second"; then generic transform and $set contexts
    When render initially, execute actual $render, generic transform, and $set
    Then first then replacement iframes retain raw {{$jason.secret}}, heights are 40px then 80px, labels first then second, old iframe disconnects, both sandbox endpoints remain, each trace is [CREATE(component), SANDBOX("allow-scripts"), SOURCE("srcdoc"), APPEND, RETURN] with RETURN from wrapper data-jasonette-type="html" completion and no later iframe event through the containing public render/action return, generic text is GENERIC, and $set text is ACTION

  Scenario: Jasonpedia fixture renders actual iframe srcdoc with authored CSS and Nexus content
    Given the public fixture support/fixtures/jasonpedia-html-index.json
    When render the fixture through the public renderer API
    Then actual iframe srcdoc contains "img{width: 100%;}" and "Nexus devices", sandbox is "allow-scripts", and events are [CREATE(component), SANDBOX("allow-scripts"), SOURCE("srcdoc"), APPEND, RETURN] with RETURN from wrapper data-jasonette-type="html" completion and no later iframe event through public render return

  Scenario: rendered HTML keeps authored script and CSS while an ordinary sibling interpolates
    Given background and component HTML contain {{$jason.secret}}, CSS uses color red and height 7, and label context is "ordinary"
    When render the templated document
    Then background srcdoc is "<style>body{color:red}</style><script>window.raw='{{$jason.secret}}'</script>", component srcdoc is "<style>p{height:7px}</style><p>{{$jason.secret}}</p>", label is "ordinary"; background events are [CREATE(background), SANDBOX("allow-scripts"), SOURCE("srcdoc"), APPEND, RETURN] and component events are [CREATE(component), SANDBOX("allow-scripts"), SOURCE("srcdoc"), APPEND, RETURN] with RETURN from wrapper data-jasonette-type="html" completion and no later iframe event through public render return

  Scenario: actual $render replaces a background iframe while old and new sandbox endpoints remain exact
    Given templated background URL starts "https://example.com/first-background.html" and $render data changes it to "https://example.com/second-background.html"
    When render initially then execute actual $render
    Then new iframe differs from disconnected old iframe, both retain sandbox="allow-scripts", new iframe has only src="https://example.com/second-background.html", and each trace is [CREATE(background), SANDBOX("allow-scripts"), SOURCE("src"), APPEND, RETURN]

  Scenario: emitted iframe policy is exact and makes no browser-enforcement assertion
    Given HTML integration component with context kind="html", secret="LEAK", height=40, label="first"
    When render the document under the finite observer
    Then emitted sandbox tokens equal only ["allow-scripts"] and events are [CREATE(component), SANDBOX("allow-scripts"), SOURCE("srcdoc"), APPEND, RETURN] with RETURN from wrapper data-jasonette-type="html" completion and no later iframe event through public render return; no browser-enforcement outcome is asserted

