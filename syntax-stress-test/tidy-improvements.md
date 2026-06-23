# Zuzu::Tidy Improvements Plan

## Summary

Fix `Zuzu::Tidy` so tidying the syntax-stress uglified scripts preserves
parseability and produces structure close to `manually-tidied`. Implement
this in `zuzu-perl/lib/Zuzu/Tidy.pm`, covered by
`zuzu-perl/t/integration/tidy.t`.

## Known Issues with Zuzu::Tidy

- Pairlists and pairlist spreads are not preserved reliably. For example,
  the ugly source `...{{ left: "(", left: "{" }}` is currently output as
  `...{` followed by a nested `{ ... }` block, which `zuzu-js` rejects as
  invalid syntax. Ideally it should remain a pairlist spread, formatted as
  either `...{{ left: "(", left: "{" }}` on one line or a multiline
  `...{{ ... }}` pairlist whose opening and closing delimiters are still
  visibly doubled.
- Dicts containing pairlists are over-compressed and structurally confusing.
  In the collection stress file, the `data` dict is currently emitted as a
  dense line containing array items, set literals, a bag, and `meta: {{`
  all together. Ideally nested collection literals should either stay on one
  readable line when short, or split by syntactic level with array/dict items
  indented under their own delimiters and pairlists kept as `{{ ... }}`.
- Function, method, class, and async function opening braces often do not
  force a new body line. Current output includes shapes such as
  `function classify (...) -> String{ if (...) {`, `class Record with
  Labelled{ let String name ...`, `method summary () -> String{ return ...`,
  and `async function delayed_double (...) -> Number{ await {`. Ideally a
  declaration block opener should always be followed by a newline and an
  indented body, even if the original source was one-line.
- Closing one block and starting the next declaration can be collapsed onto
  one line. Current output includes `} static method make (...) {` inside the
  class body. Ideally each member declaration should start on its own line,
  with the previous method body fully closed before the next declaration.
- `try`/`catch` and `for`/`else` are visually detached. Current output can
  insert a blank line between the closing `}` and the following `catch` or
  `else`. Ideally compound control continuations should stay adjacent:
  `}` followed immediately by `catch (...) {` or `else {` on the next line,
  with no blank line.
- Multiline function calls with anonymous function arguments indent badly.
  Current output for `call_twice(function(value) { ... }, 4)` closes the
  callback, then places the comma and `4` on a separate oddly indented line.
  Ideally the callback should be treated as one call argument: the callback
  body is indented normally, the closing `}` is followed by a comma as part
  of the argument list, and subsequent arguments align with the first.
- Wrapping can split inside postfix/index expressions and produce invalid
  code. Current output splits `async_lambdas[0](10)` as
  `async_lambdas[0,` followed by `](10)`, which fails to parse. Ideally
  bracketed indexes, slices, and postfix calls should be indivisible for line
  wrapping; wrapping may happen before the expression or after the call, but
  never between `[` and `]` for a simple index.
- Switch comparator spacing is hard to read. Current output uses
  `switch ( n mod 4: = )`, merging the comparator marker with the left
  expression. Ideally it should preserve readable spacing around the switch
  comparator marker, for example `switch ( n mod 4 : = )`.
- Access chains are separated by unwanted spaces. Current output includes
  `data{users} [0]{roles}`. Ideally chained dict/index access should stay
  tight as `data{users}[0]{roles}`.
- Slice/index spacing is too noisy. Current output changes `text[1:2]` and
  `bytes[2:2]` into `text[ 1: 2 ]` and `bytes[ 2: 2 ]`. Ideally simple
  indexes and slices should remain compact: `text[1:2]`, `bytes[2:2]`, and
  `array[0]`.
- Concatenation spacing around punctuation is inconsistent. Current output
  includes forms such as `text _":" _ item` and `self.label() _":" _ (...)`.
  Ideally the string concatenation operator should be spaced consistently on
  both sides, including punctuation literals: `text _ ":" _ item`.
- Some valid output happens to parse in one runtime but fails in another.
  The pairlist-spread output in script 04 is accepted by `zuzu-perl` and
  `zuzu-rust` but rejected by `zuzu-js`; the split index output in script 05
  is rejected by `zuzu-perl`, `zuzu-js`, and `zuzu-rust`. Ideally tidy output
  should parse and run under all three runtimes for these shared syntax
  stress fixtures.

## Implementation Phases

### Phase 1: Regression Harness And Baseline

- Add integration fixtures that run `Zuzu::Tidy->tidy` on the five
  `examples/syntax-stress-test/uglified/*.zzs` files. (This will
  involve copying the uglified files to `t/fixtures/ugly`. Do not
  modify the ugly files to make them cleaner: they are intentionally
  ugly to be useful as tests for zuzu-tidy.pl.)
