// @vitest-environment jsdom
// @ts-nocheck
import { beforeEach, describe, expect, it, vi } from "vitest";
import {
  BACKGROUND_MATRIX_CASES,
  BACKGROUND_PRECEDENCE_CASES,
  STATIC_BACKGROUND_CASES,
} from "./case-catalog.mjs";
import {
  createRenderer,
  foregroundBody,
  ownData,
  renderDocumentObserved,
  staticDocument,
  templatedDocument,
  wrapBackgroundBoundary,
} from "./black-box-helpers";
import { installSecurityObserver } from "./security-observer";

function matrixBackground(id: string) {
  const background: any = { type: "html" };
  const spies: any[] = [];
  switch (id) {
    case "inline": background.text = "<p>inline</p>"; break;
    case "URL": background.url = "https://example.com/background.html"; break;
    case "dual source text precedence": Object.assign(background, { text: "<p>dual</p>", url: "https://example.com/ignored.html" }); break;
    case "whitespace inline source": background.text = " \t\n"; break;
    case "empty own text with valid URL fallback": Object.assign(background, { text: "", url: "https://example.com/empty-text-fallback.html" }); break;
    case "non-string own text with valid URL fallback": {
      const text = vi.fn(() => "<p>coerced</p>");
      Object.assign(background, { text: { toString: text }, url: "https://example.com/non-string-text-fallback.html" });
      spies.push(text);
      break;
    }
    case "invalid inline HTML exact preservation": background.text = "<p><b>unterminated & raw"; break;
    case "empty sources": Object.assign(background, { text: "", url: "" }); break;
    case "non-string coercion sentinels": {
      const text = vi.fn(() => "<p>coerced</p>");
      const url = vi.fn(() => "https://example.com/coerced.html");
      const css = vi.fn(() => "p{color:coerced}");
      Object.assign(background, { text: { toString: text }, url: { toString: url }, css: { toString: css } });
      spies.push(text, url, css);
      break;
    }
    case "empty CSS": Object.assign(background, { text: "<p>css</p>", css: "" }); break;
    case "null CSS": Object.assign(background, { text: "<p>css</p>", css: null }); break;
    case "undefined CSS": Object.assign(background, { text: "<p>css</p>", css: undefined }); break;
    case "non-string CSS coercion sentinel": {
      const css = vi.fn(() => "p{color:coerced}");
      Object.assign(background, { text: "<p>css</p>", css: { toString: css } });
      spies.push(css);
      break;
    }
    case "one-space CSS": Object.assign(background, { text: "<p>css</p>", css: " " }); break;
    case "tab-newline CSS": Object.assign(background, { text: "<p>css</p>", css: "\t\n" }); break;
    case "mixed-case CSS escape": Object.assign(background, { text: "<p>css</p>", css: "</STYLE>" }); break;
    case "repeated mixed-case CSS escape": Object.assign(background, { text: "<p>css</p>", css: "a</style>b</StYlE>c" }); break;
    case "inherited-only source fields": return { background: Object.assign(Object.create({ text: "<p>bad</p>", url: "https://example.com/bad", css: "bad{}" }), { type: "html" }), spies };
    case "inherited text with own URL": return { background: Object.assign(Object.create({ text: "<p>bad</p>" }), { type: "html", url: "https://example.com/own-background.html" }), spies };
    case "inherited URL with own text": return { background: Object.assign(Object.create({ url: "https://example.com/bad" }), { type: "html", text: "<p>own background</p>" }), spies };
    case "inherited CSS with own text": return { background: Object.assign(Object.create({ css: "bad{}" }), { type: "html", text: "<p>own cssless</p>" }), spies };
    case "missing type": delete background.type; background.text = "<p>bad</p>"; break;
    case "inherited HTML type": return { background: Object.assign(Object.create({ type: "html" }), { text: "<p>bad</p>" }), spies };
    case "non-string type": background.type = 5; background.text = "<p>bad</p>"; break;
    case "non-HTML type": background.type = "label"; background.text = "<p>bad</p>"; break;
    case "__proto__ type collision": ownData(background, "type", "__proto__"); background.text = "<p>bad</p>"; break;
    case "constructor type collision": background.type = "constructor"; background.text = "<p>bad</p>"; break;
    case "prototype type collision": background.type = "prototype"; background.text = "<p>bad</p>"; break;
    case "toString type collision": background.type = "toString"; background.text = "<p>bad</p>"; break;
    case "HTML type without source": break;
    default: throw new Error(`unknown background matrix row ${id}`);
  }
  return { background, spies };
}

