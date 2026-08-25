#!/usr/bin/env python3
"""Audit PDF page sizes and create proportionally fitted ISO A4 copies."""

from __future__ import annotations

import argparse
import csv
import json
import logging
import shutil
import sys
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Iterable

try:
    import pymupdf
except ImportError as exc:  # pragma: no cover
    raise SystemExit(
        "PyMuPDF is required. Install it with: python -m pip install pymupdf"
    ) from exc

try:
    from pypdf import PdfReader
except ImportError as exc:  # pragma: no cover
    raise SystemExit(
        "pypdf is required. Install it with: python -m pip install pypdf"
    ) from exc

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

logging.getLogger("pypdf").setLevel(logging.ERROR)
pymupdf.TOOLS.mupdf_display_errors(False)
pymupdf.TOOLS.mupdf_display_warnings(False)


MM_PER_POINT = 25.4 / 72.0
A4_PORTRAIT = tuple(float(v) for v in pymupdf.paper_size("a4"))


@dataclass
class PageAudit:
    page: int
    width_pt: float
    height_pt: float
    width_mm: float
    height_mm: float
    rotation: int
    a4: bool
    orientation: str
    annotations: int
    widgets: int
    links: int
    signatures: int


@dataclass
class FileAudit:
    path: str
    relative_path: str
    pages: int
    a4_pages: int
    non_a4_pages: list[int]
    compliant: bool
    interactive: bool
    encrypted: bool
    error: str | None
    page_details: list[PageAudit]
    output: str | None = None
    action: str = "audit"


def is_a4(width: float, height: float, tolerance: float) -> bool:
    actual = sorted((width, height))
    expected = sorted(A4_PORTRAIT)
    return all(abs(a - e) <= tolerance for a, e in zip(actual, expected))


def inspect_annotations(path: Path, pages: int) -> list[dict[str, int]]:
    result = [
        {"annotations": 0, "widgets": 0, "links": 0, "signatures": 0}
        for _ in range(pages)
    ]
    try:
        reader = PdfReader(str(path), strict=False)
        for index, page in enumerate(reader.pages[:pages]):
            raw_annots = page.get("/Annots")
            if not raw_annots:
                continue
            try:
                annots = raw_annots.get_object()
            except Exception:
                annots = raw_annots
            for reference in annots or []:
                try:
                    annot = reference.get_object()
                    subtype = str(annot.get("/Subtype", ""))
                    if subtype == "/Link":
                        result[index]["links"] += 1
                    elif subtype == "/Widget":
                        result[index]["widgets"] += 1
                        field_type = annot.get("/FT")
                        if field_type is None and annot.get("/Parent"):
                            try:
                                field_type = annot["/Parent"].get_object().get("/FT")
                            except Exception:
                                field_type = None
                        if str(field_type) == "/Sig":
                            result[index]["signatures"] += 1
                    else:
                        result[index]["annotations"] += 1
                except Exception:
                    result[index]["annotations"] += 1
    except Exception:
        pass
    return result


def audit_pdf(path: Path, base: Path, tolerance: float) -> FileAudit:
    relative = path.name if base.is_file() else str(path.relative_to(base))
    try:
        doc = pymupdf.open(path)
    except Exception as exc:
        return FileAudit(
            str(path), relative, 0, 0, [], False, False, False,
            f"open failed: {exc}", [], action="error"
        )

    try:
        if doc.needs_pass:
            return FileAudit(
                str(path), relative, doc.page_count, 0, [], False, False, True,
                "encrypted PDF requires a password", [], action="skipped"
            )

        details: list[PageAudit] = []
        annotation_data = inspect_annotations(path, doc.page_count)
        interactive = False
        for index, page in enumerate(doc):
            rect = page.rect
            width = float(rect.width)
            height = float(rect.height)
            counts = annotation_data[index]
            annotations = counts["annotations"]
            widgets = counts["widgets"]
            links = counts["links"]
            signatures = counts["signatures"]
            interactive = interactive or bool(annotations or widgets)
            details.append(
                PageAudit(
                    page=index + 1,
                    width_pt=round(width, 3),
                    height_pt=round(height, 3),
                    width_mm=round(width * MM_PER_POINT, 2),
                    height_mm=round(height * MM_PER_POINT, 2),
                    rotation=int(page.rotation),
                    a4=is_a4(width, height, tolerance),
                    orientation="landscape" if width > height else "portrait",
                    annotations=annotations,
                    widgets=widgets,
                    links=links,
                    signatures=signatures,
                )
            )
        non_a4 = [item.page for item in details if not item.a4]
        return FileAudit(
            str(path), relative, len(details), len(details) - len(non_a4),
            non_a4, not non_a4, interactive, False, None, details
        )
    except Exception as exc:
        return FileAudit(
            str(path), relative, doc.page_count, 0, [], False, False, False,
            f"audit failed: {exc}", [], action="error"
        )
    finally:
        doc.close()


