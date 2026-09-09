#!/usr/bin/env node
// Generates the fixtures that pin this port to the JavaScript original.
//
//   npm install --no-save torph@0.1.3
//   node Tools/gen-goldens.mjs Tests/TextMorphTests/Fixtures/goldens.json
//
// Run by hand, never in CI. The output is checked in, and the Android twin
// carries a byte-identical copy, so this script is byte-identical in both
// repositories.
//
// The version below is the contract. Regenerating against a newer torph is a
// deliberate act: it changes what this library claims to be, and the diff has
// to be explainable. Do not regenerate to make a failing test pass.

import { writeFileSync, mkdirSync, readFileSync } from "node:fs";
import { dirname } from "node:path";

const TORPH_VERSION = "0.1.3";

// Upstream mints a numeric identity as a NULL, an "n" and a counter.
const MINTED_PREFIX = "\u0000n";

const torph = await import("torph");

// That counter climbs for the life of the process, so the same call gives
// different identities depending on what ran before it. Canonicalising them in
// order of first appearance is what makes the fixture reproducible; the port
// mints its own and only has to agree about which characters share an identity,
// not about what the identity says.
function canonicalise(segments) {
  const seen = new Map();
  return segments.map((segment) => {
    let id = segment.id;
    if (id.startsWith(MINTED_PREFIX)) {
      if (!seen.has(id)) seen.set(id, `#${seen.size}`);
      id = seen.get(id);
    }
    return segment.kind === undefined
      ? { id, string: segment.string }
      : { id, string: segment.string, kind: segment.kind };
  });
}

/**
 * How the new segmentation continues the old one, as indices rather than
 * identities: alignment[i] is the index in `previous` that the new segment at i
 * carries on from, or null if it arrived. Identity-independent, and therefore
 * the honest way to pin a morph.
 */
function alignment(previous, next) {
  const positions = new Map(previous.map((segment, index) => [segment.id, index]));
  return next.map((segment) => positions.get(segment.id) ?? null);
}

// The four exotic spaces some locales group digits with, all of which upstream
// accepts inside a number. Written as escapes so the corpus is legible.
const NBSP = "\u00A0";
const NNBSP = "\u202F";
const THIN = "\u2009";
const FIGURE = "\u2007";
const MINUS = "\u2212";

const NUMERIC_TOKENS = [
  "0", "7", "12", "1204", "1,204", "1,234.56", "$1,234.56", "$1,204",
  "3.5", "0.5", ".5", "12%", "-5", "+5", `${MINUS}5`, "(12)", "#12",
  "1'234", `1${NBSP}234`, `1${NNBSP}234`, `1${THIN}234`, `1${FIGURE}234`,
  "COVID-19", "2024-01-01", "abc", "", "1a", "a1", "1.2.3", "1..2",
  "12,", "12.", ",12", "1,204.00", "999,999", "1,000,000", "£12.00",
  "€1.234,56", "12345678901234567890", "1e5", "0x1f", "۱۲",
];

const LOCALES = [
  "en", "en-US", "en-GB", "fr-FR", "fr-CA", "de-DE", "de-CH", "es-ES", "it-IT",
  "pt-BR", "nl-NL", "sv-SE", "fi-FI", "nb-NO", "da-DK", "pl-PL", "cs-CZ",
  "ru-RU", "tr-TR", "ar-EG", "fa-IR", "hi-IN", "ja-JP", "ko-KR", "zh-CN",
  "zh-TW", "th-TH", "he-IL", "uk-UA", "id-ID", "vi-VN",
];

