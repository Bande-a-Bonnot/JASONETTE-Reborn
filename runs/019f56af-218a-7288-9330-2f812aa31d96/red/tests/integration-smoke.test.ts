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
import { PRODUCTION_BODY_PIPELINE_CASES } from "./case-catalog.mjs";

const locationItems = (path: string) => [
  {
    type: "html",
    text: `<p data-red-location="${path}">{{$jason.secret}}</p>`,
    css: "p{line-height:{{$jason.height}}px}",
    style: { height: "{{$jason.height}}" },
  },
  { type: "html", url: "{{$jason.url}}" },
  { type: "label", text: `${path}-{{$jason.label}}` },
];

const rootBackground = (path: string) => ({
  type: "html",
  text: `<p data-red-location="${path}">{{$jason.secret}}</p>`,
  css: "p{line-height:{{$jason.height}}px}",
});

function productionPipelineTemplate(path: string) {
  if (path === "body-root") return {
    style: { background: rootBackground(path) },
    sections: [{ items: [{ type: "label", text: "body-root-{{$jason.label}}" }] }],
  };
  if (path === "header") return { header: { items: locationItems(path) }, sections: [] };
  if (path === "footer") return { sections: [], footer: { items: locationItems(path) } };
  if (path === "section") return { sections: [{ items: locationItems(path) }] };
  if (path === "layout") return {
    sections: [{ items: [{ type: "vertical", items: locationItems(path) }] }],
  };
  if (path === "layer") return {
    sections: [{ items: [{ type: "label", text: "layer-foreground" }] }],
    layers: [{ type: "vertical", items: locationItems(path) }],
  };
  if (path === "background") return {
    background: rootBackground(path),
    sections: [{ items: [{ type: "label", text: "background-{{$jason.label}}" }] }],
  };
  if (path === "nested-array") return {
    sections: [{ items: [[[...locationItems(path)]]] }],
  };
  if (path === "directive") return {
    sections: [{ items: [{ "{{#if $jason.enabled}}": locationItems(path) }] }],
  };
  if (path === "action") return {
    sections: [{ items: [{
      type: "label",
      text: "run-action-{{$jason.label}}",
      action: {
        type: "{{$jason.actionType}}",
        options: { actionObjectReached: "{{$jason.label}}" },
      },
    }] }],
  };
  if (path === "action-options") return {
    sections: [{ items: [{
      type: "label",
      text: "run-action-options-{{$jason.label}}",
      action: {
        type: "$set",
        options: {
          actionOptionsProbe: {
            type: "html",
            text: "{{$jason.secret}}",
            style: { height: "{{$jason.height}}" },
          },
        },
      },
    }] }],
  };
  if (path === "action-payload") return {
    sections: [{ items: [{
      type: "label",
      text: "run-action-payload-{{$jason.label}}",
      action: {
        type: "$set",
        options: {
          actionPayloadProbe: {
            payload: {
              type: "html",
              text: "{{$jason.secret}}",
              style: { height: "{{$jason.height}}" },
            },
          },
        },
      },
    }] }],
  };
  throw new Error(`unknown production pipeline path ${path}`);
}

function exactLabel(root: HTMLElement, text: string) {
  const matches = Array.from(root.querySelectorAll(".jasonette-label"))
    .filter((node) => node.textContent === text) as HTMLElement[];
  expect(matches).toHaveLength(1);
  return matches[0];
}