def iter_pdfs(input_path: Path, recursive: bool, excluded: Path | None) -> list[Path]:
    if input_path.is_file():
        return [input_path] if input_path.suffix.lower() == ".pdf" else []
    iterator: Iterable[Path] = input_path.rglob("*") if recursive else input_path.glob("*")
    files = []
    excluded_resolved = excluded.resolve() if excluded else None
    for path in iterator:
        if not path.is_file() or path.suffix.lower() != ".pdf":
            continue
        if excluded_resolved:
            try:
                path.resolve().relative_to(excluded_resolved)
                continue
            except ValueError:
                pass
        files.append(path)
    return sorted(files, key=lambda item: str(item).casefold())


def target_canvas(source_page, orientation: str) -> tuple[float, float]:
    a4_width, a4_height = A4_PORTRAIT
    if orientation == "portrait":
        return a4_width, a4_height
    if orientation == "landscape":
        return a4_height, a4_width
    if source_page.rect.width > source_page.rect.height:
        return a4_height, a4_width
    return a4_width, a4_height


def map_rect(rect, scale: float, x0: float, y0: float):
    return pymupdf.Rect(
        x0 + rect.x0 * scale,
        y0 + rect.y0 * scale,
        x0 + rect.x1 * scale,
        y0 + rect.y1 * scale,
    )


def map_point(point, scale: float, x0: float, y0: float):
    return pymupdf.Point(x0 + point.x * scale, y0 + point.y * scale)


def copy_links(src, out, transforms: list[tuple[float, float, float]]) -> None:
    expected = 0
    inserted = 0
    for page_number, source_page in enumerate(src):
        output_page = out[page_number]
        source_scale, source_x0, source_y0 = transforms[page_number]
        try:
            links = source_page.get_links()
        except Exception:
            links = []
        expected += len(links)
        for original in links:
            link = dict(original)
            link.pop("xref", None)
            link.pop("id", None)
            if "from" in link:
                link["from"] = map_rect(
                    link["from"], source_scale, source_x0, source_y0
                )
            if link.get("kind") == pymupdf.LINK_GOTO:
                target_page = int(link.get("page", -1))
                if 0 <= target_page < len(transforms) and link.get("to") is not None:
                    scale, x0, y0 = transforms[target_page]
                    link["to"] = map_point(link["to"], scale, x0, y0)
            try:
                output_page.insert_link(link)
                inserted += 1
            except Exception:
                continue
    if inserted != expected:
        raise RuntimeError(
            f"could not preserve every link: expected {expected}, inserted {inserted}"
        )


