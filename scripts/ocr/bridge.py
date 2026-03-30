from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


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


def mock_result(input_path: str, source_name: str) -> dict:
    basis = source_name or input_path
    stem = Path(basis).stem.replace("-", " ").replace("_", " ").strip()
    if not stem:
        stem = "image"
    return {
        "available": True,
        "provider": "mock",
        "text": f"MOCK OCR {stem}",
        "warnings": [],
    }


def unavailable(provider: str | None, warning: str) -> dict:
    return {
        "available": False,
        "provider": provider,
        "text": "",
        "warnings": [warning],
    }


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


def run_tesseract(input_path: str, lang: str, timeout_ms: int | None) -> dict:
    exe = shutil.which("tesseract")
    if exe is None:
        return unavailable("tesseract", "tesseract executable was not found on PATH.")

    cmd = [exe, input_path, "stdout"]
    if lang:
        cmd.extend(["-l", lang])
    try:
        completed = subprocess.run(
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

    warnings: list[str] = []
    if completed.returncode != 0:
        detail = completed.stderr.strip() or f"exit code {completed.returncode}"
        warnings.append(f"OCR backend execution failed: {detail}")
    return {
        "available": completed.returncode == 0,
        "provider": "tesseract",
        "text": completed.stdout.strip(),
        "warnings": warnings,
    }


def run_pdf_mock(input_path: Path, source_name: str, page_numbers: list[int]) -> dict:
    import pypdfium2 as pdfium

    pdf = pdfium.PdfDocument(str(input_path))
    try:
        selected_pages, warnings = normalize_pdf_page_numbers(len(pdf), page_numbers)
    finally:
        close_if_possible(pdf)

    page_texts = [
        mock_result(str(input_path), pdf_page_source_name(source_name, input_path, page_no))["text"]
        for page_no in selected_pages
    ]
    return {
        "available": len(page_texts) > 0,
        "provider": "mock",
        "text": join_pdf_page_texts(page_texts),
        "warnings": warnings,
    }


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
    available = False
    with tempfile.TemporaryDirectory(prefix="moonbitmark-pdf-ocr-") as temp_dir_name:
        temp_dir = Path(temp_dir_name)
        rendered_pages, render_warnings = render_pdf_pages(input_path, page_numbers, temp_dir)
        warnings.extend(render_warnings)
        for page_no, image_path in rendered_pages:
            page_result = run_tesseract(str(image_path), lang, timeout_ms)
            warnings.extend(page_result["warnings"])
            page_texts.append((page_result.get("text") or "").strip())
            if page_result.get("available"):
                available = True

    return {
        "available": available,
        "provider": "tesseract",
        "text": join_pdf_page_texts(page_texts),
        "warnings": warnings,
    }


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
