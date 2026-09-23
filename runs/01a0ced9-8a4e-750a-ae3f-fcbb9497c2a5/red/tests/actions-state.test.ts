// @vitest-environment jsdom
// @ts-nocheck
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { renderSync } from "@jasonette/template-engine";
import { executeAction } from "@jasonette/web";
import {
  ACTION_TYPE_CASES,
  INHERITED_TRIGGER_CASES,
  NAMED_ACTION_ARRAY_CASES,
  NAMED_ACTION_CASES,
  NON_STRING_OWN_TRIGGER_CASES,
  SESSION_DOMAIN_CASES,
  SINK_CASES,
} from "./case-catalog.mjs";
import { createRenderer, expectSafeOwn, ownData } from "./black-box-helpers";

function freshState() {
  return createRenderer().renderer.getState();
}

function dangerousOptions(extra: Record<string, unknown> = {}) {
  const options: any = { ...extra };
  ownData(options, "__proto__", "proto-data");
  ownData(options, "constructor", "constructor-data");
  ownData(options, "prototype", "prototype-data");
  return options;
}

function expectDangerousDestination(destination: any) {
  expectSafeOwn(expect, destination, "__proto__", "proto-data");
  expectSafeOwn(expect, destination, "constructor", "constructor-data");
  expectSafeOwn(expect, destination, "prototype", "prototype-data");
}

beforeEach(() => {
  document.body.replaceChildren();
});

afterEach(() => {
  vi.unstubAllGlobals();
  for (const key of ["redInheritedAction", "redInheritedNamed", "redInheritedOnlyAction"])
    delete (Object.prototype as any)[key];
});

