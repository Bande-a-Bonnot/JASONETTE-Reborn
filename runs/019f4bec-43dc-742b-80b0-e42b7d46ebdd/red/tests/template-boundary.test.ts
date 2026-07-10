// @vitest-environment jsdom
// @ts-nocheck
import { describe, expect, it, vi } from "vitest";
import { renderSync, transform } from "@jasonette/template-engine";
import {
  BODY_RECURSION_CASES,
  DANGEROUS_ORDER_CASES,
  DANGEROUS_TRANSFORM_CASES,
  DIRECTIVE_CASES,
  NON_PROTECTING_TYPE_CASES,
  TRANSFORM_EXACT_CASES,
  TYPE_COLLISION_CASES,
} from "./case-catalog.mjs";
import { expectSafeOwn, ownData } from "./black-box-helpers";

const bodyOptions = { preserveHtmlText: true };

function exactVector(vector: string) {
  switch (vector) {
    case "literal-html":
      return [
        { type: "html", text: "<p>{{secret}}</p>", style: { height: "{{height}}" } },
        { secret: "LEAK", height: 40 },
        bodyOptions,
        { type: "html", text: "<p>{{secret}}</p>", style: { height: 40 } },
      ];
    case "resolved-both":
      return [
        { type: "{{kind}}", "{{slot}}": "<p>{{secret}}</p>" },
        { kind: "html", slot: "text", secret: "LEAK" },
        bodyOptions,
        { type: "html", text: "<p>{{secret}}</p>" },
      ];
    case "resolved-type":
      return [
        { "{{typeKey}}": "{{kind}}", text: "{{secret}}" },
        { typeKey: "type", kind: "html", secret: "LEAK" },
        bodyOptions,
        { type: "html", text: "{{secret}}" },
      ];
    case "duplicate-text":
      return [
        { type: "html", "{{slot}}": "first", text: "second" },
        { slot: "text" },
        bodyOptions,
        { type: "html", text: "second" },
      ];
    case "label":
      return [
        { type: "label", text: "{{secret}}" },
        { secret: "OK" },
        bodyOptions,
        { type: "label", text: "OK" },
      ];
    case "generic":
      return [
        { type: "html", text: "{{secret}}" },
        { secret: "GENERIC" },
        undefined,
        { type: "html", text: "GENERIC" },
      ];
    case "explicit-false":
      return [
        { type: "html", text: "{{secret}}" },
        { secret: "EXPLICIT-FALSE" },
        { preserveHtmlText: false },
        { type: "html", text: "EXPLICIT-FALSE" },
      ];
    default:
      throw new Error(`unknown exact vector ${vector}`);
  }
}

function findHtml(value: unknown): any[] {
  if (Array.isArray(value)) return value.flatMap(findHtml);
  if (!value || typeof value !== "object") return [];
  const result = (value as any).type === "html" ? [value] : [];
  return result.concat(Object.keys(value as object).flatMap((key) => findHtml((value as any)[key])));
}

function nestedAt(path: string) {
  const html = { type: "html", text: "{{secret}}" };
  switch (path) {
    case "root": return html;
    case "header": return { header: html };
    case "footer": return { footer: html };
    case "section": return { sections: [{ items: [html] }] };
    case "layout": return { sections: [{ type: "vertical", items: [{ layout: html }] }] };
    case "layer": return { layers: [{ content: html }] };
    case "background": return { style: { background: html } };
    case "array": return { arbitrary: [[{ nested: html }]] };
    case "action-options": return { action: { type: "$set", options: { probe: html } } };
    case "action-payload": return { action: { type: "$set", options: { payload: { probe: html } } } };
    default: throw new Error(`unknown recursion path ${path}`);
  }
}

