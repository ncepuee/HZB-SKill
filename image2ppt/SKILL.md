---
name: image2ppt
description: Reconstruct screenshots, slide images, posters, diagrams, dashboards, timelines, tables, or PDF pages as high-fidelity editable PowerPoint files. Use when the source composition must be preserved while readable text and simple visual structure become native PPT objects; keep only genuinely complex visuals as bounded replaceable assets.
metadata:
  short-description: High-fidelity image to editable PowerPoint reconstruction
---

# Image2PPT

Reconstruct the supplied visual; do not redesign it. Optimize for both visual fidelity and practical editability, then prove the result by rendering the PPTX and comparing it with the source.

## Non-negotiable contract

- Preserve the original input. Normalize a copy only when orientation, color profile, perspective, or format requires it.
- Resolve content authority before drawing: current user correction > authoritative source file/data > visible source text > inference.
- Rebuild reviewed text as native PowerPoint text. Never place editable text over the same readable text inside an image.
- Rebuild simple panels, cards, rules, arrows, tables, timelines, and icons as native objects when that preserves quality.
- Keep photos, textures, dense illustrations, and inseparable scientific visuals as tightly bounded local pictures or PowerPoint-compatible SVGs.
- Never use a text-bearing full-slide screenshot as the delivered background.
- A reviewed textless clean plate is allowed only when the source background cannot be reproduced cleanly with native fills and the remaining semantic objects are independently editable.
- Render with PowerPoint when available. A successfully saved file is not evidence of correct layout.
- State which elements remain pictures. Do not describe replaceable pictures as internally editable artwork.

## Quality modes

Resolve the active mode from the current request. Default to `standard`.

| Mode | Use when | Repair limit |
|---|---|---:|
| `economy` | draft, simple page, fastest useful reconstruction | 1 |
| `standard` | normal delivery balancing fidelity and effort | 2 |
| `strict` | “尽可能接近”, pixel-level, formal submission, dense CJK or scientific slide | 3 |

Higher modes increase inspection and QA, not authorization for external uploads or unbounded retries.

## Representation decision

Assign every visible semantic item to one primary representation:

1. **Native text** — every readable word, number, formula, caption, label, legend, and footnote.
2. **Native structure** — simple geometry, cards, panels, lines, arrows, table grids, nodes, and basic icons.
3. **Editable vector module** — complex but vector-reconstructable diagrams that benefit from SVG hierarchy and PowerPoint Convert to Shape/Ungroup.
4. **Bounded picture** — photos, textures, intricate illustrations, or data visuals that cannot be reliably decomposed.
5. **Textless clean plate** — last-resort background for complex integrated visuals; never contains semantic text or detachable objects.

For ambiguous, text-over-image, dense-chart, or SVG-heavy cases, read [references/element-routing.md](references/element-routing.md).

## Execution workflow

1. **Preflight** — inspect dimensions, aspect ratio, orientation, fonts, renderer, input count, and authoritative source data. Use `scripts/preflight.py` when helpful.
2. **Inventory once** — record every semantic item with ID, parent, bbox, representation, text/data, style, z-order, invariants, and negative constraints. Reinspect corners, card interiors, dividers, icons, labels, and footnotes for omissions.
3. **Lock the skeleton** — build only the canvas, title, major panels, columns, rows, timelines, and primary arrows. Render and correct macro geometry before fine details.
4. **Build semantic layers** — baseboard → major assets → panels/cards → connectors → tables/charts → text → foreground decoration. Preserve parent-child containment and reusable modules.
5. **Validate content** — normalize text to Unicode NFC; compute dates, totals, and derived values before rendering; never invent hidden chart data.
6. **Render** — use `scripts/render_ppt.py` or the available presentation runtime. Re-render after every repair.
7. **Audit** — run structural/editability checks and source-to-render comparison. Use whole-slide metrics for triage and critical-region metrics for local fidelity.
8. **Repair failed evidence only** — fix named failures, rerender, and stop at the active mode's repair limit. Report residual limitations instead of looping indefinitely.
9. **Deliver** — provide the PPTX, rendered preview, compact QA summary, and a precise declaration of non-native assets.

Read [references/workflow.md](references/workflow.md) before executing a full reconstruction. Read [references/qa-contract.md](references/qa-contract.md) before `standard` or `strict` delivery.

## Scene contract

Use a compact scene JSON when repeated styles, deterministic builds, or multi-version repair would benefit from it. Version `2.0` supports pixel or inch units, reusable styles, per-slide expected text and critical regions, semantic hierarchy, and explicit picture declarations.

Read [references/scene-schema.md](references/scene-schema.md) only when authoring or changing a scene file. `scripts/build_from_spec.py` remains backward compatible with the original flat one-slide spec.

## Text and font handling

- Use the source font when installed and licensed; otherwise match visual metrics and declare substitution.
- For Chinese or mixed CJK slides, inspect fullwidth glyph metrics, punctuation, manual line breaks, and fallback fonts.
- Do not trust approximate font-size formulas as final truth. PowerPoint rendering determines line breaks and clipping.
- Treat a one-line title wrapping, tofu, mojibake, clipped text, or a stranded final character as a hard failure.

Read [references/text-and-fonts.md](references/text-and-fonts.md) for CJK, formulas, decorative fonts, or font substitution.

## Hard delivery gates

Do not claim full success when any applicable gate fails:

- a reviewed text item is absent from native text;
- an inventory item is missing or duplicated;
- a text-bearing picture covers most of the slide;
- a semantic chart or table is flattened without a stated limitation;
- a picture is stretched, a circle becomes an oval, or a child crosses its parent boundary;
- text clips, wraps unexpectedly, contains tofu/mojibake, or extends beyond the slide;
- the PPTX opens with a repair warning or contains missing/zero-byte media;
- the rendered preview was not inspected;
- a declared critical region fails visual or semantic review.

Whole-image MAE may guide optimization but cannot override content, semantic, containment, or editability failures.

## Bundled tools

- `scripts/inspect_reference.py` — dimensions, aspect ratio, grid overlay.
- `scripts/preflight.py` — input/runtime/font/renderer capability report.
- `scripts/scene_lint.py` — scene contract and semantic coverage checks.
- `scripts/build_from_spec.py` — deterministic native PPTX build from v1 or v2 scene JSON.
- `scripts/render_ppt.py` — PowerPoint-first PNG rendering with LibreOffice/Poppler fallback.
- `scripts/compare_renders.py` — global and critical-region MAE, blurred-layout MAE, overlay, and amplified diff.
- `scripts/validate_ppt.py` — package, bounds, text, media, coverage, and editability audit with JSON output.
- `scripts/qa_pipeline.py` — render + validate + compare orchestration.

The research basis and adopted design decisions are recorded in [references/research-basis.md](references/research-basis.md).

