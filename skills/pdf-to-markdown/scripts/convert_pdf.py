#!/usr/bin/env python3
"""Convert a PDF to Markdown via PyMuPDF4LLM, with content-hash caching.

Run inside the skill's own venv (see ensure_env.sh) — pymupdf4llm must be
importable.

Usage:
    python convert_pdf.py <pdf_path> [--force]

Prints exactly one JSON object to stdout and nothing else on success paths;
diagnostic/progress text (if any) goes to stderr. Exit code 0 on
cache_hit/converted, 1 on error.

Cache key is the SHA-256 of the file's bytes, not its name or path. This is
the only correct way to answer "is this the same PDF" — two files that
happen to share a name are almost certainly different content and must get
different cache entries (different hash -> miss); the same PDF encountered
again under a different name, path, or copy must reuse the existing
conversion (same hash -> hit). Name/size/mtime alone can't guarantee either
direction: sizes collide, mtimes change on copy, names are arbitrary.
"""
import sys
import json
import hashlib
import time
from pathlib import Path
from datetime import datetime, timezone


def sha256_of(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def main() -> int:
    raw_args = sys.argv[1:]
    force = "--force" in raw_args
    positional = [a for a in raw_args if not a.startswith("--")]

    if not positional:
        print(json.dumps({"status": "error", "message": "usage: convert_pdf.py <pdf_path> [--force]"}))
        return 1

    pdf_path = Path(positional[0]).expanduser().resolve()

    if not pdf_path.exists():
        print(json.dumps({"status": "error", "message": f"file not found: {pdf_path}"}))
        return 1
    if pdf_path.suffix.lower() != ".pdf":
        print(json.dumps({"status": "error", "message": f"not a .pdf file: {pdf_path}"}))
        return 1

    skill_dir = Path(__file__).resolve().parent.parent
    cache_dir = skill_dir / "cache"
    cache_dir.mkdir(parents=True, exist_ok=True)

    file_hash = sha256_of(pdf_path)
    md_path = cache_dir / f"{file_hash}.md"
    meta_path = cache_dir / f"{file_hash}.json"

    if md_path.exists() and meta_path.exists() and not force:
        meta = json.loads(meta_path.read_text(encoding="utf-8"))
        print(json.dumps({
            "status": "cache_hit",
            "markdown_path": str(md_path),
            "original_path": str(pdf_path),
            "sha256": file_hash,
            "converted_at": meta.get("converted_at"),
            "markdown_bytes": meta.get("markdown_bytes"),
        }))
        return 0

    try:
        import pymupdf4llm
    except ImportError as e:
        print(json.dumps({"status": "error", "message": f"pymupdf4llm not importable: {e}"}))
        return 1

    try:
        t0 = time.time()
        markdown = pymupdf4llm.to_markdown(str(pdf_path))
        elapsed = time.time() - t0
    except Exception as e:
        print(json.dumps({"status": "error", "message": f"conversion failed: {e}"}))
        return 1

    md_path.write_text(markdown, encoding="utf-8")

    try:
        from importlib.metadata import version as pkg_version
        tool_version = pkg_version("pymupdf4llm")
    except Exception:
        tool_version = None

    stat = pdf_path.stat()
    meta = {
        "original_path": str(pdf_path),
        "original_name": pdf_path.name,
        "size_bytes": stat.st_size,
        "source_mtime": datetime.fromtimestamp(stat.st_mtime, tz=timezone.utc).isoformat(),
        "converted_at": datetime.now(timezone.utc).isoformat(),
        "conversion_seconds": round(elapsed, 2),
        "sha256": file_hash,
        "tool": "pymupdf4llm",
        "tool_version": tool_version,
        "markdown_bytes": len(markdown.encode("utf-8")),
    }
    meta_path.write_text(json.dumps(meta, indent=2), encoding="utf-8")

    print(json.dumps({
        "status": "converted",
        "markdown_path": str(md_path),
        "original_path": str(pdf_path),
        "sha256": file_hash,
        "conversion_seconds": round(elapsed, 2),
        "markdown_bytes": meta["markdown_bytes"],
    }))
    return 0


if __name__ == "__main__":
    sys.exit(main())
