#!/usr/bin/env node
// Generates the Unicode break property tables the segmenter runs on.
//
//   node Tools/gen-unicode-tables.mjs --swift Sources/TextMorph/Core/UnicodeBreakTables.swift \
//                                     --tests Tests/TextMorphTests/Fixtures/unicode-break-tests.json
//   node Tools/gen-unicode-tables.mjs --kotlin textmorph/src/main/kotlin/io/github/dim971/textmorph/core/UnicodeBreakTables.kt \
//                                     --tests textmorph/src/test/resources/unicode-break-tests.json
//
// Run by hand, never in CI. The output is checked in, and the two ports must
// carry byte-identical tables, so this script is byte-identical in both
// repositories and the digest is compared.
//
// Why the tables are ported at all: this library segments a value the way
// Intl.Segmenter does, and the two platforms' own ICU do not agree with each
// other about it. Foundation's .byWords splits a CJK run by dictionary and
// stops reporting spaces as gaps once one appears; Android's android.icu gives
// a third answer; and both move with the OS version. Owning the rules is the
// only way the two ports can be held to the same fixture.
//
// The version is pinned to the Unicode version of the ICU in the Node that
// generates the torph fixtures (process.versions.unicode). Bumping it is a
// deliberate act: it changes how values segment, so the goldens move with it.

import { writeFileSync, mkdirSync } from "node:fs";
import { dirname } from "node:path";

const UNICODE_VERSION = "17.0.0";
const BASE = `https://www.unicode.org/Public/${UNICODE_VERSION}/ucd`;

if (process.versions.unicode !== UNICODE_VERSION.replace(/\.0$/, "")) {
  console.warn(
    `warning: this Node reports Unicode ${process.versions.unicode}, the tables ` +
      `are pinned to ${UNICODE_VERSION}. The torph fixtures are generated with ` +
      `this Node, so the two must agree or the goldens will disagree with the port.`,
  );
}

// Property value order is part of the generated output, so both ports index the
// same way. Adding a value appends; it never reorders.
const GRAPHEME_VALUES = [
  "Other", "CR", "LF", "Control", "Extend", "ZWJ", "Regional_Indicator",
  "Prepend", "SpacingMark", "L", "V", "T", "LV", "LVT",
];
const WORD_VALUES = [
  "Other", "CR", "LF", "Newline", "Extend", "ZWJ", "Regional_Indicator",
  "Format", "Katakana", "Hebrew_Letter", "ALetter", "Single_Quote",
  "Double_Quote", "MidNumLet", "MidLetter", "MidNum", "Numeric",
  "ExtendNumLet", "WSegSpace",
];
const INCB_VALUES = ["None", "Consonant", "Extend", "Linker"];

async function fetchText(path) {
  const url = `${BASE}/${path}`;
  const response = await fetch(url);
  if (!response.ok) throw new Error(`${url}: HTTP ${response.status}`);
  return response.text();
}

/** Parses the `start..end; Value` shape every UCD data file uses. */
function* entries(text) {
  for (const rawLine of text.split("\n")) {
    const line = rawLine.split("#")[0].trim();
    if (line.length === 0) continue;
    const fields = line.split(";").map((field) => field.trim());
    const [range, ...rest] = fields;
    const [startHex, endHex] = range.split("..");
    yield {
      start: parseInt(startHex, 16),
      end: parseInt(endHex ?? startHex, 16),
      fields: rest,
    };
  }
}

/** Ranges for one property, coalesced so adjacent runs of a value become one. */
function coalesce(ranges) {
  const sorted = [...ranges].sort((a, b) => a.start - b.start);
  const out = [];
  for (const range of sorted) {
    const last = out[out.length - 1];
    if (last && last.value === range.value && range.start === last.end + 1) {
      last.end = range.end;
    } else {
      out.push({ ...range });
    }
  }
  return out;
}

// `pick` rather than `valueOf`: destructuring a name that exists on
// Object.prototype never falls through to the default.
function propertyRanges(text, values, { match = () => true, pick } = {}) {
  const ranges = [];
  for (const entry of entries(text)) {
    if (!match(entry)) continue;
    const name = pick ? pick(entry) : entry.fields[0];
    const value = values.indexOf(name);
    // A value this port has no rule for is Other, which is the table's default
    // and therefore costs nothing to leave out.
    if (value <= 0) continue;
    ranges.push({ start: entry.start, end: entry.end, value });
  }
  return coalesce(ranges);
}

/** Ranges for a boolean property, as start and end pairs. */
function booleanRanges(text, property) {
  const ranges = [];
  for (const entry of entries(text)) {
    if (entry.fields[0] !== property) continue;
    ranges.push({ start: entry.start, end: entry.end, value: 1 });
  }
  return coalesce(ranges);
}

