from __future__ import annotations

import argparse
import csv
import datetime as dt
import difflib
import functools
import html
from html.parser import HTMLParser
import importlib.util
import json
import os
from pathlib import Path, PurePosixPath
import posixpath
import re
import shutil
import subprocess
import sys
import textwrap
import unicodedata
import zipfile
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[3]
EVAL_ROOT = REPO_ROOT / "tests" / "conversion_eval"
CASES_ROOT = EVAL_ROOT / "cases"
MANIFEST_PATH = EVAL_ROOT / "fixtures" / "source_manifest.json"
LATEST_REPORT_DIR = EVAL_ROOT / "reports" / "latest"
HISTORY_REPORT_DIR = EVAL_ROOT / "reports" / "history"

BASELINE_VENV_PYTHON = Path.home() / ".venvs" / "moonbitmark-baselines" / "Scripts" / "python.exe"

SUPPORTED_FORMATS = {"csv", "docx", "epub", "html", "image", "json", "pdf", "pptx", "text", "xlsx"}
SUPPORTED_TIERS = {"smoke", "quality", "edge", "regression", "regressions"}
SUPPORTED_REFERENCE_BUILDERS = {"copy", "csv", "docx", "epub", "html", "json", "pptx", "text", "xlsx"}
BASELINE_SUPPORTED_FORMATS = {
    "markitdown": {"csv", "docx", "epub", "html", "json", "pdf", "pptx", "text", "xlsx"},
    "docling": {"csv", "docx", "html", "pdf", "pptx", "xlsx"},
}
DOCLING_INPUT_FORMATS = {
    "csv": "CSV",
    "docx": "DOCX",
    "html": "HTML",
    "pdf": "PDF",
    "pptx": "PPTX",
    "xlsx": "XLSX",
}
ARCHIVE_FORMATS = {"docx", "epub", "pptx", "xlsx"}
WEB_FORMATS = {"html"}


@dataclass
class CaseSpec:
    path: Path
    id: str
    format: str
    tier: str
    input: str
    description: str
    cli_args: list[str] = field(default_factory=list)
    skip_baselines: dict[str, str] = field(default_factory=dict)
    must_include: list[str] = field(default_factory=list)
    must_not_include: list[str] = field(default_factory=list)
    min_chars: int = 0
    min_lines: int = 0
    golden_markdown: str | None = None
    reference_builder: str | None = None
    reference_source: str | None = None
    checks: dict[str, bool] = field(default_factory=dict)
    weights: dict[str, float] = field(default_factory=dict)
    notes: str | None = None

    def canonical_tier(self) -> str:
        return "regression" if self.tier == "regressions" else self.tier

    def input_path(self) -> Path:
        return (REPO_ROOT / self.input).resolve()

    def golden_path(self) -> Path | None:
        if not self.golden_markdown:
            return None
        return (REPO_ROOT / self.golden_markdown).resolve()

    def reference_source_path(self) -> Path | None:
        if not self.reference_source:
            return None
        return (REPO_ROOT / self.reference_source).resolve()


@dataclass
class RunnerInfo:
    command: list[str]
    label: str
    stale: bool
    stale_reason: str | None = None


@dataclass
class ConversionOutput:
    stdout: str
    stderr: str
    returncode: int
    duration_ms: int


def normalize_markdown(text: str) -> str:
    normalized = unicodedata.normalize("NFKC", text.replace("\r\n", "\n").replace("\r", "\n"))
    normalized = normalized.replace("\u200b", "")
    lines = [re.sub(r"[ \t]+$", "", line) for line in normalized.split("\n")]
    text = "\n".join(lines)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def normalize_text_fragment(text: str) -> str:
    text = normalize_markdown(text)
    text = html.unescape(text)
    text = re.sub(r"\s+", " ", text)
    return text.strip().lower()


def load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def write_text(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def write_json(path: Path, content: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(content, ensure_ascii=False, indent=2), encoding="utf-8")


def validate_case(path: Path, data: dict[str, Any]) -> None:
    required = {"id", "format", "tier", "input", "checks"}
    missing = sorted(required - set(data))
    if missing:
        raise ValueError(f"{path}: missing required fields: {', '.join(missing)}")
    if data["format"] not in SUPPORTED_FORMATS:
        raise ValueError(f"{path}: unsupported format {data['format']}")
    if data["tier"] not in SUPPORTED_TIERS:
        raise ValueError(f"{path}: unsupported tier {data['tier']}")
    builder = data.get("reference_builder")
    if builder and builder not in SUPPORTED_REFERENCE_BUILDERS:
        raise ValueError(f"{path}: unsupported reference_builder {builder}")


def load_cases() -> list[CaseSpec]:
    cases: list[CaseSpec] = []
    for path in sorted(CASES_ROOT.rglob("*.case.json")):
        raw = load_json(path)
        validate_case(path, raw)
        cases.append(
            CaseSpec(
                path=path,
                id=raw["id"],
                format=raw["format"],
                tier=raw["tier"],
                input=raw["input"],
                cli_args=list(raw.get("cli_args", [])),
                description=raw.get("description", ""),
                skip_baselines={str(k): str(v) for k, v in raw.get("skip_baselines", {}).items()},
                must_include=list(raw.get("must_include", [])),
                must_not_include=list(raw.get("must_not_include", [])),
                min_chars=int(raw.get("min_chars", 0)),
                min_lines=int(raw.get("min_lines", 0)),
                golden_markdown=raw.get("golden_markdown"),
                reference_builder=raw.get("reference_builder"),
                reference_source=raw.get("reference_source"),
                checks=dict(raw.get("checks", {})),
                weights={k: float(v) for k, v in raw.get("weights", {}).items()},
                notes=raw.get("notes"),
            )
        )
    return cases


def load_source_manifest() -> list[dict[str, str]]:
    raw = load_json(MANIFEST_PATH)
    return list(raw.get("sources", []))


def sync_sources(benchmark_root: Path) -> list[dict[str, str]]:
    synced: list[dict[str, str]] = []
    for entry in load_source_manifest():
        source = benchmark_root / entry["source"]
        dest = REPO_ROOT / entry["dest"]
        if not source.exists():
            raise FileNotFoundError(f"Missing benchmark source: {source}")
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, dest)
        synced.append({"id": entry["id"], "source": str(source), "dest": str(dest)})
    return synced


def detect_stale_binary(binary_path: Path) -> tuple[bool, str | None]:
    if not binary_path.exists():
        return False, None
    binary_mtime = binary_path.stat().st_mtime
    source_times = [p.stat().st_mtime for p in (REPO_ROOT / "src").rglob("*.mbt")]
    source_times.extend(p.stat().st_mtime for p in (REPO_ROOT / "cmd").rglob("*.mbt"))
    if source_times and max(source_times) > binary_mtime:
        return True, "binary is older than current MoonBit sources"
    return False, None


def detect_runner(explicit_runner: str | None) -> RunnerInfo:
    if explicit_runner:
        runner_path = Path(explicit_runner)
        stale, reason = detect_stale_binary(runner_path)
        return RunnerInfo([str(runner_path)], str(runner_path), stale, reason)

    candidates = [
        REPO_ROOT / "_build" / "native" / "release" / "build" / "cmd" / "main" / "main.exe",
        REPO_ROOT / "_build" / "native" / "debug" / "build" / "cmd" / "main" / "main.exe",
    ]
    stale_candidates: list[tuple[Path, str]] = []
    for candidate in candidates:
        if candidate.exists():
            stale, reason = detect_stale_binary(candidate)
            if not stale:
                return RunnerInfo([str(candidate)], str(candidate.relative_to(REPO_ROOT)), False, None)
            stale_candidates.append((candidate, reason or "binary is older than current MoonBit sources"))

    fallback_reason = None
    if stale_candidates:
        labels = ", ".join(str(candidate.relative_to(REPO_ROOT)) for candidate, _ in stale_candidates)
        fallback_reason = f"compiled runner stale, using moon run instead: {labels}"
    return RunnerInfo(["moon", "run", "cmd/main", "--"], "moon run cmd/main --", False, fallback_reason)


def run_conversion(
    runner: RunnerInfo,
    input_path: Path,
    cli_args: list[str] | None = None,
    timeout_seconds: int = 180,
) -> ConversionOutput:
    started = dt.datetime.now(dt.timezone.utc)
    completed = subprocess.run(
        [*runner.command, *(cli_args or []), str(input_path)],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=timeout_seconds,
        check=False,
    )
    finished = dt.datetime.now(dt.timezone.utc)
    duration_ms = int((finished - started).total_seconds() * 1000)
    return ConversionOutput(completed.stdout, completed.stderr, completed.returncode, duration_ms)


def case_clusters(case: CaseSpec) -> list[str]:
    clusters: list[str] = []
    if case.format in ARCHIVE_FORMATS:
        clusters.append("archive")
    if case.format in WEB_FORMATS or case.input.startswith(("http://", "https://")):
        clusters.append("web")
    if case.format == "image" or "--ocr" in case.cli_args or "--ocr-images" in case.cli_args:
        clusters.append("ocr")
    return clusters


def should_collect_diag_json(case: CaseSpec) -> bool:
    return case.format == "pdf" or "ocr" in case_clusters(case)


def parse_boolish(value: Any) -> bool | None:
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        lowered = value.strip().lower()
        if lowered in {"true", "false"}:
            return lowered == "true"
    return None


def parse_intish(value: Any) -> int | None:
    if isinstance(value, int):
        return value
    if isinstance(value, str) and re.fullmatch(r"-?\d+", value.strip()):
        return int(value)
    return None


def cli_arg_value(args: list[str], flag: str) -> str | None:
    for index, arg in enumerate(args):
        if arg == flag and index + 1 < len(args):
            return args[index + 1]
    return None


def extract_loose_json_string(text: str, key: str) -> str | None:
    match = re.search(rf'"{re.escape(key)}":"([^"]*)"', text)
    return match.group(1) if match else None