function markedComponent(root: HTMLElement, path: string) {
  const matches = Array.from(root.querySelectorAll(".jasonette-html iframe[srcdoc]"))
    .filter((node) => node.getAttribute("srcdoc")?.includes(`data-red-location="${path}"`)) as HTMLIFrameElement[];
  expect(matches).toHaveLength(1);
  return matches[0];
}

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
  it.each(PRODUCTION_BODY_PIPELINE_CASES)("$title", async ({ path }) => {
    const observer = installSecurityObserver();
    const { renderer, root } = createRenderer();
    const unwrap = wrapBackgroundBoundary(renderer, observer);
    const data = (phase: "first" | "second", height: number) => ({
      enabled: true,
      actionType: "$set",
      secret: phase === "first" ? "FIRST-LEAK" : "SECOND-LEAK",
      label: phase,
      height,
      url: `https://example.com/${path}-${phase}.html`,
    });
    const isRenderedControl = path.startsWith("action");
    const isRootBackground = path === "body-root" || path === "background";
    const isComponentLocation = !isRenderedControl && !isRootBackground;
    const expectedPhaseLabel = (phase: "first" | "second") => isRenderedControl
      ? `run-${path}-${phase}`
      : `${path}-${phase}`;
    const assertComponentBoundary = (phase: "first" | "second", height: number) => {
      const inline = markedComponent(root, path);
      const remoteMatches = Array.from(root.querySelectorAll(".jasonette-html iframe[src]")) as HTMLIFrameElement[];
      expect(remoteMatches).toHaveLength(1);
      const remote = remoteMatches[0];
      expect(remote.getAttribute("src")).toBe(`https://example.com/${path}-${phase}.html`);
      expect(inline.getAttribute("srcdoc")).toContain("{{$jason.secret}}");
      expect(inline.getAttribute("srcdoc")).toContain(`line-height:${height}px`);
      expect((inline.parentElement as HTMLElement).style.height).toBe(`${height}px`);
      expect(remote.hasAttribute("srcdoc")).toBe(false);
      exactLabel(root, expectedPhaseLabel(phase));
    };
    const assertRootBackgroundBoundary = (phase: "first" | "second", height: number) => {
      const matches = Array.from(root.querySelectorAll("iframe.jasonette-background-web"))
        .filter((node) => node.getAttribute("srcdoc")?.includes(`data-red-location="${path}"`)) as HTMLIFrameElement[];
      expect(matches).toHaveLength(1);
      const background = matches[0];
      expect(background.parentNode).toBe(root);
      expect(background.srcdoc).toContain("{{$jason.secret}}");
      expect(background.srcdoc).toContain(`line-height:${height}px`);
      expect(background.hasAttribute("src")).toBe(false);
      exactLabel(root, `${path}-${phase}`);
      expect(root.querySelector(".jasonette-html")).toBeNull();
    };
    const clickActionBoundary = async (phase: "first" | "second", height: number) => {
      exactLabel(root, `run-${path}-${phase}`).click();
      await Promise.resolve();
      if (path === "action") {
        expect(renderer.getState().local.actionObjectReached).toBe(phase);
      } else if (path === "action-options") {
        const stored = renderer.getState().local.actionOptionsProbe;
        expect(stored.type).toBe("html");
        expect(stored.text).toBe("{{$jason.secret}}");
        expect(stored.style.height).toBe(height);
      } else {
        const stored = renderer.getState().local.actionPayloadProbe.payload;
        expect(stored.type).toBe("html");
        expect(stored.text).toBe("{{$jason.secret}}");
        expect(stored.style.height).toBe(height);
      }
    };
    const assertBoundary = async (phase: "first" | "second", height: number) => {
      if (isRootBackground) {
        assertRootBackgroundBoundary(phase, height);
      } else if (isRenderedControl) {
        await clickActionBoundary(phase, height);
      } else {
        assertComponentBoundary(phase, height);
      }
    };
    const assertReplacementExclusivity = (initialUrls: string[]) => {
      const currentUrlIframes = Array.from(root.querySelectorAll("iframe[src]")) as HTMLIFrameElement[];
      expect(currentUrlIframes).toHaveLength(isComponentLocation ? 1 : 0);
      for (const initialUrl of initialUrls) {
        expect(currentUrlIframes.some((iframe) => iframe.getAttribute("src") === initialUrl)).toBe(false);
      }
      if (isComponentLocation) {
        const replacement = currentUrlIframes[0];
        expect(replacement.getAttribute("src")).toBe(`https://example.com/${path}-second.html`);
        expect(replacement.hasAttribute("srcdoc")).toBe(false);
      }

      const currentLabels = Array.from(root.querySelectorAll(".jasonette-label"))
        .map((node) => node.textContent);
      const expectedLabels = path === "layer"
        ? ["layer-foreground", expectedPhaseLabel("second")]
        : [expectedPhaseLabel("second")];
      expect([...currentLabels].sort()).toEqual([...expectedLabels].sort());
      expect(currentLabels).not.toContain(expectedPhaseLabel("first"));
    };
    try {
      renderDocumentObserved(
        renderer,
        templatedDocument(productionPipelineTemplate(path) as any, data("first", 31)),
        observer,
      );
      await assertBoundary("first", 31);
      const initialUrls = Array.from(root.querySelectorAll("iframe[src]"))
        .map((iframe) => iframe.getAttribute("src"))
        .filter((url): url is string => url !== null);
      await observer.withIntegratedComponentBoundaryAsync(() => executeAction({
        type: "$render",
        options: { data: data("second", 62) },
      } as any, renderer.getState()));
      await assertBoundary("second", 62);
      assertReplacementExclusivity(initialUrls);
    } finally { unwrap(); observer.restore(); }
  });

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
      expect(background.compareDocumentPosition(component) & Node.DOCUMENT_POSITION_FOLLOWING).not.toBe(0);
      observer.assertExactTraceSet([
        { iframe: component, kind: "component", source: "srcdoc" },
        { iframe: background, kind: "background", source: "srcdoc" },
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