/** The break test files, as a list of code point runs per expected cluster. */
function parseBreakTest(text) {
  const cases = [];
  for (const rawLine of text.split("\n")) {
    const [body, comment] = rawLine.split("#");
    const line = body.trim();
    if (line.length === 0) continue;
    // The shape is: ÷ 0061 × 0301 ÷  where ÷ is a break and × is not.
    const tokens = line.split(/\s+/).filter((token) => token.length > 0);
    const clusters = [];
    let current = [];
    for (const token of tokens) {
      if (token === "÷") {
        if (current.length > 0) clusters.push(current);
        current = [];
      } else if (token === "×") {
        // no break here, so the next code point joins the run
      } else {
        current.push(parseInt(token, 16));
      }
    }
    if (current.length > 0) clusters.push(current);
    if (clusters.length === 0) continue;
    cases.push({ clusters, note: (comment ?? "").trim() });
  }
  return cases;
}

function flatten(ranges, withValue) {
  const out = [];
  for (const range of ranges) {
    out.push(range.start, range.end);
    if (withValue) out.push(range.value);
  }
  return out;
}

// Wrapped by column rather than by count, because a table of astral code points
// has six hex digits to a value where a table of Latin ones has two, and a
// fixed count that fits one overruns the other. Both projects lint the width of
// the file they generate.
//
// Swift and Kotlin also disagree about a trailing comma in a literal list, and
// both lint for that too, so the caller says which it wants.
function hexLiterals(numbers, maxWidth, indent, trailingComma) {
  const literals = numbers.map((n) => `0x${n.toString(16).toUpperCase()}`);
  const lines = [];
  let line = indent;
  for (const [index, literal] of literals.entries()) {
    const last = index === literals.length - 1;
    const piece = literal + (last && !trailingComma ? "" : ",");
    if (line !== indent && line.length + 1 + piece.length > maxWidth) {
      lines.push(line);
      line = indent;
    }
    line += line === indent ? piece : ` ${piece}`;
  }
  if (line !== indent) lines.push(line);
  return lines.join("\n");
}

function swiftEnum(name, values, doc) {
  const cases = values
    .map((value, index) => `    /// UAX #29 ${value}\n    case ${lowerFirst(value)} = ${index}`)
    .join("\n");
  return `/// ${doc}\nenum ${name}: UInt8, Sendable {\n${cases}\n}\n`;
}

function kotlinEnum(name, values, doc) {
  const cases = values.map((value) => `    ${screamingSnake(value)},`).join("\n");
  return `/** ${doc} */\ninternal enum class ${name} {\n${cases}\n}\n`;
}

function lowerFirst(value) {
  // The UCD names are already camel or Pascal within each underscore-separated
  // part, so joining and lowering the first character is enough. Only the
  // all-caps names need saying, since "cR" is not a word.
  const overrides = {
    CR: "cr", LF: "lf", ZWJ: "zwj", L: "l", V: "v", T: "t", LV: "lv", LVT: "lvt",
  };
  if (overrides[value]) return overrides[value];
  const joined = value.split("_").join("");
  return joined[0].toLowerCase() + joined.slice(1);
}

function screamingSnake(value) {
  return value.replace(/([a-z0-9])([A-Z])/g, "$1_$2").toUpperCase();
}

const HEADER_LINES = (target) => [
  `// Generated by Tools/gen-unicode-tables.mjs from Unicode ${UNICODE_VERSION}. Do not edit.`,
  "//",
  "// Regenerate with:",
  target === "swift"
    ? "//   node Tools/gen-unicode-tables.mjs --swift Sources/TextMorph/Core/UnicodeBreakTables.swift"
    : "//   node Tools/gen-unicode-tables.mjs --kotlin textmorph/src/main/kotlin/io/github/dim971/textmorph/core/UnicodeBreakTables.kt",
  "//",
  "// Each table is a flat, sorted, non-overlapping list of ranges. A table with",
  "// values holds start, end, value triples; a boolean table holds start, end",
  "// pairs. Anything not listed takes the table's default.",
];

function emitSwift(tables) {
  const parts = [];
  parts.push(HEADER_LINES("swift").join("\n"));
  parts.push("");
  parts.push(swiftEnum("GraphemeBreakProperty", GRAPHEME_VALUES, "Grapheme_Cluster_Break, from UAX #29."));
  parts.push(swiftEnum("WordBreakProperty", WORD_VALUES, "Word_Break, from UAX #29."));
  parts.push(swiftEnum("IndicConjunctBreak", INCB_VALUES, "Indic_Conjunct_Break, needed by rule GB9c."));
  parts.push("/// The generated property tables.");
  parts.push("enum UnicodeBreakTables {");
  parts.push(`    /// The Unicode version these tables were generated from.`);
  parts.push(`    static let unicodeVersion = "${UNICODE_VERSION}"`);
  parts.push("");
  for (const [name, numbers, stride] of tables) {
    parts.push(`    /// ${stride === 3 ? "start, end, value" : "start, end"} triples, sorted by start.`);
    parts.push(`    static let ${name}: [UInt32] = [`);
    parts.push(hexLiterals(numbers, 110, "        ", false));
    parts.push("    ]");
    if (name !== tables[tables.length - 1][0]) parts.push("");
  }
  parts.push("}");
  return parts.join("\n") + "\n";
}