// Pairs chosen to exercise every branch of the place walk: a single column
// changing, a carry, a magnitude jump past the cap, a fraction gaining and
// losing a place, a separator appearing, an affix changing, and a sign flip.
const PLACE_PAIRS = [
  ["1204", "1318"], ["1,204", "1,318"], ["$1,204", "$1,318"],
  ["999,999", "1,000,000"], ["1,000,000", "999,999"],
  ["9", "10"], ["10", "9"], ["99", "100"], ["100", "99"],
  ["1", "1000"], ["1", "10000"], ["1000", "1"],
  ["1.5", "1.25"], ["1.25", "1.5"], ["0.5", "0.05"],
  ["1,234.56", "1,234.57"], ["1,234.56", "9,876.54"],
  ["$1,234.56", "£1,234.56"], ["12%", "13%"], ["(12)", "(13)"],
  ["-5", "+5"], ["5", "-5"], ["1204", "1204"],
  [`1${NBSP}234`, `1${NBSP}235`], ["1'234", "1'235"],
  ["12345", "12"], ["12", "12345"],
];

// The caret path only applies when the value holds a single number, so these
// are the keystrokes a numeric field actually produces.
const CURSOR_CASES = [
  { old: "", new: "1", cursor: 1 },
  { old: "1", new: "12", cursor: 2 },
  { old: "12", new: "123", cursor: 3 },
  { old: "123", new: "1,234", cursor: 5 },
  { old: "1,234", new: "12,345", cursor: 6 },
  { old: "1,234", new: "123", cursor: 3 },
  { old: "1,234", new: "1,23", cursor: 4 },
  { old: "120", new: "1200", cursor: 4 },
  { old: "120", new: "12", cursor: 2 },
  { old: "120", new: "130", cursor: 2 },
  { old: "$120", new: "$1200", cursor: 5 },
  { old: "1.50", new: "1.55", cursor: 4 },
  { old: "1.50", new: "1.5", cursor: 3 },
  { old: "12", new: "12", cursor: 1 },
  { old: "1,234", new: "1,234", cursor: 0 },
];

// Values chosen to reach every branch of the segmenter: the word path and the
// grapheme path, the newline path, the identity collision path, and each of the
// grapheme cluster shapes that a naive per-character split would break.
//
// `diverges` marks a case where this port is known to disagree with upstream,
// and says why. The only such case is a run of CJK letters with a space
// elsewhere in the value: ICU joins the run into one word, and UAX #29 without
// dictionary breaking does not. Upstream already segments those languages by
// grapheme whenever the value holds no space, which is the common case, so the
// difference is confined to spaced CJK.
const TEXT_CASES = [
  { value: "" },
  { value: "a" },
  { value: "balance" },
  { value: "Hello world" },
  { value: "Hello, world!" },
  { value: "the quick brown fox" },
  { value: "a b c" },
  { value: "hello  double" },
  { value: " lead" },
  { value: "trail " },
  { value: "  both  " },
  { value: "a\tb" },
  { value: "a...b" },
  { value: "C++" },
  { value: "don't" },
  { value: "e.g" },
  { value: "COVID-19" },
  { value: "2024-01-01" },
  { value: "3.5 km/h" },
  { value: "1,234.56" },
  { value: "$1,234.56" },
  { value: "Total $1,204 today" },
  { value: "12% of 1,000" },
  { value: "a\nb" },
  { value: "a\nb\nc" },
  { value: "one two\nthree four" },
  { value: "\n" },
  { value: "a\n" },
  { value: "\na" },
  { value: "a\n\nb" },
  { value: "aa" },
  { value: "aaa" },
  { value: "aba" },
  { value: "a a" },
  { value: "a a a" },
  { value: "the the the" },
  { value: "é" },
  { value: "café au lait" },
  { value: "\u{1F600}" },
  { value: "\u{1F600}\u{1F601}" },
  { value: "\u{1F1EB}\u{1F1F7}\u{1F1E9}\u{1F1EA}" },
  { value: "\u{1F468}‍\u{1F469}‍\u{1F467}" },
  { value: "hi \u{1F600} there" },
  { value: "क्ष" },
  { value: "ไทย" },
  { value: "שלום" },
  { value: "مرحبا بك" },
  { value: "日本語" },
  {
    value: "日本語 です",
    diverges: "ICU joins a CJK letter run into one word; UAX #29 without dictionary breaking does not",
  },
  {
    value: "Hello 日本語",
    diverges: "ICU joins a CJK letter run into one word; UAX #29 without dictionary breaking does not",
  },
];

