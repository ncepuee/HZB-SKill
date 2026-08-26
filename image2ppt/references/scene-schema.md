# Scene schema v2.0

Use a scene file for deterministic rebuilding, repeated styles or targeted repairs. `scripts/build_from_spec.py` also accepts the legacy one-slide schema.

```json
{
  "version": "2.0",
  "units": "px",
  "canvas": {
    "width": 1920,
    "height": 1080,
    "slide_width_in": 13.333333,
    "slide_height_in": 7.5
  },
  "defaults": {"font": "Microsoft YaHei", "color": "#0E2240", "margin": 0.02},
  "styles": {
    "title": {"size": 28, "bold": true, "align": "center"},
    "card": {"fill": "#FFFFFF", "line": "#B8C3D1", "line_width": 1.0}
  },
  "slides": [
    {
      "id": "s01",
      "background": "#FFFFFF",
      "expected_text": ["Editable title"],
      "critical_regions": [{"id": "title", "x": 200, "y": 30, "w": 1520, "h": 120}],
      "elements": [
        {
          "id": "s01_title",
          "type": "text",
          "style_ref": "title",
          "x": 200,
          "y": 30,
          "w": 1520,
          "h": 120,
          "text": "Editable title",
          "z": 30,
          "representation": "native-text"
        }
      ]
    }
  ]
}
```

Properties resolve as `defaults → style_ref → element fields`. Supported deterministic types are `text`, `box`, `line`, `circle`, `table` and `picture`.

Recommended metadata includes `id`, `label`, `parent`, `level`, geometry, `style_ref`, `z`, `representation`, content/data/asset, `visual_invariants`, `negative_constraints`, `audit_mapping`, `contains_readable_text` and `complex_reason`.

Validation requires unique IDs, valid styles/parents, acyclic hierarchy, finite positive geometry, native representation of expected text, explicit declaration of large pictures, and audit mappings for hard invariants.

