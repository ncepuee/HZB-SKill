# PDF Bookmark Migration Skill

Migrate PDF bookmarks (outlines) from a source PDF to a target PDF with full
nested structure and destination precision.

## Features

- **Multi-level bookmarks**: Recursive extraction and writing of nested bookmarks (all levels)
- **Destination preservation**: Keeps `/XYZ`, `/Fit`, `/FitH`, etc. with original coordinates (x, y, zoom)
- **Page index mapping**: Uses pikepdf page object comparison for accurate cross-PDF page mapping
- **Batch mode**: Process multiple PDF pairs in one call
- **Graceful fallback**: Handles missing or malformed destinations without crashing

## Installation

```bash
pip install pikepdf
```

## Usage

### Single PDF pair

```python
from migrate_bookmarks import migrate_bookmarks

migrate_bookmarks(
    src_path="source_with_bookmarks.pdf",
    dst_path="target_without_bookmarks.pdf"
)
```

### Batch mode

```python
from migrate_bookmarks import migrate_bookmarks

pairs = [
    ("paper_v2.pdf", "paper_print.pdf"),
    ("response.pdf", "response_print.pdf"),
]

for src, dst in pairs:
    migrate_bookmarks(src, dst)
```

### CLI usage

```bash
python migrate_bookmarks.py source.pdf target.pdf
```

## How it works

1. **Extract**: Opens the source PDF and recursively reads all bookmark items,
   including their titles, destinations (page + type + coordinates), and children.
2. **Map pages**: For each bookmark, finds the corresponding page in the source PDF
   by comparing pikepdf page objects (not page numbers, which can differ).
3. **Write**: Opens the target PDF, clears existing bookmarks, and writes the
   extracted bookmarks with correct page references and preserved destination types.

## Technical details

- Uses `pikepdf` for PDF manipulation (not PyPDF2 or fitz)
- Page mapping via `page.obj` comparison (handles object generation numbers)
- Destination format: `pikepdf.Array([page_obj, /XYZ, x, y, zoom])`
- Supports `/XYZ`, `/Fit`, `/FitH`, `/FitV`, `/FitR`, `/FitB`, `/FitBH`, `/FitBV`
- Output preserves all coordinate precision from the source

## Requirements

- Python 3.10+
- pikepdf >= 8.0

## License

MIT