function emitKotlin(tables) {
  const parts = [];
  parts.push("package io.github.dim971.textmorph.core");
  parts.push("");
  parts.push(HEADER_LINES("kotlin").join("\n"));
  parts.push("//");
  parts.push("// The tables are hex rather than integer literals, six characters each, and");
  parts.push("// that is not a stylistic choice: a JVM static initialiser cannot exceed 64KB");
  parts.push("// of bytecode, and an `intArrayOf` of a few thousand elements does. A string");
  parts.push("// is a constant-pool entry rather than bytecode, so it costs nothing to load");
  parts.push("// and is decoded once. The Swift side has no such limit and keeps arrays.");
  parts.push("");
  parts.push(kotlinEnum("GraphemeBreakProperty", GRAPHEME_VALUES, "Grapheme_Cluster_Break, from UAX #29."));
  parts.push(kotlinEnum("WordBreakProperty", WORD_VALUES, "Word_Break, from UAX #29."));
  parts.push(kotlinEnum("IndicConjunctBreak", INCB_VALUES, "Indic_Conjunct_Break, needed by rule GB9c."));
  parts.push("/** The generated property tables. */");
  parts.push("internal object UnicodeBreakTables {");
  parts.push(`    /** The Unicode version these tables were generated from. */`);
  parts.push(`    const val UNICODE_VERSION: String = "${UNICODE_VERSION}"`);
  parts.push("");
  for (const [name, numbers, stride] of tables) {
    const hex = numbers.map((n) => n.toString(16).toUpperCase().padStart(6, "0")).join("");
    parts.push(`    /** ${stride === 3 ? "start, end, value" : "start, end"} triples, sorted by start. */`);
    parts.push(`    val ${screamingSnake(name)}: IntArray = decode(`);
    // Wrapped so the generated file stays readable at a hundred columns, and
    // concatenated by the compiler rather than at runtime.
    const chunks = [];
    for (let i = 0; i < hex.length; i += 84) chunks.push(hex.slice(i, i + 84));
    parts.push(chunks.map((chunk) => `        "${chunk}"`).join(" +\n"));
    parts.push("    )");
    parts.push("");
  }
  parts.push("    /** Six hex characters per integer, in order. */");
  parts.push("    private fun decode(hex: String): IntArray {");
  parts.push("        val out = IntArray(hex.length / 6)");
  parts.push("        for (index in out.indices) {");
  parts.push("            out[index] = hex.substring(index * 6, index * 6 + 6).toInt(16)");
  parts.push("        }");
  parts.push("        return out");
  parts.push("    }");
  parts.push("}");
  return parts.join("\n") + "\n";
}

function write(path, contents) {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, contents);
  console.log(`wrote ${path} (${contents.length} bytes)`);
}

const args = process.argv.slice(2);
function flag(name) {
  const index = args.indexOf(name);
  return index >= 0 ? args[index + 1] : undefined;
}

const [graphemeText, wordText, emojiText, coreText, graphemeTest, wordTest] = await Promise.all([
  fetchText("auxiliary/GraphemeBreakProperty.txt"),
  fetchText("auxiliary/WordBreakProperty.txt"),
  fetchText("emoji/emoji-data.txt"),
  fetchText("DerivedCoreProperties.txt"),
  fetchText("auxiliary/GraphemeBreakTest.txt"),
  fetchText("auxiliary/WordBreakTest.txt"),
]);

const grapheme = propertyRanges(graphemeText, GRAPHEME_VALUES);
const word = propertyRanges(wordText, WORD_VALUES);
const extendedPictographic = booleanRanges(emojiText, "Extended_Pictographic");
// DerivedCoreProperties lists these as `InCB; Linker` and so on.
const incb = propertyRanges(coreText, INCB_VALUES, {
  match: (entry) => entry.fields[0] === "InCB",
  pick: (entry) => entry.fields[1],
});

const tables = [
  ["grapheme", flatten(grapheme, true), 3],
  ["word", flatten(word, true), 3],
  ["extendedPictographic", flatten(extendedPictographic, false), 2],
  ["indicConjunctBreak", flatten(incb, true), 3],
];

console.log(
  `ranges: grapheme ${grapheme.length}, word ${word.length}, ` +
    `extendedPictographic ${extendedPictographic.length}, incb ${incb.length}`,
);

const swiftPath = flag("--swift");
if (swiftPath) write(swiftPath, emitSwift(tables));

const kotlinPath = flag("--kotlin");
if (kotlinPath) write(kotlinPath, emitKotlin(tables));

const testsPath = flag("--tests");
if (testsPath) {
  const payload = {
    unicodeVersion: UNICODE_VERSION,
    grapheme: parseBreakTest(graphemeTest),
    word: parseBreakTest(wordTest),
  };
  write(testsPath, JSON.stringify(payload, null, 1) + "\n");
  console.log(`cases: grapheme ${payload.grapheme.length}, word ${payload.word.length}`);
}

if (!swiftPath && !kotlinPath && !testsPath) {
  console.error("nothing to do: pass --swift, --kotlin or --tests with a path");
  process.exit(2);
}