describe("body template transformation boundary", () => {
  it.each(TRANSFORM_EXACT_CASES)("$title", ({ vector }) => {
    const [input, context, options, expected] = exactVector(vector);
    expect(transform(input, context, options)).toEqual(expected);
  });

  it("protected raw string output is strictly equal to its input", () => {
    const raw = `<script>window.x = "{{secret}}"</script>`;
    const result = transform({ type: "html", text: raw }, { secret: "LEAK" }, bodyOptions);
    expect(result.text).toBe(raw);
  });

  it("protected raw object output retains the identical reference without recursion", () => {
    const getter = vi.fn(() => "LEAK");
    const raw = { nested: "{{secret}}" };
    Object.defineProperty(raw, "probe", { enumerable: true, get: getter });
    const result = transform({ type: "html", text: raw }, { secret: "LEAK" }, bodyOptions);
    expect(result.text).toBe(raw);
    expect(getter).not.toHaveBeenCalled();
  });

  it.each(TYPE_COLLISION_CASES)("$title", ({ finalType, expected }) => {
    const input: any = { type: finalType === "label" ? "html" : "label", text: "{{secret}}" };
    input["{{resolvedType}}"] = finalType;
    const result = transform(input, { resolvedType: "type", secret: "VISIBLE" }, bodyOptions);
    expect(result).toEqual({ type: finalType, text: expected });
  });

  it("duplicate raw text entries are never evaluated and the last authored value wins", () => {
    const first = vi.fn(() => "FIRST-EVALUATED");
    const second = vi.fn(() => "SECOND-EVALUATED");
    const input = { type: "html", "{{slot}}": "{{first}}", text: "{{second}}" };
    const result = transform(input, {
      slot: "text",
      get first() { return first(); },
      get second() { return second(); },
    }, bodyOptions);
    expect(result.text).toBe("{{second}}");
    expect(first).not.toHaveBeenCalled();
    expect(second).not.toHaveBeenCalled();
  });

  it.each(NON_PROTECTING_TYPE_CASES)("$title", ({ kind, expected }) => {
    const input: any = { text: "{{secret}}" };
    if (kind === "unresolved") input.type = "{{unknownKind}}";
    if (kind === "non-string") input.type = { value: "html" };
    const result = transform(input, { secret: "VISIBLE" }, bodyOptions);
    expect(result.text).toBe(expected);
  });

  it.each(BODY_RECURSION_CASES)("$title", ({ path }) => {
    const result = renderSync(nestedAt(path), { secret: "LEAK" }, bodyOptions);
    const htmlShapes = findHtml(result);
    expect(htmlShapes).toHaveLength(1);
    expect(htmlShapes[0].text).toBe("{{secret}}");
  });

  it.each(DIRECTIVE_CASES)("$title", ({ directive }) => {
    const html = { type: "html", text: "{{secret}}" };
    let input: any;
    let context: any;
    if (directive === "if") {
      input = { "{{#if enabled}}": html };
      context = { enabled: true, secret: "LEAK" };
    } else if (directive === "elseif") {
      input = { "{{#if first}}": { type: "label", text: "wrong" }, "{{#elseif second}}": html };
      context = { first: false, second: true, secret: "LEAK" };
    } else if (directive === "else") {
      input = { "{{#if enabled}}": { type: "label", text: "wrong" }, "{{#else}}": html };
      context = { enabled: false, secret: "LEAK" };
    } else {
      input = { "{{#each rows}}": html };
      context = { rows: [1, 2], secret: "LEAK" };
    }
    const result = renderSync(input, context, bodyOptions);
    const htmlShapes = findHtml(result);
    expect(htmlShapes.length).toBe(directive === "each" ? 2 : 1);
    for (const shape of htmlShapes) expect(shape.text).toBe("{{secret}}");
  });

  it("embedded body action options are raw immediately after body transformation", () => {
    const embedded = {
      type: "$set",
      options: { probe: { type: "html", text: "{{secret}}" } },
    };
    const result = renderSync(embedded, { secret: "BODY" }, bodyOptions);
    expect(result.options.probe.text).toBe("{{secret}}");
  });

  it("standalone transform with an unrelated option remains generic", () => {
    const result = transform(
      { type: "html", text: "{{secret}}" },
      { secret: "GENERIC" },
      { preserveFalsy: true } as any,
    );
    expect(result.text).toBe("GENERIC");
  });

  it("body mode resolves all flat keys before type and ordinary value expressions exactly once", () => {
    const log: string[] = [];
    const calls = new Map<string, number>();
    const getter = (name: string, value: unknown) => ({
      enumerable: true,
      get() {
        log.push(name);
        calls.set(name, (calls.get(name) ?? 0) + 1);
        return value;
      },
    });
    const context = {};
    for (const [name, value] of [["keyA", "alpha"], ["typeKey", "type"], ["keyB", "omega"], ["kind", "label"], ["valueA", "A"], ["valueB", "B"]])
      Object.defineProperty(context, name, getter(name as string, value));
    transform({ "{{keyA}}": "{{valueA}}", "{{typeKey}}": "{{kind}}", "{{keyB}}": "{{valueB}}" }, context, bodyOptions);
    expect(log).toEqual(["keyA", "typeKey", "keyB", "kind", "valueA", "valueB"]);
    expect(Object.fromEntries(calls)).toEqual({ keyA: 1, typeKey: 1, keyB: 1, kind: 1, valueA: 1, valueB: 1 });
  });

  it("body mode applies all-keys-first ordering independently in each nested frame", () => {
    const log: string[] = [];
    const context: any = {};
    for (const [name, value] of [["outerKey", "child"], ["tailKey", "tail"], ["innerKey", "value"], ["innerTypeKey", "type"], ["innerKind", "label"], ["innerValue", "done"], ["tailValue", "end"]]) {
      Object.defineProperty(context, name, { enumerable: true, get() { log.push(name); return value; } });
    }
    transform({ "{{outerKey}}": { "{{innerKey}}": "{{innerValue}}", "{{innerTypeKey}}": "{{innerKind}}" }, "{{tailKey}}": "{{tailValue}}" }, context, bodyOptions);
    expect(log).toEqual(["outerKey", "tailKey", "innerKey", "innerTypeKey", "innerKind", "innerValue", "tailValue"]);
  });

  it("off mode preserves per-entry key-then-value getter ordering", () => {
    const log: string[] = [];
    const context: any = {};
    for (const [name, value] of [["keyA", "alpha"], ["valueA", "A"], ["typeKey", "type"], ["kind", "label"], ["keyB", "omega"], ["valueB", "B"]]) {
      Object.defineProperty(context, name, { enumerable: true, get() { log.push(name); return value; } });
    }
    transform({ "{{keyA}}": "{{valueA}}", "{{typeKey}}": "{{kind}}", "{{keyB}}": "{{valueB}}" }, context);
    expect(log).toEqual(["keyA", "valueA", "typeKey", "kind", "keyB", "valueB"]);
  });

  it("explicit false option preserves per-entry key-then-value getter ordering", () => {
    const log: string[] = [];
    const context: any = {};
    for (const [name, value] of [["keyA", "alpha"], ["valueA", "A"], ["typeKey", "type"], ["kind", "html"], ["keyB", "omega"], ["valueB", "B"]]) {
      Object.defineProperty(context, name, { enumerable: true, get() { log.push(name); return value; } });
    }
    const result = transform(
      { "{{keyA}}": "{{valueA}}", "{{typeKey}}": "{{kind}}", "{{keyB}}": "{{valueB}}" },
      context,
      { preserveHtmlText: false },
    );
    expect(log).toEqual(["keyA", "valueA", "typeKey", "kind", "keyB", "valueB"]);
    expect(result).toEqual({ alpha: "A", type: "html", omega: "B" });
  });

  it("numeric own keys transform in ECMAScript order 1 then 2 then alpha", () => {
    const log: string[] = [];
    const context: any = {};
    for (const name of ["one", "two", "alpha"])
      Object.defineProperty(context, name, { enumerable: true, get() { log.push(name); return name; } });
    transform({ "2": "{{two}}", "1": "{{one}}", alpha: "{{alpha}}" }, context, bodyOptions);
    expect(log).toEqual(["one", "two", "alpha"]);
  });

  it.each(DANGEROUS_TRANSFORM_CASES)("$title", ({ key, mode }) => {
    const input: any = {};
    input["{{firstKey}}"] = "first";
    input["{{lastKey}}"] = "last";
    const result = transform(input, { firstKey: key, lastKey: key }, mode === "body" ? bodyOptions : undefined);
    expectSafeOwn(expect, result, key, "last");
  });

  it.each(DANGEROUS_ORDER_CASES)("$title", ({ key, mode }) => {
    const log: string[] = [];
    const context: any = {};
    for (const [name, value] of [["firstKey", key], ["dangerousKey", key], ["lastKey", key], ["firstValue", "first"], ["lastValue", "last"]]) {
      Object.defineProperty(context, name, { enumerable: true, get() { log.push(name); return value; } });
    }
    Object.defineProperty(context, "boom", { enumerable: true, get() { log.push("boom"); throw new Error(`dangerous-${key}`); } });
    const input = { "{{firstKey}}": "{{firstValue}}", "{{dangerousKey}}": "{{boom}}", "{{lastKey}}": "{{lastValue}}" };
    expect(() => transform(input, context, mode === "body" ? bodyOptions : undefined)).toThrow(`dangerous-${key}`);
    expect(log).toEqual(mode === "body"
      ? ["firstKey", "dangerousKey", "lastKey", "firstValue", "boom"]
      : ["firstKey", "firstValue", "dangerousKey", "boom"]);
  });

  it("transformation enumerates only own enumerable string keys", () => {
    const inherited = { inherited: "{{secret}}" };
    const input = Object.create(inherited);
    input.visible = "{{secret}}";
    Object.defineProperty(input, "hidden", { enumerable: false, value: "{{secret}}" });
    input[Symbol("symbol")] = "{{secret}}";
    const result = transform(input, { secret: "VALUE" }, bodyOptions);
    expect(result).toEqual({ visible: "VALUE" });
    expect(Object.getPrototypeOf(result)).toBe(Object.prototype);
  });

  it("unresolved expression output remains the exact authored string", () => {
    const authored = "prefix {{missing.deep.value}} suffix";
    expect(transform(authored, {})).toBe(authored);
  });
});