function segmentTextSection() {
  return TEXT_CASES.flatMap((testCase) =>
    [true, false].map((numbers) => ({
      value: testCase.value,
      numbers,
      diverges: testCase.diverges ?? null,
      segments: canonicalise(torph.segmentText(testCase.value, "en", numbers)),
    })),
  );
}

// Every ordered pair of these is recorded, both with numbers on and off. Chosen
// so the sweep reaches every branch of the diff: a word surviving, a word
// moving, a word becoming another word, a number changing magnitude, a value
// emptying and filling, a line break appearing, and the multi-segment word
// ("3.5 km/h") that upstream indexes a per-character subsequence into.
const DIFF_CORPUS = [
  "",
  "a",
  "balance",
  "Total",
  "Total balance",
  "balance Total",
  "the quick brown fox",
  "the brown fox",
  "the quick brown fox jumps over the lazy dog",
  "1204",
  "1,204",
  "$1,204",
  "$1,318",
  "999,999",
  "1,000,000",
  "3.5 km/h",
  "980 MB",
  "1.2 GB",
  "hello  double",
  "a\nb",
  "one two\nthree four",
  "12% of 1,000",
];

// The caret path needs a value holding exactly one number, so these are pairs a
// numeric field produces rather than arbitrary values.
const DIFF_CURSOR_CASES = [
  { old: "", new: "1", cursor: 1 },
  { old: "1", new: "12", cursor: 2 },
  { old: "123", new: "1,234", cursor: 5 },
  { old: "1,234", new: "123", cursor: 3 },
  { old: "$120", new: "$1200", cursor: 5 },
  { old: "Total 120", new: "Total 1200", cursor: 10 },
  { old: "120", new: "130", cursor: 2 },
  { old: "1.50", new: "1.55", cursor: 4 },
];

function serialiseSplits(splits, rename) {
  const out = {};
  for (const [id, segments] of splits) {
    out[rename(id)] = segments.map((segment) => ({
      id: rename(segment.id),
      string: segment.string,
    }));
  }
  return out;
}

/**
 * One diff, recorded three ways: the identities as strings, which are
 * deterministic except for the minted numeric ones; the alignment against the
 * old segmentation, which is not; and the splits map.
 */
function diffCase(before, after, numbers, cursorIndex) {
  const previous = torph.segmentText(before, "en", numbers);
  const result = torph.diffSegments(previous, after, "en", { numbers, cursorIndex });

  // Canonicalise across both sides at once, so an identity inherited from the
  // old segmentation gets the same name in both.
  const seen = new Map();
  const rename = (id) => {
    if (!id.startsWith(MINTED_PREFIX)) return id;
    if (!seen.has(id)) seen.set(id, `#${seen.size}`);
    return seen.get(id);
  };
  for (const segment of previous) rename(segment.id);

  const positions = new Map(previous.map((segment, index) => [segment.id, index]));

  return {
    before,
    after,
    numbers,
    cursor: cursorIndex ?? null,
    previous: previous.map((segment) => rename(segment.id)),
    segments: result.segments.map((segment) =>
      segment.kind === undefined
        ? { id: rename(segment.id), string: segment.string }
        : { id: rename(segment.id), string: segment.string, kind: segment.kind },
    ),
    alignment: result.segments.map((segment) => positions.get(segment.id) ?? null),
    splits: serialiseSplits(result.splits, rename),
  };
}

function diffSegmentsSection() {
  const cases = [];
  for (const before of DIFF_CORPUS) {
    for (const after of DIFF_CORPUS) {
      for (const numbers of [true, false]) {
        cases.push(diffCase(before, after, numbers, undefined));
      }
    }
  }
  for (const testCase of DIFF_CURSOR_CASES) {
    cases.push(diffCase(testCase.old, testCase.new, true, testCase.cursor));
  }
  return cases;
}