def normalize_pdf(
    source: Path,
    destination: Path,
    orientation: str,
    margin_mm: float,
    allow_interactive_loss: bool,
) -> None:
    src = pymupdf.open(source)
    if src.needs_pass:
        src.close()
        raise RuntimeError("encrypted PDF requires a password")
    inventory = inspect_annotations(source, src.page_count)
    blocking = sum(item["annotations"] + item["widgets"] for item in inventory)
    if blocking and not allow_interactive_loss:
        src.close()
        raise RuntimeError(
            "interactive annotations/widgets/links detected; use "
            "--allow-interactive-loss only with approval"
        )

    out = pymupdf.open()
    margin = margin_mm / MM_PER_POINT
    transforms: list[tuple[float, float, float]] = []
    try:
        for page_number, source_page in enumerate(src):
            canvas_width, canvas_height = target_canvas(source_page, orientation)
            if margin * 2 >= min(canvas_width, canvas_height):
                raise RuntimeError("margin is too large for an A4 page")
            output_page = out.new_page(width=canvas_width, height=canvas_height)
            available = pymupdf.Rect(
                margin, margin, canvas_width - margin, canvas_height - margin
            )
            source_width = float(source_page.rect.width)
            source_height = float(source_page.rect.height)
            scale = min(available.width / source_width, available.height / source_height)
            draw_width = source_width * scale
            draw_height = source_height * scale
            x0 = available.x0 + (available.width - draw_width) / 2
            y0 = available.y0 + (available.height - draw_height) / 2
            target = pymupdf.Rect(x0, y0, x0 + draw_width, y0 + draw_height)
            transforms.append((scale, x0, y0))
            if blocking and allow_interactive_loss:
                # Rendering with annotations preserves the visible appearance of
                # highlights, stamps and signature widgets. The derivative is
                # deliberately flattened: original signature validation and
                # editability cannot survive a page-size transformation.
                pixmap = source_page.get_pixmap(dpi=300, alpha=False, annots=True)
                output_page.insert_image(target, pixmap=pixmap, keep_proportion=True)
            else:
                output_page.show_pdf_page(
                    target, src, page_number, keep_proportion=True, overlay=True
                )

        copy_links(src, out, transforms)

        metadata = {key: value for key, value in (src.metadata or {}).items() if value}
        if metadata:
            try:
                out.set_metadata(metadata)
            except Exception:
                pass
        try:
            toc = src.get_toc()
            if toc:
                out.set_toc(toc)
        except Exception:
            pass

        destination.parent.mkdir(parents=True, exist_ok=True)
        out.save(destination, garbage=4, deflate=True)
    finally:
        out.close()
        src.close()


def output_path_for(source: Path, base: Path, output_dir: Path | None) -> Path:
    if output_dir:
        relative = Path(source.name) if base.is_file() else source.relative_to(base)
        return output_dir / relative
    return source.with_name(f"{source.stem}_A4.pdf")


def verify_output(path: Path, expected_pages: int, tolerance: float) -> None:
    result = audit_pdf(path, path, tolerance)
    if result.error:
        raise RuntimeError(result.error)
    if result.pages != expected_pages:
        raise RuntimeError(
            f"page count changed: expected {expected_pages}, got {result.pages}"
        )
    if not result.compliant:
        raise RuntimeError(f"output still has non-A4 pages: {result.non_a4_pages}")


