---
name: pdf-to-markdown
description: "Converts PDF files to Markdown with PyMuPDF4LLM before Claude reads them, with content-hash caching so the same PDF is never reconverted twice. TRIGGER: whenever a PDF file is referenced, attached, opened, uploaded, or about to be read — any .pdf path, including right before calling the Read tool on one — invoke this skill FIRST so Claude reads the cached/converted Markdown instead of paying native multimodal PDF token costs on every access. Also invoke explicitly via /pdf-to-markdown <path>. Installs and self-updates its own isolated PyMuPDF4LLM environment automatically; falls back to native PDF reading if conversion looks unreliable."
trigger: /pdf-to-markdown
allowed-tools: Bash(${CLAUDE_SKILL_DIR}/scripts/ensure_env.sh:*)
---

# /pdf-to-markdown

Intercepts PDF reads and serves a cached [PyMuPDF4LLM](https://github.com/pymupdf/pymupdf4llm) Markdown conversion instead of the raw file, to cut token cost and latency — especially on any PDF read more than once.

## Why PyMuPDF4LLM, and why cache

This skill's tool choice and cache design come directly from a hands-on comparison of 7 PDF→Markdown approaches (Docling, Marker, MinerU, MarkItDown, pdfplumber, PyMuPDF4LLM, and Claude's native PDF reading) run on real single-column and multi-column business documents. Findings that shaped this skill:

- **PyMuPDF4LLM was the only conversion tool that got multi-column reading order right** — the layout-aware "AI-native" tools (Docling, Marker) looked more polished but silently detached dollar values from their labels on multi-column documents, which is worse than no structure at all when an LLM is the reader.
- It's also the **lightest and fastest**: no GPU, no torch, ~60 MB of deps, sub-second conversions once warmed up — versus multi-GB installs and 10–60+ second conversions for Docling/Marker/MinerU.
- Claude's own native PDF reading (no conversion) was fully accurate in testing too, but only because it sends a full-resolution page image alongside the text — that costs meaningfully more tokens per read than a KB-scale Markdown file, and that cost repeats on every single access. Converting once and caching the result avoids paying it more than once per unique file.
- Known failure mode to watch for: PyMuPDF4LLM can misread stylized logo/header text (e.g. a wordmark) and occasionally forces plain header text into a table cell, splitting a word mid-way. Both are cosmetic — they hit decorative content, not data fields — but worth a glance if something in a header looks garbled.
- While building this skill, reconverting the same test PDF produced a slightly different table split on the very first run versus every rerun after it (same file, same tool version) — the output stabilized from the second conversion onward. This is a second, independent reason to cache: a cached result is guaranteed byte-identical on every reuse, even though a fresh conversion isn't perfectly guaranteed to be.

## What you must do when a PDF is about to enter context

Do this **before** calling `Read` on any `.pdf` path — that includes files the user attaches, references by path, or that you're about to open for any reason.

### Step 1 — Convert (or fetch from cache)

Run, for each PDF path:

```bash
bash "${CLAUDE_SKILL_DIR}/scripts/ensure_env.sh" "<absolute path to the .pdf>"
```

First run ever: this creates an isolated venv at `${CLAUDE_SKILL_DIR}/.venv` (Python 3.11, via `uv` if available, otherwise `python -m venv`) and installs `pymupdf4llm`. Every run after that is fast — the environment check is a local import, not a network call.

The script prints exactly one JSON line to stdout (setup/progress messages go to stderr, ignore those unless something failed):

```json
{"status": "converted", "markdown_path": "...", "original_path": "...", "sha256": "...", "conversion_seconds": 0.4, "markdown_bytes": 1234}
```
or
```json
{"status": "cache_hit", "markdown_path": "...", "original_path": "...", "sha256": "...", "converted_at": "2026-08-13T20:41:00Z", "markdown_bytes": 1234}
```
or
```json
{"status": "error", "message": "..."}
```

### Step 2 — Act on the result

