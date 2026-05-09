# ZuzuScript examples

Small, newcomer-friendly examples that show practical tasks with ZuzuScript.

- `01_raccoon_class.zzs` — tiny object-oriented example with Zia.
- `02_etl_sleepy_log_to_json.zzs` — simple CSV → JSON ETL flow.
- `03_openai_api_story.zzs` — calls the OpenAI API with `std/net/http`.
- `04_mastodon_post.zzs` — posts a status to a Mastodon server.
- `05_system_automation_backup.zzs` — timestamped backup + shell command.
- `06_text_processing_zia_digest.zzs` — quick regex/split/join text workflow.
- `07_gui_controls_demo.zzs` — builds a small `std/gui` window and
  wires control events.
- `08_gui_extended_controls_demo.zzs` — shows Phase 3 GUI widgets such
  as sliders, progress bars, tabs, lists, and trees.
- `09_gui_dialogue_demo.zzs` — opens every `std/gui/dialogue` helper
  and prints each result.
- `10_web_psgi_app.zzs` and `10_web_psgi_app.psgi` — runs a small
  ZuzuScript web app through Plack/PSGI.
- `11_web_compat_static.zzs` — web response examples for text, binary,
  and `std/io` Path file bodies.
- `12_rust_web_server.zzs` — minimal app for the Rust `zuzu-rust-server`
  binary, including a static `Path` response.

Tip: set required environment variables before running API examples.

Run the PSGI example with:

```sh
plackup examples/10_web_psgi_app.psgi
```

The `.psgi` file returns a normal PSGI app, so it can be wrapped with
standard Plack middleware and served by normal Plack-compatible servers.

Run the compatibility static-file example from the repository root with:

```sh
bin/zuzu-plackup -Imodules examples/11_web_compat_static.zzs -- -p 5000
```

Run the Rust web server example from the repository root with:

```sh
cargo run --manifest-path extras/zuzu-rust/Cargo.toml \
  --bin zuzu-rust-server -- \
  --listen 127.0.0.1:3000 \
  examples/12_rust_web_server.zzs
```
