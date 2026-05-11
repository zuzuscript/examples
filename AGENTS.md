# ZuzuScript Examples

This repository contains small, practical ZuzuScript examples for learners,
documentation, demos, and syntax-tool validation.

Use Oxford English in documentation: mostly standard British English, with
`-ize` word endings.

## Relationship To Other Projects

The examples are consumed as submodules by runtimes, editor tooling, the
website, and documentation builds. They should demonstrate the language and
stdlib without relying on private implementation details.

When an example exposes a runtime or stdlib bug, fix the relevant runtime or
`stdlib` repository rather than changing the example to hide the issue,
unless the example is genuinely wrong or out of date.

## Writing Examples

- Keep examples small, readable, and focused on one practical idea.
- Prefer standard library APIs over runtime-specific hooks.
- Use environment variables for credentials, tokens, and service endpoints.
- Make networked examples safe to read without executing real side effects.
- Include enough comments to orient a newcomer, but avoid turning examples
  into full tutorials.
- Keep examples runnable from runtime checkouts that include this repository
  as `docs/examples`.

## ZuzuScript Style

Use tabs for indentation, spaces for alignment, One True Brace Style,
uncuddled `else`, whitespace around binary operators, and semicolons as
terminators. Keep code lines under 80 columns where practical.

POD code samples should use spaces, not tabs. Blank lines in POD code blocks
may need indentation to avoid ending the block.

## Validation

Run changed examples with the runtime they target:

- General language and stdlib examples should run under `zuzu-perl` and, if
  supported, `zuzu-rust` and `zuzu-js`.
- PSGI examples target `zuzu-perl`.
- Rust web-server examples target `zuzu-rust`.
- GUI/browser examples may require the JS or Rust GUI host described in the
  example.

Do not commit secrets, generated local output, or machine-specific paths.