def extract_loose_json_bool(text: str, key: str) -> bool | None:
    match = re.search(rf'"{re.escape(key)}":(true|false)', text)
    return match.group(1) == "true" if match else None


def collect_case_evidence(
    runner: RunnerInfo,
    case: CaseSpec,
    artifact_dir: Path,
) -> dict[str, Any] | None:
    if not should_collect_diag_json(case):
        return None
    conversion = run_conversion(
        runner,
        case.input_path(),
        ["--diag-json", *case.cli_args],
    )
    stderr = conversion.stderr.strip()
    if conversion.returncode != 0:
        return {
            "diag_json_available": False,
            "diag_json_error": stderr or "diag-json command failed",
        }
    try:
        payload = json.loads(conversion.stdout)
    except json.JSONDecodeError as exc:
        loose_ocr = {
            "mode": extract_loose_json_string(conversion.stdout, "ocr_mode"),
            "backend": extract_loose_json_string(conversion.stdout, "ocr_backend"),
            "lang": extract_loose_json_string(conversion.stdout, "ocr_lang"),
            "timeout": extract_loose_json_string(conversion.stdout, "ocr_timeout"),
            "images": extract_loose_json_string(conversion.stdout, "ocr_images"),
            "provider": extract_loose_json_string(conversion.stdout, "ocr_provider"),
            "attempted": extract_loose_json_string(conversion.stdout, "ocr_attempted"),
            "available": extract_loose_json_string(conversion.stdout, "ocr_available"),
            "fallback_used": extract_loose_json_string(conversion.stdout, "ocr_fallback_used"),
            "embedded_image_count": extract_loose_json_string(conversion.stdout, "ocr_embedded_image_count"),
        }
        if any(value is not None for value in loose_ocr.values()):
            return {
                "diag_json_available": False,
                "diag_json_error": f"invalid diag-json payload: {exc}",
                "ocr": loose_ocr,
                "pdf": {
                    "text_fallback_used": extract_loose_json_string(conversion.stdout, "pdf_text_fallback_used"),
                    "route_recovery_pages": extract_loose_json_string(conversion.stdout, "route_recovery_pages"),
                    "used_fallback": extract_loose_json_bool(conversion.stdout, "used_fallback"),
                },
            }
        return {
            "diag_json_available": False,
            "diag_json_error": f"invalid diag-json payload: {exc}",
        }

    write_json(artifact_dir / "diag.json", payload)
    metadata = payload.get("metadata") or {}
    stats = payload.get("stats") or {}
    return {
        "diag_json_available": True,
        "ocr": {
            "mode": metadata.get("ocr_mode"),
            "backend": metadata.get("ocr_backend"),
            "lang": metadata.get("ocr_lang"),
            "timeout": metadata.get("ocr_timeout"),
            "images": parse_boolish(metadata.get("ocr_images")),
            "provider": metadata.get("ocr_provider"),
            "attempted": parse_boolish(metadata.get("ocr_attempted")),
            "available": parse_boolish(metadata.get("ocr_available")),
            "fallback_used": parse_boolish(metadata.get("ocr_fallback_used")),
            "embedded_image_count": parse_intish(metadata.get("ocr_embedded_image_count")),
        },
        "pdf": {
            "text_fallback_used": parse_boolish(metadata.get("pdf_text_fallback_used")),
            "route_recovery_pages": parse_intish(metadata.get("route_recovery_pages")),
            "used_fallback": stats.get("used_fallback"),
        },
    }


def clean_inline(text: str) -> str:
    return re.sub(r"\s+", " ", html.unescape(text or "")).strip()


def markdown_table(rows: list[list[str]]) -> str:
    if not rows:
        return ""
    normalized_rows = [[clean_inline(cell) for cell in row] for row in rows]
    col_count = max(len(row) for row in normalized_rows)
    padded_rows = [row + [""] * (col_count - len(row)) for row in normalized_rows]
    lines = [
        "| " + " | ".join(padded_rows[0]) + " |",
        "| " + " | ".join(["---"] * col_count) + " |",
    ]
    for row in padded_rows[1:]:
        lines.append("| " + " | ".join(row) + " |")
    return "\n".join(lines)


def build_reference(case: CaseSpec, refresh: bool) -> Path | None:
    golden_path = case.golden_path()
    if not golden_path:
        return None
    if golden_path.exists() and not refresh:
        return golden_path
    if not case.reference_builder:
        return golden_path if golden_path.exists() else None

    builder = case.reference_builder
    input_path = case.input_path()
    if not input_path.exists():
        raise FileNotFoundError(f"Missing fixture input for {case.id}: {input_path}")

    if builder == "copy":
        source = case.reference_source_path()
        if not source or not source.exists():
            raise FileNotFoundError(f"Missing reference source for {case.id}")
        content = source.read_text(encoding="utf-8")
    elif builder == "csv":
        content = build_csv_reference(input_path)
    elif builder == "json":
        content = build_json_reference(input_path)
    elif builder == "text":
        content = build_text_reference(input_path)
    elif builder == "docx":
        content = build_docx_reference(input_path)
    elif builder == "xlsx":
        content = build_xlsx_reference(input_path)
    elif builder == "pptx":
        content = build_pptx_reference(input_path)
    elif builder == "epub":
        content = build_epub_reference(input_path)
    elif builder == "html":
        content = build_html_reference(input_path)
    else:
        raise ValueError(f"Unsupported reference builder {builder}")

    write_text(golden_path, normalize_markdown(content) + "\n")
    metadata_path = EVAL_ROOT / "fixtures" / "expected" / "metadata" / f"{case.id}.json"
    write_json(
        metadata_path,
        {
            "case_id": case.id,
            "reference_builder": builder,
            "generated_at_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
        },
    )
    return golden_path


def build_csv_reference(path: Path) -> str:
    with path.open("r", encoding="utf-8", newline="") as handle:
        rows = list(csv.reader(handle))
    return markdown_table(rows)


def build_json_reference(path: Path) -> str:
    data = json.loads(path.read_text(encoding="utf-8"))
    body = json.dumps(data, ensure_ascii=False, indent=2)
    return f"```json\n{body}\n```"


def build_text_reference(path: Path) -> str:
    text = path.read_text(encoding="utf-8")
    chunks = [chunk.strip() for chunk in re.split(r"\n\s*\n", text) if chunk.strip()]
    return "\n\n".join(chunks)


def build_docx_reference(path: Path) -> str:
    ns = {"w": "http://schemas.openxmlformats.org/wordprocessingml/2006/main"}
    with zipfile.ZipFile(path) as archive:
        root = ET.fromstring(archive.read("word/document.xml"))
    blocks: list[str] = []
    for paragraph in root.findall(".//w:body/w:p", ns):
        text = "".join(t.text or "" for t in paragraph.findall(".//w:t", ns)).strip()
        if not text:
            continue
        style = paragraph.find("./w:pPr/w:pStyle", ns)
        style_name = style.attrib.get(f"{{{ns['w']}}}val", "") if style is not None else ""
        if style_name.lower() == "title":
            blocks.append(f"# {text}")
        elif style_name.lower().startswith("heading"):
            digits = "".join(ch for ch in style_name if ch.isdigit())
            level = max(1, min(6, int(digits or "1")))
            blocks.append(f"{'#' * level} {text}")
        elif paragraph.find("./w:pPr/w:numPr", ns) is not None or "list" in style_name.lower():
            blocks.append(f"- {text}")
        else:
            blocks.append(text)
    return "\n\n".join(blocks)


def cell_ref_to_col_index(cell_ref: str) -> int:
    value = 0
    for char in cell_ref:
        if "A" <= char <= "Z":
            value = value * 26 + (ord(char) - ord("A") + 1)
        elif "a" <= char <= "z":
            value = value * 26 + (ord(char) - ord("a") + 1)
        else:
            break
    return max(value - 1, 0)


def build_xlsx_reference(path: Path) -> str:
    with zipfile.ZipFile(path) as archive:
        workbook = ET.fromstring(archive.read("xl/workbook.xml"))
        relationships = ET.fromstring(archive.read("xl/_rels/workbook.xml.rels"))
        rel_map = {rel.attrib["Id"]: rel.attrib["Target"] for rel in relationships.findall(".//{*}Relationship")}
        shared_strings: list[str] = []
        if "xl/sharedStrings.xml" in archive.namelist():
            shared_root = ET.fromstring(archive.read("xl/sharedStrings.xml"))
            shared_strings = [elem.text or "" for elem in shared_root.findall(".//{*}t")]

        blocks: list[str] = []
        for sheet in workbook.findall(".//{*}sheet"):
            name = sheet.attrib.get("name", "Sheet")
            rid = sheet.attrib.get("{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id")
            target = rel_map.get(rid or "", "")
            if not target:
                continue
            worksheet_path = target if target.startswith("xl/") else f"xl/{target}"
            worksheet = ET.fromstring(archive.read(worksheet_path))
            rows: list[list[str]] = []
            for row in worksheet.findall(".//{*}sheetData/{*}row"):
                current: dict[int, str] = {}
                for cell in row.findall("{*}c"):
                    ref = cell.attrib.get("r", "")
                    col_idx = cell_ref_to_col_index(ref)
                    cell_type = cell.attrib.get("t", "")
                    value = "".join(v.text or "" for v in cell.findall(".//{*}v"))
                    inline_text = "".join(v.text or "" for v in cell.findall(".//{*}is/{*}t"))
                    if cell_type == "s" and value.isdigit():
                        resolved = shared_strings[int(value)] if int(value) < len(shared_strings) else ""
                    elif cell_type == "inlineStr":
                        resolved = inline_text
                    elif cell_type == "b":
                        resolved = "TRUE" if value == "1" else "FALSE"
                    else:
                        resolved = value or inline_text
                    current[col_idx] = clean_inline(resolved)
                if current:
                    max_col = max(current)
                    rows.append([current.get(i, "") for i in range(max_col + 1)])
            blocks.append(f"## {name}")
            blocks.append("")
            blocks.append(markdown_table(rows) if rows else "*(Empty sheet)*")
            blocks.append("")
        return "\n".join(blocks).strip()


