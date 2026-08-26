# Examples

## 1. Validate structured data

```bash
python examples/validate_reviewer_counts.py
```

## 2. Inspect reference image

```bash
python scripts/inspect_reference.py reference.png --grid 100
```

## 3. Build editable PPT from JSON spec

```bash
python scripts/build_from_spec.py templates/spec_template.json output.pptx
```

## 4. Validate the generated PPT

```bash
python scripts/validate_ppt.py output.pptx
```

## 5. Install the Skill

```bash
python scripts/install_skill.py --target /path/to/skills --force
```
