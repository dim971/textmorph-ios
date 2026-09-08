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

import { writeFileSync, mkdirSync } from "node:fs";
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
  numberRules: numberRulesSection(),
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
  if (typeof section !== "object") continue;
  for (const [key, value] of Object.entries(section)) {
    console.log(`  ${name}.${key}: ${Array.isArray(value) ? value.length : 1} cases`);
  }
}