def slide_sort_key(name: str) -> int:
    match = re.search(r"slide(\d+)\.xml$", name)
    return int(match.group(1)) if match else 0


def build_pptx_reference(path: Path) -> str:
    with zipfile.ZipFile(path) as archive:
        slide_names = sorted(
            [name for name in archive.namelist() if re.match(r"ppt/slides/slide\d+\.xml$", name)],
            key=slide_sort_key,
        )
        blocks: list[str] = []
        for index, slide_name in enumerate(slide_names, start=1):
            root = ET.fromstring(archive.read(slide_name))
            blocks.append(f"## Slide {index}")
            relationships = pptx_slide_relationships(archive, slide_name)
            shape_tree = root.find(".//{*}spTree")
            if shape_tree is not None:
                blocks.extend(pptx_shape_tree_blocks(shape_tree, archive, relationships))
            blocks.extend(pptx_notes_blocks(archive, relationships))
        return "\n\n".join(block for block in blocks if block.strip()).strip()


def pptx_shape_kind(shape: ET.Element) -> str:
    name = ""
    # ElementTree does not support attribute lookups in findtext; read them explicitly.
    c_nv_pr = shape.find("./{*}nvSpPr/{*}cNvPr")
    if c_nv_pr is not None:
        name = c_nv_pr.attrib.get("name", "")
    ph = shape.find("./{*}nvSpPr/{*}nvPr/{*}ph")
    ph_type = (ph.attrib.get("type", "") if ph is not None else "").lower()
    lowered = name.lower()
    if "subtitle" in lowered or ph_type == "subtitle":
        return "subtitle"
    if "title" in lowered or ph_type in {"title", "ctrtitle"}:
        return "title"
    if "content placeholder" in lowered or "text placeholder" in lowered or ph_type in {"body", "obj"}:
        return "body"
    return "generic"


def pptx_shape_paragraphs(shape: ET.Element) -> list[tuple[str, str]]:
    paragraphs: list[tuple[str, str]] = []
    for paragraph in shape.findall("./{*}txBody/{*}p"):
        texts = [clean_inline(elem.text or "") for elem in paragraph.findall(".//{*}t")]
        text = clean_inline(" ".join(part for part in texts if part))
        if text:
            kind = "plain"
            properties = paragraph.find("./{*}pPr")
            if properties is not None:
                if properties.find("./{*}buAutoNum") is not None:
                    kind = "numbered"
                elif properties.find("./{*}buChar") is not None:
                    kind = "bullet"
            paragraphs.append((text, kind))
    return paragraphs


def pptx_table_rows(table: ET.Element) -> list[list[str]]:
    rows: list[list[str]] = []
    for row in table.findall("./{*}tr"):
        current_row: list[str] = []
        for cell in row.findall("./{*}tc"):
            parts: list[str] = []
            for paragraph in cell.findall(".//{*}p"):
                texts = [clean_inline(elem.text or "") for elem in paragraph.findall(".//{*}t")]
                text = clean_inline(" ".join(part for part in texts if part))
                if text:
                    parts.append(text)
            current_row.append("<br>".join(parts))
        if any(cell for cell in current_row):
            rows.append(current_row)
    return rows


def pptx_shape_tree_blocks(
    parent: ET.Element,
    archive: zipfile.ZipFile,
    relationships: dict[str, dict[str, str]],
) -> list[str]:
    blocks: list[str] = []
    for child in parent:
        child_name = local_name(child.tag)
        if child_name == "sp":
            paragraphs = pptx_shape_paragraphs(child)
            if paragraphs:
                blocks.extend(pptx_render_shape_blocks(pptx_shape_kind(child), paragraphs))
        elif child_name == "graphicFrame":
            table = child.find(".//{*}tbl")
            if table is not None:
                rows = pptx_table_rows(table)
                if rows:
                    blocks.append(markdown_table(rows))
                continue
            chart_ref = pptx_chart_relationship_id(child)
            if chart_ref:
                relationship = relationships.get(chart_ref)
                if relationship and relationship["type"].endswith("/chart"):
                    blocks.extend(pptx_chart_blocks(archive, relationship["target"]))
        elif child_name == "grpSp":
            blocks.extend(pptx_shape_tree_blocks(child, archive, relationships))
    return blocks


def pptx_render_shape_blocks(kind: str, paragraphs: list[tuple[str, str]]) -> list[str]:
    if not paragraphs:
        return []
    if kind == "title":
        blocks = [f"### {paragraphs[0][0]}"]
        blocks.extend(text for text, _ in paragraphs[1:])
        return blocks
    if kind == "body" and len(paragraphs) > 1 and all(paragraph_kind == "plain" for _, paragraph_kind in paragraphs):
        return ["\n".join(f"- {text}" for text, _ in paragraphs)]

    blocks: list[str] = []
    pending: list[str] = []
    pending_ordered = False
    for text, paragraph_kind in paragraphs:
        if paragraph_kind == "plain":
            if pending:
                blocks.append(pptx_list_block(pending, pending_ordered))
                pending = []
            blocks.append(text)
            continue
        next_ordered = paragraph_kind == "numbered"
        if pending and pending_ordered != next_ordered:
            blocks.append(pptx_list_block(pending, pending_ordered))
            pending = []
        if not pending:
            pending_ordered = next_ordered
        pending.append(text)
    if pending:
        blocks.append(pptx_list_block(pending, pending_ordered))
    return blocks


def pptx_list_block(items: list[str], ordered: bool) -> str:
    if ordered:
        return "\n".join(f"{index}. {item}" for index, item in enumerate(items, start=1))
    return "\n".join(f"- {item}" for item in items)


def pptx_slide_relationships(archive: zipfile.ZipFile, slide_name: str) -> dict[str, dict[str, str]]:
    rel_path = pptx_relationship_path(slide_name)
    if rel_path not in archive.namelist():
        return {}
    root = ET.fromstring(archive.read(rel_path))
    relationships: dict[str, dict[str, str]] = {}
    for rel in root.findall(".//{*}Relationship"):
        rel_id = rel.attrib.get("Id", "")
        target = rel.attrib.get("Target", "")
        type_name = rel.attrib.get("Type", "")
        if rel_id and target and type_name:
            relationships[rel_id] = {
                "target": pptx_resolve_target(slide_name, target),
                "type": type_name,
            }
    return relationships


def pptx_relationship_path(slide_name: str) -> str:
    slide_path = PurePosixPath(slide_name)
    return str(slide_path.parent / "_rels" / f"{slide_path.name}.rels")


def pptx_resolve_target(base_entry: str, target: str) -> str:
    resolved = PurePosixPath(base_entry).parent / target
    return posixpath.normpath(str(resolved)).lstrip("/")


def pptx_chart_relationship_id(graphic_frame: ET.Element) -> str | None:
    chart_node = graphic_frame.find(".//{*}chart")
    if chart_node is None:
        return None
    for key, value in chart_node.attrib.items():
        if key.endswith("id") and value:
            return value
    return None


def pptx_notes_blocks(
    archive: zipfile.ZipFile,
    relationships: dict[str, dict[str, str]],
) -> list[str]:
    blocks: list[str] = []
    for relationship in relationships.values():
        if not relationship["type"].endswith("/notesSlide"):
            continue
        target = relationship["target"]
        if target not in archive.namelist():
            continue
        root = ET.fromstring(archive.read(target))
        paragraphs = []
        for paragraph in root.findall(".//{*}sp/{*}txBody/{*}p"):
            texts = [clean_inline(elem.text or "") for elem in paragraph.findall(".//{*}t")]
            text = clean_inline(" ".join(part for part in texts if part))
            if text:
                paragraphs.append(text)
        if paragraphs:
            blocks.append("#### Speaker Notes")
            blocks.extend(paragraphs)
    return blocks


def pptx_chart_blocks(
    archive: zipfile.ZipFile,
    chart_name: str,
) -> list[str]:
    if chart_name not in archive.namelist():
        return []
    root = ET.fromstring(archive.read(chart_name))
    title_parts = [
        clean_inline(elem.text or "")
        for elem in root.findall(".//{*}chart/{*}title//{*}t")
        if clean_inline(elem.text or "")
    ]
    if not title_parts:
        title_parts = [
            clean_inline(elem.text or "")
            for elem in root.findall(".//{*}chart/{*}title//{*}v")
            if clean_inline(elem.text or "")
        ]
    title = clean_inline(" ".join(title_parts)) or "Chart 1"

    series_data: list[tuple[str, list[str], list[str]]] = []
    for index, series in enumerate(root.findall(".//{*}ser"), start=1):
        series_name_parts = [
            clean_inline(elem.text or "")
            for elem in series.findall("./{*}tx//{*}v")
            if clean_inline(elem.text or "")
        ]
        if not series_name_parts:
            series_name_parts = [
                clean_inline(elem.text or "")
                for elem in series.findall("./{*}tx//{*}t")
                if clean_inline(elem.text or "")
            ]
        categories = [
            clean_inline(point.findtext("./{*}v", default=""))
            for point in series.findall("./{*}cat//{*}pt")
            if clean_inline(point.findtext("./{*}v", default=""))
        ]
        values = [
            clean_inline(point.findtext("./{*}v", default=""))
            for point in series.findall("./{*}val//{*}pt")
            if clean_inline(point.findtext("./{*}v", default=""))
        ]
        series_name = clean_inline(" ".join(series_name_parts)) or f"Series {index}"
        if categories or values:
            series_data.append((series_name, categories, values))

    blocks = [f"#### {title}"]
    if not series_data:
        return blocks

    categories = next((cats for _, cats, _ in series_data if cats), [])
    row_count = max([len(categories), *[len(values) for _, _, values in series_data]])
    rows = [["Category", *[name for name, _, _ in series_data]]]
    for row_index in range(row_count):
        label = categories[row_index] if row_index < len(categories) else f"Item {row_index + 1}"
        row = [label]
        for _, _, values in series_data:
            row.append(values[row_index] if row_index < len(values) else "")
        rows.append(row)
    blocks.append(markdown_table(rows))
    return blocks


