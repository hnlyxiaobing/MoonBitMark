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


def normalize_box(left: float, top: float, right: float, bottom: float, width: float, height: float) -> dict:
    safe_width = max(1.0, width)
    safe_height = max(1.0, height)
    return {
        "left": max(0, min(1000, round(left * 1000 / safe_width))),
        "top": max(0, min(1000, round((safe_height - bottom) * 1000 / safe_height))),
        "right": max(0, min(1000, round(right * 1000 / safe_width))),
        "bottom": max(0, min(1000, round((safe_height - top) * 1000 / safe_height))),
    }


def iter_text_lines(node):
    try:
        from pdfminer.layout import LTTextLine
    except Exception:
        return

    if isinstance(node, LTTextLine):
        yield node
        return
    if hasattr(node, "__iter__"):
        for child in node:
            yield from iter_text_lines(child)


def extract_line_words(line, page_width: float, page_height: float) -> list[dict]:
    try:
        from pdfminer.layout import LTAnno, LTChar
    except Exception:
        return []

    words: list[dict] = []
    current_text = ""
    current_left = current_top = current_right = current_bottom = None
    previous_char = None

    def flush_word() -> None:
        nonlocal current_text, current_left, current_top, current_right, current_bottom
        if not current_text.strip() or current_left is None:
            current_text = ""
            current_left = current_top = current_right = current_bottom = None
            return
        words.append(
            {
                "text": current_text.strip(),
                **normalize_box(current_left, current_top, current_right, current_bottom, page_width, page_height),
            }
        )
        current_text = ""
        current_left = current_top = current_right = current_bottom = None

    for child in line:
        if isinstance(child, LTAnno):
            if str(child).isspace():
                flush_word()
            continue
        if not isinstance(child, LTChar):
            continue

        char_text = child.get_text()
        if not char_text.strip():
            flush_word()
            continue

        gap = 0.0 if previous_char is None else child.x0 - previous_char.x1
        if current_text and gap > max(1.5, child.width * 0.45):
            flush_word()

        current_text += char_text
        current_left = child.x0 if current_left is None else min(current_left, child.x0)
        current_top = child.y0 if current_top is None else min(current_top, child.y0)
        current_right = child.x1 if current_right is None else max(current_right, child.x1)
        current_bottom = child.y1 if current_bottom is None else max(current_bottom, child.y1)
        previous_char = child

    flush_word()
    return words


def extract_layout_pages(input_path: Path) -> tuple[list[dict], list[str]]:
    try:
        from pdfminer.high_level import extract_pages
    except Exception as exc:
        return [], [f"pdfminer layout extraction is unavailable: {exc}"]

    warnings: list[str] = []
    pages: list[dict] = []
    try:
        for page_no, layout_page in enumerate(extract_pages(str(input_path)), start=1):
            page_width = float(getattr(layout_page, "width", 0.0) or 0.0)
            page_height = float(getattr(layout_page, "height", 0.0) or 0.0)
            lines: list[dict] = []
            for line in iter_text_lines(layout_page):
                text = line.get_text().replace("\r\n", "\n").replace("\r", "\n").replace("\n", " ").strip()
                if not text:
                    continue
                line_box = normalize_box(line.x0, line.y0, line.x1, line.y1, page_width, page_height)
                lines.append(
                    {
                        "text": text,
                        **line_box,
                        "words": extract_line_words(line, page_width, page_height),
                    }
                )
            lines.sort(key=lambda item: (item["top"], item["left"]))
            pages.append(
                {
                    "page_no": page_no,
                    "width": max(1, round(page_width)),
                    "height": max(1, round(page_height)),
                    "lines": lines,
                }
            )
    except Exception as exc:
        warnings.append(f"layout extraction failed: {exc}")
    return pages, warnings


def extract_pages(input_path: Path) -> tuple[str | None, list[str], list[dict], list[str]]:
    try:
        from pdfminer.high_level import extract_text
        from pdfminer.pdfpage import PDFPage
    except Exception as exc:
        return None, [], [], [f"pdfminer is unavailable: {exc}"]

    try:
        with input_path.open("rb") as fh:
            page_count = sum(1 for _ in PDFPage.get_pages(fh))
    except Exception as exc:
        return "pdfminer", [], [], [f"failed to count PDF pages: {exc}"]

    warnings: list[str] = []
    layout_pages, layout_warnings = extract_layout_pages(input_path)
    warnings.extend(layout_warnings)
    try:
        text = extract_text(str(input_path))
        pages = split_pdfminer_pages(text)
        pages = reconcile_page_count(pages, page_count, warnings)
        return "pdfminer", pages, layout_pages, warnings
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

    return "pdfminer", pages, layout_pages, warnings


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

    provider, pages, layout_pages, warnings = extract_pages(Path(args.input))
    payload = {
        "available": provider is not None and any(page.strip() for page in pages),
        "provider": provider,
        "pages": pages,
        "layout_json": json.dumps({"pages": layout_pages}, ensure_ascii=False) if layout_pages else None,
        "warnings": warnings,
    }
    output_path = Path(args.output_json)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(payload, ensure_ascii=False), encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
