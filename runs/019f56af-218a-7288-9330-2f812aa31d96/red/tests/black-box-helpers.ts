import { JasonetteRenderer, renderComponent } from "@jasonette/web";
import type { SecurityObserver } from "./security-observer";

export function createRenderer() {
  const root = document.createElement("div");
  document.body.appendChild(root);
  const renderer = new (JasonetteRenderer as any)(root);
  return { renderer, root };
}

export function staticDocument(body: Record<string, unknown>) {
  return {
    $jason: {
      head: { title: "Red boundary fixture" },
      body,
    },
  };
}

export function templatedDocument(template: Record<string, unknown>, data: Record<string, unknown>) {
  return {
    $jason: {
      head: {
        title: "Red boundary template",
        templates: { body: template },
      },
      body: data,
    },
  };
}

export function renderComponentAtBoundary(component: unknown, observer?: SecurityObserver) {
  if (!observer) return (renderComponent as any)(component);
  const returned = observer.withKind("component", () => (renderComponent as any)(component)) as HTMLElement;
  observer.markComponentReturn(returned);
  return returned;
}

export function wrapBackgroundBoundary(renderer: any, observer: SecurityObserver) {
  const original = renderer.renderBodyBackground;
  if (typeof original !== "function") {
    throw new Error("JasonetteRenderer.renderBodyBackground must be runtime-wrappable at the NLSpec boundary");
  }
  Object.defineProperty(renderer, "renderBodyBackground", {
    configurable: true,
    writable: true,
    value: function observedRenderBodyBackground(this: unknown, ...args: unknown[]) {
      const result = observer.withKind("background", () => original.apply(this, args));
      observer.markBackgroundReturn();
      return result;
    },
  });
  return () => {
    delete renderer.renderBodyBackground;
  };
}

export function renderDocumentObserved(renderer: any, appDocument: unknown, observer: SecurityObserver) {
  return observer.withIntegratedComponentBoundary(() => renderer.renderDocument(appDocument));
}

export function ownData(object: object, key: string, value: unknown) {
  Object.defineProperty(object, key, {
    value,
    enumerable: true,
    writable: true,
    configurable: true,
  });
  return object;
}

export function expectSafeOwn(expect: any, object: object, key: string, value: unknown) {
  expect(Object.getPrototypeOf(object)).toBe(Object.prototype);
  expect(Object.hasOwn(object, key)).toBe(true);
  expect(Object.getOwnPropertyDescriptor(object, key)).toEqual({
    value,
    enumerable: true,
    writable: true,
    configurable: true,
  });
}

export function foregroundBody(extra: Record<string, unknown> = {}) {
  return {
    ...extra,
    sections: [{ items: [{ type: "label", text: "foreground" }] }],
  };
}
