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

TODO.

### Phase 2

TODO.

### Phase 3

TODO.

### Phase 4

TODO.

### Phase 5

TODO.

### Phase 6

TODO.

