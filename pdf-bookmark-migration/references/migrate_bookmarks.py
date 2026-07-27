#!/usr/bin/env python3
"""Migrate PDF bookmarks (outlines) from a source PDF to a target PDF.

Preserves nested structure, destination types (XYZ/Fit/etc.), and coordinates.
Uses pikepdf for reliable cross-PDF page object mapping.

Usage:
    python migrate_bookmarks.py source.pdf target.pdf
    python migrate_bookmarks.py --batch pair1_src.pdf pair1_dst.pdf pair2_src.pdf pair2_dst.pdf
"""

import sys
import os
import argparse

try:
    import pikepdf
except ImportError:
    print("Error: pikepdf not installed. Run: pip install pikepdf")
    sys.exit(1)


def get_page_index(pdf, dest):
    """Find the page index (0-based) for a bookmark destination.

    Uses pikepdf page object comparison for accurate mapping,
    handling cases where object generation numbers differ.
    """
    if dest is None:
        return 0
    try:
        page_obj = dest[0]
        for i, page in enumerate(pdf.pages):
            if page.obj == page_obj:
                return i
    except Exception:
        pass
    return 0


def extract_bookmarks(pdf, items, indent=0):
    """Recursively extract bookmarks from a PDF outline.

    Returns a list of dicts with keys:
        title, page, dest_type, dest_args, children
    """
    result = []
    for item in items:
        title = str(item.title)
        page_idx = get_page_index(pdf, item.destination)

        dest_type = "/Fit"
        dest_args = []
        if item.destination and len(item.destination) > 1:
            try:
                dest_type = str(item.destination[1])
            except Exception:
                dest_type = "/Fit"
            if len(item.destination) > 2:
                try:
                    dest_args = [
                        item.destination[j] for j in range(2, len(item.destination))
                    ]
                except Exception:
                    dest_args = []

        prefix = "  " * indent
        print(f"{prefix}{title} -> p.{page_idx + 1}")

        children = []
        if item.children:
            children = extract_bookmarks(pdf, item.children, indent + 1)

        result.append({
            "title": title,
            "page": page_idx,
            "dest_type": dest_type,
            "dest_args": dest_args,
            "children": children,
        })
    return result


def write_bookmarks(dst_pdf, bookmarks, parent_list):
    """Recursively write bookmarks to a PDF outline."""
    for bm in bookmarks:
        page_idx = bm["page"]
        if page_idx >= len(dst_pdf.pages):
            page_idx = 0

        page_obj = dst_pdf.pages[page_idx]

        dest_list = [page_obj.obj, pikepdf.Name(bm["dest_type"])]
        for arg in bm["dest_args"]:
            dest_list.append(arg)
        dest = pikepdf.Array(dest_list)

        item = pikepdf.OutlineItem(bm["title"], dest)
        parent_list.append(item)

        if bm["children"]:
            write_bookmarks(dst_pdf, bm["children"], item.children)


def migrate_bookmarks(src_path, dst_path):
    """Migrate bookmarks from src_path to dst_path.

    Args:
        src_path: Path to source PDF (has bookmarks).
        dst_path: Path to target PDF (will receive bookmarks, overwritten in place).

    Returns:
        int: Number of top-level bookmarks migrated.
    """
    src_name = os.path.basename(src_path)
    dst_name = os.path.basename(dst_path)

    print(f"\n=== {src_name[:60]} -> {dst_name[:60]} ===")

    src = pikepdf.open(src_path)
    dst = pikepdf.open(dst_path, allow_overwriting_input=True)

    print(f"  Source pages: {len(src.pages)}, Target pages: {len(dst.pages)}")

    bookmarks = []
    with src.open_outline() as ol:
        bookmarks = extract_bookmarks(src, ol.root)

    count = len(bookmarks)
    print(f"  Extracted: {count} top-level bookmarks")

    if count == 0:
        print("  No bookmarks found in source, skipping")
        src.close()
        dst.close()
        return 0

    with dst.open_outline() as ol:
        ol.root.clear()
        write_bookmarks(dst, bookmarks, ol.root)

    dst.save(dst_path)
    dst.close()
    src.close()

    print(f"  Written to target: {count} top-level bookmarks")
    return count


def main():
    parser = argparse.ArgumentParser(
        description="Migrate PDF bookmarks from source to target PDF"
    )
    parser.add_argument("source", help="Source PDF path (has bookmarks)")
    parser.add_argument("target", help="Target PDF path (receives bookmarks)")
    args = parser.parse_args()

    if not os.path.exists(args.source):
        print(f"Error: Source not found: {args.source}")
        sys.exit(1)
    if not os.path.exists(args.target):
        print(f"Error: Target not found: {args.target}")
        sys.exit(1)

    migrate_bookmarks(args.source, args.target)
    print("\nDone!")


if __name__ == "__main__":
    main()
