from __future__ import annotations

import argparse
import json
import shutil
import subprocess
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="MoonBitMark OCR bridge")
    parser.add_argument("--input", required=True)
    parser.add_argument("--output-json", required=True)
    parser.add_argument("--source-name", default="")
    parser.add_argument("--lang", default="eng")
    parser.add_argument("--backend", default="auto")
    parser.add_argument("--timeout-ms", type=int, default=None)
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


def main() -> int:
    args = parse_args()
    backend = (args.backend or "auto").strip().lower()

    if backend == "mock":
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
