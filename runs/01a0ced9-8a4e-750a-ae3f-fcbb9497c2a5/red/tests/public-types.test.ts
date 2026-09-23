import { describe, expect, it } from "vitest";
import type { RenderOptions } from "@jasonette/template-engine";

const explicitFalseOptions: RenderOptions = { preserveHtmlText: false };
const explicitTrueOptions: RenderOptions = { preserveHtmlText: true };

describe("public template-engine type contract", () => {
  it("public RenderOptions type accepts preserveHtmlText", () => {
    expect(explicitFalseOptions.preserveHtmlText).toBe(false);
    expect(explicitTrueOptions.preserveHtmlText).toBe(true);
  });
});