def write_json(path: Path, records: list[FileAudit], summary: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = {"summary": summary, "files": [asdict(item) for item in records]}
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")


def page_size_summary(record: FileAudit) -> str:
    sizes = sorted(
        {f"{page.width_mm:.2f}x{page.height_mm:.2f} mm" for page in record.page_details}
    )
    return "; ".join(sizes)


def write_csv(path: Path, records: list[FileAudit]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=[
                "relative_path", "pages", "a4_pages", "non_a4_pages",
                "compliant", "interactive", "encrypted", "sizes",
                "action", "output", "error",
            ],
        )
        writer.writeheader()
        for item in records:
            writer.writerow(
                {
                    "relative_path": item.relative_path,
                    "pages": item.pages,
                    "a4_pages": item.a4_pages,
                    "non_a4_pages": ",".join(map(str, item.non_a4_pages)),
                    "compliant": item.compliant,
                    "interactive": item.interactive,
                    "encrypted": item.encrypted,
                    "sizes": page_size_summary(item),
                    "action": item.action,
                    "output": item.output or "",
                    "error": item.error or "",
                }
            )


def compact_pages(pages: list[int]) -> str:
    if not pages:
        return ""
    ranges = []
    start = previous = pages[0]
    for number in pages[1:]:
        if number == previous + 1:
            previous = number
            continue
        ranges.append(str(start) if start == previous else f"{start}-{previous}")
        start = previous = number
    ranges.append(str(start) if start == previous else f"{start}-{previous}")
    return ", ".join(ranges)


def md_escape(value: str) -> str:
    return value.replace("|", "\\|").replace("\n", " ")


def write_markdown(path: Path, records: list[FileAudit], summary: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    non_a4 = [item for item in records if not item.compliant and not item.encrypted]
    risky = [item for item in non_a4 if item.interactive]
    lines = [
        "# PDF A4 页面尺寸核查报告",
        "",
        "## 汇总",
        "",
        f"- PDF 文件：{summary['files']} 份",
        f"- PDF 页面：{summary['pages']} 页",
        f"- 已为 A4：{summary['compliant_files']} 份",
        f"- 含非 A4 页面：{len(non_a4)} 份，共 {summary['non_a4_pages']} 页",
        f"- 已转换：{summary['normalized']} 份",
        f"- 含注释、表单或签名的非 A4 文件：{len(risky)} 份",
        f"- 处理错误：{summary['errors']} 份",
        "",
        "## 非 A4 文件",
        "",
        "| 文件 | 非 A4 页 | 检测尺寸 | 风险 | 处理状态 |",
        "| --- | ---: | --- | --- | --- |",
    ]
    for item in non_a4:
        if item.interactive and item.action == "normalized":
            risk = "含注释/表单/签名；可见效果已扁平化"
        else:
            risk = "含注释/表单/签名" if item.interactive else "无"
        lines.append(
            "| " + " | ".join(
                [
                    md_escape(item.relative_path),
                    compact_pages(item.non_a4_pages),
                    md_escape(page_size_summary(item)),
                    risk,
                    md_escape(item.action),
                ]
            ) + " |"
        )
    converted_risky = [item for item in risky if item.action == "normalized"]
    pending_risky = [item for item in risky if item.action != "normalized"]
    if converted_risky:
        lines.extend(
            [
                "",
                "## 已扁平化处理的交互或签名文件",
                "",
                "这些派生副本以 300 dpi 保留签章、高亮等可见效果；原始数字签名验证状态和注释/表单可编辑性不继承。原文件未修改。",
                "",
            ]
        )
        for item in converted_risky:
            signatures = sum(page.signatures for page in item.page_details)
            annotations = sum(page.annotations for page in item.page_details)
            widgets = sum(page.widgets for page in item.page_details)
            links = sum(page.links for page in item.page_details)
            lines.append(
                f"- `{item.relative_path}`：签名 {signatures}、注释 {annotations}、"
                f"表单控件 {widgets}、链接 {links}。"
            )
    if pending_risky:
        lines.extend(
            [
                "",
                "## 待确认的交互或签名文件",
                "",
                "这些文件改变页面后可能使数字签名失效，或丢失非链接注释/表单对象，默认未转换。",
                "",
            ]
        )
        for item in pending_risky:
            lines.append(f"- `{item.relative_path}`")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def make_summary(records: list[FileAudit]) -> dict:
    return {
        "files": len(records),
        "pages": sum(item.pages for item in records),
        "compliant_files": sum(item.compliant and not item.error for item in records),
        "non_a4_files": sum(
            (not item.compliant) and not item.error and not item.encrypted
            for item in records
        ),
        "non_a4_pages": sum(len(item.non_a4_pages) for item in records),
        "interactive_files": sum(item.interactive for item in records),
        "encrypted_files": sum(item.encrypted for item in records),
        "errors": sum(bool(item.error) for item in records),
        "normalized": sum(item.action == "normalized" for item in records),
        "copied": sum(item.action == "copied" for item in records),
        "skipped": sum(item.action == "skipped" for item in records),
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path, help="PDF file or directory")
    parser.add_argument("--mode", choices=("audit", "normalize"), default="audit")
    parser.add_argument("--recursive", action="store_true", help="scan directories recursively")
    parser.add_argument("--output-dir", type=Path)
    parser.add_argument(
        "--orientation", choices=("preserve", "portrait", "landscape"),
        default="preserve"
    )
    parser.add_argument("--margin-mm", type=float, default=0.0)
    parser.add_argument("--tolerance-pt", type=float, default=2.0)
    parser.add_argument("--copy-compliant", action="store_true")
    parser.add_argument("--force-all", action="store_true")
    parser.add_argument("--allow-interactive-loss", action="store_true")
    parser.add_argument("--overwrite", action="store_true")
    parser.add_argument("--report-json", type=Path)
    parser.add_argument("--report-csv", type=Path)
    parser.add_argument("--report-md", type=Path)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    source = args.input.resolve()
    if not source.exists():
        print(f"ERROR: input does not exist: {source}", file=sys.stderr)
        return 2
    if source.is_file() and source.suffix.lower() != ".pdf":
        print("ERROR: input file is not a PDF", file=sys.stderr)
        return 2
    if args.margin_mm < 0 or args.tolerance_pt < 0:
        print("ERROR: margin and tolerance must be non-negative", file=sys.stderr)
        return 2

    output_dir = args.output_dir.resolve() if args.output_dir else None
    if args.mode == "normalize" and source.is_dir() and output_dir is None:
        print("ERROR: --output-dir is required when normalizing a directory", file=sys.stderr)
        return 2
    if output_dir and output_dir == source:
        print("ERROR: output directory must differ from the source directory", file=sys.stderr)
        return 2

    pdfs = iter_pdfs(source, args.recursive, output_dir)
    if not pdfs:
        print("No PDF files found.")
        return 1

    records = [audit_pdf(path, source, args.tolerance_pt) for path in pdfs]

    if args.mode == "normalize":
        for record, pdf in zip(records, pdfs):
            if record.error or record.encrypted:
                record.action = "skipped"
                continue
            destination = output_path_for(pdf, source, output_dir)
            record.output = str(destination)
            if destination.exists() and not args.overwrite:
                record.action = "skipped"
                record.error = "output exists; use --overwrite to replace it"
                continue
            if record.compliant and not args.force_all:
                if args.copy_compliant:
                    destination.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(pdf, destination)
                    verify_output(destination, record.pages, args.tolerance_pt)
                    record.action = "copied"
                else:
                    record.action = "skipped"
                continue
            if record.interactive and not args.allow_interactive_loss:
                record.action = "skipped"
                record.error = "interactive content detected; not normalized"
                continue
            try:
                normalize_pdf(
                    pdf, destination, args.orientation, args.margin_mm,
                    args.allow_interactive_loss,
                )
                verify_output(destination, record.pages, args.tolerance_pt)
                record.action = "normalized"
            except Exception as exc:
                record.action = "error"
                record.error = f"normalize failed: {exc}"

    summary = make_summary(records)
    print(json.dumps(summary, ensure_ascii=False, indent=2))
    non_a4 = [
        item for item in records
        if not item.compliant and not item.error and not item.encrypted
    ]
    if non_a4:
        print("\nNON_A4_FILES")
        for item in non_a4:
            print(
                f"- {item.relative_path} | pages={item.non_a4_pages} | "
                f"sizes={page_size_summary(item)}"
            )
    issues = [item for item in records if item.error or item.encrypted or item.interactive]
    if issues:
        print("\nISSUES")
        for item in issues:
            print(
                f"- {item.relative_path} | interactive={item.interactive} | "
                f"encrypted={item.encrypted} | error={item.error or ''}"
            )

    if args.report_json:
        write_json(args.report_json, records, summary)
    if args.report_csv:
        write_csv(args.report_csv, records)
    if args.report_md:
        write_markdown(args.report_md, records, summary)
    return 0 if not summary["errors"] else 3


if __name__ == "__main__":
    raise SystemExit(main())
