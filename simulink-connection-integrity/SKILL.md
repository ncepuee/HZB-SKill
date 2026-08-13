---
name: simulink-connection-integrity
description: Baseline and verify Simulink, Stateflow, Specialized Power Systems, and masked subsystem wiring before and after model edits. Use whenever an .slx/.mdl model is modified, blocks are copied or replaced, Mask parameters can rebuild ports, callbacks are changed, library links are changed, or the user asks to detect disconnected lines, preserve untouched modules, or prove connection integrity before saving.
---

# Simulink Connection Integrity

Treat connection preservation as a blocking gate. Compilation alone is not proof that wiring is intact.

## Select A Profile

- `fast`: Default for parameter, callback, Mask, annotation, or UserData edits. Checks every line and connection-related block state. Skips compilation, full input-port enumeration, dangling-line audit, and external-PID audit.
- `standard`: Use when blocks, ports, controller modes, Goto/From tags, Variant branches, or PID parameter wiring may change. Adds connected-input preservation, dangling-line warnings, and external-PID checks.
- `release`: Use before a release, Git milestone, formal sweep, or when the user asks for the strongest validation. Adds model update/compile and requires it to pass.

Do not use `release` for every small edit. On large models, pair a pre-save in-memory check with a sub-second saved-package check.

## Mandatory Workflow

1. Identify the exact model and the smallest intended modified scopes.
2. Resolve a dirty model before baseline creation. Ask whether to save, discard, or explicitly baseline the unsaved state.
3. Create a baseline and disk backup before editing.
4. Make the smallest scoped edit. Never rebuild an existing subsystem merely to synchronize it unless explicitly requested.
5. Run `check` before saving. Require `Passed=true`.
6. Save only after the pre-save check passes.
7. Run `packagecheck` against the saved `.slx`. Use `standard` or `release` again after reload only for high-risk or milestone changes.
8. Preserve the baseline MAT and model backup until the user accepts the result.

## MATLAB Usage

```matlab
skillDir = 'C:\Users\hzb\.agents\skills\HZB-Skill\simulink-connection-integrity';
addpath(fullfile(skillDir, 'scripts'));
```

### Fast Daily Edit

```matlab
baselineFile = fullfile(tempdir, 'model_before_edit.mat');

opts = struct();
opts.Profile = "fast";
opts.ModifiedScopes = {'Controller/VoltageLoop'};

simulink_connection_guard("baseline", modelFile, baselineFile, opts);

% Edit the loaded model here, but do not save yet.

preSave = simulink_connection_guard("check", modelName, baselineFile, opts);
assert(preSave.Passed);
save_system(modelName);

postSave = simulink_connection_guard( ...
    "packagecheck", modelFile, baselineFile, opts);
assert(postSave.Passed);
```

`packagecheck` reads the saved SLX ZIP/XML directly. It compares every `system_*.xml` line structure and block count while ignoring thumbnails, editor windows, and metadata timestamps. It never loads or saves the model.

### Protect Callbacks And Mask Parameters

Use contracts when an editor, Mask, callback, or automated script is being changed but its business initialization values must remain untouched:

```matlab
opts.PreserveModelCallbacks = true;
opts.ModelCallbackNames = { ...
    'PreLoadFcn','PostLoadFcn','InitFcn','StartFcn'};
opts.ProtectedMaskParameters = { ...
    'Model Initialization_new', ...
    {'InitFcnX','prel','posl','inif','strf'} ...
};
```

Contract definitions stored in the baseline are inherited automatically by later `check` calls.

### Standard Or Release Validation

```matlab
opts.Profile = "standard";  % Structural and port-level validation.
report = simulink_connection_guard("check", modelName, baselineFile, opts);

opts.Profile = "release";   % Also update/compile and require success.
report = simulink_connection_guard("audit", modelName, '', opts);
```

Existing calls without `Profile` remain valid and use `standard`.

## Intentional Wiring Changes

Declare only the intended model-relative scopes:

```matlab
opts.ModifiedScopes = {'GFM Controller/OVI'};
```

Inside a modified scope, changed lines are tolerated only when connected-port preservation still passes in `standard` or `release`. Use these exceptions only for explicit user-approved changes:

```matlab
opts.AllowedRemovedLines = {'exact identifying text'};
opts.AllowedAddedLines = {'exact identifying text'};
opts.AllowedDisconnectedPorts = {'Block|Inport|3'};
```

`packagecheck` is intentionally strict and does not map saved XML back to `ModifiedScopes`. For an intentional structural edit, use `check` as the authoritative scoped result and set package allowances only after reviewing the in-memory report:

```matlab
opts.PackageAllowLineChanges = true;
opts.PackageAllowBlockCountChanges = true;
```

## Required Interpretation

- `Passed=true` is required before save.
- `UnexpectedRemovedLines` or `UnexpectedAddedLines` means an undeclared topology change.
- `NewlyDisconnectedPorts` means a formerly connected input or physical port lost its source.
- `ExternalPIDIssues` identifies dynamic PID external parameter inputs without sources.
- `ChangedBlockStates` covers block additions/removals, comments, port counts, Goto/From tags, tag visibility, and external controller/reset modes.
- `ContractViolations` identifies protected callbacks or Mask parameters that changed.
- `PackageLineChanges`, `PackageBlockCountChanges`, and `PackageSystemChanges` identify saved SLX structural changes.
- `Warnings` may contain inactive Variant or commented-branch line-tree artifacts. Baseline losses and disconnected-port failures are the deterministic regression evidence.
- `DurationSeconds` is included in every report. Investigate unexpectedly slow `fast` checks rather than silently switching off protection.

## Non-Negotiable Guardrails

- Never save a model merely to make parallel workers see it before the guard passes.
- Never silently reconnect, revert, or overwrite the user's model after a failed check.
- Never infer integrity from simulation success, package equality, or compilation alone; combine evidence according to risk.
- Never delete the baseline or backup before the user accepts the edit.
- Never declare the whole model as `ModifiedScopes` to make violations disappear.