- Assert each tidied result parses with `Zuzu::Parser` and runs under
  `zuzu-perl`.
- Add focused assertions for the known bad shapes: pairlist spread,
  class/function opening braces, `try`/`catch`, `for`/`else`, multiline
  function-call arguments, and array index calls.
- Exit criteria: current formatter failures are reproduced by tests,
  `manually-tidied/*.zzs` still pass under Perl/JS/Rust, and no production
  formatter code has been changed yet.

### Phase 2: Preserve Delimiter Structure

- Stop normalizing `{{` and `}}` into independent `{`/`}` tokens for
  formatting decisions, or annotate the split tokens as pairlist delimiters
  so they cannot be treated as nested dict/block braces.
- Replace regex-based pairlist reconstruction in
  `_normalize_split_brace_literals` with token-context-aware handling that
  preserves `{{ ... }}` and `...{{ ... }}` exactly as pairlist syntax.
- Update delimiter pairing/wrapping so line breaks are never inserted inside
  indivisible postfix/index constructs like `async_lambdas[0](10)`.
- Exit criteria: auto-tidied equivalents for scripts 04 and 05 parse in
  `zuzu-perl`, `zuzu-js`, and `zuzu-rust`; pairlist spread output remains
  valid `...{{ ... }}`; no formatter pass creates `{ { ... } }` from
  pairlists.

### Phase 3: Block Boundary Formatting

- Tighten block classification in `_is_inline_brace` and `_tidy_code_chunk`
  so declaration and control blocks always emit a newline immediately after
  `{`.
- Cover `function`, `async function`, `method`, `static method`, `class`,
  `trait`, `if`, `else`, `for`, `while`, `switch`, `try`, `catch`, `do`,
  `await`, and `spawn`.
- Keep `else` attached to its preceding block and `catch` attached to its
  `try` block with no blank line between them.
- Exit criteria: no output contains `function ... { statement`,
  `class ... { field`, or `} static method` on one line; `try`/`catch` and
  `for`/`else` remain adjacent in all stress fixtures.

### Phase 4: Multiline Calls And Continuation Indentation

- Replace the current generic wrap-at-comma/operator rule with
  delimiter-aware wrapping: when wrapping call arguments, place each argument
  on its own continuation line, indent one level from the call start, and put
  the closing `)` aligned with the call expression.
- Treat anonymous function arguments as a complete argument: close the
  callback block, then place the comma and following argument in normal
  call-argument position.
- Avoid wrapping inside indexing brackets, slices, pairlist braces, and
  spread prefixes.
- Exit criteria: multiline calls in script 04 and multiline `await { ... }`
  arguments in script 05 are parseable and visually nested; no line break
  occurs between an index value and its closing `]`.

### Phase 5: Whitespace Rules Cleanup

- Adjust operator spacing tables so switch comparators keep readable spacing
  around `:` and the comparator operator, for example
  `switch ( n mod 4 : = )`.
- Keep access chains tight: `data{users}[0]{roles}`, not
  `data{users} [0]{roles}`.
- Keep slices compact: `text[1:2]`, not `text[ 1: 2 ]`.
- Keep string concatenation around punctuation readable:
  `text _ ":" _ item`, not `text _":" _ item`.
- Exit criteria: focused tests for switch comparator spacing, access chains,
  slices, and concatenation all pass; existing operator canonicalisation
  tests still pass.

### Phase 6: End-To-End Acceptance

- Run `prove -lr t/integration/tidy.t` in `zuzu-perl`.
- Tidy all five `uglified/*.zzs` files to temporary output only, then run
  the temporary outputs under `zuzu-perl`, `zuzu-js`, and `zuzu-rust`.
- Compare temporary tidy output against `manually-tidied` for major
  structural expectations, not exact byte-for-byte equality.
- Exit criteria: all tidy integration tests pass; all five tidied temporary
  scripts parse and run under all three runtimes; no tracked files under
  `manually-tidied` or `auto-tidied-1` are modified.

## Key Changes

- Prefer token/delimiter-aware formatting over post-hoc regex normalisation
  for pairlists, arrays, sets, bags, calls, and indexes.
- Keep validation after tidying, but make it meaningful by failing tests when
  generated output is invalid rather than silently returning malformed but
  attempted output.
- Preserve current CLI interface and `--canonical-operators` behaviour.

## Test Plan

- Add unit-style integration cases for each systematic issue:
  - `...{{ left: "(", left: "{" }}` remains a pairlist spread.
  - `async_lambdas[0](10)` is never split inside `[0]`.
  - `class Record with Labelled {` is followed by a newline and indented
    body.
  - `catch` follows `try` without an intervening blank line.
  - multiline calls with callback arguments indent consistently.
  - `data{users}[0]{roles}`, `text[1:2]`, and switch comparator spacing stay
    readable.
