// @vitest-environment jsdom
// @ts-nocheck
import { describe, expect, it } from "vitest";
import {
  INSERTION_OBSERVER_CASES,
  OBSERVER_CREATION_CASES,
  SANDBOX_OBSERVER_CASES,
  SOURCE_OBSERVER_CASES,
} from "./case-catalog.mjs";
import { renderComponentAtBoundary } from "./black-box-helpers";
import { installSecurityObserver } from "./security-observer";

function performInsertion(route: string, iframe: HTMLIFrameElement) {
  const parent = document.createElement("div");
  const anchor = document.createElement("span");
  const old = document.createElement("b");
  switch (route) {
    case "Element appendChild": parent.appendChild(iframe); break;
    case "DocumentFragment appendChild": document.createDocumentFragment().appendChild(iframe); break;
    case "insertBefore": parent.appendChild(anchor); parent.insertBefore(iframe, anchor); break;
    case "replaceChild": parent.appendChild(old); parent.replaceChild(iframe, old); break;
    case "Element append": parent.append(iframe); break;
    case "Element prepend": parent.prepend(iframe); break;
    case "replaceChildren": parent.replaceChildren(iframe); break;
    case "before": parent.appendChild(anchor); anchor.before(iframe); break;
    case "after": parent.appendChild(anchor); anchor.after(iframe); break;
    case "replaceWith": parent.appendChild(old); old.replaceWith(iframe); break;
    case "insertAdjacentElement": parent.insertAdjacentElement("beforeend", iframe); break;
    default: throw new Error(`unknown insertion route ${route}`);
  }
}

function prepareAttribute(iframe: HTMLIFrameElement, name: string, value: string) {
  iframe.setAttribute(name, value);
  return iframe.getAttributeNode(name)!;
}

function performSandboxMutation(route: string, iframe: HTMLIFrameElement, reset: () => void) {
  switch (route) {
    case "setAttribute": iframe.setAttribute("sandbox", "allow-scripts"); break;
    case "setAttributeNS": iframe.setAttributeNS(null, "sandbox", "allow-scripts"); break;
    case "removeAttribute": prepareAttribute(iframe, "sandbox", "allow-scripts"); reset(); iframe.removeAttribute("sandbox"); break;
    case "removeAttributeNS": prepareAttribute(iframe, "sandbox", "allow-scripts"); reset(); iframe.removeAttributeNS(null, "sandbox"); break;
    case "toggleAttribute": iframe.toggleAttribute("sandbox", true); break;
    case "setAttributeNode": { const attr = document.createAttribute("sandbox"); attr.value = "allow-scripts"; iframe.setAttributeNode(attr); break; }
    case "setAttributeNodeNS": { const attr = document.createAttributeNS(null, "sandbox"); attr.value = "allow-scripts"; iframe.setAttributeNodeNS(attr); break; }
    case "removeAttributeNode": { const attr = prepareAttribute(iframe, "sandbox", "allow-scripts"); reset(); iframe.removeAttributeNode(attr); break; }
    case "NamedNodeMap setNamedItem": { const attr = document.createAttribute("sandbox"); attr.value = "allow-scripts"; iframe.attributes.setNamedItem(attr); break; }
    case "NamedNodeMap setNamedItemNS": { const attr = document.createAttributeNS(null, "sandbox"); attr.value = "allow-scripts"; iframe.attributes.setNamedItemNS(attr); break; }
    case "NamedNodeMap removeNamedItem": prepareAttribute(iframe, "sandbox", "allow-scripts"); reset(); iframe.attributes.removeNamedItem("sandbox"); break;
    case "NamedNodeMap removeNamedItemNS": prepareAttribute(iframe, "sandbox", "allow-scripts"); reset(); iframe.attributes.removeNamedItemNS(null, "sandbox"); break;
    case "Attr value": { const attr = prepareAttribute(iframe, "sandbox", "allow-forms"); reset(); attr.value = "allow-scripts"; break; }
    case "Attr nodeValue": { const attr = prepareAttribute(iframe, "sandbox", "allow-forms"); reset(); attr.nodeValue = "allow-scripts"; break; }
    case "Attr textContent": { const attr = prepareAttribute(iframe, "sandbox", "allow-forms"); reset(); attr.textContent = "allow-scripts"; break; }
    case "sandbox value": iframe.sandbox.value = "allow-scripts"; break;
    case "sandbox add": iframe.sandbox.add("allow-scripts"); break;
    case "sandbox remove": iframe.sandbox.add("allow-scripts"); reset(); iframe.sandbox.remove("allow-scripts"); break;
    case "sandbox toggle": iframe.sandbox.toggle("allow-scripts"); break;
    case "sandbox replace": iframe.sandbox.add("allow-forms"); reset(); iframe.sandbox.replace("allow-forms", "allow-scripts"); break;
    default: throw new Error(`unknown sandbox route ${route}`);
  }
}

