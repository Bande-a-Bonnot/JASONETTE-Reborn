export type IframeKind = "component" | "background" | "self-test";

export interface IframeTrace {
  iframe: HTMLIFrameElement;
  kind: IframeKind;
  events: string[];
}

export interface ExpectedIframeTrace {
  iframe: HTMLIFrameElement;
  kind: IframeKind;
  source: "src" | "srcdoc";
}

const SECURITY_NAMES = new Set(["sandbox", "src", "srcdoc"]);

function localName(name: string): string {
  const colon = name.indexOf(":");
  return (colon >= 0 ? name.slice(colon + 1) : name).toLowerCase();
}

export function installSecurityObserver() {
  const traces: IframeTrace[] = [];
  const byIframe = new WeakMap<HTMLIFrameElement, IframeTrace>();
  const attributesOwner = new WeakMap<NamedNodeMap, Element>();
  const tokenOwner = new WeakMap<DOMTokenList, HTMLIFrameElement>();
  const datasetProxies = new WeakMap<DOMStringMap, DOMStringMap>();
  const restores: Array<() => void> = [];
  let currentKind: IframeKind = "self-test";
  let integratedComponentDepth = 0;

  const patchValue = (target: object, key: PropertyKey, value: unknown) => {
    const own = Object.getOwnPropertyDescriptor(target, key);
    if (!own) return false;
    Object.defineProperty(target, key, { ...own, value });
    restores.push(() => Object.defineProperty(target, key, own));
    return true;
  };

  const patchDescriptor = (target: object, key: PropertyKey, descriptor: PropertyDescriptor) => {
    const own = Object.getOwnPropertyDescriptor(target, key);
    if (!own) return false;
    Object.defineProperty(target, key, { ...own, ...descriptor });
    restores.push(() => Object.defineProperty(target, key, own));
    return true;
  };

  const registerIframe = (iframe: HTMLIFrameElement, parserCreated = false) => {
    let trace = byIframe.get(iframe);
    if (trace) return trace;
    trace = { iframe, kind: currentKind, events: [`CREATE(${currentKind})`] };
    traces.push(trace);
    byIframe.set(iframe, trace);
    if (parserCreated) {
      for (const attribute of Array.from(iframe.attributes)) {
        const name = localName(attribute.name);
        if (name === "sandbox") trace.events.push(`SANDBOX(${JSON.stringify(attribute.value)})`);
        else if (name === "src" || name === "srcdoc") trace.events.push(`SOURCE(${JSON.stringify(name)})`);
      }
      if (iframe.parentNode) trace.events.push("APPEND");
    }
    return trace;
  };

  const visitTree = (value: unknown, operation: (iframe: HTMLIFrameElement) => void) => {
    if (!(value instanceof Node)) return;
    if (value instanceof HTMLIFrameElement) operation(value);
    for (const child of Array.from(value.childNodes)) visitTree(child, operation);
    if (value instanceof HTMLTemplateElement) visitTree(value.content, operation);
  };

  const registerParserTree = (value: unknown) => visitTree(value, (iframe) => registerIframe(iframe, true));

  const markComponentReturn = (returned: unknown) => {
    visitTree(returned, (iframe) => {
      const trace = byIframe.get(iframe);
      if (trace?.kind === "component" && !trace.events.includes("RETURN")) trace.events.push("RETURN");
    });
  };

  const markIntegratedComponentCompletion = (element: Element, name: string) => {
    if (integratedComponentDepth === 0 || localName(name) !== "data-jasonette-type") return;
    if (element.getAttribute("data-jasonette-type") !== "html") return;
    markComponentReturn(element);
  };

  const assertIntegratedComponentCompletion = (startIndex: number) => {
    for (const trace of traces.slice(startIndex)) {
      if (trace.kind !== "component") continue;
      const returnIndex = trace.events.indexOf("RETURN");
      if (returnIndex < 0) {
        throw new Error(`integrated component iframe missing data-jasonette-type completion: ${JSON.stringify(trace.events)}`);
      }
      if (returnIndex !== trace.events.length - 1) {
        throw new Error(`iframe event occurred after integrated component completion: ${JSON.stringify(trace.events)}`);
      }
    }
  };

  const recordAttributeMutation = (element: Element | null, name: string) => {
    if (!(element instanceof HTMLIFrameElement)) return;
    const trace = byIframe.get(element);
    const normalized = localName(name);
    if (!trace || !SECURITY_NAMES.has(normalized)) return;
    if (normalized === "sandbox") {
      trace.events.push(`SANDBOX(${JSON.stringify(element.getAttribute("sandbox"))})`);
    } else {
      trace.events.push(`SOURCE(${JSON.stringify(normalized)})`);
    }
  };

  const originalCreateElement = Document.prototype.createElement;
  patchValue(Document.prototype, "createElement", function createElement(
    this: Document,
    name: string,
    options?: ElementCreationOptions,
  ) {
    const element = originalCreateElement.call(this, name, options as ElementCreationOptions);
    if (String(name).toLowerCase() === "iframe") registerIframe(element as HTMLIFrameElement);
    return element;
  });

  const originalCreateElementNS = Document.prototype.createElementNS;
  patchValue(Document.prototype, "createElementNS", function createElementNS(
    this: Document,
    namespace: string | null,
    qualifiedName: string,
    options?: string | ElementCreationOptions,
  ) {
    const element = originalCreateElementNS.call(this, namespace, qualifiedName, options as ElementCreationOptions);
    if (localName(String(qualifiedName)) === "iframe" && element instanceof HTMLIFrameElement) registerIframe(element);
    return element;
  });

  for (const property of ["src", "srcdoc"] as const) {
    const descriptor = Object.getOwnPropertyDescriptor(HTMLIFrameElement.prototype, property);
    if (!descriptor?.set) continue;
    patchDescriptor(HTMLIFrameElement.prototype, property, {
      get: descriptor.get,
      set(this: HTMLIFrameElement, value: string) {
        descriptor.set!.call(this, value);
        recordAttributeMutation(this, property);
      },
    });
  }

  const elementMethods: Array<[keyof Element, (args: unknown[]) => string]> = [
    ["setAttribute", (args) => String(args[0])],
    ["setAttributeNS", (args) => String(args[1])],
    ["removeAttribute", (args) => String(args[0])],
    ["removeAttributeNS", (args) => String(args[1])],
    ["toggleAttribute", (args) => String(args[0])],
    ["setAttributeNode", (args) => (args[0] as Attr).name],
    ["setAttributeNodeNS", (args) => (args[0] as Attr).name],
    ["removeAttributeNode", (args) => (args[0] as Attr).name],
  ];
  for (const [key, nameFromArgs] of elementMethods) {
    const original = (Element.prototype as any)[key];
    if (typeof original !== "function") continue;
    patchValue(Element.prototype, key, function observedAttributeMethod(this: Element, ...args: unknown[]) {
      const name = nameFromArgs(args);
      const result = original.apply(this, args);
      recordAttributeMutation(this, name);
      markIntegratedComponentCompletion(this, name);
      return result;
    });
  }

  const datasetDescriptor = Object.getOwnPropertyDescriptor(HTMLElement.prototype, "dataset");
  if (datasetDescriptor?.get) {
    patchDescriptor(HTMLElement.prototype, "dataset", {
      get(this: HTMLElement) {
        const dataset = datasetDescriptor.get!.call(this) as DOMStringMap;
        let proxy = datasetProxies.get(dataset);
        if (!proxy) {
          const owner = this;
          proxy = new Proxy(dataset, {
            set(target, key, value) {
              const result = Reflect.set(target, key, value);
              if (key === "jasonetteType") markIntegratedComponentCompletion(owner, "data-jasonette-type");
              return result;
            },
          });
          datasetProxies.set(dataset, proxy);
        }
        return proxy;
      },
    });
  }

  const attributesDescriptor = Object.getOwnPropertyDescriptor(Element.prototype, "attributes");
  if (attributesDescriptor?.get) {
    patchDescriptor(Element.prototype, "attributes", {
      get(this: Element) {
        const attributes = attributesDescriptor.get!.call(this) as NamedNodeMap;
        attributesOwner.set(attributes, this);
        return attributes;
      },
    });
  }

  for (const key of ["setNamedItem", "setNamedItemNS", "removeNamedItem", "removeNamedItemNS"] as const) {
    const original = NamedNodeMap.prototype[key];
    if (typeof original !== "function") continue;
    patchValue(NamedNodeMap.prototype, key, function observedNamedNodeMap(this: NamedNodeMap, ...args: unknown[]) {
      const owner = attributesOwner.get(this) ?? ((args[0] as Attr | undefined)?.ownerElement ?? null);
      const name = typeof args[0] === "string" ? args[0] : (args[0] as Attr).name;
      const result = (original as Function).apply(this, args);
      recordAttributeMutation(owner, name);
      if (owner) markIntegratedComponentCompletion(owner, name);
      return result;
    });
  }

  const attrValue = Object.getOwnPropertyDescriptor(Attr.prototype, "value");
  if (attrValue?.set) {
    patchDescriptor(Attr.prototype, "value", {
      get: attrValue.get,
      set(this: Attr, value: string) {
        const owner = this.ownerElement;
        const name = this.name;
        attrValue.set!.call(this, value);
        recordAttributeMutation(owner, name);
        if (owner) markIntegratedComponentCompletion(owner, name);
      },
    });
  }
  for (const key of ["nodeValue", "textContent"] as const) {
    const descriptor = Object.getOwnPropertyDescriptor(Node.prototype, key);
    if (!descriptor?.set) continue;
    patchDescriptor(Node.prototype, key, {
      get: descriptor.get,
      set(this: Node, value: string | null) {
        const attr = this instanceof Attr ? this : null;
        const owner = attr?.ownerElement ?? null;
        const name = attr?.name ?? "";
        descriptor.set!.call(this, value);
        if (attr) {
          recordAttributeMutation(owner, name);
          if (owner) markIntegratedComponentCompletion(owner, name);
        }
      },
    });
  }

  const sandboxDescriptor = Object.getOwnPropertyDescriptor(HTMLIFrameElement.prototype, "sandbox");
  if (sandboxDescriptor?.get) {
    patchDescriptor(HTMLIFrameElement.prototype, "sandbox", {
      get(this: HTMLIFrameElement) {
        const list = sandboxDescriptor.get!.call(this) as DOMTokenList;
        tokenOwner.set(list, this);
        return list;
      },
      set: sandboxDescriptor.set,
    });
  }
  for (const key of ["add", "remove", "toggle", "replace"] as const) {
    const original = DOMTokenList.prototype[key];
    if (typeof original !== "function") continue;
    patchValue(DOMTokenList.prototype, key, function observedTokenMutation(this: DOMTokenList, ...args: unknown[]) {
      const result = (original as Function).apply(this, args);
      const owner = tokenOwner.get(this);
      if (owner) recordAttributeMutation(owner, "sandbox");
      return result;
    });
  }
  const tokenValue = Object.getOwnPropertyDescriptor(DOMTokenList.prototype, "value");
  if (tokenValue?.set) {
    patchDescriptor(DOMTokenList.prototype, "value", {
      get: tokenValue.get,
      set(this: DOMTokenList, value: string) {
        tokenValue.set!.call(this, value);
        const owner = tokenOwner.get(this);
        if (owner) recordAttributeMutation(owner, "sandbox");
      },
    });
  }

  const collectTrackedIframes = (value: unknown, found: Set<HTMLIFrameElement>) =>
    visitTree(value, (iframe) => { if (byIframe.has(iframe)) found.add(iframe); });

  const patchInsertion = (prototype: object, key: string) => {
    const original = (prototype as any)[key];
    if (typeof original !== "function" || !Object.prototype.hasOwnProperty.call(prototype, key)) return;
    patchValue(prototype, key, function observedInsertion(this: Node, ...args: unknown[]) {
      const found = new Set<HTMLIFrameElement>();
      for (const arg of args) collectTrackedIframes(arg, found);
      const prior = new Map(Array.from(found, (iframe) => [iframe, iframe.parentNode]));
      const result = original.apply(this, args);
      for (const iframe of found) {
        if (iframe.parentNode && (prior.get(iframe) !== iframe.parentNode || args.includes(iframe))) {
          byIframe.get(iframe)!.events.push("APPEND");
        }
      }
      return result;
    });
  };

  for (const key of ["appendChild", "insertBefore", "replaceChild"]) patchInsertion(Node.prototype, key);
  for (const prototype of [Element.prototype, DocumentFragment.prototype, Document.prototype]) {
    for (const key of ["append", "prepend", "replaceChildren"]) patchInsertion(prototype, key);
  }
  for (const prototype of [Element.prototype, CharacterData.prototype]) {
    for (const key of ["before", "after", "replaceWith"]) patchInsertion(prototype, key);
  }
  patchInsertion(Element.prototype, "insertAdjacentElement");

  const patchHtmlSetter = (prototype: object, key: "innerHTML" | "outerHTML") => {
    const descriptor = Object.getOwnPropertyDescriptor(prototype, key);
    if (!descriptor?.set) return;
    patchDescriptor(prototype, key, {
      get: descriptor.get,
      set(this: Element | ShadowRoot, value: string) {
        const scanRoot = key === "outerHTML" ? (this as Element).parentNode : this;
        descriptor.set!.call(this, value);
        registerParserTree(scanRoot);
      },
    });
  };
  patchHtmlSetter(Element.prototype, "innerHTML");
  patchHtmlSetter(Element.prototype, "outerHTML");
  if (typeof ShadowRoot !== "undefined") patchHtmlSetter(ShadowRoot.prototype, "innerHTML");

  const insertAdjacentHTML = Element.prototype.insertAdjacentHTML;
  if (typeof insertAdjacentHTML === "function") {
    patchValue(Element.prototype, "insertAdjacentHTML", function observedInsertAdjacentHTML(
      this: Element,
      position: InsertPosition,
      text: string,
    ) {
      const root = this.parentNode ?? this;
      const result = insertAdjacentHTML.call(this, position, text);
      registerParserTree(root);
      return result;
    });
  }

  const contextualFragment = Range.prototype.createContextualFragment;
  patchValue(Range.prototype, "createContextualFragment", function observedContextualFragment(this: Range, fragment: string) {
    const result = contextualFragment.call(this, fragment);
    registerParserTree(result);
    return result;
  });

  const parseFromString = DOMParser.prototype.parseFromString;
  patchValue(DOMParser.prototype, "parseFromString", function observedParseFromString(
    this: DOMParser,
    input: string,
    mimeType: DOMParserSupportedType,
  ) {
    const result = parseFromString.call(this, input, mimeType);
    registerParserTree(result);
    return result;
  });

  const expectedEvents = (kind: IframeKind, source: "src" | "srcdoc") => [
    `CREATE(${kind})`,
    'SANDBOX("allow-scripts")',
    `SOURCE(${JSON.stringify(source)})`,
    "APPEND",
    "RETURN",
  ];

  const api = {
    traces,
    withKind<T>(kind: IframeKind, operation: () => T): T {
      const previous = currentKind;
      currentKind = kind;
      try { return operation(); } finally { currentKind = previous; }
    },
    async withKindAsync<T>(kind: IframeKind, operation: () => Promise<T>): Promise<T> {
      const previous = currentKind;
      currentKind = kind;
      try { return await operation(); } finally { currentKind = previous; }
    },
    withIntegratedComponentBoundary<T>(operation: () => T): T {
      const previous = currentKind;
      const startIndex = traces.length;
      currentKind = "component";
      integratedComponentDepth += 1;
      try {
        const result = operation();
        assertIntegratedComponentCompletion(startIndex);
        return result;
      } finally {
        integratedComponentDepth -= 1;
        currentKind = previous;
      }
    },
    async withIntegratedComponentBoundaryAsync<T>(operation: () => Promise<T>): Promise<T> {
      const previous = currentKind;
      const startIndex = traces.length;
      currentKind = "component";
      integratedComponentDepth += 1;
      try {
        const result = await operation();
        assertIntegratedComponentCompletion(startIndex);
        return result;
      } finally {
        integratedComponentDepth -= 1;
        currentKind = previous;
      }
    },
    markComponentReturn(returned: unknown) {
      markComponentReturn(returned);
    },
    markBackgroundReturn() {
      for (const trace of traces) {
        if (trace.kind === "background" && !trace.events.includes("RETURN")) trace.events.push("RETURN");
      }
    },
    traceFor(iframe: HTMLIFrameElement) {
      const trace = byIframe.get(iframe);
      if (!trace) throw new Error("iframe was not created inside the observer window");
      return trace;
    },
    resetEvents(iframe: HTMLIFrameElement) {
      api.traceFor(iframe).events.length = 0;
    },
    assertCreationTrace(
      iframe: HTMLIFrameElement,
      kind: IframeKind,
      source: "src" | "srcdoc",
    ) {
      const actual = api.traceFor(iframe).events;
      const expected = expectedEvents(kind, source);
      if (actual.length !== expected.length || actual.some((event, index) => event !== expected[index])) {
        throw new Error(`invalid iframe trace: ${JSON.stringify(actual)}; expected ${JSON.stringify(expected)}`);
      }
    },
    assertExactTraceSet(expected: ExpectedIframeTrace[]) {
      if (traces.length !== expected.length) {
        throw new Error(`invalid complete iframe trace count: ${traces.length}; expected ${expected.length}`);
      }
      expected.forEach((entry, index) => {
        const actual = traces[index];
        if (actual.iframe !== entry.iframe || actual.kind !== entry.kind) {
          throw new Error(`invalid iframe trace identity/kind at ${index}`);
        }
        api.assertCreationTrace(entry.iframe, entry.kind, entry.source);
      });
    },
    assertNoSourceOrInsertionBeforeSandbox(iframe: HTMLIFrameElement) {
      const events = api.traceFor(iframe).events;
      const sandbox = events.indexOf('SANDBOX("allow-scripts")');
      const unsafe = events.findIndex((event) => event === "APPEND" || event.startsWith("SOURCE("));
      if (unsafe >= 0 && (sandbox < 0 || unsafe < sandbox)) {
        throw new Error(`iframe source/insertion occurred before exact sandbox: ${JSON.stringify(events)}`);
      }
    },
    restore() {
      for (const restore of restores.reverse()) restore();
    },
  };
  return api;
}

export type SecurityObserver = ReturnType<typeof installSecurityObserver>;