- Add an end-to-end test loop over the syntax-stress uglified fixtures using
  temporary tidied output.
- Run targeted cross-runtime smoke tests on the tidied temporary outputs.

## Assumptions

- Do not modify `examples/syntax-stress-test/manually-tidied` or
  `examples/syntax-stress-test/auto-tidied-1`.
- Exact byte-for-byte matching to `manually-tidied` is not required;
  parseable, stable, idiomatic structure is required.
- Keep changes scoped to `Zuzu::Tidy` and its tests unless lexer/parser
  defects are discovered during implementation.

## Implementation Report

### Phase 1

Added a regression harness without touching `Zuzu::Tidy` production code.

- Copied the five `examples/syntax-stress-test/uglified/*.zzs` files verbatim
  into `zuzu-perl/t/fixtures/ugly/` (confirmed byte-identical via `diff`).
- Extended `zuzu-perl/t/integration/tidy.t` with a fixture-driven loop that,
  for each of the five fixtures: tidies it with `Zuzu::Tidy->tidy`, asserts
  the result parses with `Zuzu::Parser`, writes it to a temp file, and runs
  it under `bin/zuzu.pl` (with `-I stdlib/modules -I stdlib/test-modules`),
  checking for a clean TAP pass.
- Added the same parse+run assertions for the corresponding
  `examples/syntax-stress-test/manually-tidied/*.zzs` files (read directly,
  not copied/modified).
- Added eleven focused assertions reproducing the specific bad shapes from
  the Known Issues section: pairlist spread (`...{{ ... }}` must not split
  into nested `{ { ... } }`), forced newline after the opening brace for
  `class`, `function`, `method`, and `async function`, no `} static method`
  collapse, no blank line between `}`/`catch` or `}`/`else` after a 5+ line
  block, no stranded trailing call argument after a closing callback `}`,
  and no line break inside `[0]` of `async_lambdas[0](10)`.

Result: `prove -lv t/integration/tidy.t` now reports 111 assertions, 17
failing — all 17 failures are exactly the issues this plan sets out to fix
(the 6 fixture-loop failures for scripts 03/04/05, and the 11 new focused
assertions for pairlist spread, brace placement, static-method collapse,
try/catch and for/else cuddling, multiline call arguments, and index-call
splitting). Scripts 01 and 02 already round-trip cleanly. No code in
`lib/Zuzu/Tidy.pm` was modified in this phase.

One unrelated pre-existing bug was discovered and is **not** in scope for
this plan: `examples/syntax-stress-test/manually-tidied/03-collections-paths-and-slices.zzs`
fails under `zuzu-perl` with
`RuntimeError[E_RUNTIME_GENERIC]: Indexing expects Array, String, or BinaryString`
inside `stdlib/modules/std/path/z/node.zzm:738` (`Node.children()`). This
reproduces identically on the never-tidied `original/03-...zzs` source, so
it is a stdlib/runtime defect unrelated to `Zuzu::Tidy`, out of scope per
the Assumptions section. The corresponding test assertion is wrapped in a
`todo` block with that explanation so a future fix shows up as a new,
visible test failure rather than silently auto-passing.

### Phase 2

Root-caused and fixed the pairlist-delimiter and index-splitting bugs in
`lib/Zuzu/Tidy.pm`, instead of patching around them with regexes.

- **Pairlist halves are now tagged, not guessed.** `_normalize_tokens`
  still splits a single lexer `{{`/`}}` token into two `{`/`}` tokens (the
  rest of the formatter is built around single-brace tokens), but each
  synthesized half is now tagged with `_pairlist_half` (`open1`/`open2`/
  `close1`/`close2`) directly on the token object. `_is_inline_brace`
  checks this tag first and unconditionally treats `open1` as inline and
  `open2` as a block-opener, regardless of what precedes the pair. This
  was the actual root cause of the `...{{ ... }}` bug: the old context-only
  heuristic only recognised `{{` as inline when preceded by `:=`, `=`, `,`,
  `(`, `[`, or `:` — a spread `...` wasn't in that list, so the first `{`
  fell back to being treated as its own nested block, producing the
  reported `...{` + nested `{ ... }` shape.
- **Closing `}}` is kept tight at the token-loop level**, not stitched
  back together by post-hoc regex. `close1` now skips the normal
  block-closing flush so it stays on the same line as `close2`, and
  `_need_space_before` only suppresses the space between two adjacent `}`
  tokens when they are a real tagged `close1`/`close2` pair (genuinely
  independent adjacent closing braces, e.g. nested dict literals, still
  get a space, since collapsing those to `}}` would re-lex as a pairlist
  close).
