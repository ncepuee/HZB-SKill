---
name: upgrade-legacy-simulink-models
description: Upgrade legacy MATLAB/Simulink .slx or .mdl models to a newer installed MATLAB release, including broken library links, removed toolboxes, SPS/SimPowerSystems to native Simscape Electrical migration, callback cleanup, Solver Configuration repair, signal-interface preservation, release-variant saving, and compile/simulation verification. Use when an old model opens with unresolved links, missing powergui/powericon/sps_rtmsupport, newer-release incompatibilities, or when a verified upgrade must preserve behavior without overwriting the source.
---

# Upgrade Legacy Simulink Models

## Operating contract

Treat migration as five independent layers: path resolution, block conversion, physical-network solver setup, signal/parameter compatibility, and behavioral verification. Never call an upgrade successful because the file opens or because unresolved links reach zero.

Preserve the source before loading it in a newer release. Do not overwrite the requested final filename until a working copy passes the required validation gates.

Keep source- and target-release files independent. Open and save the legacy baseline only with its source MATLAB release after recovery. A backward-exported native model is not a replacement for the original SPS model.

## 1. Classify the requested outcome

Choose one route before editing:

- **Legacy-runtime route**: preserve the old topology and solver semantics. Use the source-compatible MATLAB release or an explicitly installed compatible third-party runtime. Cross-release paths may diagnose missing assets but are not a supported final runtime.
- **Native-migration route**: replace removed technology with current Simulink/Simscape blocks. Accept that solver, initialization, physical ports, units, and signal shapes require revalidation.

Read [migration-decision-tree.md](references/migration-decision-tree.md) when the correct route is unclear.

## 2. Inspect the environment and model before editing

Run:

```matlab
addpath(fullfile(skillDir, 'scripts'));
filegen = configure_release_filegen(fileparts(modelFile));
env = inspect_upgrade_environment(modelFile);
risk = scan_model_migration_risks(modelFile);
```

Configure release-specific cache and code-generation folders before model update or simulation. MATLAB releases must not share `slprj`, accelerator, or code-generation artifacts. Use `PersistInModel=true` only when the user explicitly wants direct-run isolation embedded in the model.

Record:

- `version('-release')` and `matlabroot`;
- installed sibling MATLAB releases;
- availability of `powergui`, `sps_lib`, `spsConversionAssistant`, and `spsConversionFindBlocks`;
- unresolved links and legacy library references;
- model/block callbacks that call `save_system`, `cd`, `powericon`, or `sps_rtmsupport`;
- SPS block count and existing Solver Configuration blocks.

Do not infer the active release from the `matlab` command or a filename suffix.

## 3. Create a protected migration input

Run `prepare_migration_copy.m` in a release that can load the source model. Pass an explicit `InitMarker` when the model callback begins with auto-save or path-changing code followed by a parameter section.

```matlab
prep = prepare_migration_copy(sourceFile, migrationFile, ...
    'InitMarker', '%% Simulation parameters', ...
    'LegacyCallbackTokens', {'sps_rtmsupport','powericon'}, ...
    'ClearLegacyCallbacks', false);
```

Keep parameter initialization. Remove only the unsafe prefix. Audit removed-runtime callbacks first; clear them only after the associated legacy blocks have been converted. An empty `InitFcn` often makes a model uncompileable because block parameters disappear.

Never use a file as the source baseline after a newer release has executed an `InitFcn` containing `save_system`.

## 4. Select and execute the migration route

### Legacy-runtime route

Use `setup_legacy_library_paths.m` only to locate exact missing assets and add their parent directories for the current session. Add current-release locations first and older fallbacks last. Never call `savepath` automatically.

After resolving links, require model update and a short simulation in the intended runtime. If old P-code or solver initialization fails in the newer release, stop using mixed-release paths and choose the native route or a supported legacy runtime.

### Native-migration route

When `spsConversionAssistant` exists:

```matlab
load_system(migrationFile);
spsConversionAssistant(bdroot, outputFolder);
```

Allow the assistant to create a new model. Re-scan the result with `spsConversionFindBlocks`. If conversion stalls after writing `*.slx.err`, treat that file as a possible SLX checkpoint: copy it to a new `.slx` filename, load it, and audit remaining SPS blocks before discarding progress.

Read [sps-to-native-playbook.md](references/sps-to-native-playbook.md) before repairing unsupported SPS blocks.

## 5. Repair conversion gaps incrementally

For every remaining legacy block:

1. Preserve its external port count, direction, units, sign convention, phase order, and vector shape.
2. Replace the smallest self-contained subsystem possible.
3. Remove every callback whose code references the removed runtime, including load/save/start/stop/name/delete callbacks.
4. Re-scan legacy references before moving to the next subsystem.

Compare critical block library identity against the source-release model. A block can have `LinkStatus='none'` and still retain connected-looking ports after backward export while no longer being the original SPS block. Check `MaskType`, `ReferenceBlock`, port families, and phase connectivity for sources, measurements, breakers, transformers, and `powergui`.

For Simscape physical networks:

- connect exactly one Solver Configuration block to each topologically distinct network;
- do not count an unconnected Solver Configuration as valid;
- check converted R/L/C parameters for strict positivity constraints;
- check PS-Simulink Converter vector format (`inherit` can change a width-3 vector into a `1x3` matrix);
- preserve SI versus per-unit measurement semantics explicitly.

## 6. Validate in gates

Run:

```matlab
result = validate_migrated_model(candidateFile, ...
    'ExpectedMode', 'native', ...
    'UpdateModel', true, ...
    'SimulationStopTime', 0.02);
assert(result.passed, result.summary);
```

Use these gates in order:

1. source backup exists;
2. model loads in the target release;
3. unresolved links equal zero;
4. native route has zero SPS references;
5. risky removed-runtime callbacks equal zero;
6. each physical network has a connected Solver Configuration;
7. model update succeeds;
8. short simulation succeeds;
9. steady-state and representative outputs match the baseline;
10. full-duration simulation and domain-specific sweeps pass.

Run source acceptance in the source MATLAB release and target acceptance in the target MATLAB release. Start each acceptance in a fresh MATLAB process without manually injected compatibility paths.

Read [verification-checklist.md](references/verification-checklist.md) for release acceptance and behavioral comparison.

## 7. Save release variants safely

Maintain independent baselines:

- source-release model for historical behavior;
- target-release native model for future maintenance.

Do not export a native target-release model backward and label it behaviorally equivalent to the legacy source. `ExportToVersion` proves file compatibility, not physical or numerical equivalence.

Back up the existing target filename, save the validated working copy to the requested name, then reload that exact file and repeat the structural, update, and short-simulation gates.

## Bundled resources

- `scripts/inspect_upgrade_environment.m`: detect releases, tool capabilities, and model metadata.
- `scripts/configure_release_filegen.m`: isolate cache and code-generation artifacts by MATLAB release, optionally embedding the setup in model initialization.
- `scripts/setup_legacy_library_paths.m`: add exact compatibility asset directories for diagnosis without global path mutation.
- `scripts/scan_model_migration_risks.m`: audit links, SPS references, risky callbacks, and solver blocks.
- `scripts/prepare_migration_copy.m`: create a protected copy while preserving parameter initialization.
- `scripts/validate_migrated_model.m`: run structural, update, and short-simulation validation.
- `references/migration-decision-tree.md`: choose legacy-runtime versus native migration.
- `references/sps-to-native-playbook.md`: SPS-specific conversion gaps and repairs.
- `references/verification-checklist.md`: acceptance gates and behavioral comparison.
