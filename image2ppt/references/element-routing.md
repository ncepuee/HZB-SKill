# Element routing

Use this guide when representation is ambiguous. Route by semantic editing value and visual risk, not by a desire to maximize native-object count.

## Decision order

1. If it is readable semantic text, make it native text.
2. If it is simple geometry with stable PowerPoint support, make it native structure.
3. If it is complex but vector-reconstructable and meaningful as a module, use SVG with a semantic group hierarchy.
4. If it is visually complex and internal editing has low value, use a tightly bounded picture.
5. Use a full-slide clean plate only when it is textless, reviewed, and necessary for an integrated complex background.

## Native structure

Use native shapes for solid or lightly styled rectangles, rounded cards, circles, rules, arrows, timelines, progress bars, table borders, and icons that need no more than a few geometric primitives.

Do not approximate a complex illustration with dozens of crude primitives. That increases object count while reducing both fidelity and useful editability.

## SVG module

Use SVG when a diagram is naturally vectorial and its semantic hierarchy matters. Prefer PowerPoint-friendly elements: `text`, `rect`, `line`, `circle`, `ellipse`, `polygon`, `polyline`, and `path`. Avoid `foreignObject`, external resources, fragile filters, and CSS dependencies.

Treat these as separate claims: the SVG is embedded intact; PowerPoint can convert or ungroup it; the complete hierarchy survives conversion. Only the last claim requires actual conversion and inspection in the target PowerPoint version.

## Bounded picture

Use a picture for photos, textured illustration, handwriting, dense scientific figures, maps, or chart visuals whose hidden data cannot be recovered. Crop tightly and declare the source, whether it contains readable text, why native reconstruction is unreliable, and which surrounding labels remain native.

## OCR and inpainting

OCR plus text removal is useful when text sits on photography or texture. It is a fallback, not the default for clean dashboards or information graphics.

Risks include thick-font remnants, merged dense labels, weak inverted-text masks, invented background pixels, and damage to faces or structured objects. Never overlay native text on top of the same readable raster text.

## Editing granularity

Prefer semantic units such as “reviewer card”, “process node”, “legend”, or “icon + label”, rather than arbitrary pixel fragments. A useful unit remains meaningful when moved or edited independently.