function performSourceMutation(route: string, iframe: HTMLIFrameElement, reset: () => void) {
  switch (route) {
    case "src property": iframe.src = "https://example.com/a"; break;
    case "srcdoc property": iframe.srcdoc = "<p>a</p>"; break;
    case "setAttribute src": iframe.setAttribute("src", "https://example.com/a"); break;
    case "setAttribute srcdoc": iframe.setAttribute("srcdoc", "<p>a</p>"); break;
    case "setAttributeNS src": iframe.setAttributeNS(null, "src", "https://example.com/a"); break;
    case "removeAttribute src": prepareAttribute(iframe, "src", "https://example.com/a"); reset(); iframe.removeAttribute("src"); break;
    case "removeAttributeNS srcdoc": prepareAttribute(iframe, "srcdoc", "<p>a</p>"); reset(); iframe.removeAttributeNS(null, "srcdoc"); break;
    case "toggleAttribute srcdoc": iframe.toggleAttribute("srcdoc", true); break;
    case "setAttributeNode srcdoc": { const attr = document.createAttribute("srcdoc"); attr.value = "<p>a</p>"; iframe.setAttributeNode(attr); break; }
    case "setAttributeNodeNS src": { const attr = document.createAttributeNS(null, "src"); attr.value = "https://example.com/a"; iframe.setAttributeNodeNS(attr); break; }
    case "removeAttributeNode srcdoc": { const attr = prepareAttribute(iframe, "srcdoc", "<p>a</p>"); reset(); iframe.removeAttributeNode(attr); break; }
    case "NamedNodeMap setNamedItem src": { const attr = document.createAttribute("src"); attr.value = "https://example.com/a"; iframe.attributes.setNamedItem(attr); break; }
    case "NamedNodeMap setNamedItemNS srcdoc": { const attr = document.createAttributeNS(null, "srcdoc"); attr.value = "<p>a</p>"; iframe.attributes.setNamedItemNS(attr); break; }
    case "NamedNodeMap removeNamedItem src": prepareAttribute(iframe, "src", "https://example.com/a"); reset(); iframe.attributes.removeNamedItem("src"); break;
    case "NamedNodeMap removeNamedItemNS srcdoc": prepareAttribute(iframe, "srcdoc", "<p>a</p>"); reset(); iframe.attributes.removeNamedItemNS(null, "srcdoc"); break;
    case "Attr value srcdoc": { const attr = prepareAttribute(iframe, "srcdoc", "<p>before</p>"); reset(); attr.value = "<p>after</p>"; break; }
    case "Attr nodeValue src": { const attr = prepareAttribute(iframe, "src", "https://example.com/before"); reset(); attr.nodeValue = "https://example.com/after"; break; }
    case "Attr textContent srcdoc": { const attr = prepareAttribute(iframe, "srcdoc", "<p>before</p>"); reset(); attr.textContent = "<p>after</p>"; break; }
    default: throw new Error(`unknown source route ${route}`);
  }
}

