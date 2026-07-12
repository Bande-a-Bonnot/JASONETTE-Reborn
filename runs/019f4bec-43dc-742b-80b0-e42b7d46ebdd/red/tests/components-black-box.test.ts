// @vitest-environment jsdom
// @ts-nocheck
import { beforeEach, describe, expect, it, vi } from "vitest";
import { transform } from "@jasonette/template-engine";
import {
  COMPONENT_SOURCE_CASES,
  COMPONENT_TYPE_CASES,
  CSS_CASES,
  INHERITED_COMPONENT_CALLABLE_CASES,
  TRANSFORM_RENDER_INHERITANCE_CASES,
} from "./case-catalog.mjs";
import { ownData, renderComponentAtBoundary } from "./black-box-helpers";
import { installSecurityObserver } from "./security-observer";

function sourceComponent(kind: string) {
  const component: any = { type: "html" };
  switch (kind) {
    case "dual": Object.assign(component, { text: "<p>inline</p>", url: "https://example.com/ignored.html" }); break;
    case "whitespace": component.text = " \t\n"; break;
    case "empty-text-url": Object.assign(component, { text: "", url: "https://example.com/fallback.html" }); break;
    case "coercion": {
      const textToString = vi.fn(() => "<p>coerced text</p>");
      const urlToString = vi.fn(() => "https://example.com/coerced.html");
      component.text = { toString: textToString };
      component.url = { toString: urlToString };
      component.coercionSpies = [textToString, urlToString];
      break;
    }
    case "inherited-only": return Object.assign(Object.create({ text: "<p>inherited</p>", url: "https://example.com/inherited.html" }), { type: "html" });
    case "inherited-text-own-url": return Object.assign(Object.create({ text: "<p>inherited</p>" }), { type: "html", url: "https://example.com/own.html" });
    case "inherited-url-own-text": return Object.assign(Object.create({ url: "https://example.com/inherited.html" }), { type: "html", text: "<p>own</p>" });
    case "missing": break;
    case "invalid": component.text = "<p><b>unterminated & raw"; break;
    default: throw new Error(`unknown component source case ${kind}`);
  }
  return component;
}

function expectIframePolicy(iframe: HTMLIFrameElement, source: "src" | "srcdoc", expected: string) {
  expect(iframe.getAttribute("sandbox")).toBe("allow-scripts");
  expect(Array.from(iframe.sandbox)).toEqual(["allow-scripts"]);
  expect(iframe.hasAttribute(source)).toBe(true);
  expect(iframe.getAttribute(source)).toBe(expected);
  expect(iframe.hasAttribute(source === "src" ? "srcdoc" : "src")).toBe(false);
}

function expectVisibleFallback(wrapper: HTMLElement) {
  expect(wrapper.hidden).toBe(false);
  expect(wrapper.textContent?.trim().length).toBeGreaterThan(0);
}

beforeEach(() => document.body.replaceChildren());

