---
name: pdf-a4-normalizer
description: Audit PDF page dimensions and create verified ISO A4 copies while preserving originals. Use for single files or recursive folders when page sizes must be checked or standardized; ordinary pages retain vector content, while approved annotation or signature pages can be flattened with their visible appearance retained.
---

# PDF A4 Normalizer

Use `scripts/normalize_pdf_a4.py` for deterministic inspection and conversion. It uses PyMuPDF `show_pdf_page`, so ordinary text, images, and vector graphics remain PDF content instead of being rasterized.

## Essential rules

- Start with `--mode audit`. Report the exact files and pages that are not A4 before creating outputs.
- Treat portrait and landscape ISO A4 as compliant. Default tolerance is 2 points per dimension to accommodate normal PDF rounding.
- Preserve originals. Write conversions to a separate output directory or a new `_A4.pdf` file unless the user explicitly authorizes replacement.
- Default to `--orientation preserve`: portrait sources go to A4 portrait and landscape sources to A4 landscape. Use forced portrait or landscape only when the user requests it.
- Fit proportionally and center the source page. Never stretch content to fill A4.
- A PDF filename, application UI, or nominal print setting is not proof. Re-audit generated files and confirm page count.
- `show_pdf_page` does not preserve annotations, form widgets, or digital signatures. The script re-creates standard links, but refuses files containing other annotations or widgets by default. With `--allow-interactive-loss`, it renders those files at 300 dpi with annotations enabled so visible stamps, highlights, and signature appearances remain, while interactivity and signature validity do not.
- A modified signed PDF no longer has the original signature validity. Never claim otherwise.

## Runtime

Use Python 3.10+ with PyMuPDF and pypdf:

```powershell
python -m pip install --upgrade pymupdf pypdf
python scripts/normalize_pdf_a4.py --help
```

## Workflow

### 1. Audit recursively

```powershell
python scripts/normalize_pdf_a4.py '<input-folder>' `
  --mode audit `
  --recursive `
  --report-json '<report.json>' `
  --report-csv '<report.csv>' `
  --report-md '<report.md>'
```

Lead with the non-A4 file count and list. Distinguish fully compliant, mixed-size, unreadable/encrypted, and interactive files.

### 2. Normalize while preserving originals

To create only corrected copies of non-A4 PDFs:

```powershell
python scripts/normalize_pdf_a4.py '<input-folder>' `
  --mode normalize `
  --recursive `
  --output-dir '<output-folder>'
```

To create a complete mirrored set, copying already-compliant PDFs unchanged:

```powershell
python scripts/normalize_pdf_a4.py '<input-folder>' `
  --mode normalize `
  --recursive `
  --output-dir '<output-folder>' `
  --copy-compliant
```

Use `--overwrite` only for files already present in the output directory. It never authorizes overwriting the source tree.

### 3. Verify

Re-run audit against the output directory and require:

- every page is A4 within tolerance;
- page counts equal their source files;
- no conversion errors or skipped interactive/encrypted files;
- output files open and render successfully.

Visually inspect every converted PDF when the batch is small. For large batches, inspect at least the first, middle, and last page of every converted file, plus pages near reported size/orientation transitions. Check for clipping, unexpected rotation, excessive shrinkage, missing stamps, and blank pages.

## Useful options

- `--orientation preserve|portrait|landscape`
- `--margin-mm N` to reserve an N mm white border while keeping proportional fit; zero adds no extra border
- `--tolerance-pt 2` to control A4 classification tolerance
- `--copy-compliant` to mirror compliant files unchanged
- `--force-all` to rebuild even already-A4 PDFs; use only for a specific reason
- `--allow-interactive-loss` only after the user accepts losing forms, non-link annotations, or signatures

## Failure handling

- If PyMuPDF cannot open a file, report it and leave it unchanged.
- If a PDF is encrypted, request a password or exclude it; do not attempt bypasses.
- If interactive objects are detected, stop for that file by default.
- If output validation fails, keep the source and failed output separate, report the exact file/page, and do not replace any original.
- If page orientation is ambiguous or forced A4 causes severe shrinkage, show the measured dimensions and ask whether portrait, landscape, or manual handling is desired.

## Basis

This workflow adapts PyMuPDF's official A4 page creation and `show_pdf_page` approach. The important invariant is a new ISO A4 canvas with proportional, centered placement of the original PDF page.
