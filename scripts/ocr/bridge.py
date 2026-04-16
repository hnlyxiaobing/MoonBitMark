from __future__ import annotations

import argparse
import csv
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
from io import StringIO


PDF_PAGE_BREAK_MARKER = "[[[MOONBITMARK_PDF_PAGE_BREAK]]]"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="MoonBitMark OCR bridge")
    parser.add_argument("--input", required=True)
    parser.add_argument("--output-json", required=True)
    parser.add_argument("--source-name", default="")
    parser.add_argument("--lang", default="eng")
    parser.add_argument("--backend", default="auto")
    parser.add_argument("--timeout-ms", type=int, default=None)
    parser.add_argument("--page-numbers", default="")
    return parser.parse_args()


def make_result(
    *,
    available: bool,
    provider: str | None,
    text: str,
    warnings: list[str],
    layout_json: str | None = None,
) -> dict:
    return {
        "available": available,
        "provider": provider,
        "text": text,
        "layout_json": layout_json,
        "warnings": warnings,
    }


def synthesize_mock_layout(text: str, page_no: int) -> dict:
    words = [word for word in text.split() if word]
    line_words: list[dict] = []
    left = 80
    top = 120
    for index, word in enumerate(words):
        word_left = left + index * 90
        line_words.append(
            {
                "text": word,
                "left": word_left,
                "top": top,
                "right": word_left + max(40, len(word) * 14),
                "bottom": top + 40,
            }
        )
    return {
        "pages": [
            {
                "page_no": page_no,
                "width": 1000,
                "height": 1000,
                "lines": [
                    {
                        "text": text,
                        "left": 80,
                        "top": top,
                        "right": 920,
                        "bottom": top + 40,
                        "words": line_words,
                    }
                ],
            }
        ]
    }


def mock_result(input_path: str, source_name: str) -> dict:
    basis = source_name or input_path
    stem = Path(basis).stem.replace("-", " ").replace("_", " ").strip()
    if not stem:
        stem = "image"
    text = f"MOCK OCR {stem}"
    return make_result(
        available=True,
        provider="mock",
        text=text,
        layout_json=json.dumps(synthesize_mock_layout(text, 1), ensure_ascii=False),
        warnings=[],
    )


def unavailable(provider: str | None, warning: str) -> dict:
    return make_result(
        available=False,
        provider=provider,
        text="",
        layout_json=None,
        warnings=[warning],
    )


def parse_page_numbers(raw: str) -> list[int]:
    if not raw.strip():
        return []
    page_numbers: list[int] = []
    for part in raw.split(","):
        value = part.strip()
        if not value:
            continue
        page_no = int(value)
        if page_no <= 0:
            raise ValueError("page numbers must be positive integers")
        page_numbers.append(page_no)
    return page_numbers


def pdf_rendering_dependencies_available() -> bool:
    try:
        import pypdfium2  # noqa: F401
        from PIL import Image  # noqa: F401
    except Exception:
        return False
    return True


def maybe_delegate_for_pdf(input_path: Path) -> None:
    if input_path.suffix.lower() != ".pdf":
        return
    if os.environ.get("MOONBITMARK_OCR_BRIDGE_DELEGATED") == "1":
        return
    if pdf_rendering_dependencies_available():
        return

    candidate = Path.home() / ".venvs" / "moonbitmark-baselines" / "Scripts" / "python.exe"
    if not candidate.exists():
        return
    if Path(sys.executable).resolve() == candidate.resolve():
        return

    env = dict(os.environ)
    env["MOONBITMARK_OCR_BRIDGE_DELEGATED"] = "1"
    completed = subprocess.run([str(candidate), __file__, *sys.argv[1:]], env=env, check=False)
    raise SystemExit(completed.returncode)


def normalize_pdf_page_numbers(total_pages: int, requested: list[int]) -> tuple[list[int], list[str]]:
    warnings: list[str] = []
    if total_pages <= 0:
        return [], warnings
    if not requested:
        return list(range(1, total_pages + 1)), warnings

    selected: list[int] = []
    seen: set[int] = set()
    for page_no in requested:
        if page_no < 1 or page_no > total_pages:
            warnings.append(f"Skipping out-of-range PDF page number: {page_no}")
            continue
        if page_no in seen:
            continue
        seen.add(page_no)
        selected.append(page_no)
    return selected, warnings


def pdf_page_source_name(source_name: str, input_path: Path, page_no: int) -> str:
    basis = source_name or input_path.name or "pdf"
    stem = Path(basis).stem or "pdf"
    return f"{stem}_page_{page_no}.png"


def join_pdf_page_texts(page_texts: list[str]) -> str:
    if not page_texts:
        return ""
    if len(page_texts) == 1:
        return page_texts[0]
    return f"\n{PDF_PAGE_BREAK_MARKER}\n".join(page_texts)


def close_if_possible(value: object) -> None:
    close = getattr(value, "close", None)
    if callable(close):
        try:
            close()
        except Exception:
            pass