describe("public HTML component renderer", () => {
  it("component inline iframe trace installs sandbox before source insertion and return", () => {
    const observer = installSecurityObserver();
    try {
      const wrapper = renderComponentAtBoundary({ type: "html", text: "<p>inline</p>" }, observer);
      const iframe = wrapper.querySelector("iframe")!;
      observer.assertExactTraceSet([{ iframe, kind: "component", source: "srcdoc" }]);
      expectIframePolicy(iframe, "srcdoc", "<p>inline</p>");
    } finally { observer.restore(); }
  });

  it("component URL iframe trace installs sandbox before source insertion and return", () => {
    const observer = installSecurityObserver();
    try {
      const wrapper = renderComponentAtBoundary({ type: "html", url: "https://example.com/page.html" }, observer);
      const iframe = wrapper.querySelector("iframe")!;
      observer.assertExactTraceSet([{ iframe, kind: "component", source: "src" }]);
      expectIframePolicy(iframe, "src", "https://example.com/page.html");
    } finally { observer.restore(); }
  });

  it("component wrapper return topology and legacy class size border contract remain exact", () => {
    const observer = installSecurityObserver();
    try {
      const wrapper = renderComponentAtBoundary({ type: "html", text: "<p>x</p>" }, observer) as HTMLElement;
      const iframe = wrapper.querySelector("iframe")!;
      observer.assertExactTraceSet([{ iframe, kind: "component", source: "srcdoc" }]);
      expect(wrapper.parentNode).toBeNull();
      expect(wrapper.isConnected).toBe(false);
      expect(wrapper.classList.contains("jasonette-html")).toBe(true);
      expect(wrapper.getAttribute("data-jasonette-type")).toBe("html");
      expect(iframe.parentNode).toBe(wrapper);
      expect(iframe.style.width).toBe("100%");
      expect(iframe.style.borderStyle).toBe("none");
    } finally { observer.restore(); }
  });

  it.each(COMPONENT_SOURCE_CASES)("$title", ({ kind, source, expected }) => {
    const observer = installSecurityObserver();
    try {
      const component = sourceComponent(kind);
      const wrapper = renderComponentAtBoundary(component, observer);
      const iframe = wrapper.querySelector("iframe");
      if (source === "none") {
        expect(iframe).toBeNull();
        expect(observer.traces).toEqual([]);
      } else {
        expect(iframe).not.toBeNull();
        observer.assertExactTraceSet([{ iframe: iframe!, kind: "component", source }]);
        expectIframePolicy(iframe!, source, expected);
      }
      for (const spy of component.coercionSpies ?? []) expect(spy).not.toHaveBeenCalled();
    } finally { observer.restore(); }
  });

  it.each(CSS_CASES)("$title", ({ kind, css, expected }) => {
    const observer = installSecurityObserver();
    try {
      const component: any = { type: "html", text: "<p>x</p>" };
      if (kind === "inherited") {
        Object.setPrototypeOf(component, { css: "p{color:inherited}" });
      } else if (kind === "coercion") {
        const coercion = vi.fn(() => "p{color:coerced}");
        component.css = { toString: coercion };
        component.coercionSpy = coercion;
      } else if (kind !== "absent" && kind !== "undefined") {
        component.css = css;
      } else if (kind === "undefined") {
        component.css = undefined;
      }
      const wrapper = renderComponentAtBoundary(component, observer) as HTMLElement;
      const iframe = wrapper.querySelector("iframe")!;
      observer.assertExactTraceSet([{ iframe, kind: "component", source: "srcdoc" }]);
      expect(iframe.srcdoc).toBe(expected);
      expect(iframe.getAttribute("srcdoc")).toBe(expected);
      if (component.coercionSpy) expect(component.coercionSpy).not.toHaveBeenCalled();
      if (kind === "mixed" || kind === "repeated") {
        expect(expected.codePointAt(expected.indexOf("\\"))).toBe(0x5c);
      }
    } finally { observer.restore(); }
  });

  it.each(COMPONENT_TYPE_CASES)("$title", ({ kind, outcome }) => {
    const observer = installSecurityObserver();
    try {
      let component: any;
      if (kind === "missing") component = { text: "fallback label" };
      else if (kind === "inherited-html") component = Object.assign(Object.create({ type: "html" }), { text: "fallback label" });
      else if (kind === "non-string") component = { type: 9, text: "fallback label" };
      else component = { type: kind, text: "visible value" };
      expect(() => {
        const wrapper = renderComponentAtBoundary(component, observer) as HTMLElement;
        expect(wrapper.querySelector("iframe")).toBeNull();
        expect(observer.traces).toEqual([]);
        if (outcome === "unknown") {
          expectVisibleFallback(wrapper);
          expect(wrapper.getAttribute("data-jasonette-type")).toBe(kind);
        } else {
          expect(wrapper.textContent).toBe(component.text);
        }
      }).not.toThrow();
    } finally { observer.restore(); }
  });

  it("component registry never invokes an inherited callable renderer", () => {
    const observer = installSecurityObserver();
    const name = "redInheritedComponent";
    const original = Object.getOwnPropertyDescriptor(Object.prototype, name);
    const inheritedCallable = vi.fn(() => document.createElement("iframe"));
    let publicCallThrew = false;
    let observations: any;
    try {
      ownData(Object.prototype, name, inheritedCallable);
      try {
        let wrapper: HTMLElement | undefined;
        try {
          wrapper = renderComponentAtBoundary({ type: name, text: "visible unknown" }, observer) as HTMLElement;
        } catch {
          publicCallThrew = true;
        }
        observations = {
          publicCallThrew,
          callableCallCount: inheritedCallable.mock.calls.length,
          fallbackHidden: wrapper?.hidden,
          visibleTextLength: wrapper?.textContent?.trim().length,
          dataType: wrapper?.getAttribute("data-jasonette-type") ?? null,
          iframeCount: wrapper?.querySelectorAll("iframe").length,
          traceCount: observer.traces.length,
        };
      } finally {
        if (original) Object.defineProperty(Object.prototype, name, original);
        else delete (Object.prototype as any)[name];
      }

      expect(observations.publicCallThrew).toBe(false);
      expect(observations.callableCallCount).toBe(0);
      expect(observations.fallbackHidden).toBe(false);
      expect(observations.visibleTextLength).toBeGreaterThan(0);
      expect(observations.dataType).toBe(name);
      expect(observations.iframeCount).toBe(0);
      expect(observations.traceCount).toBe(0);
    } finally { observer.restore(); }
  });

  it.each(INHERITED_COMPONENT_CALLABLE_CASES)("$title", ({ name }) => {
    const observer = installSecurityObserver();
    const original = Object.getOwnPropertyDescriptor(Object.prototype, name);
    const inheritedCallable = vi.fn(() => document.createElement("iframe"));
    let publicCallThrew = false;
    let observations: any;
    try {
      Object.defineProperty(Object.prototype, name, {
        value: inheritedCallable, enumerable: false, writable: true, configurable: true,
      });
      try {
        let wrapper: HTMLElement | undefined;
        try {
          wrapper = renderComponentAtBoundary({ type: name, text: "ignored" }, observer) as HTMLElement;
        } catch {
          publicCallThrew = true;
        }
        observations = {
          publicCallThrew,
          callableCallCount: inheritedCallable.mock.calls.length,
          fallbackHidden: wrapper?.hidden,
          visibleTextLength: wrapper?.textContent?.trim().length,
          dataType: wrapper?.getAttribute("data-jasonette-type") ?? null,
          iframeCount: wrapper?.querySelectorAll("iframe").length,
          traceCount: observer.traces.length,
        };
      } finally {
        if (original) Object.defineProperty(Object.prototype, name, original);
        else delete (Object.prototype as any)[name];
      }

      expect(observations.publicCallThrew).toBe(false);
      expect(observations.callableCallCount).toBe(0);
      expect(observations.fallbackHidden).toBe(false);
      expect(observations.visibleTextLength).toBeGreaterThan(0);
      expect(observations.dataType).toBe(name);
      expect(observations.iframeCount).toBe(0);
      expect(observations.traceCount).toBe(0);
    } finally { observer.restore(); }
  });

  it.each(TRANSFORM_RENDER_INHERITANCE_CASES)("$title", ({ kind, source, expected }) => {
    const observer = installSecurityObserver();
    try {
      let authored: any;
      if (kind === "all-inherited") authored = Object.assign(Object.create({ text: "<p>bad</p>", url: "https://example.com/bad", css: "bad{}" }), { type: "html" });
      else if (kind === "inherited-text") authored = Object.assign(Object.create({ text: "<p>bad</p>" }), { type: "html", url: expected });
      else if (kind === "inherited-url") authored = Object.assign(Object.create({ url: "https://example.com/bad" }), { type: "html", text: expected });
      else authored = Object.assign(Object.create({ css: "bad{}" }), { type: "html", text: expected });
      const transformed = transform(authored, {}, { preserveHtmlText: true });
      const wrapper = renderComponentAtBoundary(transformed, observer) as HTMLElement;
      const iframe = wrapper.querySelector("iframe");
      if (source === "none") {
        expect(iframe).toBeNull();
        expect(observer.traces).toEqual([]);
      } else {
        expect(iframe).not.toBeNull();
        observer.assertExactTraceSet([{ iframe: iframe!, kind: "component", source }]);
        expect(iframe!.getAttribute(source)).toBe(expected);
        expect(iframe!.hasAttribute(source === "src" ? "srcdoc" : "src")).toBe(false);
      }
    } finally { observer.restore(); }
  });
});
