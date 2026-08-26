# image2ppt

`image2ppt` reconstructs screenshots, slide images, diagrams, dashboards and PDF pages as high-fidelity editable PowerPoint files.

The upgraded workflow adds:

- native text/structure, SVG module and bounded-picture routing;
- economy, standard and strict QA modes;
- scene v2 with reusable styles and critical regions;
- PowerPoint-first rendering;
- global and region-level visual comparison;
- package, media, bounds, text and editability audits;
- deterministic repair limits and compact QA summaries.

Quick smoke test:

```powershell
python tests/smoke_test.py
```

Full QA after building a PPTX:

```powershell
python scripts/qa_pipeline.py output.pptx `
  --reference reference.png `
  --scene scene.json `
  --out-dir run/qa `
  --mode strict
```

See `SKILL.md` for the operating contract and progressive reference routing.

