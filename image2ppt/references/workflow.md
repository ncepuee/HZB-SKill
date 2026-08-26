# Reconstruction workflow

## 1. Preflight

- Preserve the original input and normalize only a copy.
- Detect dimensions, orientation, aspect ratio, font requirements and renderer availability.
- Resolve authoritative text, data, dates, totals and formulas.
- Create a task-local run directory for normalized inputs, scene, assets, build, render and QA outputs.

## 2. Inventory and completeness pass

For every slide, record canvas/background; semantic ID, parent and level; bbox and z-order; representation route; text/data; style; invariants; negative constraints; audit mapping; and shared-versus-unique status.

Reinspect corners, card interiors, chart labels, divider marks, icons and footnotes after the first inventory. An unexpectedly low asset count on a visually rich slide often indicates omissions.

## 3. Skeleton pass

Build only aspect ratio, title anchors, panel/card boxes, column widths, row heights, gaps, primary timeline/arrows and visual center of mass. Render the skeleton. Do not proceed while macro geometry is visibly wrong.

## 4. Detailed construction

Use this z-order:

```text
background/native fill
→ textless clean plate or large bounded assets
→ panel/card fills
→ small assets and icons
→ connectors and table grids
→ native charts/tables
→ native text
→ foreground outlines and brand elements
```

For important containers, consider fill and outline as separate layers when this prevents doubled or unstable borders.

## 5. Content validation

- Normalize strings to Unicode NFC and store JSON as UTF-8.
- Recompute totals and derived dates in code.
- Verify source-language punctuation and bilingual spelling.
- Do not infer unseen chart values.
- Record content conflicts rather than silently choosing by appearance.

## 6. Rendering

Render after the skeleton pass and after each repair. Prefer Microsoft PowerPoint on Windows because its layout engine determines delivered appearance. If unavailable, use LibreOffice/Poppler as an approximation and disclose the renderer.

## 7. QA and repair

Run structural validation before visual comparison. Compare the whole slide, then critical regions. Use overlays and amplified diffs to localize problems.

Repair in this order: content; slide ratio and macro geometry; containment and z-order; text/font issues; table/chart/connector semantics; then color, border, icon and spacing details.

Repair only failed evidence. Stop after the mode-specific limit and report residual differences.

## 8. Delivery

Deliver the editable PPTX, actual rendered preview, compact QA summary, declared picture/SVG limitations, and unresolved differences.

