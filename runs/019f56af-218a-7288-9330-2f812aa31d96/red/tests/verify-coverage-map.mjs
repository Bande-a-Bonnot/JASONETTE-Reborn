#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import * as catalog from "./case-catalog.mjs";

const root = path.resolve(path.dirname(new URL(import.meta.url).pathname), "..");
const testsDir = path.join(root, "tests");
const featuresDir = path.join(root, "features");
const coveragePath = path.join(testsDir, "coverage-map.json");
const failures = [];
const fail = (message) => failures.push(message);

const testFiles = fs.readdirSync(testsDir).filter((name) => name.endsWith(".test.ts")).sort();
const vitestTitles = [];
const usedArrays = new Map();

const publicTypeContract = "public-types.test.ts";
const publicTypeConfigRelative = "tests/tsconfig.public-types.json";
const publicTypeCommand = `npx tsc --project ${publicTypeConfigRelative}`;
if (!testFiles.includes(publicTypeContract)) {
  fail(`${publicTypeContract}: public RenderOptions contract is missing from the test runner inputs`);
} else {
  const source = fs.readFileSync(path.join(testsDir, publicTypeContract), "utf8");
  if (/@ts-nocheck/.test(source)) fail(`${publicTypeContract}: public type contract must be typechecked`);
  if (!/import\s+type\s*\{\s*RenderOptions\s*\}\s+from\s+["']@jasonette\/template-engine["']/.test(source)) {
    fail(`${publicTypeContract}: RenderOptions must use the public template-engine type export`);
  }
  if (!/:\s*RenderOptions\s*=\s*\{\s*preserveHtmlText\s*:/.test(source)) {
    fail(`${publicTypeContract}: no RenderOptions assignment covers preserveHtmlText`);
  }
}

const publicTypeConfigPath = path.join(root, publicTypeConfigRelative);
if (!fs.existsSync(publicTypeConfigPath)) {
  fail(`${publicTypeConfigRelative}: dedicated public typecheck config is missing`);
} else {
  const config = JSON.parse(fs.readFileSync(publicTypeConfigPath, "utf8"));
  const options = config.compilerOptions ?? {};
  if (options.noEmit !== true || options.strict !== true) {
    fail(`${publicTypeConfigRelative}: public contract must run strict no-emit tsc`);
  }
  if (options.moduleResolution !== "Bundler") {
    fail(`${publicTypeConfigRelative}: public package exports must be resolved with Bundler module resolution`);
  }
  if (Object.hasOwn(options, "paths") || Object.hasOwn(options, "typeRoots")) {
    fail(`${publicTypeConfigRelative}: aliases/type roots could bypass the real public package type`);
  }
  if (JSON.stringify(config.files) !== JSON.stringify([publicTypeContract])) {
    fail(`${publicTypeConfigRelative}: files must contain only ${publicTypeContract}`);
  }
}

for (const file of testFiles) {
  const source = fs.readFileSync(path.join(testsDir, file), "utf8");
  const literalMatches = [...source.matchAll(/\bit\(\s*("(?:[^"\\]|\\.)*")/g)];
  for (const match of literalMatches) {
    try {
      vitestTitles.push(JSON.parse(match[1]));
    } catch {
      fail(`${file}: malformed literal Vitest title ${match[1]}`);
    }
  }

  const eachMatches = [...source.matchAll(/\bit\.each\((\w+)\)\(\s*"\$title"/g)];
  for (const match of eachMatches) {
    const name = match[1];
    if (!Array.isArray(catalog[name])) {
      fail(`${file}: it.each(${name}) has no exported concrete catalog array`);
      continue;
    }
    usedArrays.set(name, (usedArrays.get(name) ?? 0) + 1);
    for (const [index, row] of catalog[name].entries()) {
      if (!row || typeof row.title !== "string" || row.title.length === 0) {
        fail(`${name}[${index}] has no exact title`);
      } else {
        vitestTitles.push(row.title);
      }
    }
  }

  const declared = [...source.matchAll(/\bit\s*(?:\.each\([^)]*\))?\s*\(/g)].length;
  if (declared !== literalMatches.length + eachMatches.length) {
    fail(`${file}: found ${declared} it declarations but only ${literalMatches.length + eachMatches.length} exact declarations`);
  }
  if (/\b(?:it|test)\.(?:skip|todo|only)\b/.test(source)) fail(`${file}: skipped, todo, or exclusive tests are forbidden`);
  if (/\b(?:setTimeout|setInterval|sleep)\s*\(/.test(source)) fail(`${file}: arbitrary timing waits are forbidden`);
  if (/from\s+["'][^"']*(?:\/src\/|\/source\/)[^"']*["']/.test(source)) fail(`${file}: implementation/source import detected`);

  for (const importMatch of source.matchAll(/from\s+["']([^"']+)["']/g)) {
    const specifier = importMatch[1];
    const allowed = specifier === "vitest"
      || specifier === "@jasonette/template-engine"
      || specifier === "@jasonette/web"
      || specifier.startsWith("./")
      || specifier === "../support/fixtures/jasonpedia-html-index.json";
    if (!allowed) fail(`${file}: non-public or unapproved import ${specifier}`);
  }
}

const integrationTestSource = fs.readFileSync(path.join(testsDir, "integration-smoke.test.ts"), "utf8");
if (/returnBoundary\s*:\s*false/.test(integrationTestSource)) {
  fail("integration-smoke.test.ts: every integrated component trace must require RETURN");
}
if (/withKindAsync\(\s*["']component["']/.test(integrationTestSource)) {
  fail("integration-smoke.test.ts: component actions must use the integrated completion-marker boundary");
}
if (!/withIntegratedComponentBoundaryAsync/.test(integrationTestSource)) {
  fail("integration-smoke.test.ts: public action return is not kept inside the integrated observation window");
}
const helpersSource = fs.readFileSync(path.join(testsDir, "black-box-helpers.ts"), "utf8");
if (!/renderDocumentObserved[\s\S]*withIntegratedComponentBoundary\(\(\)\s*=>\s*renderer\.renderDocument/.test(helpersSource)) {
  fail("black-box-helpers.ts: public render return must use the integrated completion-marker boundary");
}
const observerSource = fs.readFileSync(path.join(testsDir, "security-observer.ts"), "utf8");
if (!/data-jasonette-type/.test(observerSource)
  || !/iframe event occurred after integrated component completion/.test(observerSource)) {
  fail("security-observer.ts: integrated data marker completion and later-event rejection are required");
}

const requiredActionInheritedCandidates = ["toString", "constructor", "__proto__", "prototype", "redInheritedOnlyAction"];
for (const kind of requiredActionInheritedCandidates) {
  const row = catalog.ACTION_TYPE_CASES?.find((entry) => entry.kind === kind);
  const contract = row && catalog.GHERKIN_CONTRACTS?.[row.title];
  if (!row || !contract?.setup.includes(`Object.prototype[${JSON.stringify(kind)}] is a same-key observable inherited callable`)
    || !contract?.expected.includes("callable calls are zero")) {
    fail(`ACTION_TYPE_CASES: ${kind} must have a same-key inherited callable zero-call oracle`);
  }
}
for (const pathName of ["canonical", "legacy"]) {
  for (const id of [
    "empty own text with valid URL fallback",
    "non-string own text with valid URL fallback",
    "invalid inline HTML exact preservation",
  ]) {
    const row = catalog.BACKGROUND_MATRIX_CASES?.find((entry) => entry.path === pathName && entry.id === id);
    const contract = row && catalog.GHERKIN_CONTRACTS?.[row.title];
    if (!row || !contract?.expected.includes("only ") || !contract.expected.includes("RETURN")) {
      fail(`BACKGROUND_MATRIX_CASES: ${pathName} ${id} must have exclusive attributes and an exact completed trace`);
    }
  }
}

for (const [name, value] of Object.entries(catalog)) {
  if (!Array.isArray(value)) continue;
  const uses = usedArrays.get(name) ?? 0;
  if (uses !== 1) fail(`${name}: concrete it.each catalog must be used exactly once, found ${uses}`);
}

function duplicateValues(values) {
  const seen = new Set();
  const duplicates = new Set();
  for (const value of values) seen.has(value) ? duplicates.add(value) : seen.add(value);
  return [...duplicates];
}
for (const title of duplicateValues(vitestTitles)) fail(`ambiguous duplicate Vitest title: ${title}`);

const gherkinTitles = [];
let gherkinOutlineCaseCount = 0;
let gherkinLiteralCaseCount = 0;
const usedGherkinContracts = new Set();
const gherkinContracts = catalog.GHERKIN_CONTRACTS;
if (!gherkinContracts || Array.isArray(gherkinContracts) || typeof gherkinContracts !== "object") {
  fail("case-catalog.mjs: GHERKIN_CONTRACTS object is missing");
}
for (const [title, contract] of Object.entries(gherkinContracts ?? {})) {
  if (!contract || Object.keys(contract).sort().join(",") !== "action,expected,setup") {
    fail(`GHERKIN_CONTRACTS[${JSON.stringify(title)}]: expected only setup/action/expected`);
  } else {
    for (const key of ["setup", "action", "expected"]) {
      if (typeof contract[key] !== "string" || !contract[key].trim()) fail(`GHERKIN_CONTRACTS[${JSON.stringify(title)}].${key}: concrete text is required`);
    }
  }
}

function parseGherkinCells(line) {
  const inner = line.trim().slice(1, -1);
  const cells = [""];
  for (let index = 0; index < inner.length; index += 1) {
    const char = inner[index];
    if (char === "|") {
      cells.push("");
    } else if (char === "\\" && index + 1 < inner.length) {
      const escaped = inner[index + 1];
      if (escaped === "n") cells[cells.length - 1] += "\n";
      else if (escaped === "\\" || escaped === "|") cells[cells.length - 1] += escaped;
      else cells[cells.length - 1] += `\\${escaped}`;
      index += 1;
    } else {
      cells[cells.length - 1] += char;
    }
  }
  return cells.map((cell) => cell.trim());
}

const featureFiles = fs.readdirSync(featuresDir).filter((name) => name.endsWith(".feature")).sort();
for (const file of featureFiles) {
  const featureSource = fs.readFileSync(path.join(featuresDir, file), "utf8");
  const lines = featureSource.split(/\r?\n/);
  if (file === "integration.feature") {
    for (const line of lines.filter((value) => value.includes("CREATE(component)"))) {
      if (!/APPEND, RETURN\]/.test(line) || /omit RETURN/.test(line)) {
        fail(`${file}: every integrated component trace must end in RETURN`);
      }
      if (!/wrapper data-jasonette-type="html" completion/.test(line)
        || !/no later iframe event through (?:the containing )?public (?:render\/action|render) return/.test(line)) {
        fail(`${file}: integrated component RETURN must use the wrapper marker and continue through public return`);
      }
    }
  }
  if (!lines.some((line) => /^Feature:\s+\S/.test(line))) fail(`${file}: missing Feature declaration`);
  let current = null;
  let inExamples = false;
  let headers = null;
  const finish = () => {
    if (!current) return;
    if (current.steps.length < 1 || current.steps.length > 5) fail(`${file}: ${current.name} has ${current.steps.length} steps; expected 1..5`);
    if (!current.steps.some(({ keyword }) => keyword === "When")) fail(`${file}: ${current.name} has no When step`);
    if (current.outline) {
      if (current.exampleCount === 0) fail(`${file}: ${current.name} has no concrete Examples rows`);
      const expectedSteps = [["Given", "<setup>"], ["When", "<action>"], ["Then", "<expected>"]];
      if (JSON.stringify(current.steps.map(({ keyword, text }) => [keyword, text])) !== JSON.stringify(expectedSteps)) {
        fail(`${file}: ${current.name} must use concrete <setup>, <action>, and <expected> in Given/When/Then`);
      }
    } else {
      const contract = gherkinContracts?.[current.name];
      if (!contract) {
        fail(`${file}: ${current.name} has no authored Gherkin contract in case-catalog.mjs`);
      } else {
        const expectedSteps = [["Given", contract.setup], ["When", contract.action], ["Then", contract.expected]];
        if (JSON.stringify(current.steps.map(({ keyword, text }) => [keyword, text])) !== JSON.stringify(expectedSteps)) {
          fail(`${file}: ${current.name} steps differ from its concrete case-catalog contract`);
        }
        usedGherkinContracts.add(current.name);
      }
    }
  };
  for (const raw of lines) {
    const line = raw.trim();
    let match = line.match(/^Scenario Outline:\s*(.+)$/);
    if (match) {
      finish();
      current = { name: match[1], outline: true, steps: [], exampleCount: 0 };
      inExamples = false;
      headers = null;
      continue;
    }
    match = line.match(/^Scenario:\s*(.+)$/);
    if (match) {
      finish();
      current = { name: match[1], outline: false, steps: [], exampleCount: 0 };
      gherkinTitles.push(match[1]);
      gherkinLiteralCaseCount += 1;
      inExamples = false;
      headers = null;
      continue;
    }
    if (/^Examples:\s*\S/.test(line)) {
      if (!current?.outline) fail(`${file}: Examples outside a Scenario Outline`);
      inExamples = true;
      headers = null;
      continue;
    }
    if (inExamples && /^\|.*\|$/.test(line)) {
      const cells = parseGherkinCells(line);
      if (!headers) {
        headers = cells;
        if (JSON.stringify(headers) !== JSON.stringify(["title", "setup", "action", "expected"])) {
          fail(`${file}: Examples columns must be exactly title, setup, action, expected`);
        }
      } else {
        if (cells.length !== headers.length) fail(`${file}: Examples row has ${cells.length} cells; expected ${headers.length}`);
        const row = Object.fromEntries(headers.map((header, index) => [header, cells[index]]));
        const title = row.title;
        if (!title || /^<[^>]+>$/.test(title)) {
          fail(`${file}: non-concrete Examples title ${title}`);
        } else {
          gherkinTitles.push(title);
          gherkinOutlineCaseCount += 1;
          current.exampleCount += 1;
          const contract = gherkinContracts?.[title];
          if (!contract) {
            fail(`${file}: ${title} has no authored Gherkin contract in case-catalog.mjs`);
          } else {
            for (const key of ["setup", "action", "expected"]) {
              if (row[key] !== contract[key]) fail(`${file}: ${title} ${key} differs from its concrete case-catalog value`);
            }
            usedGherkinContracts.add(title);
          }
        }
      }
      continue;
    }
    match = line.match(/^(Given|When|Then|And|But)\s+(.+)$/);
    if (match) {
      if (!current) fail(`${file}: step outside a scenario: ${line}`);
      else {
        current.steps.push({ keyword: match[1], text: match[2] });
        if (match[1] === "Given" && /\b(?:rendered|transformed|executes|mutated|inserted|assigned)\b/i.test(match[2])) {
          fail(`${file}: rendering or mutation belongs in When, not Given: ${line}`);
        }
        if (/\b(?:named|unnamed)\s+(?:vector|contract)\b|\bcontract holds\b/i.test(match[2])) {
          fail(`${file}: step defers to a vector/contract instead of concrete behavior: ${line}`);
        }
      }
    }
  }
  finish();
}
for (const title of duplicateValues(gherkinTitles)) fail(`ambiguous duplicate Gherkin scenario title: ${title}`);
for (const title of Object.keys(gherkinContracts ?? {})) if (!usedGherkinContracts.has(title)) fail(`unused Gherkin case-catalog contract: ${title}`);

const vitestSet = new Set(vitestTitles);
const gherkinSet = new Set(gherkinTitles);
for (const title of vitestSet) if (!gherkinSet.has(title)) fail(`Vitest title has no one-to-one Gherkin scenario: ${title}`);
for (const title of gherkinSet) if (!vitestSet.has(title)) fail(`stale Gherkin scenario has no Vitest declaration: ${title}`);

const coverage = JSON.parse(fs.readFileSync(coveragePath, "utf8"));
const expectedGherkinConcretenessMetadata = {
  schema: "setup-action-expected-v1",
  catalog: "tests/case-catalog.mjs#GHERKIN_CONTRACTS",
  expandedCaseCount: gherkinTitles.length,
  outlineExampleCount: gherkinOutlineCaseCount,
  literalScenarioCount: gherkinLiteralCaseCount,
};
if (JSON.stringify(coverage.suite?.gherkinConcreteness) !== JSON.stringify(expectedGherkinConcretenessMetadata)) {
  fail("coverage-map suite metadata must record the verified concrete Gherkin schema and case counts");
}
const expectedTypecheckMetadata = {
  command: publicTypeCommand,
  config: publicTypeConfigRelative,
  entrypoint: `tests/${publicTypeContract}`,
  publicImport: "@jasonette/template-engine",
};
if (JSON.stringify(coverage.suite?.requiredTypecheck) !== JSON.stringify(expectedTypecheckMetadata)) {
  fail("coverage-map suite metadata must require the exact dedicated public-package tsc command");
}
const compileEvidence = coverage.requirements?.["6.1-1"]?.compileEvidence;
if (JSON.stringify(compileEvidence) !== JSON.stringify(["CMD-9"])) {
  fail("6.1-1: compile-time evidence CMD-9 is required and cannot be inferred from Vitest transpilation");
}
const expectedRequirementIds = [];
for (const [section, count] of [["6.1", 3], ["6.2", 6], ["6.3", 3], ["6.4", 5], ["6.5", 14], ["6.6", 6], ["6.7", 7], ["6.8", 6], ["6.9", 4], ["6.10", 1]]) {
  for (let index = 1; index <= count; index += 1) expectedRequirementIds.push(`${section}-${index}`);
}
const actualRequirementIds = Object.keys(coverage.requirements ?? {});
for (const id of expectedRequirementIds) if (!actualRequirementIds.includes(id)) fail(`missing DoD coverage item ${id}`);
for (const id of actualRequirementIds) if (!expectedRequirementIds.includes(id)) fail(`unknown DoD coverage item ${id}`);

const mappedTitles = new Set();
const externalIds = new Set((coverage.external ?? []).map((item) => item.id));
for (const [id, item] of Object.entries(coverage.requirements ?? {})) {
  if (item.status === "automated") {
    if (!Array.isArray(item.tests) || item.tests.length === 0) fail(`${id}: automated item has no tests`);
    for (const title of item.tests ?? []) {
      if (typeof title !== "string" || title.includes("$title") || title.includes("<title>") || title.includes("*")) {
        fail(`${id}: wildcard/non-exact coverage reference ${String(title)}`);
      } else if (!vitestSet.has(title)) {
        fail(`${id}: stale coverage reference ${title}`);
      }
      mappedTitles.add(title);
    }
    for (const title of duplicateValues(item.tests ?? [])) fail(`${id}: duplicate/ambiguous coverage reference ${title}`);
  } else if (item.status === "external-pending") {
    if (!Array.isArray(item.external) || item.external.length === 0) fail(`${id}: external item has no typed evidence IDs`);
    if ((item.tests ?? []).length) fail(`${id}: external obligation must not be represented by a Vitest assertion`);
    for (const external of item.external ?? []) if (!externalIds.has(external)) fail(`${id}: missing external evidence ${external}`);
  } else {
    fail(`${id}: unsupported status ${item.status}`);
  }
}
for (const title of vitestSet) if (!mappedTitles.has(title)) fail(`Vitest title is absent from coverage map: ${title}`);

const exactCommands = [
  "npm run test --workspace=@jasonette/template-engine -- transformer.test.ts",
  "npm run test --workspace=@jasonette/web -- components.test.ts integration.test.ts actions-parity.test.ts renderer.test.ts",
  "npm run typecheck --workspace=@jasonette/template-engine",
  "npm run typecheck --workspace=@jasonette/web",
  "npm run build --workspace=@jasonette/template-engine",
  "npm run build --workspace=@jasonette/web",
  "npm run test --workspace=@jasonette/template-engine",
  "npm run test --workspace=@jasonette/web",
  publicTypeCommand,
];
const external = coverage.external ?? [];
for (const [index, command] of exactCommands.entries()) {
  const item = external.find((entry) => entry.id === `CMD-${index + 1}`);
  if (!item || item.type !== "command" || item.status !== "pending" || item.obligation !== command) {
    fail(`CMD-${index + 1}: exact pending command obligation is missing or altered`);
  }
}
const ci = external.find((entry) => entry.id === "CI-1");
if (!ci || ci.type !== "ci" || ci.status !== "pending" || !ci.obligation.includes("implementation-SHA Web CI")) {
  fail("CI-1: exact implementation-SHA CI obligation is not typed pending");
}
if (external.length !== 10) fail(`expected exactly 10 external pending items, found ${external.length}`);
if (coverage.suite?.reportedTestCount !== vitestTitles.length) fail("coverage-map reportedTestCount is stale");
if (coverage.suite?.gherkinScenarioCount !== gherkinTitles.length) fail("coverage-map gherkinScenarioCount is stale");

if (failures.length) {
  console.error(`coverage-map verification failed (${failures.length}):`);
  for (const message of failures) console.error(`- ${message}`);
  process.exit(1);
}

const automatedCount = Object.values(coverage.requirements).filter((item) => item.status === "automated").length;
const externalRequirementCount = Object.values(coverage.requirements).filter((item) => item.status === "external-pending").length;
console.log(`coverage-map verification passed`);
console.log(`Vitest reported cases: ${vitestTitles.length}`);
console.log(`Gherkin expanded scenarios: ${gherkinTitles.length}`);
console.log(`Gherkin concrete contracts: ${usedGherkinContracts.size} (${gherkinOutlineCaseCount} outline rows, ${gherkinLiteralCaseCount} literal scenarios)`);
console.log(`DoD checkboxes: ${actualRequirementIds.length} (${automatedCount} automated, ${externalRequirementCount} external-pending)`);
console.log(`External pending items: ${external.length}`);
for (const item of external) console.log(`- ${item.id} [${item.type}]: ${item.obligation}`);
