// @vitest-environment jsdom
// @ts-nocheck
import { beforeEach, describe, expect, it } from "vitest";
import { transform } from "@jasonette/template-engine";
import { executeAction } from "@jasonette/web";
import jasonpedia from "../support/fixtures/jasonpedia-html-index.json";
import {
  createRenderer,
  foregroundBody,
  renderDocumentObserved,
  templatedDocument,
  wrapBackgroundBoundary,
} from "./black-box-helpers";
import { installSecurityObserver } from "./security-observer";

const integrationTemplate = {
  sections: [{
    items: [
      {
        type: "{{$jason.kind}}",
        text: "<script>window.__html_boundary = \"{{$jason.secret}}\"</script>",
        style: { height: "{{$jason.height}}" },
      },
      { type: "label", text: "{{$jason.label}}" },
    ],
  }],
};

beforeEach(() => document.body.replaceChildren());

describe("renderer integration", () => {
  it("integration smoke: initial render actual $render generic action and all iframe traces stay live", async () => {
    const observer = installSecurityObserver();
    const { renderer, root } = createRenderer();
    const unwrap = wrapBackgroundBoundary(renderer, observer);
    try {
      const appDocument = templatedDocument(integrationTemplate, {
        kind: "html", secret: "LEAK", height: 40, label: "first",
      });
      renderDocumentObserved(renderer, appDocument, observer);
      const first = root.querySelector(".jasonette-html iframe") as HTMLIFrameElement;
      expect(first).not.toBeNull();
      expect(first.srcdoc).toContain('<script>window.__html_boundary = "{{$jason.secret}}"</script>');
      expect((root.querySelector(".jasonette-html") as HTMLElement).style.height).toBe("40px");
      expect(root.querySelector(".jasonette-label")!.textContent).toBe("first");
      expect(first.getAttribute("sandbox")).toBe("allow-scripts");
      expect(first.hasAttribute("src")).toBe(false);
      observer.assertExactTraceSet([{ iframe: first, kind: "component", source: "srcdoc" }]);

      await observer.withIntegratedComponentBoundaryAsync(() => executeAction({
        type: "$render",
        options: { data: { kind: "html", secret: "SECOND", height: 80, label: "second" } },
      } as any, renderer.getState()));

      const second = root.querySelector(".jasonette-html iframe") as HTMLIFrameElement;
      expect(second).not.toBe(first);
      expect((root.querySelector(".jasonette-html") as HTMLElement).style.height).toBe("80px");
      expect(root.querySelector(".jasonette-label")!.textContent).toBe("second");
      expect(second.srcdoc).toContain("{{$jason.secret}}");
      expect(second.srcdoc).not.toContain("SECOND");
      expect(first.isConnected).toBe(false);
      expect(first.getAttribute("sandbox")).toBe("allow-scripts");
      expect(second.getAttribute("sandbox")).toBe("allow-scripts");
      observer.assertExactTraceSet([
        { iframe: first, kind: "component", source: "srcdoc" },
        { iframe: second, kind: "component", source: "srcdoc" },
      ]);

      expect(transform({ type: "html", text: "{{secret}}" }, { secret: "GENERIC" }).text).toBe("GENERIC");
      await executeAction({
        type: "$set",
        options: { probe: { type: "html", text: "{{$jason.value}}" } },
      } as any, renderer.getState(), { value: "ACTION" } as any);
      expect(renderer.getState().local.probe.text).toBe("ACTION");
      observer.assertExactTraceSet([
        { iframe: first, kind: "component", source: "srcdoc" },
        { iframe: second, kind: "component", source: "srcdoc" },
      ]);
    } finally { unwrap(); observer.restore(); }
  });

  it("Jasonpedia fixture renders actual iframe srcdoc with authored CSS and Nexus content", () => {
    const observer = installSecurityObserver();
    const { renderer, root } = createRenderer();
    const unwrap = wrapBackgroundBoundary(renderer, observer);
    try {
      renderDocumentObserved(renderer, jasonpedia as any, observer);
      const iframe = root.querySelector(".jasonette-html iframe") as HTMLIFrameElement;
      expect(iframe).not.toBeNull();
      expect(iframe.srcdoc).toContain("img{width: 100%;}");
      expect(iframe.srcdoc).toContain("Nexus devices");
      expect(iframe.getAttribute("sandbox")).toBe("allow-scripts");
      observer.assertExactTraceSet([{ iframe, kind: "component", source: "srcdoc" }]);
    } finally { unwrap(); observer.restore(); }
  });

  it("rendered HTML keeps authored script and CSS while an ordinary sibling interpolates", () => {
    const observer = installSecurityObserver();
    const { renderer, root } = createRenderer();
    const unwrap = wrapBackgroundBoundary(renderer, observer);
    try {
      const template = {
        background: {
          type: "html",
          text: "<script>window.raw='{{$jason.secret}}'</script>",
          css: "body{color:{{$jason.color}}}",
        },
        sections: [{ items: [
          { type: "html", text: "<p>{{$jason.secret}}</p>", css: "p{height:{{$jason.height}}px}" },
          { type: "label", text: "{{$jason.label}}" },
        ] }],
      };
      renderDocumentObserved(renderer, templatedDocument(template, {
        secret: "LEAK", color: "red", height: 7, label: "ordinary",
      }), observer);
      const background = root.querySelector("iframe.jasonette-background-web") as HTMLIFrameElement;
      const component = root.querySelector(".jasonette-html iframe") as HTMLIFrameElement;
      expect(background.srcdoc).toBe("<style>body{color:red}</style><script>window.raw='{{$jason.secret}}'</script>");
      expect(component.srcdoc).toBe("<style>p{height:7px}</style><p>{{$jason.secret}}</p>");
      expect(root.querySelector(".jasonette-label")!.textContent).toBe("ordinary");
      observer.assertExactTraceSet([
        { iframe: background, kind: "background", source: "srcdoc" },
        { iframe: component, kind: "component", source: "srcdoc" },
      ]);
    } finally { unwrap(); observer.restore(); }
  });

  it("actual $render replaces a background iframe while old and new sandbox endpoints remain exact", async () => {
    const observer = installSecurityObserver();
    const { renderer, root } = createRenderer();
    const unwrap = wrapBackgroundBoundary(renderer, observer);
    try {
      const template = foregroundBody({
        background: { type: "html", url: "{{$jason.backgroundUrl}}" },
      });
      renderDocumentObserved(renderer, templatedDocument(template, {
        backgroundUrl: "https://example.com/first-background.html",
      }), observer);
      const first = root.querySelector("iframe.jasonette-background-web") as HTMLIFrameElement;
      observer.assertExactTraceSet([{ iframe: first, kind: "background", source: "src" }]);
      await observer.withIntegratedComponentBoundaryAsync(() => executeAction({
        type: "$render",
        options: { data: { backgroundUrl: "https://example.com/second-background.html" } },
      } as any, renderer.getState()));
      const second = root.querySelector("iframe.jasonette-background-web") as HTMLIFrameElement;
      expect(second).not.toBe(first);
      expect(first.isConnected).toBe(false);
      expect(first.getAttribute("sandbox")).toBe("allow-scripts");
      expect(second.getAttribute("sandbox")).toBe("allow-scripts");
      expect(second.getAttribute("src")).toBe("https://example.com/second-background.html");
      expect(second.hasAttribute("srcdoc")).toBe(false);
      observer.assertExactTraceSet([
        { iframe: first, kind: "background", source: "src" },
        { iframe: second, kind: "background", source: "src" },
      ]);
    } finally { unwrap(); observer.restore(); }
  });

  it("emitted iframe policy is exact and makes no browser-enforcement assertion", () => {
    const observer = installSecurityObserver();
    const { renderer, root } = createRenderer();
    const unwrap = wrapBackgroundBoundary(renderer, observer);
    try {
      renderDocumentObserved(renderer, templatedDocument(integrationTemplate, {
        kind: "html", secret: "LEAK", height: 40, label: "first",
      }), observer);
      const iframe = root.querySelector("iframe") as HTMLIFrameElement;
      expect(iframe.getAttribute("sandbox")).toBe("allow-scripts");
      expect(iframe.getAttribute("sandbox")!.split(/\s+/)).toEqual(["allow-scripts"]);
      observer.assertExactTraceSet([{ iframe, kind: "component", source: "srcdoc" }]);
    } finally { unwrap(); observer.restore(); }
  });
});
