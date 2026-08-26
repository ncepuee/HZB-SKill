# QA contract

## Modes

### Economy

- package, bounds, text and full-slide-picture audit;
- one global preview and comparison when a reference exists;
- at most one repair pass.

### Standard

- economy checks;
- skeleton and critical-region inspection;
- font substitution and overflow review;
- editability summary and picture declaration;
- at most two repair passes.

### Strict

- standard checks;
- selective OCR only for ambiguous regions;
- per-region metrics and failure crops;
- containment, semantic and negative-constraint coverage;
- PowerPoint-open/readback validation;
- at most three repair passes.

## Hard gates

Fail on unresolved missing/duplicated text, text-bearing full-slide pictures, undeclared large pictures, overflow/wrap/tofu/mojibake, missing media, package corruption, unexplained out-of-bounds shapes, stretched geometry, wrong table/chart/flow semantics, unchecked critical regions, or an uninspected reference render.

## Structural metrics

Record object counts, native text characters, picture count and maximum coverage, tables/charts, out-of-bounds items, empty explicit text boxes and missing media.

Do not warn merely because an auto-shape has an empty text frame. Only explicit text boxes and text placeholders should be checked for empty content.

## Visual metrics

Compute RGB MAE, blurred-layout MAE, critical-region MAE, a 50/50 overlay and amplified diff. Whole-image MAE can be dominated by flat backgrounds; it cannot override missing text, wrong arrows, incorrect data or failed critical regions.

## Repair evidence

Record issue ID, component ID, failure type, before evidence, changed property, after evidence, attempt count and final status. Never hard-code a check as passed before executing it.