def run_tesseract_command(
    input_path: str,
    lang: str,
    timeout_ms: int | None,
    *extra_args: str,
) -> subprocess.CompletedProcess[str] | dict:
    exe = shutil.which("tesseract")
    if exe is None:
        return unavailable("tesseract", "tesseract executable was not found on PATH.")

    cmd = [exe, input_path, "stdout", *extra_args]
    if lang:
        cmd.extend(["-l", lang])
    try:
        return subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=(timeout_ms / 1000.0) if timeout_ms else None,
            check=False,
        )
    except subprocess.TimeoutExpired:
        return unavailable("tesseract", "OCR backend timed out.")
    except OSError as exc:
        return unavailable("tesseract", f"OCR backend execution failed: {exc}")


def read_image_size(input_path: str) -> tuple[int, int] | None:
    try:
        from PIL import Image
    except Exception:
        return None

    image = None
    try:
        image = Image.open(input_path)
        return image.size
    except Exception:
        return None
    finally:
        close_if_possible(image)


def normalize_box(left: int, top: int, right: int, bottom: int, width: int, height: int) -> dict:
    safe_width = max(1, width)
    safe_height = max(1, height)
    return {
        "left": max(0, min(1000, round(left * 1000 / safe_width))),
        "top": max(0, min(1000, round(top * 1000 / safe_height))),
        "right": max(0, min(1000, round(right * 1000 / safe_width))),
        "bottom": max(0, min(1000, round(bottom * 1000 / safe_height))),
    }


def parse_tesseract_layout(tsv_text: str, page_no: int, image_size: tuple[int, int] | None) -> dict | None:
    rows: list[dict] = []
    max_right = 0
    max_bottom = 0
    reader = csv.DictReader(StringIO(tsv_text), delimiter="\t")
    for row in reader:
        text = (row.get("text") or "").strip()
        if not text:
            continue
        try:
            left = int(row.get("left") or "0")
            top = int(row.get("top") or "0")
            width = int(row.get("width") or "0")
            height = int(row.get("height") or "0")
        except ValueError:
            continue
        if width <= 0 or height <= 0:
            continue
        right = left + width
        bottom = top + height
        max_right = max(max_right, right)
        max_bottom = max(max_bottom, bottom)
        rows.append(
            {
                "text": text,
                "block_num": int(row.get("block_num") or "0"),
                "par_num": int(row.get("par_num") or "0"),
                "line_num": int(row.get("line_num") or "0"),
                "left": left,
                "top": top,
                "right": right,
                "bottom": bottom,
            }
        )

    if not rows:
        return None

    if image_size is None:
        image_width = max(1, max_right)
        image_height = max(1, max_bottom)
    else:
        image_width, image_height = image_size

    grouped: dict[tuple[int, int, int], list[dict]] = {}
    for row in rows:
        key = (row["block_num"], row["par_num"], row["line_num"])
        grouped.setdefault(key, []).append(row)

    lines: list[dict] = []
    for words in grouped.values():
        words.sort(key=lambda item: (item["left"], item["top"]))
        line_left = min(word["left"] for word in words)
        line_top = min(word["top"] for word in words)
        line_right = max(word["right"] for word in words)
        line_bottom = max(word["bottom"] for word in words)
        line_box = normalize_box(line_left, line_top, line_right, line_bottom, image_width, image_height)
        line_words = []
        for word in words:
            word_box = normalize_box(word["left"], word["top"], word["right"], word["bottom"], image_width, image_height)
            line_words.append({"text": word["text"], **word_box})
        lines.append(
            {
                "text": " ".join(word["text"] for word in words),
                **line_box,
                "words": line_words,
            }
        )

    lines.sort(key=lambda item: (item["top"], item["left"]))
    return {
        "pages": [
            {
                "page_no": page_no,
                "width": image_width,
                "height": image_height,
                "lines": lines,
            }
        ]
    }


def run_tesseract(input_path: str, lang: str, timeout_ms: int | None, page_no: int = 1) -> dict:
    text_completed = run_tesseract_command(input_path, lang, timeout_ms)
    if isinstance(text_completed, dict):
        return text_completed

    warnings: list[str] = []
    if text_completed.returncode != 0:
        detail = text_completed.stderr.strip() or f"exit code {text_completed.returncode}"
        warnings.append(f"OCR backend execution failed: {detail}")

    layout_json = None
    if text_completed.returncode == 0:
        tsv_completed = run_tesseract_command(input_path, lang, timeout_ms, "tsv")
        if isinstance(tsv_completed, dict):
            warnings.extend(tsv_completed["warnings"])
        elif tsv_completed.returncode != 0:
            detail = tsv_completed.stderr.strip() or f"exit code {tsv_completed.returncode}"
            warnings.append(f"OCR TSV extraction failed: {detail}")
        else:
            layout_payload = parse_tesseract_layout(tsv_completed.stdout, page_no, read_image_size(input_path))
            if layout_payload is not None:
                layout_json = json.dumps(layout_payload, ensure_ascii=False)

    return make_result(
        available=text_completed.returncode == 0,
        provider="tesseract",
        text=text_completed.stdout.strip(),
        layout_json=layout_json,
        warnings=warnings,
    )


