from __future__ import annotations

import argparse
import csv
import datetime as dt
import difflib
import html
from html.parser import HTMLParser
import importlib.util
import json
import os
from pathlib import Path, PurePosixPath
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
    for candidate in candidates:
        if candidate.exists():
            stale, reason = detect_stale_binary(candidate)
            return RunnerInfo([str(candidate)], str(candidate.relative_to(REPO_ROOT)), stale, reason)

    return RunnerInfo(["moon", "run", "cmd/main", "--"], "moon run cmd/main --", False, None)


def run_conversion(
    runner: RunnerInfo,
    input_path: Path,
    cli_args: list[str] | None = None,
    timeout_seconds: int = 60,
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
            texts = [clean_inline(elem.text or "") for elem in root.findall(".//{*}t")]
            texts = [text for text in texts if text]
            if not texts:
                continue
            blocks.append(f"## Slide {index}")
            blocks.extend(texts)
            blocks.append("")
        return "\n\n".join(blocks).strip()


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
    code_blocks = 0
    paragraphs = 0
    in_code = False
    current_paragraph: list[str] = []
    for line in lines:
        stripped = line.strip()
        if stripped.startswith("```"):
            in_code = not in_code
            code_blocks += 1 if in_code else 0
            if current_paragraph:
                paragraphs += 1
                current_paragraph = []
            continue
        if in_code:
            continue
        if stripped.startswith("#"):
            if current_paragraph:
                paragraphs += 1
                current_paragraph = []
            level = len(stripped) - len(stripped.lstrip("#"))
            headings.append((level, clean_inline(stripped[level:])))
            continue
        if re.match(r"^([-*+]|\d+\.)\s+", stripped):
            if current_paragraph:
                paragraphs += 1
                current_paragraph = []
            list_items += 1
            continue
        if stripped.startswith("|"):
            if current_paragraph:
                paragraphs += 1
                current_paragraph = []
            continue
        if stripped:
            current_paragraph.append(stripped)
        elif current_paragraph:
            paragraphs += 1
            current_paragraph = []
    if current_paragraph:
        paragraphs += 1
    return {
        "headings": headings,
        "list_items": list_items,
        "code_blocks": code_blocks,
        "paragraphs": paragraphs,
        "tables": parse_markdown_tables(text),
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
    return importlib.util.find_spec(tool) is not None


def baseline_supports_format(tool: str, format_name: str) -> bool:
    return format_name in BASELINE_SUPPORTED_FORMATS.get(tool, set())


def compare_baseline(
    tool: str,
    format_name: str,
    input_path: Path,
    reference_markdown: str | None,
) -> tuple[float | None, str | None, int | None]:
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
            return None, f"baseline does not support format: {format_name}", None
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
            [sys.executable, "-c", script, str(input_path)],
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
        return None, "baseline execution timed out", duration_ms
    if completed.returncode != 0:
        error = completed.stderr.strip() or completed.stdout.strip() or "baseline execution failed"
        return None, error, duration_ms
    output = normalize_markdown(completed.stdout)
    if reference_markdown:
        score = 0.6 * sequence_similarity(output, reference_markdown) + 0.4 * structure_similarity(output, reference_markdown)
    else:
        score = None
    return score, None, duration_ms


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
                "reference": str(reference_path.relative_to(REPO_ROOT)) if reference_path and reference_path.exists() else None,
                "runner_returncode": conversion.returncode,
                "runner_duration_ms": conversion.duration_ms,
                "stderr": conversion.stderr.strip(),
                "passed": passed,
                "score": round(score, 4),
                "metrics": {key: round(value, 4) for key, value in metrics.items()},
                "checks": checks,
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
    for result in results:
        bucket = by_format.setdefault(result["format"], {"total": 0, "passed": 0, "score_sum": 0.0})
        bucket["total"] += 1
        bucket["passed"] += 1 if result["passed"] else 0
        bucket["score_sum"] += result["score"]

    for bucket in by_format.values():
        bucket["average_score"] = round(bucket["score_sum"] / max(bucket["total"], 1), 4)
        del bucket["score_sum"]

    return {
        "total_cases": total,
        "passed_cases": passed,
        "failed_cases": failed,
        "pass_rate": round(passed / max(total, 1), 4),
        "average_score": round(average_score, 4),
        "by_format": by_format,
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
