from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import subprocess
import sys


def maybe_delegate() -> None:
    if os.environ.get("MOONBITMARK_PDF_BRIDGE_DELEGATED") == "1":
        return
    try:
        import pdfminer.high_level  # noqa: F401
        return
    except Exception:
        pass

    candidate = Path.home() / ".venvs" / "moonbitmark-baselines" / "Scripts" / "python.exe"
    if not candidate.exists():
        return
    if Path(sys.executable).resolve() == candidate.resolve():
        return

    env = dict(os.environ)
    env["MOONBITMARK_PDF_BRIDGE_DELEGATED"] = "1"
    completed = subprocess.run([str(candidate), __file__, *sys.argv[1:]], env=env, check=False)
    raise SystemExit(completed.returncode)


def extract_pages(input_path: Path) -> tuple[str | None, list[str], list[str]]:
    try:
        from pdfminer.high_level import extract_text
        from pdfminer.pdfpage import PDFPage
    except Exception as exc:
        return None, [], [f"pdfminer is unavailable: {exc}"]

    try:
        with input_path.open("rb") as fh:
            page_count = sum(1 for _ in PDFPage.get_pages(fh))
    except Exception as exc:
        return "pdfminer", [], [f"failed to count PDF pages: {exc}"]

    warnings: list[str] = []
    try:
        text = extract_text(str(input_path))
        pages = split_pdfminer_pages(text)
        pages = reconcile_page_count(pages, page_count, warnings)
        return "pdfminer", pages, warnings
    except Exception as exc:
        warnings.append(f"full-document extraction failed: {exc}")

    pages: list[str] = []
    for page_no in range(page_count):
        try:
            text = extract_text(str(input_path), page_numbers=[page_no])
        except Exception as exc:
            warnings.append(f"failed to extract page {page_no + 1}: {exc}")
            pages.append("")
            continue
        pages.append(text.replace("\r\n", "\n").replace("\r", "\n").rstrip("\n"))

    return "pdfminer", pages, warnings


def split_pdfminer_pages(text: str) -> list[str]:
    normalized = text.replace("\r\n", "\n").replace("\r", "\n")
    pages = [part.rstrip("\n") for part in normalized.split("\f")]
    while pages and not pages[-1].strip():
        pages.pop()
    return pages


def reconcile_page_count(pages: list[str], page_count: int, warnings: list[str]) -> list[str]:
    if page_count <= 0:
        return pages
    if len(pages) < page_count:
        warnings.append(
            f"pdfminer returned {len(pages)} page chunk(s) for {page_count} counted page(s); padding missing pages"
        )
        pages = [*pages, *([""] * (page_count - len(pages)))]
    elif len(pages) > page_count:
        extra = pages[page_count:]
        if any(part.strip() for part in extra):
            warnings.append(
                f"pdfminer returned {len(pages)} page chunk(s) for {page_count} counted page(s); truncating extras"
            )
        pages = pages[:page_count]
    return pages


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output-json", required=True)
    args = parser.parse_args()

    maybe_delegate()

    provider, pages, warnings = extract_pages(Path(args.input))
    payload = {
        "available": provider is not None and any(page.strip() for page in pages),
        "provider": provider,
        "pages": pages,
        "warnings": warnings,
    }
    output_path = Path(args.output_json)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(payload, ensure_ascii=False), encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
