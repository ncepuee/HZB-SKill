# Text and font policy

Use the exact font when installed and permitted. Otherwise choose a fallback by metrics and visual role, then disclose substitution.

Suggested CJK fallbacks include Microsoft YaHei, DengXian, Microsoft JhengHei, Yu Gothic, Meiryo, Malgun Gothic and Noto Sans CJK. Use Aptos or Arial for generic Latin UI text and Cambria Math when PowerPoint formula support is needed.

## CJK considerations

- Fullwidth glyphs and punctuation differ from Latin metrics.
- Mixed Chinese/English text can invoke different fallback fonts within one line.
- Pixel-height formulas provide only an initial font estimate.
- Manual line breaks should reproduce deliberate source breaks, not compensate for incorrect width.

## Text-box rules

- Set font, size, color, bold, alignment, vertical alignment and margins explicitly.
- Avoid auto-fit for titles and tightly aligned labels.
- Keep one logical paragraph per natural paragraph.
- Let normal body text wrap naturally.
- Use `word_wrap: false` only after verifying fixed one-line labels.
- Treat a stranded final character as a width/font/margin failure, not content to delete.

Validate PowerPoint-rendered output for unexpected wraps, clipping, tofu, mojibake, mixed-script baseline shifts, substitutions and formula displacement. For a wrapped title adjust width, margin, size and font family before inserting manual breaks.