- **Pairlist bodies get one-entry-per-line and trailing commas natively.**
  A parallel `@pairlist_body_stack` (tracking `[is_pairlist_body,
  paren_depth, bracket_depth]` per open brace) lets the main loop treat a
  top-level comma inside a pairlist body as a line break, the same way
  `;` is treated as a statement separator, and append a trailing comma
  when closing. The paren/bracket-depth guard means commas that belong to
  a nested call or array inside a pairlist value (e.g.
  `{{ a: [1,2,3], b: f(1,2) }}`) are correctly left alone. This made the
  old `_normalize_split_brace_literals` regex pass (which depended on
  recognising the specific broken `}\n};` shape the old bug produced)
  entirely dead code, so it was deleted along with its call site.
- **Index/call expressions are never split by line-wrapping**, fixed by
  replacing the naive "first occurrence of the close character on a later
  line" scan in `_normalize_split_sequence_literals` with a depth-aware
  scan (new `_find_matching_sequence_close`). The old scan found the
  closing `]` of an *inner* `[0]` index and mistook it for the closing `]`
  of the *outer* array literal, which is exactly what produced
  `async_lambdas[0,` / `](10);` in script 05.

Verified: `lib/Zuzu/Tidy.pm` t/integration/tidy.t assertions 87–90 and 101,
102, 111 (added in Phase 1) now pass. All five auto-tidied
`uglified/*.zzs` fixtures parse; scripts 01, 02, 04, and 05 now run
cleanly under `zuzu-perl`, `zuzu-js`, and `zuzu-rust`. Script 03's
auto-tidied output now also parses and runs under `zuzu-js`/`zuzu-rust`,
and under `zuzu-perl` it gets past parsing and fails only on the same
pre-existing, unrelated `std/path/z/node.zzm` runtime bug noted in Phase 1
(not a new regression — the still-messy `data` dict formatting for script
03 from Known Issue 2 is unaddressed until a later phase). `prove -lr t/`
shows no regressions outside the still-open Phase 3/4 assertions in
`tidy.t` (103–110) and the pre-existing todo'd bug (86/96).

### Phase 3

Fixed declaration-block brace classification and adjacent
control-continuation spacing in `lib/Zuzu/Tidy.pm`.

- **Root cause:** `_is_inline_brace` decided block-vs-inline by looking a
  fixed 1–2 tokens behind the `{`. That works for `if (...) {` (fixed
  distance) but breaks for declarations with a variable-length clause
  between the keyword and the brace: a return-type arrow
  (`function f() -> String {`) or a trait list
  (`class Record with Labelled {`). In both cases the token immediately
  before `{` is an identifier (the return type or the last trait name),
  not the declaring keyword, so the existing heuristic fell through to
  treating the brace as inline.
- **Fix:** added `_tag_declaration_block_braces`, which scans forward
  from each `class`/`trait`/`function`/`method` keyword (skipping an
  optional name, a balanced parameter-list `(...)`, an optional
  `extends Base` / `with Trait, ...` / `but Trait` clause, and an
  optional `-> Type` arrow) and tags the `{` it lands on with
  `_forced_block`. `_is_inline_brace` checks this tag first, before any
  of the old context heuristics, so the brace is always classified as a
  block regardless of what token directly precedes it. `async function`
  and `static method` need no special handling since the scan starts at
  the `function`/`method` token itself, wherever it is.
- **Cuddled continuations:** `_apply_vertical_spacing_rules` was adding a
  blank line after the closing `}` of any 5+ line block unconditionally,
  including when the next line was `catch` or `else`. It now checks
  whether the next non-blank line starts with `catch`/`else` and skips
  the blank line in that case, so `try`/`catch` and `for`/`else` stay
  adjacent for longer bodies (this previously already worked for bodies
  under 5 lines, which don't hit that rule).

Also fixed two test assertions left over from Phase 1/2 that used `\s*`
in their "bad shape" regexes — `\s` matches newlines, so e.g.
`qr/\{\s*let\b/` matched the *correct* `{\n\tlet ...` output just as
happily as the broken inline shape it was meant to catch. Replaced with
`[ \t]*` (same-line only) in the four brace-newline assertions and the
static-method-collapse assertion.

Verified: `t/integration/tidy.t` assertions 103–109 (added in Phase 1) now
pass. All five fixtures' auto-tidied output was spot-checked against
`manually-tidied` for class/trait/method structure (script 02) and
remains parseable/runnable under all three runtimes with the same
results as Phase 2 (script 03 still only blocked by the pre-existing,
unrelated `std/path/z/node.zzm` runtime bug under `zuzu-perl`).
`prove -lr t/` shows no regressions; only `tidy.t` assertion 110
(multiline call arguments, Phase 4's target) and the todo'd assertion 96
remain failing.

### Phase 4

TODO.

### Phase 5

TODO.

### Phase 6

TODO.