function renderBackground(body: any) {
  const observer = installSecurityObserver();
  const { renderer, root } = createRenderer();
  const unwrap = wrapBackgroundBoundary(renderer, observer);
  try {
    if (!Object.hasOwn(body, "sections")) {
      body.sections = [{ items: [{ type: "label", text: "foreground" }] }];
    }
    renderDocumentObserved(renderer, staticDocument(body), observer);
    return { observer, root, cleanup: () => { unwrap(); observer.restore(); } };
  } catch (error) {
    unwrap(); observer.restore();
    throw error;
  }
}

function expectBackgroundIframe(root: HTMLElement, observer: any, source: "src" | "srcdoc", expected: string) {
  const iframe = root.querySelector("iframe.jasonette-background-web") as HTMLIFrameElement;
  expect(iframe).not.toBeNull();
  expect(iframe.parentNode).toBe(root);
  expect(iframe.className).toBe("jasonette-background-web");
  expect(iframe.getAttribute("aria-hidden")).toBe("true");
  expect(iframe.getAttribute("sandbox")).toBe("allow-scripts");
  expect(Array.from(iframe.sandbox)).toEqual(["allow-scripts"]);
  expect(iframe.hasAttribute(source)).toBe(true);
  expect(iframe.getAttribute(source)).toBe(expected);
  if (source === "srcdoc") expect(iframe.srcdoc).toBe(expected);
  expect(iframe.hasAttribute(source === "src" ? "srcdoc" : "src")).toBe(false);
  const foreground = root.querySelector(".jasonette-section, .jasonette-label")!;
  expect(iframe.compareDocumentPosition(foreground) & Node.DOCUMENT_POSITION_FOLLOWING).not.toBe(0);
  observer.assertExactTraceSet([{ iframe, kind: "background", source }]);
  return iframe;
}

beforeEach(() => document.body.replaceChildren());