def local_name(tag: str) -> str:
    return tag.split("}", 1)[-1].split(":", 1)[-1]


def dedupe_adjacent_blocks(blocks: list[str]) -> list[str]:
    deduped: list[str] = []
    for block in blocks:
        if not deduped or deduped[-1] != block:
            deduped.append(block)
    return deduped


def extract_xhtml_blocks(root: ET.Element) -> list[str]:
    blocks: list[str] = []
    for elem in root.iter():
        name = local_name(elem.tag)
        text = clean_inline("".join(elem.itertext()))
        if not text:
            continue
        if name in {"h1", "h2", "h3", "h4", "h5", "h6"}:
            blocks.append(f"{'#' * int(name[1])} {text}")
        elif name == "li":
            blocks.append(f"- {text}")
        elif name in {"p", "blockquote"}:
            blocks.append(text)
    return dedupe_adjacent_blocks(blocks)


def build_epub_reference(path: Path) -> str:
    with zipfile.ZipFile(path) as archive:
        container = ET.fromstring(archive.read("META-INF/container.xml"))
        rootfile = container.find(".//{*}rootfile")
        if rootfile is None:
            raise ValueError(f"{path}: missing EPUB rootfile")
        opf_path = PurePosixPath(rootfile.attrib["full-path"])
        opf_root = ET.fromstring(archive.read(str(opf_path)))
        base_dir = opf_path.parent
        title_node = opf_root.find(".//{*}title")
        blocks: list[str] = []
        if title_node is not None and clean_inline(title_node.text or ""):
            blocks.append(f"# {clean_inline(title_node.text or '')}")
            blocks.append("")
        manifest = {
            item.attrib["id"]: item.attrib["href"]
            for item in opf_root.findall(".//{*}item")
            if item.attrib.get("media-type", "").endswith(("html+xml", "xhtml+xml"))
        }
        spine = [item.attrib["idref"] for item in opf_root.findall(".//{*}itemref") if item.attrib.get("idref")]
        for itemref in spine:
            href = manifest.get(itemref)
            if not href:
                continue
            xhtml_path = str((base_dir / href).as_posix())
            root = ET.fromstring(archive.read(xhtml_path))
            blocks.extend(extract_xhtml_blocks(root))
        return "\n\n".join(block for block in blocks if block.strip()).strip()


class SimpleHtmlReferenceParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.blocks: list[str] = []
        self.current_text: list[str] = []
        self.current_heading_level: int | None = None
        self.in_cell = False
        self.current_cell: list[str] = []
        self.current_row: list[str] = []
        self.current_table: list[list[str]] = []
        self.skip_depth = 0

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if tag in {"script", "style"}:
            self.skip_depth += 1
            return
        if self.skip_depth:
            return
        if tag in {"h1", "h2", "h3", "h4", "h5", "h6", "p", "div", "li"}:
            self.flush_text()
            self.current_heading_level = int(tag[1]) if tag.startswith("h") and len(tag) == 2 else None
        elif tag == "br":
            self.current_text.append("\n")
        elif tag == "tr":
            self.current_row = []
        elif tag in {"td", "th"}:
            self.in_cell = True
            self.current_cell = []

    def handle_endtag(self, tag: str) -> None:
        if tag in {"script", "style"} and self.skip_depth:
            self.skip_depth -= 1
            return
        if self.skip_depth:
            return
        if tag in {"h1", "h2", "h3", "h4", "h5", "h6", "p", "div", "li"}:
            self.flush_text()
            self.current_heading_level = None
        elif tag in {"td", "th"} and self.in_cell:
            self.in_cell = False
            self.current_row.append(clean_inline("".join(self.current_cell)))
            self.current_cell = []
        elif tag == "tr":
            if any(cell for cell in self.current_row):
                self.current_table.append(self.current_row)
            self.current_row = []
        elif tag == "table":
            if self.current_table:
                self.blocks.append(markdown_table(self.current_table))
                self.current_table = []

    def handle_data(self, data: str) -> None:
        if self.skip_depth:
            return
        if self.in_cell:
            self.current_cell.append(data)
        else:
            self.current_text.append(data)

    def flush_text(self) -> None:
        text = clean_inline("".join(self.current_text))
        self.current_text = []
        if not text:
            return
        if self.current_heading_level is not None:
            self.blocks.append(f"{'#' * self.current_heading_level} {text}")
        else:
            self.blocks.append(text)


def build_html_reference(path: Path) -> str:
    parser = SimpleHtmlReferenceParser()
    parser.feed(path.read_text(encoding="utf-8"))
    return "\n\n".join(block for block in parser.blocks if block.strip())


def parse_markdown_tables(markdown: str) -> list[dict[str, Any]]:
    lines = normalize_markdown(markdown).split("\n")
    tables: list[dict[str, Any]] = []
    index = 0
    while index < len(lines) - 1:
        if lines[index].strip().startswith("|") and lines[index + 1].strip().startswith("|"):
            raw_rows: list[str] = []
            while index < len(lines) and lines[index].strip().startswith("|"):
                raw_rows.append(lines[index])
                index += 1
            rows = [[clean_inline(cell) for cell in row.strip().strip("|").split("|")] for row in raw_rows]
            if len(rows) >= 2:
                tables.append({"header": rows[0], "rows": rows[2:]})
            continue
        index += 1
    return tables