describe("generic action transforms and safe state boundaries", () => {
  it("production $set action options use generic interpolation at action time", async () => {
    const state = freshState();
    await executeAction({
      type: "$set",
      options: { probe: { type: "html", text: "{{$jason.value}}" } },
    } as any, state, { value: "ACTION" } as any);
    expect(state.local.probe.text).toBe("ACTION");
  });

  it("an embedded raw body action interpolates when its separate action phase executes", async () => {
    const state = freshState();
    const embedded = {
      type: "$set",
      options: { probe: { type: "html", text: "{{$jason.value}}" } },
    };
    const transformed = renderSync(
      embedded,
      { $jason: { value: "BODY" } },
      { preserveHtmlText: true },
    );
    expect(transformed.options.probe.text).toBe("{{$jason.value}}");
    await executeAction(transformed as any, state, { value: "LATER" } as any);
    expect(state.local.probe).toEqual({ type: "html", text: "LATER" });
  });

  it("controlled success continuation transforms HTML-shaped options generically in key/value order", async () => {
    const state = freshState();
    const order: string[] = [];
    const payload: any = {};
    const controlled = (key: string, value: unknown) => Object.defineProperty(payload, key, {
      enumerable: true,
      get() {
        order.push(key);
        return value;
      },
    });
    controlled("destinationKey", "continuationProbe");
    controlled("typeKey", "type");
    controlled("kind", "html");
    controlled("textKey", "text");
    controlled("secret", "CONTINUED");
    controlled("heightKey", "height");
    controlled("height", 12);

    const response = new Response("{}", {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
    vi.spyOn(response, "json").mockResolvedValue(payload);
    const fetchHandler = vi.fn(async () => response);
    vi.stubGlobal("fetch", fetchHandler);

    state.actions = {};
    ownData(state.actions, "redControlledSuccess", {
      type: "$network.request",
      options: { url: "https://continuation.example.com/payload" },
      success: {
        type: "$set",
        options: {
          "{{$jason.destinationKey}}": {
            "{{$jason.typeKey}}": "{{$jason.kind}}",
            "{{$jason.textKey}}": "<p>{{$jason.secret}}</p>",
            style: { "{{$jason.heightKey}}": "{{$jason.height}}" },
          },
        },
      },
    });

    await executeAction({ trigger: "redControlledSuccess" } as any, state);
    expect(fetchHandler).toHaveBeenCalledTimes(1);
    expect(order).toEqual([
      "destinationKey", "typeKey", "kind", "textKey", "secret", "heightKey", "height",
    ]);
    expect(state.local.continuationProbe).toEqual({
      type: "html", text: "<p>CONTINUED</p>", style: { height: 12 },
    });
  });

  it.each(SINK_CASES)("$title", async ({ actionType, destination }) => {
    const state = freshState();
    await executeAction({ type: actionType, options: dangerousOptions() } as any, state);
    expectDangerousDestination(state[destination]);
  });

  it("safe state sinks accept a null-prototype options object", async () => {
    const state = freshState();
    const options = Object.create(null);
    options.nullPrototypeProbe = "supported";
    await executeAction({ type: "$set", options } as any, state);
    expect(state.local.nullPrototypeProbe).toBe("supported");
    expect(Object.getPrototypeOf(state.local)).toBe(Object.prototype);
  });

  it("session storage safely copies dangerous option keys into a fresh ordinary object", async () => {
    const state = freshState();
    const options = dangerousOptions({ domain: "safe.example.com", header: { "X-Probe": "stored" } });
    await executeAction({ type: "$session.set", options } as any, state);
    const stored = state.sessions["safe.example.com"];
    expect(stored).not.toBe(options);
    expectDangerousDestination(stored);
    expect(Object.getPrototypeOf(state.sessions)).toBe(Object.prototype);
  });

  it.each(SESSION_DOMAIN_CASES)("$title", async ({ domain }) => {
    const state = freshState();
    await executeAction({ type: "$session.set", options: { domain, marker: `stored-${domain}` } } as any, state);
    expect(Object.getPrototypeOf(state.sessions)).toBe(Object.prototype);
    expectSafeOwn(expect, state.sessions, domain, state.sessions[domain]);
    expect(Object.getPrototypeOf(state.sessions[domain])).toBe(Object.prototype);
    expect(state.sessions[domain].marker).toBe(`stored-${domain}`);
  });

  it("session storage accepts null-prototype transformed options", async () => {
    const state = freshState();
    const options = Object.create(null);
    options.domain = "null-options.example.com";
    options.header = { "X-Null": "accepted" };
    await executeAction({ type: "$session.set", options } as any, state);
    expect(state.sessions["null-options.example.com"].header).toEqual({ "X-Null": "accepted" });
    expect(Object.getPrototypeOf(state.sessions["null-options.example.com"])).toBe(Object.prototype);
  });

  it("own session decorates a request through a concrete Headers instance", async () => {
    const state = freshState();
    ownData(state.sessions, "api.example.com", { header: { "X-Session": "own-value" } });
    const fetchSpy = vi.fn(async () => new Response(JSON.stringify({ ok: true }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    }));
    vi.stubGlobal("fetch", fetchSpy);
    await executeAction({
      type: "$network.request",
      options: { url: "https://api.example.com/resource", header: { "X-Request": "request-value" } },
    } as any, state);
    expect(fetchSpy).toHaveBeenCalledTimes(1);
    const init = fetchSpy.mock.calls[0][1] as RequestInit;
    expect(init.headers).toBeInstanceOf(Headers);
    const headers = init.headers as Headers;
    expect(headers.get("X-Session")).toBe("own-value");
    expect(headers.get("X-Request")).toBe("request-value");
  });

  it("inherited session domain cannot decorate request headers or body", async () => {
    const state = freshState();
    const inheritedSession = {
      header: { "X-Inherited-Session": "must-not-appear" },
      body: { inheritedBodySentinel: "must-not-appear" },
    };
    state.sessions = Object.create({ "api.example.com": inheritedSession });
    const fetchSpy = vi.fn(async () => new Response(JSON.stringify({ ok: true }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    }));
    vi.stubGlobal("fetch", fetchSpy);
    await executeAction({
      type: "$network.request",
      options: {
        url: "https://api.example.com/resource",
        method: "POST",
        header: { "X-Own-Request": "kept-exactly" },
        data: { own: "kept" },
      },
    } as any, state);
    expect(fetchSpy).toHaveBeenCalledTimes(1);
    const init = fetchSpy.mock.calls[0][1] as RequestInit;
    const headers = new Headers(init.headers);
    expect(headers.get("X-Own-Request")).toBe("kept-exactly");
    expect(headers.has("X-Inherited-Session")).toBe(false);
    expect(init.body).toBeDefined();
    expect(String(init.body)).toContain("kept");
    expect(String(init.body)).not.toContain("inheritedBodySentinel");
    expect(String(init.body)).not.toContain("must-not-appear");
  });
});

describe("own action and named-action dispatch", () => {
  it.each(ACTION_TYPE_CASES)("$title", async ({ kind }) => {
    const state = freshState();
    const continuation = { type: "$set", options: { continuationWasCalled: true } };
    const inheritedHandler = vi.fn();
    const sameKeyCandidate = ["toString", "constructor", "__proto__", "prototype", "redInheritedOnlyAction"].includes(kind);
    const inheritedKey = sameKeyCandidate ? kind : "redInheritedAction";
    const original = Object.getOwnPropertyDescriptor(Object.prototype, inheritedKey);
    Object.defineProperty(Object.prototype, inheritedKey, {
      value: inheritedHandler, enumerable: false, writable: true, configurable: true,
    });
    let action: any;
    if (kind === "missing") action = { success: continuation };
    else if (kind === "inherited") action = Object.assign(Object.create({ type: "redInheritedAction" }), { success: continuation });
    else if (kind === "non-string") action = { type: 7, success: continuation };
    else action = { type: kind, success: continuation };
    let result: unknown;
    try {
      result = await executeAction(action, state);
    } finally {
      if (original) Object.defineProperty(Object.prototype, inheritedKey, original);
      else delete (Object.prototype as any)[inheritedKey];
    }
    expect(result).toBeUndefined();
    expect(inheritedHandler).not.toHaveBeenCalled();
    expect(state.local.continuationWasCalled).not.toBe(true);
  });

  it("inherited action type plus own trigger falls through to the own named action", async () => {
    const state = freshState();
    state.actions = {};
    ownData(state.actions, "runOwnTrigger", { type: "$set", options: { triggerFallback: "called" } });
    const inheritedHandler = vi.fn();
    const original = Object.getOwnPropertyDescriptor(Object.prototype, "redInheritedAction");
    let observations: any;
    ownData(Object.prototype, "redInheritedAction", inheritedHandler);
    try {
      const action = Object.assign(Object.create({ type: "redInheritedAction" }), { trigger: "runOwnTrigger" });
      await executeAction(action, state);
      observations = {
        inheritedCallCount: inheritedHandler.mock.calls.length,
        triggerFallback: state.local.triggerFallback,
      };
    } finally {
      if (original) Object.defineProperty(Object.prototype, "redInheritedAction", original);
      else delete (Object.prototype as any).redInheritedAction;
    }
    expect(observations.inheritedCallCount).toBe(0);
    expect(observations.triggerFallback).toBe("called");
  });

  it.each(NON_STRING_OWN_TRIGGER_CASES)("$title", async ({ name }) => {
    const state = freshState();
    state.actions = {};
    ownData(state.actions, name, { type: "$set", options: { nonStringTriggerResult: name } });
    await executeAction({ type: 17, trigger: name } as any, state);
    expect(state.local.nonStringTriggerResult).toBe(name);
  });

  it.each(INHERITED_TRIGGER_CASES)("$title", async ({ name }) => {
    const state = freshState();
    state.actions = {};
    ownData(state.actions, name, { type: "$set", options: { inheritedTriggerRan: name } });
    const action = Object.create({ trigger: name });
    const result = await executeAction(action as any, state);
    expect(result).toBeUndefined();
    expect(state.local.inheritedTriggerRan).toBeUndefined();
  });

  it.each(NAMED_ACTION_CASES)("$title", async ({ dispatch, ownership, name }) => {
    const state = freshState();
    const inheritedHandler = vi.fn();
    const original = Object.getOwnPropertyDescriptor(Object.prototype, "redInheritedNamed");
    let observations: any;
    ownData(Object.prototype, "redInheritedNamed", inheritedHandler);
    try {
      const named = { type: "$set", options: { namedDispatchResult: `${dispatch}-${name}` } };
      if (ownership === "own") {
        state.actions = {};
        ownData(state.actions, name, named);
      } else {
        const inheritedNamed = { type: "redInheritedNamed" };
        const prototype: any = {};
        ownData(prototype, name, inheritedNamed);
        state.actions = Object.create(prototype);
      }
      const action = dispatch === "trigger"
        ? { trigger: name }
        : { type: "$lambda", options: { name } };
      const result = await executeAction(action as any, state);
      observations = {
        result,
        namedDispatchResult: state.local.namedDispatchResult,
        inheritedCallCount: inheritedHandler.mock.calls.length,
      };
    } finally {
      if (original) Object.defineProperty(Object.prototype, "redInheritedNamed", original);
      else delete (Object.prototype as any).redInheritedNamed;
    }
    if (ownership === "own") {
      expect(observations.namedDispatchResult).toBe(`${dispatch}-${name}`);
    } else {
      expect(observations.result).toBeUndefined();
      expect(observations.namedDispatchResult).toBeUndefined();
    }
    expect(observations.inheritedCallCount).toBe(0);
  });

  it.each(NAMED_ACTION_ARRAY_CASES)("$title", async ({ dispatch }) => {
    const state = freshState();
    state.actions = {};
    ownData(state.actions, "arrayAction", [
      { type: "$set", options: { namedArrayFirstEffect: "first-authored-entry" } },
      { type: "$set", options: { namedArraySecondEffect: "second-authored-entry" } },
    ]);
    const action = dispatch === "trigger"
      ? { trigger: "arrayAction" }
      : { type: "$lambda", options: { name: "arrayAction" } };
    await executeAction(action as any, state);
    expect(state.local.namedArrayFirstEffect).toBe("first-authored-entry");
    expect(state.local.namedArraySecondEffect).toBe("second-authored-entry");
  });
});