- **`converted` or `cache_hit`**: `Read` the file at `markdown_path` instead of the original PDF. Mention in one short line whether it was freshly converted or served from cache (e.g. "(cached, converted 2026-08-10)") — don't belabor it.
- **`error`**: fall back to `Read`-ing the original PDF directly (Claude's native multimodal PDF handling). Say briefly that conversion failed and native reading was used instead — don't fail the user's actual request over a converter hiccup.

### Step 3 — Sanity check (only if something looks off)

If the converted Markdown is suspiciously short (near-empty) relative to the PDF's apparent size/page count, or is obviously corrupted, treat it as unreliable: fall back to `Read`-ing the original PDF natively rather than working from bad data. This should be rare — flag it if it happens, since it may mean the PDF is a pure scanned image PyMuPDF4LLM's OCR fallback handled poorly.

## Cache design

**Cache key is the SHA-256 hash of the PDF's bytes — never the filename.** This is the only correct way to answer "have I already converted this exact file": two different files that happen to share a name get different hashes and are converted independently; the same file encountered again under a different name, path, or copy hashes identically and hits the cache. Filename, size, or mtime alone can't guarantee this in either direction.

- Markdown lives at `${CLAUDE_SKILL_DIR}/cache/<sha256>.md`.
- A sidecar `${CLAUDE_SKILL_DIR}/cache/<sha256>.json` records the original path/name, size, source mtime, conversion timestamp, tool version, and output size — so any cache entry can be traced back to what it came from.
- This cache is **persistent**, deliberately not the OS temp directory — the entire point is to avoid re-paying conversion cost for a PDF already processed, and temp directories get cleared, which would silently defeat that. It survives across projects and sessions, since PDFs referenced in different projects can still be the same file.

## Environment maintenance

- `pymupdf4llm`'s own update is checked at most **once every 7 days** (tracked via `${CLAUDE_SKILL_DIR}/.last_update_check`), not on every conversion — keeps repeat conversions fast and doesn't require network access most of the time.
- To force an update check right now: `/pdf-to-markdown --update` (or delete `${CLAUDE_SKILL_DIR}/.last_update_check` and run any conversion).
- To force a specific file to reconvert instead of using its cache entry: `/pdf-to-markdown <path> --force`.

## Manual invocation

- `/pdf-to-markdown <path>` — convert (or serve from cache), report the markdown path.
- `/pdf-to-markdown <path> --force` — bypass the cache and reconvert.
- `/pdf-to-markdown --update` — force the dependency update check now, without converting anything.

## If automated setup fails

`ensure_env.sh` prints manual recovery steps to stderr if it can't create the environment or install the package itself — surface those to the user verbatim rather than paraphrasing, since they include exact commands. The short version:

1. Install [uv](https://astral.sh/uv) (recommended) or Python 3.11+.
2. `uv venv --python 3.11 "${CLAUDE_SKILL_DIR}/.venv"` (or `python -m venv "${CLAUDE_SKILL_DIR}/.venv"`).
3. `uv pip install --python "${CLAUDE_SKILL_DIR}/.venv" pymupdf4llm` (or activate the venv and `pip install pymupdf4llm`).

Dependencies pulled in by `pymupdf4llm` are `pymupdf` and `pymupdf-layout` — no GPU, no system packages, no Docker, no compiler needed on any platform tested.

## Cache maintenance

The cache grows by one `.md` + `.json` pair per unique PDF ever seen (by content, not by name). These are plain files — safe to delete individually or wipe `${CLAUDE_SKILL_DIR}/cache/` entirely at any time; the next request for that PDF just reconverts. No automatic eviction is implemented; if the cache grows large, clear it manually.

## Note on trigger reliability

This is a Claude-invoked skill, not a hard system hook — it fires when Claude recognizes a PDF is about to be read and chooses to invoke it, which is reliable in practice but not mechanically guaranteed the way a `PreToolUse` hook on `Read` would be. If you need an absolute guarantee that raw PDF bytes never reach the model, ask for a hook instead (see the `update-config` skill) — this skill optimizes for the common case with minimal setup, not for enforcement.