def markdown_structure(markdown: str) -> dict[str, Any]:
    text = normalize_markdown(markdown)
    lines = text.split("\n") if text else []
    headings: list[tuple[int, str]] = []
    list_items = 0
    list_nesting: list[int] = []
    code_blocks = 0
    paragraphs = 0
    paragraph_lines: list[int] = []
    in_code = False
    current_paragraph: list[str] = []
    for line in lines:
        stripped = line.strip()
        if stripped.startswith("```"):
            in_code = not in_code
            code_blocks += 1 if in_code else 0
            if current_paragraph:
                paragraphs += 1
                paragraph_lines.append(len(current_paragraph))
                current_paragraph = []
            continue
        if in_code:
            continue
        if stripped.startswith("#"):
            if current_paragraph:
                paragraphs += 1
                paragraph_lines.append(len(current_paragraph))
                current_paragraph = []
            level = len(stripped) - len(stripped.lstrip("#"))
            headings.append((level, clean_inline(stripped[level:])))
            continue
        if re.match(r"^([-*+]|\d+\.)\s+", stripped):
            if current_paragraph:
                paragraphs += 1
                paragraph_lines.append(len(current_paragraph))
                current_paragraph = []
            list_items += 1
            list_nesting.append((len(line) - len(line.lstrip(" "))) // 2)
            continue
        if stripped.startswith("|"):
            if current_paragraph:
                paragraphs += 1
                paragraph_lines.append(len(current_paragraph))
                current_paragraph = []
            continue
        if stripped:
            current_paragraph.append(stripped)
        elif current_paragraph:
            paragraphs += 1
            paragraph_lines.append(len(current_paragraph))
            current_paragraph = []
    if current_paragraph:
        paragraphs += 1
        paragraph_lines.append(len(current_paragraph))
    return {
        "headings": headings,
        "list_items": list_items,
        "list_nesting": list_nesting,
        "code_blocks": code_blocks,
        "paragraphs": paragraphs,
        "paragraph_lines": paragraph_lines,
        "tables": parse_markdown_tables(text),
        "asset_links": count_asset_links(text),
    }


def ratio_by_distance(left: int, right: int) -> float:
    if left == 0 and right == 0:
        return 1.0
    return max(0.0, 1.0 - abs(left - right) / max(left, right))


def sequence_similarity(left: str, right: str) -> float:
    if not left and not right:
        return 1.0
    return difflib.SequenceMatcher(None, left, right).ratio()


def token_f1(left: str, right: str) -> float:
    left_tokens = re.findall(r"\w+", left.lower())
    right_tokens = re.findall(r"\w+", right.lower())
    if not left_tokens and not right_tokens:
        return 1.0
    left_counts: dict[str, int] = {}
    right_counts: dict[str, int] = {}
    for token in left_tokens:
        left_counts[token] = left_counts.get(token, 0) + 1
    for token in right_tokens:
        right_counts[token] = right_counts.get(token, 0) + 1
    overlap = sum(min(left_counts.get(token, 0), right_counts.get(token, 0)) for token in set(left_counts) | set(right_counts))
    precision = overlap / max(len(left_tokens), 1)
    recall = overlap / max(len(right_tokens), 1)
    if precision + recall == 0:
        return 0.0
    return 2 * precision * recall / (precision + recall)


def heading_similarity(left: list[tuple[int, str]], right: list[tuple[int, str]]) -> float:
    if not left and not right:
        return 1.0
    left_text = "\n".join(f"{level}:{text}" for level, text in left)
    right_text = "\n".join(f"{level}:{text}" for level, text in right)
    return sequence_similarity(left_text, right_text)


def heading_structure_score(left_markdown: str, right_markdown: str) -> float:
    left = markdown_structure(left_markdown)
    right = markdown_structure(right_markdown)
    return heading_similarity(left["headings"], right["headings"])


def table_similarity(left_markdown: str, right_markdown: str) -> float:
    left_tables = parse_markdown_tables(left_markdown)
    right_tables = parse_markdown_tables(right_markdown)
    if not left_tables and not right_tables:
        return 1.0
    if not left_tables or not right_tables:
        return 0.0
    scores: list[float] = []
    for index, left_table in enumerate(left_tables):
        right_table = right_tables[min(index, len(right_tables) - 1)]
        header_score = token_f1(" ".join(left_table["header"]), " ".join(right_table["header"]))
        shape_score = (
            ratio_by_distance(len(left_table["header"]), len(right_table["header"]))
            + ratio_by_distance(len(left_table["rows"]), len(right_table["rows"]))
        ) / 2
        left_cells = " ".join(" ".join(row) for row in left_table["rows"])
        right_cells = " ".join(" ".join(row) for row in right_table["rows"])
        cell_score = token_f1(left_cells, right_cells)
        scores.append(0.35 * header_score + 0.25 * shape_score + 0.4 * cell_score)
    return sum(scores) / len(scores)


def table_shape_score(left_markdown: str, right_markdown: str) -> float:
    left_tables = parse_markdown_tables(left_markdown)
    right_tables = parse_markdown_tables(right_markdown)
    if not left_tables and not right_tables:
        return 1.0
    if not left_tables or not right_tables:
        return 0.0
    scores: list[float] = []
    for index, left_table in enumerate(left_tables):
        right_table = right_tables[min(index, len(right_tables) - 1)]
        scores.append(
            (
                ratio_by_distance(len(left_table["header"]), len(right_table["header"]))
                + ratio_by_distance(len(left_table["rows"]), len(right_table["rows"]))
            )
            / 2
        )
    return sum(scores) / len(scores)


def list_nesting_score(left_markdown: str, right_markdown: str) -> float:
    left = markdown_structure(left_markdown)
    right = markdown_structure(right_markdown)
    left_text = ",".join(str(level) for level in left["list_nesting"])
    right_text = ",".join(str(level) for level in right["list_nesting"])
    return sequence_similarity(left_text, right_text)


def paragraph_segmentation_score(left_markdown: str, right_markdown: str) -> float:
    left = markdown_structure(left_markdown)
    right = markdown_structure(right_markdown)
    count_score = ratio_by_distance(left["paragraphs"], right["paragraphs"])
    left_lines = ",".join(str(size) for size in left["paragraph_lines"])
    right_lines = ",".join(str(size) for size in right["paragraph_lines"])
    line_score = sequence_similarity(left_lines, right_lines)
    return 0.5 * count_score + 0.5 * line_score


def count_asset_links(markdown: str) -> int:
    return len(re.findall(r"!\[[^\]]*\]\(([^)]+)\)", markdown))


def asset_link_score(left_markdown: str, right_markdown: str) -> float:
    left = markdown_structure(left_markdown)
    right = markdown_structure(right_markdown)
    return ratio_by_distance(left["asset_links"], right["asset_links"])


def structure_similarity(left_markdown: str, right_markdown: str) -> float:
    left = markdown_structure(left_markdown)
    right = markdown_structure(right_markdown)
    heading_score = heading_similarity(left["headings"], right["headings"])
    list_score = ratio_by_distance(left["list_items"], right["list_items"])
    code_score = ratio_by_distance(left["code_blocks"], right["code_blocks"])
    paragraph_score = ratio_by_distance(left["paragraphs"], right["paragraphs"])
    table_score = table_similarity(left_markdown, right_markdown)
    return 0.3 * heading_score + 0.15 * list_score + 0.15 * code_score + 0.15 * paragraph_score + 0.25 * table_score


def anchor_presence_score(output: str, anchors: list[str]) -> float:
    if not anchors:
        return 1.0
    normalized = normalize_text_fragment(output)
    hits = 0
    for anchor in anchors:
        if normalize_text_fragment(anchor) in normalized:
            hits += 1
    return hits / len(anchors)


def noise_control_score(output: str, forbidden: list[str]) -> float:
    if not forbidden:
        return 1.0
    normalized = normalize_text_fragment(output)
    misses = 0
    for item in forbidden:
        if normalize_text_fragment(item) not in normalized:
            misses += 1
    return misses / len(forbidden)


def text_order_score(output: str, anchors: list[str]) -> float:
    ordered_anchors = [anchor for anchor in anchors if anchor.strip()]
    if len(ordered_anchors) < 2:
        return 1.0 if anchor_presence_score(output, ordered_anchors) == 1.0 else 0.0
    haystack = normalize_text_fragment(output)
    positions: list[int] = []
    for anchor in ordered_anchors:
        position = haystack.find(normalize_text_fragment(anchor))
        if position < 0:
            return 0.0
        positions.append(position)
    ordered_pairs = sum(1 for left, right in zip(positions, positions[1:]) if left <= right)
    return ordered_pairs / (len(positions) - 1)


def length_score(output: str, min_chars: int, min_lines: int) -> float:
    normalized = normalize_markdown(output)
    char_score = 1.0 if min_chars <= 0 else min(len(normalized) / max(min_chars, 1), 1.0)
    line_count = 0 if not normalized else len(normalized.split("\n"))
    line_score = 1.0 if min_lines <= 0 else min(line_count / max(min_lines, 1), 1.0)
    return (char_score + line_score) / 2


def metric_key_alias(key: str) -> str:
    aliases = {
        "anchors": "anchors",
        "noise_control": "noise_control",
        "length": "length",
        "markdown_similarity": "markdown_similarity",
        "ast_similarity": "ast_similarity",
        "table_similarity": "table_similarity",
        "heading_structure_score": "heading_structure_score",
        "list_nesting_score": "list_nesting_score",
        "table_shape_score": "table_shape_score",
        "paragraph_segmentation_score": "paragraph_segmentation_score",
        "asset_link_score": "asset_link_score",
        "text_order": "text_order",
    }
    return aliases.get(key, key)


def weighted_score(metrics: dict[str, float], weights: dict[str, float]) -> float:
    if not weights:
        return sum(metrics.values()) / max(len(metrics), 1)
    total = 0.0
    denominator = 0.0
    for key, weight in weights.items():
        metric_name = metric_key_alias(key)
        if metric_name in metrics:
            total += metrics[metric_name] * weight
            denominator += weight
    if denominator == 0:
        return sum(metrics.values()) / max(len(metrics), 1)
    return total / denominator


def pass_fail_summary(case: CaseSpec, metrics: dict[str, float]) -> dict[str, bool]:
    summary: dict[str, bool] = {}
    if case.checks.get("anchors"):
        summary["anchors"] = (
            metrics.get("anchors", 0.0) >= 1.0
            and metrics.get("noise_control", 0.0) >= 1.0
            and metrics.get("length", 0.0) >= 0.9
        )
    if case.checks.get("golden_markdown"):
        summary["golden_markdown"] = metrics.get("markdown_similarity", 0.0) >= 0.7
    if case.checks.get("ast_compare"):
        summary["ast_compare"] = metrics.get("ast_similarity", 0.0) >= 0.65
    if case.checks.get("table_compare"):
        summary["table_compare"] = metrics.get("table_similarity", 0.0) >= 0.6
    if case.checks.get("text_order"):
        summary["text_order"] = metrics.get("text_order", 0.0) >= 0.8
    return summary


def configure_stdio_utf8() -> None:
    for stream_name in ("stdout", "stderr"):
        stream = getattr(sys, stream_name, None)
        if stream is not None and hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8", errors="replace")


def baseline_availability(tool: str) -> bool:
    return baseline_python_for_tool(tool) is not None


@functools.lru_cache(maxsize=None)
def python_has_module(python_exe: str, module: str) -> bool:
    try:
        completed = subprocess.run(
            [
                python_exe,
                "-c",
                f"import importlib.util, sys; raise SystemExit(0 if importlib.util.find_spec({module!r}) else 1)",
            ],
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=15,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return False
    return completed.returncode == 0


@functools.lru_cache(maxsize=None)
def baseline_python_for_tool(tool: str) -> str | None:
    candidates = [sys.executable]
    if BASELINE_VENV_PYTHON.exists():
        candidates.append(str(BASELINE_VENV_PYTHON))

    seen: set[str] = set()
    for candidate in candidates:
        resolved = str(Path(candidate).resolve())
        if resolved in seen:
            continue
        seen.add(resolved)
        if python_has_module(resolved, tool):
            return resolved
    return None


def baseline_supports_format(tool: str, format_name: str) -> bool:
    return format_name in BASELINE_SUPPORTED_FORMATS.get(tool, set())


def compare_baseline(
    tool: str,
    format_name: str,
    input_path: Path,
    reference_markdown: str | None,
) -> tuple[float | None, str | None, int | None]:
    output_markdown, error, duration_ms, _python_exe = run_baseline_conversion(tool, format_name, input_path)
    if error:
        return None, error, duration_ms
    if reference_markdown:
        score = 0.6 * sequence_similarity(output_markdown or "", reference_markdown) + 0.4 * structure_similarity(output_markdown or "", reference_markdown)
    else:
        score = None
    return score, None, duration_ms


def run_baseline_conversion(
    tool: str,
    format_name: str,
    input_path: Path,
) -> tuple[str | None, str | None, int | None, str | None]:
    python_exe = baseline_python_for_tool(tool)
    if not python_exe:
        return None, f"baseline package is unavailable: {tool}", None, None
    if tool == "markitdown":
        script = textwrap.dedent(
            """
            from markitdown import MarkItDown
            import sys
            if hasattr(sys.stdout, "reconfigure"):
                sys.stdout.reconfigure(encoding="utf-8", errors="replace")
            result = MarkItDown().convert(sys.argv[1])
            print(getattr(result, "text_content", str(result)))
            """
        ).strip()
    elif tool == "docling":
        docling_format = DOCLING_INPUT_FORMATS.get(format_name)
        if not docling_format:
            return None, f"baseline does not support format: {format_name}", None, python_exe
        if format_name == "pdf":
            script = textwrap.dedent(
                f"""
                from docling.document_converter import DocumentConverter, PdfFormatOption
                from docling.datamodel.base_models import InputFormat
                from docling.datamodel.pipeline_options import PdfPipelineOptions
                import sys
                if hasattr(sys.stdout, "reconfigure"):
                    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
                converter = DocumentConverter(
                    allowed_formats=[InputFormat.{docling_format}],
                    format_options={{
                        InputFormat.{docling_format}: PdfFormatOption(
                            pipeline_options=PdfPipelineOptions(do_ocr=False)
                        )
                    }},
                )
                result = converter.convert(sys.argv[1])
                print(result.document.export_to_markdown())
                """
            ).strip()
        else:
            script = textwrap.dedent(
                f"""
                from docling.document_converter import DocumentConverter
                from docling.datamodel.base_models import InputFormat
                import sys
                if hasattr(sys.stdout, "reconfigure"):
                    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
                converter = DocumentConverter(allowed_formats=[InputFormat.{docling_format}])
                result = converter.convert(sys.argv[1])
                print(result.document.export_to_markdown())
                """
            ).strip()
    else:
        raise ValueError(tool)

    started = dt.datetime.now(dt.timezone.utc)
    try:
        completed = subprocess.run(
            [python_exe, "-c", script, str(input_path)],
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            env={**os.environ, "PYTHONUTF8": "1", "PYTHONIOENCODING": "utf-8"},
            timeout=90,
            check=False,
        )
        finished = dt.datetime.now(dt.timezone.utc)
        duration_ms = int((finished - started).total_seconds() * 1000)
    except subprocess.TimeoutExpired:
        finished = dt.datetime.now(dt.timezone.utc)
        duration_ms = int((finished - started).total_seconds() * 1000)
        return None, "baseline execution timed out", duration_ms, python_exe
    if completed.returncode != 0:
        error = completed.stderr.strip() or completed.stdout.strip() or "baseline execution failed"
        return None, error, duration_ms, python_exe
    output = normalize_markdown(completed.stdout)
    return output, None, duration_ms, python_exe


def compare_candidate_against_baseline(
    candidate_markdown: str,
    baseline_markdown: str,
) -> dict[str, float]:
    return {
        "overall_score": round(
            0.6 * sequence_similarity(candidate_markdown, baseline_markdown)
            + 0.4 * structure_similarity(candidate_markdown, baseline_markdown),
            4,
        ),
        "sequence_similarity": round(sequence_similarity(candidate_markdown, baseline_markdown), 4),
        "token_f1": round(token_f1(candidate_markdown, baseline_markdown), 4),
        "structure_similarity": round(structure_similarity(candidate_markdown, baseline_markdown), 4),
        "table_similarity": round(table_similarity(candidate_markdown, baseline_markdown), 4),
        "heading_structure_score": round(heading_structure_score(candidate_markdown, baseline_markdown), 4),
        "list_nesting_score": round(list_nesting_score(candidate_markdown, baseline_markdown), 4),
        "table_shape_score": round(table_shape_score(candidate_markdown, baseline_markdown), 4),
        "paragraph_segmentation_score": round(paragraph_segmentation_score(candidate_markdown, baseline_markdown), 4),
        "asset_link_score": round(asset_link_score(candidate_markdown, baseline_markdown), 4),
    }


def evaluate_cases(cases: list[CaseSpec], runner: RunnerInfo, refresh_references: bool, compare_baselines_flag: bool) -> dict[str, Any]:
    results: list[dict[str, Any]] = []
    case_artifacts_dir = LATEST_REPORT_DIR / "artifacts"
    case_artifacts_dir.mkdir(parents=True, exist_ok=True)

    baseline_tools = [tool for tool in ("markitdown", "docling") if compare_baselines_flag and baseline_availability(tool)]
    baseline_errors: dict[str, list[str]] = {tool: [] for tool in ("markitdown", "docling")}
    baseline_scores: dict[str, list[float]] = {tool: [] for tool in ("markitdown", "docling")}
    baseline_durations: dict[str, list[int]] = {tool: [] for tool in ("markitdown", "docling")}
    baseline_attempts: dict[str, int] = {tool: 0 for tool in ("markitdown", "docling")}
    baseline_successes: dict[str, int] = {tool: 0 for tool in ("markitdown", "docling")}

    for case in cases:
        reference_path = build_reference(case, refresh=refresh_references)
        reference_markdown = normalize_markdown(reference_path.read_text(encoding="utf-8")) if reference_path and reference_path.exists() else None
        conversion = run_conversion(runner, case.input_path(), case.cli_args)
        output_markdown = normalize_markdown(conversion.stdout)

        metrics: dict[str, float] = {
            "anchors": anchor_presence_score(output_markdown, case.must_include),
            "noise_control": noise_control_score(output_markdown, case.must_not_include),
            "length": length_score(output_markdown, case.min_chars, case.min_lines),
        }
        if reference_markdown:
            metrics["markdown_similarity"] = 0.6 * sequence_similarity(output_markdown, reference_markdown) + 0.4 * token_f1(output_markdown, reference_markdown)
            metrics["ast_similarity"] = structure_similarity(output_markdown, reference_markdown)
            metrics["table_similarity"] = table_similarity(output_markdown, reference_markdown)
            metrics["heading_structure_score"] = heading_structure_score(output_markdown, reference_markdown)
            metrics["list_nesting_score"] = list_nesting_score(output_markdown, reference_markdown)
            metrics["table_shape_score"] = table_shape_score(output_markdown, reference_markdown)
            metrics["paragraph_segmentation_score"] = paragraph_segmentation_score(output_markdown, reference_markdown)
            metrics["asset_link_score"] = asset_link_score(output_markdown, reference_markdown)
        if case.checks.get("text_order"):
            metrics["text_order"] = text_order_score(output_markdown, case.must_include)

        checks = pass_fail_summary(case, metrics)
        passed = conversion.returncode == 0 and all(checks.values())
        score = weighted_score(metrics, case.weights)

        artifact_dir = case_artifacts_dir / case.id
        artifact_dir.mkdir(parents=True, exist_ok=True)
        write_text(artifact_dir / "output.md", output_markdown + ("\n" if output_markdown else ""))
        if reference_markdown:
            write_text(artifact_dir / "reference.md", reference_markdown + "\n")
        evidence = collect_case_evidence(runner, case, artifact_dir)

        baseline_result: dict[str, Any] = {}
        for tool in baseline_tools:
            skip_reason = case.skip_baselines.get(tool)
            if skip_reason:
                baseline_result[tool] = {
                    "available": True,
                    "score": None,
                    "error": None,
                    "skipped": True,
                    "reason": skip_reason,
                }
                continue
            if not baseline_supports_format(tool, case.format):
                baseline_result[tool] = {
                    "available": True,
                    "score": None,
                    "error": None,
                    "skipped": True,
                    "reason": f"baseline does not support format: {case.format}",
                }
                continue
            baseline_attempts[tool] += 1
            score_value, error, duration_ms = compare_baseline(tool, case.format, case.input_path(), reference_markdown)
            if error:
                baseline_errors[tool].append(f"{case.id}: {error}")
                baseline_result[tool] = {"available": True, "score": None, "error": error, "duration_ms": duration_ms}
            else:
                baseline_successes[tool] += 1
                if score_value is not None:
                    baseline_scores[tool].append(score_value)
                if duration_ms is not None:
                    baseline_durations[tool].append(duration_ms)
                baseline_result[tool] = {"available": True, "score": score_value, "error": None, "duration_ms": duration_ms}

        results.append(
            {
                "id": case.id,
                "tier": case.canonical_tier(),
                "format": case.format,
                "description": case.description,
                "input": str(case.input_path().relative_to(REPO_ROOT)),
                "cli_args": case.cli_args,
                "clusters": case_clusters(case),
                "reference": str(reference_path.relative_to(REPO_ROOT)) if reference_path and reference_path.exists() else None,
                "runner_returncode": conversion.returncode,
                "runner_duration_ms": conversion.duration_ms,
                "stderr": conversion.stderr.strip(),
                "passed": passed,
                "score": round(score, 4),
                "metrics": {key: round(value, 4) for key, value in metrics.items()},
                "checks": checks,
                "evidence": evidence,
                "baseline": baseline_result,
            }
        )

    baseline_summary: dict[str, dict[str, Any]] = {}
    for tool in ("markitdown", "docling"):
        available = tool in baseline_tools
        score_value = sum(baseline_scores[tool]) / len(baseline_scores[tool]) if baseline_scores[tool] else None
        duration_value = sum(baseline_durations[tool]) / len(baseline_durations[tool]) if baseline_durations[tool] else None
        baseline_summary[tool] = {
            "available": available,
            "score": round(score_value, 4) if score_value is not None else None,
            "average_duration_ms": round(duration_value, 1) if duration_value is not None else None,
            "success_count": baseline_successes[tool],
            "attempted_count": baseline_attempts[tool],
            "errors": baseline_errors[tool][:10],
        }

    return {"results": results, "baseline_summary": baseline_summary}


def summarize_results(results: list[dict[str, Any]]) -> dict[str, Any]:
    total = len(results)
    passed = sum(1 for result in results if result["passed"])
    failed = total - passed
    average_score = sum(result["score"] for result in results) / max(total, 1)

    by_format: dict[str, dict[str, Any]] = {}
    by_cluster: dict[str, dict[str, Any]] = {}
    by_tier: dict[str, dict[str, Any]] = {}
    ocr_providers: dict[str, int] = {}
    ocr_summary = {
        "relevant_cases": 0,
        "attempted_cases": 0,
        "available_cases": 0,
        "forced_cases": 0,
        "fallback_used_cases": 0,
    }
    structure_metrics = (
        "heading_structure_score",
        "list_nesting_score",
        "table_shape_score",
        "paragraph_segmentation_score",
        "asset_link_score",
    )
    for result in results:
        bucket = by_format.setdefault(result["format"], {"total": 0, "passed": 0, "score_sum": 0.0, "metric_sums": {name: 0.0 for name in structure_metrics}, "metric_counts": {name: 0 for name in structure_metrics}})
        bucket["total"] += 1
        bucket["passed"] += 1 if result["passed"] else 0
        bucket["score_sum"] += result["score"]
        for metric_name in structure_metrics:
            value = result["metrics"].get(metric_name)
            if value is not None:
                bucket["metric_sums"][metric_name] += value
                bucket["metric_counts"][metric_name] += 1
        for cluster in result.get("clusters", []):
            cluster_bucket = by_cluster.setdefault(cluster, {"total": 0, "passed": 0, "score_sum": 0.0})
            cluster_bucket["total"] += 1
            cluster_bucket["passed"] += 1 if result["passed"] else 0
            cluster_bucket["score_sum"] += result["score"]
        tier_bucket = by_tier.setdefault(result["tier"], {"total": 0, "passed": 0, "score_sum": 0.0})
        tier_bucket["total"] += 1
        tier_bucket["passed"] += 1 if result["passed"] else 0
        tier_bucket["score_sum"] += result["score"]

        evidence = result.get("evidence") or {}
        ocr = evidence.get("ocr") or {}
        if "ocr" in result.get("clusters", []):
            ocr_summary["relevant_cases"] += 1
        attempted = parse_boolish(ocr.get("attempted"))
        available = parse_boolish(ocr.get("available"))
        fallback_used = parse_boolish(ocr.get("fallback_used"))
        mode = ocr.get("mode")
        provider = ocr.get("provider")
        if mode is None:
            mode = cli_arg_value(result.get("cli_args", []), "--ocr")
        if attempted is None:
            attempted = mode in {"auto", "force"} or "--ocr-images" in result.get("cli_args", [])
        elif attempted is False and provider and mode in {"auto", "force"}:
            attempted = True
        if available is None and provider:
            available = True
        elif available is False and provider:
            available = True
        if attempted:
            ocr_summary["attempted_cases"] += 1
        if available:
            ocr_summary["available_cases"] += 1
        if fallback_used:
            ocr_summary["fallback_used_cases"] += 1
        if mode == "force":
            ocr_summary["forced_cases"] += 1
        if provider:
            ocr_providers[provider] = ocr_providers.get(provider, 0) + 1

    for bucket in list(by_format.values()) + list(by_cluster.values()) + list(by_tier.values()):
        bucket["average_score"] = round(bucket["score_sum"] / max(bucket["total"], 1), 4)
        del bucket["score_sum"]
        if "metric_sums" in bucket and "metric_counts" in bucket:
            bucket["structure_metrics"] = {
                metric_name: round(bucket["metric_sums"][metric_name] / bucket["metric_counts"][metric_name], 4)
                for metric_name in structure_metrics
                if bucket["metric_counts"][metric_name] > 0
            }
            del bucket["metric_sums"]
            del bucket["metric_counts"]

    weakest_formats = [
        {
            "format": format_name,
            "average_score": stats["average_score"],
            "structure_metrics": stats.get("structure_metrics", {}),
        }
        for format_name, stats in by_format.items()
    ]
    weakest_formats.sort(key=lambda item: (item["average_score"], item["format"]))

    top_regressions_by_format: dict[str, list[dict[str, Any]]] = {}
    for format_name in by_format.keys():
        format_results = [result for result in results if result["format"] == format_name]
        format_results.sort(key=lambda item: (item["score"], item["id"]))
        top_regressions_by_format[format_name] = [
            {
                "id": result["id"],
                "score": result["score"],
                "failing_checks": [name for name, ok in result["checks"].items() if not ok],
            }
            for result in format_results[:3]
        ]

    structure_metric_names = (
        "heading_structure_score",
        "list_nesting_score",
        "table_shape_score",
        "paragraph_segmentation_score",
        "asset_link_score",
    )
    top_unstable_cases_by_metric: dict[str, list[dict[str, Any]]] = {}
    for metric_name in structure_metric_names:
        unstable = [
            {
                "id": result["id"],
                "format": result["format"],
                "score": result["metrics"][metric_name],
                "case_score": result["score"],
            }
            for result in results
            if metric_name in result["metrics"]
        ]
        unstable.sort(key=lambda item: (item["score"], item["case_score"], item["id"]))
        top_unstable_cases_by_metric[metric_name] = unstable[:5]

    ocr_gain_cases = []
    ocr_loss_cases = []
    for result in results:
        evidence = result.get("evidence") or {}
        ocr = evidence.get("ocr") or {}
        provider = ocr.get("provider")
        attempted = parse_boolish(ocr.get("attempted"))
        fallback_used = parse_boolish(ocr.get("fallback_used"))
        if attempted is None:
            attempted = "ocr" in result.get("clusters", [])
        if not attempted:
            continue
        item = {
            "id": result["id"],
            "format": result["format"],
            "score": result["score"],
            "provider": provider,
            "fallback_used": bool(fallback_used),
            "case_score": result["score"],
            "failing_checks": [name for name, ok in result["checks"].items() if not ok],
        }
        if result["score"] >= 0.99:
            ocr_gain_cases.append(item)
        if result["score"] < 0.97 or item["failing_checks"]:
            ocr_loss_cases.append(item)
    ocr_gain_cases.sort(key=lambda item: (-item["score"], item["id"]))
    ocr_loss_cases.sort(key=lambda item: (item["score"], item["id"]))

    baseline_gap_summary: dict[str, dict[str, Any]] = {}
    for tool in ("markitdown", "docling"):
        comparable_cases = []
        for result in results:
            baseline = (result.get("baseline") or {}).get(tool) or {}
            baseline_score = baseline.get("score")
            if isinstance(baseline_score, (int, float)):
                comparable_cases.append(
                    {
                        "id": result["id"],
                        "format": result["format"],
                        "score": result["score"],
                        "baseline_score": float(baseline_score),
                        "gap": round(result["score"] - float(baseline_score), 4),
                    }
                )
        comparable_cases.sort(key=lambda item: (item["gap"], item["id"]))
        average_gap = (
            round(sum(item["gap"] for item in comparable_cases) / len(comparable_cases), 4)
            if comparable_cases
            else None
        )
        baseline_gap_summary[tool] = {
            "comparable_cases": len(comparable_cases),
            "average_gap": average_gap,
            "largest_losses": comparable_cases[:5],
            "largest_wins": sorted(comparable_cases, key=lambda item: (-item["gap"], item["id"]))[:5],
        }

    return {
        "total_cases": total,
        "passed_cases": passed,
        "failed_cases": failed,
        "pass_rate": round(passed / max(total, 1), 4),
        "average_score": round(average_score, 4),
        "by_format": by_format,
        "by_cluster": by_cluster,
        "by_tier": by_tier,
        "ocr_summary": {**ocr_summary, "providers": dict(sorted(ocr_providers.items()))},
        "shortfalls": {
            "weakest_formats": weakest_formats[:5],
            "top_regressions_by_format": top_regressions_by_format,
            "top_unstable_cases_by_metric": top_unstable_cases_by_metric,
            "ocr_gain_cases": ocr_gain_cases[:5],
            "ocr_loss_cases": ocr_loss_cases[:5],
            "baseline_gap_by_tool": baseline_gap_summary,
        },
    }


def render_summary_markdown(report: dict[str, Any]) -> str:
    summary = report["summary"]
    runner = report["runner"]
    lines = [
        "# MoonBitMark Conversion Eval",
        "",
        f"- Generated at: `{report['generated_at_utc']}`",
        f"- Runner: `{runner['label']}`",
        f"- Runner stale: `{runner['stale']}`",
    ]
    if report.get("provisional"):
        lines.append("- Report status: `provisional`")
    if runner.get("stale_reason"):
        lines.append(f"- Runner stale reason: `{runner['stale_reason']}`")
    lines.extend(
        [
            f"- Pass rate: `{summary['passed_cases']}/{summary['total_cases']}` ({summary['pass_rate']:.2%})",
            f"- Average score: `{summary['average_score']:.4f}`",
            "",
            "## By Format",
            "",
            "| Format | Passed | Total | Avg Score |",
            "| --- | ---: | ---: | ---: |",
        ]
    )
    for format_name, stats in sorted(summary["by_format"].items()):
        lines.append(f"| {format_name} | {stats['passed']} | {stats['total']} | {stats['average_score']:.4f} |")

    lines.extend(
        [
            "",
            "## Structure Metrics By Format",
            "",
            "| Format | Heading | List | Table Shape | Paragraph | Asset Link |",
            "| --- | ---: | ---: | ---: | ---: | ---: |",
        ]
    )
    for format_name, stats in sorted(summary["by_format"].items()):
        metrics = stats.get("structure_metrics", {})
        lines.append(
            f"| {format_name} | {metrics.get('heading_structure_score', 0.0):.4f} | "
            f"{metrics.get('list_nesting_score', 0.0):.4f} | "
            f"{metrics.get('table_shape_score', 0.0):.4f} | "
            f"{metrics.get('paragraph_segmentation_score', 0.0):.4f} | "
            f"{metrics.get('asset_link_score', 0.0):.4f} |"
        )

    shortfalls = summary.get("shortfalls") or {}
    lines.extend(["", "## Priority Signals", ""])
    weakest_formats = shortfalls.get("weakest_formats") or []
    if weakest_formats:
        lines.append("- Weakest formats by average score:")
        for item in weakest_formats:
            lines.append(f"  - `{item['format']}`: `{item['average_score']:.4f}`")
    else:
        lines.append("- Weakest formats by average score: `none`")

    unstable_cases = shortfalls.get("top_unstable_cases_by_metric") or {}
    if unstable_cases:
        lines.append("- Top unstable cases by structure metric:")
        for metric_name, cases in unstable_cases.items():
            if not cases:
                continue
            preview = ", ".join(f"{case['id']}:{case['score']:.4f}" for case in cases[:3])
            lines.append(f"  - `{metric_name}` -> {preview}")

    regressions_by_format = shortfalls.get("top_regressions_by_format") or {}
    if regressions_by_format:
        lines.append("- Top regressions by format:")
        for format_name, cases in sorted(regressions_by_format.items()):
            if not cases:
                continue
            preview = ", ".join(f"{case['id']}:{case['score']:.4f}" for case in cases[:2])
            lines.append(f"  - `{format_name}` -> {preview}")

    lines.extend(["", "## By Cluster", "", "| Cluster | Passed | Total | Avg Score |", "| --- | ---: | ---: | ---: |"])
    if summary["by_cluster"]:
        for cluster_name, stats in sorted(summary["by_cluster"].items()):
            lines.append(f"| {cluster_name} | {stats['passed']} | {stats['total']} | {stats['average_score']:.4f} |")
    else:
        lines.append("| none | 0 | 0 | 0.0000 |")

    lines.extend(["", "## By Tier", "", "| Tier | Passed | Total | Avg Score |", "| --- | ---: | ---: | ---: |"])
    for tier_name, stats in sorted(summary["by_tier"].items()):
        lines.append(f"| {tier_name} | {stats['passed']} | {stats['total']} | {stats['average_score']:.4f} |")

    ocr_summary = summary["ocr_summary"]
    lines.extend(["", "## OCR Evidence", ""])
    lines.append(
        f"- Relevant cases: `{ocr_summary['relevant_cases']}`, attempted: `{ocr_summary['attempted_cases']}`, "
        f"available: `{ocr_summary['available_cases']}`, forced: `{ocr_summary['forced_cases']}`, "
        f"fallback used: `{ocr_summary['fallback_used_cases']}`"
    )
    if ocr_summary["providers"]:
        provider_summary = ", ".join(f"{name}:{count}" for name, count in ocr_summary["providers"].items())
        lines.append(f"- Providers: `{provider_summary}`")
    else:
        lines.append("- Providers: `none`")
    ocr_gain_cases = shortfalls.get("ocr_gain_cases") or []
    if ocr_gain_cases:
        lines.append("- OCR gain signals (high-scoring OCR-involved cases):")
        for item in ocr_gain_cases:
            provider = item["provider"] or "unknown"
            lines.append(
                f"  - `{item['id']}` ({item['format']}) score `{item['score']:.4f}`, provider `{provider}`, "
                f"fallback_used `{item['fallback_used']}`"
            )
    ocr_loss_cases = shortfalls.get("ocr_loss_cases") or []
    if ocr_loss_cases:
        lines.append("- OCR loss signals (low-scoring OCR-involved cases):")
        for item in ocr_loss_cases:
            provider = item["provider"] or "unknown"
            failing = ", ".join(item["failing_checks"]) if item["failing_checks"] else "none"
            lines.append(
                f"  - `{item['id']}` ({item['format']}) score `{item['score']:.4f}`, provider `{provider}`, "
                f"failing `{failing}`"
            )

    failures = [result for result in report["results"] if not result["passed"]]
    lines.extend(["", "## Failures", ""])
    if not failures:
        lines.append("- None")
    else:
        for result in failures:
            failing_checks = ", ".join(name for name, ok in result["checks"].items() if not ok) or "runner"
            lines.append(f"- `{result['id']}`: score `{result['score']:.4f}`, failing `{failing_checks}`")

    lines.extend(["", "## Baselines", ""])
    for tool, data in report["baseline_summary"].items():
        if not data["available"]:
            lines.append(f"- `{tool}`: unavailable")
            continue
        lines.append(
            f"- `{tool}`: attempted `{data['attempted_count']}`, succeeded `{data['success_count']}`, "
            f"average score `{data['score']}`, average duration `{data['average_duration_ms']}` ms"
        )
        for error in data["errors"][:3]:
            lines.append(f"  - error: `{error}`")
    baseline_gap_by_tool = shortfalls.get("baseline_gap_by_tool") or {}
    if baseline_gap_by_tool:
        lines.extend(["", "## Baseline Gaps", ""])
        for tool, data in baseline_gap_by_tool.items():
            lines.append(
                f"- `{tool}`: comparable `{data['comparable_cases']}`, average gap `{data['average_gap']}`"
            )
            largest_losses = data.get("largest_losses") or []
            if largest_losses:
                preview = ", ".join(
                    f"{item['id']}:{item['gap']:.4f}" for item in largest_losses[:3]
                )
                lines.append(f"  - largest losses: {preview}")
            largest_wins = data.get("largest_wins") or []
            if largest_wins:
                preview = ", ".join(
                    f"{item['id']}:{item['gap']:.4f}" for item in largest_wins[:3]
                )
                lines.append(f"  - largest wins: {preview}")
    return "\n".join(lines) + "\n"


def write_reports(report: dict[str, Any]) -> None:
    LATEST_REPORT_DIR.mkdir(parents=True, exist_ok=True)
    timestamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    history_dir = HISTORY_REPORT_DIR / timestamp
    history_dir.mkdir(parents=True, exist_ok=True)
    write_json(LATEST_REPORT_DIR / "report.json", report)
    write_text(LATEST_REPORT_DIR / "summary.md", render_summary_markdown(report))
    write_json(history_dir / "report.json", report)
    write_text(history_dir / "summary.md", render_summary_markdown(report))


def build_report(cases: list[CaseSpec], runner: RunnerInfo, refresh_references: bool, compare_baselines_flag: bool) -> dict[str, Any]:
    evaluation = evaluate_cases(cases, runner, refresh_references, compare_baselines_flag)
    results = evaluation["results"]
    summary = summarize_results(results)
    return {
        "generated_at_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
        "provisional": runner.stale,
        "runner": {
            "label": runner.label,
            "command": runner.command,
            "stale": runner.stale,
            "stale_reason": runner.stale_reason,
        },
        "summary": summary,
        "baseline_summary": evaluation["baseline_summary"],
        "results": results,
    }


def command_sync(args: argparse.Namespace) -> None:
    synced = sync_sources(Path(args.benchmark_root))
    print(json.dumps({"synced": synced, "count": len(synced)}, ensure_ascii=False, indent=2))


def command_prepare(args: argparse.Namespace) -> None:
    if args.benchmark_root:
        sync_sources(Path(args.benchmark_root))
    cases = load_cases()
    generated = []
    for case in cases:
        path = build_reference(case, refresh=args.refresh_references)
        if path:
            generated.append(str(path.relative_to(REPO_ROOT)))
    print(json.dumps({"generated": generated, "count": len(generated)}, ensure_ascii=False, indent=2))


def command_run(args: argparse.Namespace) -> None:
    if args.benchmark_root:
        sync_sources(Path(args.benchmark_root))
    cases = load_cases()
    runner = detect_runner(args.runner)
    report = build_report(cases, runner, args.refresh_references, args.compare_baselines)
    write_reports(report)
    print(render_summary_markdown(report))


def command_compare_baseline(args: argparse.Namespace) -> None:
    input_path = Path(args.input)
    available = baseline_availability(args.tool)
    supported = baseline_supports_format(args.tool, args.format)
    output_markdown, error, duration_ms, python_exe = run_baseline_conversion(
        args.tool,
        args.format,
        input_path,
    )
    candidate_markdown = None
    agreement = None
    if args.candidate_markdown:
        candidate_markdown = normalize_markdown(
            Path(args.candidate_markdown).read_text(encoding="utf-8")
        )
    if candidate_markdown is not None and output_markdown is not None and error is None:
        agreement = compare_candidate_against_baseline(
            candidate_markdown,
            output_markdown,
        )
    payload = {
        "tool": args.tool,
        "format": args.format,
        "input": str(input_path),
        "available": available,
        "supported": supported,
        "python_exe": python_exe,
        "error": error,
        "duration_ms": duration_ms,
        "baseline_markdown": output_markdown,
        "baseline_chars": len(output_markdown or ""),
        "comparison_basis": "candidate_vs_baseline" if candidate_markdown is not None else "baseline_only",
        "agreement": agreement,
    }
    print(json.dumps(payload, ensure_ascii=False, separators=(",", ":")))


def command_all(args: argparse.Namespace) -> None:
    sync_sources(Path(args.benchmark_root))
    cases = load_cases()
    for case in cases:
        build_reference(case, refresh=args.refresh_references)
    runner = detect_runner(args.runner)
    report = build_report(cases, runner, args.refresh_references, args.compare_baselines)
    write_reports(report)
    print(render_summary_markdown(report))


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="MoonBitMark conversion evaluation harness")
    subparsers = parser.add_subparsers(dest="command", required=True)

    sync_parser = subparsers.add_parser("sync", help="sync benchmark samples into fixtures")
    sync_parser.add_argument("--benchmark-root", required=True)
    sync_parser.set_defaults(func=command_sync)

    prepare_parser = subparsers.add_parser("prepare", help="generate or refresh reference markdown")
    prepare_parser.add_argument("--benchmark-root")
    prepare_parser.add_argument("--refresh-references", action="store_true")
    prepare_parser.set_defaults(func=command_prepare)

    run_parser = subparsers.add_parser("run", help="run the conversion evaluation")
    run_parser.add_argument("--benchmark-root")
    run_parser.add_argument("--runner")
    run_parser.add_argument("--compare-baselines", action="store_true")
    run_parser.add_argument("--refresh-references", action="store_true")
    run_parser.set_defaults(func=command_run)

    compare_baseline_parser = subparsers.add_parser(
        "compare-baseline",
        help="run one baseline tool against one input and optionally compare with candidate markdown",
    )
    compare_baseline_parser.add_argument("--tool", required=True, choices=["markitdown", "docling"])
    compare_baseline_parser.add_argument("--format", required=True)
    compare_baseline_parser.add_argument("--input", required=True)
    compare_baseline_parser.add_argument("--candidate-markdown")
    compare_baseline_parser.set_defaults(func=command_compare_baseline)

    all_parser = subparsers.add_parser("all", help="sync, prepare references, and run the evaluation")
    all_parser.add_argument("--benchmark-root", required=True)
    all_parser.add_argument("--runner")
    all_parser.add_argument("--compare-baselines", action="store_true")
    all_parser.add_argument("--refresh-references", action="store_true")
    all_parser.set_defaults(func=command_all)

    return parser


def main() -> None:
    configure_stdio_utf8()
    parser = build_parser()
    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
