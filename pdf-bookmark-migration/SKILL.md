---
name: pdf-bookmark-migration
description: >-
  Migrate PDF bookmarks (outlines) from a source PDF to a target PDF, preserving
  nested structure, destination types (XYZ/Fit), and page-level coordinates.
  Handles multi-level bookmarks with children, cross-PDF page index mapping via
  pikepdf object comparison, and batch processing of multiple PDF pairs.
  Use when: migrate bookmarks, copy PDF outline, transfer PDF bookmarks,
  迁移书签, 复制书签, PDF书签, 添加书签, bookmark transfer.
---

# PDF Bookmark Migration

Migrates bookmarks (outlines) from a source PDF to a target PDF with full
nested structure and destination precision.

## When to use

- A Print/export PDF lost its bookmarks and needs them restored from the source
- Batch-migrating bookmarks across multiple PDF pairs
- Any scenario requiring PDF outline transfer between two PDFs with the same
  or similar page count

## Prerequisites

- Python 3.10+
- `pikepdf` library (`pip install pikepdf`)

## Routing protocol

### 1. Identify file pairs

Determine the source PDF (has bookmarks) and target PDF (needs bookmarks).
If the target has existing bookmarks, they will be replaced.

### 2. Run migration

Read [references/migrate_bookmarks.py](references/migrate_bookmarks.py) and
execute the `migrate_bookmarks(src_path, dst_path)` function. The script
handles:

- Recursive extraction of nested bookmarks (all levels)
- Page index mapping via pikepdf page object comparison
- Preservation of destination type (`/XYZ`, `/Fit`, `/FitH`, etc.) and
  coordinates (x, y, zoom)
- Graceful handling of missing or malformed destinations

### 3. Batch mode

For multiple PDF pairs, call `migrate_bookmarks` in a loop. See
[references/migrate_bookmarks.py](references/migrate_bookmarks.py) for the
batch example at the bottom of the file.

### 4. Verify

After migration, open the target PDF in a reader and verify:
- All bookmark titles appear correctly
- Clicking a bookmark navigates to the correct page
- Nested (child) bookmarks are indented properly
- XYZ coordinates preserve scroll position