function performCreation(route: string) {
  const markup = '<iframe sandbox="allow-scripts" srcdoc="<p>a</p>"></iframe>';
  if (route === "createElementNS") {
    return document.createElementNS("http://www.w3.org/1999/xhtml", "iframe") as HTMLIFrameElement;
  }
  if (route === "Element innerHTML" || route === "source-first innerHTML") {
    const parent = document.createElement("div");
    parent.innerHTML = route === "source-first innerHTML"
      ? '<iframe srcdoc="<p>a</p>" sandbox="allow-scripts"></iframe>'
      : markup;
    return parent.querySelector("iframe")!;
  }
  if (route === "template innerHTML") {
    const template = document.createElement("template");
    template.innerHTML = markup;
    return template.content.querySelector("iframe")!;
  }
  if (route === "insertAdjacentHTML") {
    const parent = document.createElement("div");
    parent.insertAdjacentHTML("beforeend", markup);
    return parent.querySelector("iframe")!;
  }
  if (route === "Range contextual fragment") {
    const range = document.createRange();
    range.selectNode(document.body);
    return range.createContextualFragment(markup).querySelector("iframe")!;
  }
  if (route === "DOMParser") {
    return new DOMParser().parseFromString(markup, "text/html").querySelector("iframe")!;
  }
  throw new Error(`unknown creation route ${route}`);
}

function assertSandboxCompatibility(iframe: HTMLIFrameElement) {
  const sandbox = iframe.sandbox;
  iframe.setAttribute(
    "sandbox",
    "allow-scripts allow-forms allow-scripts allow-popups allow-forms",
  );

  expect(iframe.sandbox).toBe(sandbox);
  expect(sandbox.length).toBe(3);
  expect(Array.from(sandbox)).toEqual(["allow-scripts", "allow-forms", "allow-popups"]);
  expect(sandbox.toggle("allow-scripts")).toBe(false);
  expect(iframe.getAttribute("sandbox")).toBe("allow-forms allow-popups");

  iframe.setAttribute("sandbox", "allow-modals allow-forms allow-modals");
  expect(sandbox.length).toBe(2);
  expect(Array.from(sandbox)).toEqual(["allow-modals", "allow-forms"]);
  expect(sandbox.replace("allow-modals", "allow-forms")).toBe(true);
  expect(iframe.getAttribute("sandbox")).toBe("allow-forms");
}