// Values chosen for the places two number formatters part company: the default
// fraction length, padding versus truncating, halves on both sides of zero,
// grouping in a locale that groups by lakh, and a magnitude past what a double
// represents exactly.
const FORMAT_VALUES = [
  0, 1, -1, 0.5, -0.5, 1.5, -1.5, 2.5, -2.5, 0.05, 0.125, 0.135,
  1.005, 1.015, 3.5, 12.345, 1234.5, 1234567.5, 1234567.891,
  999999.9995, 0.0001, 0.00001, 1e21, -1e21, 1e-7,
];

const FORMAT_DECIMALS = [null, 0, 1, 2, 3, 4];

function numberFormattingSection() {
  const cases = [];
  for (const locale of LOCALES) {
    for (const value of FORMAT_VALUES) {
      for (const decimals of FORMAT_DECIMALS) {
        cases.push({
          value,
          decimals,
          locale,
          formatted: value.toLocaleString(locale, {
            minimumFractionDigits: decimals ?? undefined,
            maximumFractionDigits: decimals ?? undefined,
          }),
        });
      }
    }
  }
  return cases;
}

// The easing and spring solvers are not part of torph's public API, so they
// cannot be called the way segmentText can. They are still *in* the published
// package, so rather than restate them here, which would only compare one
// transcription against another, they are lifted out of the published bundle.
//
// Each one is found by a pattern over its body rather than by its minified
// name, so a re-minify at the same version still finds it, and a version that
// no longer contains it fails loudly instead of silently skipping a section.
const INTERNAL_PROBES = {
  springPosition: /function (\w+)\([^)]*\)\{if\(\w+<1\)\{let \w+=\w+\*Math\.sqrt\(1-\w+\*\w+\)/,
  computeDuration: /function (\w+)\([^)]*\)\{let \w+=0;for\(let \w+=0;\w+<10;\w+\+=\.001\)/,
  cubicBezier: /function (\w+)\([^)]*\)\{return \w+=>\{if\(\w+<=0\)return 0;if\(\w+>=1\)return 1;/,
  slopeAt: /function (\w+)\((\w+),(\w+)\)\{let \w+=Math\.min\(Math\.max/,
  carry: /function (\w+)\((\w+),(\w+)\)\{let \w+=Math\.max\(0,Math\.min\(/,
  // The FLIP helpers. They take DOM elements upstream, but only ever ask a Set
  // whether it holds one and index an array with it, so plain numbers drive
  // them just as well.
  computeDelta: /function (\w+)\((\w+),(\w+),(\w+)\)\{let \w+=\w+\[\w+\],\w+=\w+\[\w+\];return ?!\w+\|\|!\w+\?\{dx:0,dy:0\}/,
  findNearestAnchor: /function (\w+)\((\w+),(\w+),(\w+),(\w+)="backward-first"\)/,
  resolveExitingAnchors: /function (\w+)\((\w+),(\w+),(\w+),(\w+)\)\{let \w+=new Set\(\w+\.filter\(/,
  replacedRuns: /function (\w+)\((\w+),(\w+)\)\{let \w+=\[\],\w+=\[\],\w+=\(\)=>\{/,
};

async function loadInternals() {
  const entry = await import.meta.resolve("torph");
  const bundle = readFileSync(new URL(entry), "utf8");

  const renames = [];
  for (const [name, pattern] of Object.entries(INTERNAL_PROBES)) {
    const match = pattern.exec(bundle);
    if (!match) {
      throw new Error(
        `could not find ${name} in ${entry}. The bundle changed shape; ` +
          `update INTERNAL_PROBES rather than dropping the section.`,
      );
    }
    renames.push(`${match[1]} as ${name}`);
  }

  const source = `${bundle}\nexport { ${renames.join(", ")} };\n`;
  const url = `data:text/javascript;base64,${Buffer.from(source).toString("base64")}`;
  return import(url);
}

const internals = await loadInternals();

/** A curve at 101 evenly spaced points, which is finer than a frame at 120Hz. */
function sampleCurve(curve, points = 101) {
  return Array.from({ length: points }, (_, i) => curve(i / (points - 1)));
}

const BEZIERS = [
  { name: "default", points: [0.19, 1, 0.22, 1] },
  { name: "linear", points: [0, 0, 1, 1] },
  { name: "ease", points: [0.25, 0.1, 0.25, 1] },
  { name: "ease-in", points: [0.42, 0, 1, 1] },
  { name: "ease-out", points: [0, 0, 0.58, 1] },
  { name: "ease-in-out", points: [0.42, 0, 0.58, 1] },
  // Deliberately outside the unit square on x, which CSS allows and which
  // makes the bisection work for its answer.
  { name: "overshoot", points: [0.34, 1.56, 0.64, 1] },
  { name: "anticipate", points: [0.68, -0.55, 0.27, 1.55] },
];

const CARRY_VELOCITIES = [
  0, 0.001, 0.5, 1, 1.5, 2, 3, 5, 7.9, 8, 8.1, 20, 1000, -1, -5,
];

// Parameters chosen for the branches: well underdamped, near critical from both
// sides, exactly critical, and overdamped. The precision sweep is here because
// the duration is a threshold crossing and the threshold is the precision.
const SPRING_PARAMETERS = [
  { stiffness: 100, damping: 10, mass: 1, precision: 0.001 },
  { stiffness: 150, damping: 19, mass: 1.2, precision: 0.001 },
  { stiffness: 200, damping: 20, mass: 1, precision: 0.001 },
  { stiffness: 100, damping: 5, mass: 1, precision: 0.001 },
  { stiffness: 100, damping: 1, mass: 1, precision: 0.001 },
  { stiffness: 100, damping: 19.98, mass: 1, precision: 0.001 },
  { stiffness: 100, damping: 20, mass: 1, precision: 0.001 },
  { stiffness: 100, damping: 20.02, mass: 1, precision: 0.001 },
  { stiffness: 100, damping: 30, mass: 1, precision: 0.001 },
  { stiffness: 100, damping: 60, mass: 1, precision: 0.001 },
  { stiffness: 1000, damping: 10, mass: 1, precision: 0.001 },
  { stiffness: 10, damping: 10, mass: 1, precision: 0.001 },
  { stiffness: 100, damping: 10, mass: 10, precision: 0.001 },
  { stiffness: 100, damping: 10, mass: 0.1, precision: 0.001 },
  { stiffness: 100, damping: 10, mass: 1, precision: 0.01 },
  { stiffness: 100, damping: 10, mass: 1, precision: 0.0001 },
  { stiffness: 100, damping: 10, mass: 1, precision: 1e-6 },
];

/** Preserves the values JSON flattens: NaN becomes null, and -0 becomes 0. */
function exactly(value) {
  if (Number.isNaN(value)) return "NaN";
  if (Object.is(value, -0)) return "-0";
  return value;
}

function easingSection() {
  return {
    bezier: BEZIERS.map(({ name, points }) => {
      const curve = internals.cubicBezier(...points);
      return {
        name,
        points,
        samples: sampleCurve(curve),
        slopeAtZero: internals.slopeAt(curve, 0),
        slopeAtHalf: internals.slopeAt(curve, 0.5),
        slopeAtOne: internals.slopeAt(curve, 1),
      };
    }),
    carry: BEZIERS.slice(0, 3).flatMap(({ name, points }) =>
      CARRY_VELOCITIES.map((velocity) => {
        const base = internals.cubicBezier(...points);
        const { curve, k } = internals.carry(base, velocity);
        return { base: name, velocity, k: exactly(k), samples: sampleCurve(curve, 21) };
      }),
    ),
  };
}

function springSection() {
  return SPRING_PARAMETERS.map((parameters) => {
    const { stiffness, damping, mass, precision } = parameters;
    const omega0 = Math.sqrt(stiffness / mass);
    const zeta = damping / (2 * Math.sqrt(stiffness * mass));
    const duration = internals.computeDuration(omega0, zeta, precision);
    const broken = Number.isNaN(internals.springPosition(0.5, omega0, zeta));

    return {
      ...parameters,
      omega0,
      zeta,
      // Recorded for the record even where it is nonsense, so the deviation
      // lives in the fixture rather than only in a comment.
      upstreamDuration: exactly(duration),
      deviates: broken
        ? "upstream's overdamped branch divides by zero at a damping ratio of one, "
          + "so springPosition is NaN and the duration is minus zero"
        : null,
      samples: broken
        ? null
        : Array.from({ length: 21 }, (_, i) =>
            internals.springPosition((i / 20) * (duration / 1000), omega0, zeta),
          ),
    };
  });
}

// Layouts and identity lists chosen so the anchor search has to look both ways,
// run off both ends, and find nothing at all.
const ANCHOR_CASES = [
  { ids: ["a", "b", "c", "d", "e"], persisting: ["a", "e"] },
  { ids: ["a", "b", "c", "d", "e"], persisting: ["c"] },
  { ids: ["a", "b", "c", "d", "e"], persisting: [] },
  { ids: ["a", "b", "c", "d", "e"], persisting: ["a", "b", "c", "d", "e"] },
  { ids: ["a"], persisting: ["a"] },
  { ids: ["a"], persisting: [] },
  { ids: [], persisting: [] },
  { ids: ["x", "y", "x2", "y2", "z", "w"], persisting: ["y2", "w"] },
];

const EXITING_CASES = [
  { oldIds: ["a", "b", "c", "d"], exiting: [1, 2], newIds: ["a", "d"] },
  { oldIds: ["a", "b", "c", "d"], exiting: [0], newIds: ["b", "c", "d"] },
  { oldIds: ["a", "b", "c", "d"], exiting: [3], newIds: ["a", "b", "c"] },
  { oldIds: ["a", "b", "c", "d"], exiting: [0, 1, 2, 3], newIds: [] },
  { oldIds: ["a", "b", "c", "d"], exiting: [1], newIds: ["a", "c", "d"] },
  // An identity that is in the new value but is also leaving, which is what a
  // segment already part way out looks like.
  { oldIds: ["a", "b", "c"], exiting: [1], newIds: ["a", "b", "c"] },
];

const RUN_CASES = [
  { count: 10, members: [] },
  { count: 10, members: [0, 1, 2, 3, 4] },
  { count: 10, members: [0, 1, 2, 3, 4, 5] },
  { count: 10, members: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9] },
  { count: 10, members: [0, 1, 2, 4, 5, 6, 7, 8, 9] },
  { count: 14, members: [0, 1, 2, 3, 4, 5, 8, 9, 10, 11, 12, 13] },
  { count: 6, members: [0, 1, 2, 3, 4, 5] },
  { count: 5, members: [0, 1, 2, 3, 4] },
];

function anchorSection() {
  const nearest = [];
  for (const { ids, persisting } of ANCHOR_CASES) {
    for (const order of ["backward-first", "forward-first"]) {
      for (let index = 0; index <= ids.length; index += 1) {
        nearest.push({
          ids,
          persisting,
          order,
          index,
          anchor: internals.findNearestAnchor(index, ids, new Set(persisting), order) ?? null,
        });
      }
    }
  }

  const exiting = EXITING_CASES.map((testCase) => {
    const indices = testCase.oldIds.map((_, index) => index);
    const resolved = internals.resolveExitingAnchors(
      indices,
      new Set(testCase.exiting),
      testCase.oldIds,
      new Set(testCase.newIds),
    );
    const anchors = {};
    for (const [index, anchor] of resolved) {
      if (anchor !== null) anchors[index] = anchor;
    }
    return { ...testCase, anchors };
  });

  const runs = RUN_CASES.map((testCase) => ({
    ...testCase,
    runs: internals.replacedRuns(
      Array.from({ length: testCase.count }, (_, i) => i),
      new Set(testCase.members),
    ),
  }));

  // A pair of layouts with a segment present in one, the other, both or
  // neither, since "neither" is the case that has to answer zero rather than
  // refuse.
  const deltas = [];
  const previous = { a: { x: 10, y: 0 }, b: { x: 30, y: 0 }, c: { x: 50, y: 20 } };
  const current = { a: { x: 0, y: 0 }, b: { x: 25, y: 4 }, d: { x: 70, y: 20 } };
  for (const id of ["a", "b", "c", "d", "missing"]) {
    deltas.push({ id, delta: internals.computeDelta(previous, current, id) });
  }

  return { nearest, exiting, runs, deltas, previous, current };
}

function numberRulesSection() {
  return {
    isNumericWord: NUMERIC_TOKENS.map((token) => ({
      token,
      result: torph.isNumericWord(token),
    })),
    decimalSeparator: LOCALES.map((locale) => ({
      locale,
      separator: torph.decimalSeparator(locale),
    })),
  };
}

function segmentNumberSection() {
  const fresh = NUMERIC_TOKENS.filter((token) => torph.isNumericWord(token)).map((token) => ({
    value: token,
    segments: canonicalise(torph.segmentNumber(token)),
  }));

  const place = PLACE_PAIRS.map(([before, after]) => {
    const previous = torph.segmentNumber(before);
    const next = torph.segmentNumber(after, previous, undefined, ".");
    return {
      before,
      after,
      strings: next.map((segment) => segment.string),
      kinds: next.map((segment) => segment.kind),
      alignment: alignment(previous, next),
    };
  });

  // The same pairs again with a comma as the decimal separator, which moves the
  // pivot and therefore every column.
  const placeComma = PLACE_PAIRS.map(([before, after]) => {
    const previous = torph.segmentNumber(before);
    const next = torph.segmentNumber(after, previous, undefined, ",");
    return { before, after, alignment: alignment(previous, next) };
  });

  const cursor = CURSOR_CASES.map((testCase) => {
    const previous = torph.segmentNumber(testCase.old);
    const next = torph.segmentNumber(testCase.new, previous, testCase.cursor, ".");
    return {
      before: testCase.old,
      after: testCase.new,
      cursor: testCase.cursor,
      strings: next.map((segment) => segment.string),
      alignment: alignment(previous, next),
    };
  });

  return { fresh, place, placeComma, cursor };
}

const goldens = {
  torphVersion: TORPH_VERSION,
  nodeUnicodeVersion: process.versions.unicode,
  segmentText: segmentTextSection(),
  diffSegments: diffSegmentsSection(),
  numberRules: numberRulesSection(),
  numberFormatting: numberFormattingSection(),
  easing: easingSection(),
  spring: springSection(),
  anchors: anchorSection(),
  segmentNumber: segmentNumberSection(),
};

const path = process.argv[2];
if (!path) {
  console.error("usage: node Tools/gen-goldens.mjs <path to goldens.json>");
  process.exit(2);
}

mkdirSync(dirname(path), { recursive: true });
writeFileSync(path, JSON.stringify(goldens, null, 1) + "\n");
console.log(`wrote ${path}`);
for (const [name, section] of Object.entries(goldens)) {
  if (Array.isArray(section)) {
    console.log(`  ${name}: ${section.length} cases`);
  } else if (section !== null && typeof section === "object") {
    for (const [key, value] of Object.entries(section)) {
      console.log(`  ${name}.${key}: ${Array.isArray(value) ? value.length : 1} cases`);
    }
  }
}