describe("background path selection and rendering", () => {
  it.each(STATIC_BACKGROUND_CASES)("$title", ({ vector }) => {
    const observer = installSecurityObserver();
    const { renderer, root } = createRenderer();
    const unwrap = wrapBackgroundBoundary(renderer, observer);
    try {
      let appDocument: any;
      if (vector === "static-canonical") {
        appDocument = staticDocument(foregroundBody({ background: { type: "html", text: "<p>static</p>", css: "p{color:red}" } }));
      } else if (vector === "static-legacy") {
        appDocument = staticDocument(foregroundBody({ style: { background: { type: "html", url: "https://example.com/bg.html" } } }));
      } else if (vector === "template-canonical") {
        appDocument = templatedDocument(foregroundBody({ background: { type: "html", text: "<p>{{$jason.secret}}</p>", css: "p{color:{{$jason.color}}}" } }), { secret: "LEAK", color: "red" });
      } else if (vector === "template-legacy") {
        appDocument = templatedDocument(foregroundBody({ style: { background: { type: "html", url: "{{$jason.url}}" } } }), { url: "https://example.com/dynamic.html" });
      } else {
        appDocument = staticDocument(foregroundBody({ background: { type: "html" } }));
      }
      renderDocumentObserved(renderer, appDocument, observer);
      if (vector === "no-source") {
        expect(root.querySelector("iframe")).toBeNull();
        expect(observer.traces).toEqual([]);
      } else if (vector === "static-canonical") {
        expectBackgroundIframe(root, observer, "srcdoc", "<style>p{color:red}</style><p>static</p>");
      } else if (vector === "static-legacy") {
        expectBackgroundIframe(root, observer, "src", "https://example.com/bg.html");
      } else if (vector === "template-canonical") {
        expectBackgroundIframe(root, observer, "srcdoc", "<style>p{color:red}</style><p>{{$jason.secret}}</p>");
      } else {
        expectBackgroundIframe(root, observer, "src", "https://example.com/dynamic.html");
      }
    } finally { unwrap(); observer.restore(); }
  });

  it.each(BACKGROUND_PRECEDENCE_CASES)("$title", ({ kind, expected }) => {
    const legacy = { type: "html", text: "<p>legacy fallback</p>" };
    let body: any = { style: { background: legacy } };
    if (kind === "false-canonical") body.background = false;
    else if (kind === "malformed-canonical") body.background = { type: "label", text: "bad" };
    else if (kind === "source-less-canonical") body.background = { type: "html" };
    else if (kind === "null-canonical") body.background = null;
    else if (kind === "undefined-canonical") body.background = undefined;
    else if (kind === "inherited-canonical") body = Object.assign(Object.create({ background: { type: "html", text: "bad" } }), body);
    else if (kind === "inherited-style") body = Object.create({ style: { background: legacy } });
    else if (kind === "inherited-legacy") body = { style: Object.create({ background: legacy }) };
    else if (kind === "inherited-canonical-none") body = Object.create({ background: { type: "html", text: "bad" } });
    else if (kind === "missing") body = {};
    const { observer, root, cleanup } = renderBackground(body);
    try {
      const iframe = root.querySelector("iframe.jasonette-background-web") as HTMLIFrameElement | null;
      if (expected === "legacy") expectBackgroundIframe(root, observer, "srcdoc", "<p>legacy fallback</p>");
      else {
        expect(iframe).toBeNull();
        expect(observer.traces).toEqual([]);
      }
    } finally { cleanup(); }
  });

  it.each(BACKGROUND_MATRIX_CASES)("$title", ({ path, id, source, expected }) => {
    const { background, spies } = matrixBackground(id);
    const slot = path === "canonical" ? { background } : { style: { background } };
    const { observer, root, cleanup } = renderBackground(slot);
    try {
      if (source === "none") {
        expect(root.querySelector("iframe.jasonette-background-web")).toBeNull();
        expect(observer.traces).toEqual([]);
      } else {
        const iframe = expectBackgroundIframe(root, observer, source, expected);
        if (source === "srcdoc" && id.includes("CSS escape")) {
          expect(iframe.srcdoc).toBe(expected);
          expect(iframe.srcdoc.codePointAt(iframe.srcdoc.indexOf("\\"))).toBe(0x5c);
        }
      }
      for (const spy of spies) expect(spy).not.toHaveBeenCalled();
    } finally { cleanup(); }
  });

  it("background RETURN is captured at the runtime-wrapped renderBodyBackground method boundary", () => {
    const observer = installSecurityObserver();
    const { renderer, root } = createRenderer();
    const unwrap = wrapBackgroundBoundary(renderer, observer);
    try {
      renderDocumentObserved(renderer, staticDocument(foregroundBody({ background: { type: "html", text: "<p>boundary</p>" } })), observer);
      const iframe = root.querySelector("iframe.jasonette-background-web") as HTMLIFrameElement;
      expect(observer.traceFor(iframe).events.at(-1)).toBe("RETURN");
      observer.assertExactTraceSet([{ iframe, kind: "background", source: "srcdoc" }]);
    } finally { unwrap(); observer.restore(); }
  });

  it("malformed selected background never creates a transient iframe", () => {
    const { observer, root, cleanup } = renderBackground({ background: { type: "html", text: 17, url: { href: "bad" } } });
    try {
      expect(root.querySelector("iframe")).toBeNull();
      expect(observer.traces).toEqual([]);
    } finally { cleanup(); }
  });
});