describe("security observer self-tests", () => {
  it("component RETURN observer self-test marks only after direct renderComponent returns", () => {
    expect(Object.getOwnPropertyDescriptor(HTMLIFrameElement.prototype, "sandbox")).toBeUndefined();
    const observer = installSecurityObserver();
    const markComponentReturn = observer.markComponentReturn.bind(observer);
    let marks = 0;
    observer.markComponentReturn = (returned: unknown) => {
      const wrapper = returned as HTMLElement;
      const iframe = wrapper.querySelector("iframe")!;
      expect(wrapper.getAttribute("data-jasonette-type")).toBe("html");
      expect(observer.traceFor(iframe).events).toEqual([
        "CREATE(component)",
        'SANDBOX("allow-scripts")',
        'SOURCE("srcdoc")',
        "APPEND",
      ]);
      marks += 1;
      markComponentReturn(returned);
    };
    try {
      const wrapper = renderComponentAtBoundary({ type: "html", text: "<p>timing</p>" }, observer);
      const iframe = wrapper.querySelector("iframe")!;
      expect(marks).toBe(1);
      observer.assertExactTraceSet([{ iframe, kind: "component", source: "srcdoc" }]);
    } finally {
      observer.restore();
      expect(Object.getOwnPropertyDescriptor(HTMLIFrameElement.prototype, "sandbox")).toBeUndefined();
    }
  });

  it("integrated component marker completes before public return and later iframe events are rejected", () => {
    const observer = installSecurityObserver();
    let iframe: HTMLIFrameElement;
    try {
      expect(() => observer.withIntegratedComponentBoundary(() => {
        const wrapper = document.createElement("div");
        iframe = document.createElement("iframe");
        iframe.setAttribute("sandbox", "allow-scripts");
        iframe.srcdoc = "<p>before</p>";
        wrapper.appendChild(iframe);
        wrapper.setAttribute("data-jasonette-type", "html");
        iframe.srcdoc = "<p>late</p>";
      })).toThrow("iframe event occurred after integrated component completion");
      expect(observer.traceFor(iframe!).events).toEqual([
        "CREATE(component)",
        'SANDBOX("allow-scripts")',
        'SOURCE("srcdoc")',
        "APPEND",
        "RETURN",
        'SOURCE("srcdoc")',
      ]);
    } finally { observer.restore(); }
  });

  it.each(OBSERVER_CREATION_CASES)("$title", ({ route, unsafe }) => {
    const observer = installSecurityObserver();
    try {
      const iframe = observer.withKind("self-test", () => performCreation(route));
      const expected = route === "createElementNS"
        ? ["CREATE(self-test)"]
        : unsafe
          ? ["CREATE(self-test)", 'SOURCE("srcdoc")', 'SANDBOX("allow-scripts")', "APPEND"]
          : ["CREATE(self-test)", 'SANDBOX("allow-scripts")', 'SOURCE("srcdoc")', "APPEND"];
      expect(observer.traces).toHaveLength(1);
      expect(observer.traceFor(iframe).events).toEqual(expected);
      if (unsafe) {
        expect(() => observer.assertNoSourceOrInsertionBeforeSandbox(iframe)).toThrow(
          "source/insertion occurred before exact sandbox",
        );
      } else {
        expect(() => observer.assertNoSourceOrInsertionBeforeSandbox(iframe)).not.toThrow();
      }
    } finally { observer.restore(); }
  });

  it.each(INSERTION_OBSERVER_CASES)("$title", ({ route }) => {
    const observer = installSecurityObserver();
    try {
      const iframe = observer.withKind("self-test", () => document.createElement("iframe"));
      performInsertion(route, iframe);
      expect(observer.traces).toHaveLength(1);
      expect(observer.traceFor(iframe).events).toEqual(["CREATE(self-test)", "APPEND"]);
      expect(() => observer.assertNoSourceOrInsertionBeforeSandbox(iframe)).toThrow(
        "source/insertion occurred before exact sandbox",
      );
    } finally { observer.restore(); }
  });

  it.each(SANDBOX_OBSERVER_CASES)("$title", ({ route }) => {
    const observer = installSecurityObserver();
    try {
      const iframe = observer.withKind("self-test", () => document.createElement("iframe"));
      const reset = () => observer.resetEvents(iframe);
      reset();
      performSandboxMutation(route, iframe, reset);
      expect(observer.traces).toHaveLength(1);
      expect(observer.traceFor(iframe).events).toEqual([
        `SANDBOX(${JSON.stringify(iframe.getAttribute("sandbox"))})`,
      ]);
      assertSandboxCompatibility(iframe);
    } finally { observer.restore(); }
  });

  it.each(SOURCE_OBSERVER_CASES)("$title", ({ route }) => {
    const observer = installSecurityObserver();
    try {
      const iframe = observer.withKind("self-test", () => document.createElement("iframe"));
      const reset = () => observer.resetEvents(iframe);
      reset();
      performSourceMutation(route, iframe, reset);
      const name = route.includes("srcdoc") ? "srcdoc" : "src";
      expect(observer.traces).toHaveLength(1);
      expect(observer.traceFor(iframe).events).toEqual([`SOURCE(${JSON.stringify(name)})`]);
      expect(() => observer.assertNoSourceOrInsertionBeforeSandbox(iframe)).toThrow(
        "source/insertion occurred before exact sandbox",
      );
    } finally { observer.restore(); }
  });
});