def run_pdf_mock(input_path: Path, source_name: str, page_numbers: list[int]) -> dict:
    import pypdfium2 as pdfium

    pdf = pdfium.PdfDocument(str(input_path))
    try:
        selected_pages, warnings = normalize_pdf_page_numbers(len(pdf), page_numbers)
    finally:
        close_if_possible(pdf)

    page_texts: list[str] = []
    layout_pages: list[dict] = []
    for page_no in selected_pages:
        page_result = mock_result(str(input_path), pdf_page_source_name(source_name, input_path, page_no))
        page_texts.append(page_result["text"])
        if page_result.get("layout_json"):
            payload = json.loads(page_result["layout_json"])
            for page in payload.get("pages", []):
                layout_pages.append({**page, "page_no": page_no})
    return make_result(
        available=len(page_texts) > 0,
        provider="mock",
        text=join_pdf_page_texts(page_texts),
        layout_json=json.dumps({"pages": layout_pages}, ensure_ascii=False) if layout_pages else None,
        warnings=warnings,
    )


def render_pdf_pages(input_path: Path, page_numbers: list[int], image_dir: Path) -> tuple[list[tuple[int, Path]], list[str]]:
    import pypdfium2 as pdfium

    rendered: list[tuple[int, Path]] = []
    pdf = pdfium.PdfDocument(str(input_path))
    try:
        selected_pages, warnings = normalize_pdf_page_numbers(len(pdf), page_numbers)
        for page_no in selected_pages:
            page = pdf[page_no - 1]
            bitmap = None
            image = None
            try:
                bitmap = page.render(scale=2)
                image = bitmap.to_pil()
                image_path = image_dir / f"page-{page_no}.png"
                image.save(image_path)
                rendered.append((page_no, image_path))
            finally:
                close_if_possible(image)
                close_if_possible(bitmap)
                close_if_possible(page)
        return rendered, warnings
    finally:
        close_if_possible(pdf)


def run_pdf_tesseract(
    input_path: Path,
    source_name: str,
    lang: str,
    timeout_ms: int | None,
    page_numbers: list[int],
) -> dict:
    if shutil.which("tesseract") is None:
        return unavailable("tesseract", "tesseract executable was not found on PATH.")

    warnings: list[str] = []
    page_texts: list[str] = []
    layout_pages: list[dict] = []
    available = False
    with tempfile.TemporaryDirectory(prefix="moonbitmark-pdf-ocr-") as temp_dir_name:
        temp_dir = Path(temp_dir_name)
        rendered_pages, render_warnings = render_pdf_pages(input_path, page_numbers, temp_dir)
        warnings.extend(render_warnings)
        for page_no, image_path in rendered_pages:
            page_result = run_tesseract(str(image_path), lang, timeout_ms, page_no=page_no)
            warnings.extend(page_result["warnings"])
            page_texts.append((page_result.get("text") or "").strip())
            if page_result.get("available"):
                available = True
            if page_result.get("layout_json"):
                payload = json.loads(page_result["layout_json"])
                layout_pages.extend(payload.get("pages", []))

    return make_result(
        available=available,
        provider="tesseract",
        text=join_pdf_page_texts(page_texts),
        layout_json=json.dumps({"pages": layout_pages}, ensure_ascii=False) if layout_pages else None,
        warnings=warnings,
    )


def run_pdf_backend(
    input_path: Path,
    source_name: str,
    backend: str,
    lang: str,
    timeout_ms: int | None,
    page_numbers: list[int],
) -> dict:
    if backend == "mock":
        return run_pdf_mock(input_path, source_name, page_numbers)
    if backend in ("auto", "tesseract"):
        if backend == "auto" and shutil.which("tesseract") is None:
            return unavailable(None, "No OCR backend is available in auto mode.")
        return run_pdf_tesseract(input_path, source_name, lang, timeout_ms, page_numbers)
    return unavailable(None, f"Unsupported OCR backend: {backend}")


def main() -> int:
    args = parse_args()
    input_path = Path(args.input)
    maybe_delegate_for_pdf(input_path)

    try:
        page_numbers = parse_page_numbers(args.page_numbers)
    except ValueError as exc:
        result = unavailable(None, f"Invalid PDF page number list: {exc}")
    else:
        backend = (args.backend or "auto").strip().lower()
        if input_path.suffix.lower() == ".pdf":
            result = run_pdf_backend(
                input_path,
                args.source_name,
                backend,
                args.lang,
                args.timeout_ms,
                page_numbers,
            )
        elif backend == "mock":
            result = mock_result(args.input, args.source_name)
        elif backend in ("auto", "tesseract"):
            if backend == "auto" and shutil.which("tesseract") is None:
                result = unavailable(None, "No OCR backend is available in auto mode.")
            else:
                result = run_tesseract(args.input, args.lang, args.timeout_ms)
        else:
            result = unavailable(None, f"Unsupported OCR backend: {backend}")

    output_path = Path(args.output_json)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(result, ensure_ascii=False), encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
