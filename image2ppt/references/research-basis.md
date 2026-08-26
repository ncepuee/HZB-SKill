# Research basis and adopted decisions

This skill combines independently useful ideas from open-source image-to-editable-PPT workflows. It does not copy their runtime code or require hosted services.

- BrainChen/image2ppt — https://github.com/BrainChen/image2ppt — artifact staging, layout/AST separation, crops and non-overwriting outputs.
- Kevinyyy1/image-to-editable-pptx-v2 — https://github.com/Kevinyyy1/image-to-editable-pptx-v2 — quality modes, compact scenes, repair limits, clean-plate and region QA.
- w1163222589-coder/slide-image-to-editable-pptx — https://github.com/w1163222589-coder/slide-image-to-editable-pptx — three-layer decomposition, pixel inventory, completeness review and textless assets.
- Lancelot-Xie/img2pptx — https://github.com/Lancelot-Xie/img2pptx — semantic hierarchy, containment, constraint coverage, PowerPoint-friendly SVG and component metrics.
- JadeLiu-tech/px-image2pptx — https://github.com/JadeLiu-tech/px-image2pptx — selective OCR, text-mask clipping, local inpainting and explicit failure boundaries.

A local dense-information-graphic reconstruction additionally showed that native editability alone does not guarantee fidelity. Pixel-coordinate geometry, PowerPoint-native icons, PowerPoint-first rendering and both RGB and blurred-layout comparisons produced the strongest result. This evidence motivated the skeleton gate, PowerPoint render requirement and dual-metric QA.

