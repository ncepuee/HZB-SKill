---
name: simulink-connection-integrity
description: Baseline and verify Simulink, Stateflow, Specialized Power Systems, and masked subsystem wiring before and after any model edit. Use whenever an .slx/.mdl model is modified, blocks are copied or replaced, Mask parameters can rebuild ports, library links are changed, or the user asks to detect disconnected lines, preserve untouched modules, or prove connection integrity before saving.
---

# Simulink Connection Integrity

Treat connection preservation as a blocking gate for every model edit. A model compiling is not proof that its wiring is intact.

## Mandatory Workflow

1. Identify the exact model and intended modified scopes.
2. Before editing, create a baseline with `scripts/simulink_connection_guard.m`. Do not proceed if the model is dirty unless the user explicitly chooses how to handle unsaved changes.
3. Make the smallest scoped edit. Do not replace or rebuild an existing subsystem merely to synchronize it unless explicitly requested.
4. Before saving, run `check` against the baseline.
5. Treat any unexpected removed/added line outside the declared scopes, newly disconnected formerly-connected port, external PID parameter port without a source, or connection-related block-state change as failure. Inspect raw dangling line-tree warnings separately because inactive Variant and commented branches can expose incomplete internal line objects.
6. Do not save on failure. Report exact block paths and ports. Never silently reconnect, revert, or overwrite the user's model.
7. After a passing check, save only when the task requires it, reload if practical, then run `audit` or `check` once more.

## MATLAB Usage

Add the bundled script folder:

```matlab
skillDir = 'C:\Users\hzb\.agents\skills\HZB-Skill\simulink-connection-integrity';
addpath(fullfile(skillDir, 'scripts'));
```

Create the pre-edit baseline and a disk backup:

```matlab
baselineFile = fullfile(tempdir, 'my_model_connection_baseline.mat');
simulink_connection_guard("baseline", "C:\work\my_model.slx", baselineFile);
```

Check after editing but before saving. Scopes are model-relative paths:

```matlab
opts = struct();
opts.ModifiedScopes = {'Controller/VoltageLoop'};
report = simulink_connection_guard("check", "C:\work\my_model.slx", baselineFile, opts);
```

Run a standalone audit when no baseline exists:

```matlab
report = simulink_connection_guard("audit", "C:\work\my_model.slx");
```

For intentional rewiring, declare the modified scope. Removed lines are accepted inside that scope only when their destination ports remain connected to another source. Use `AllowedDisconnectedPorts` only for a user-approved intentional disconnection.

## Required Interpretation

- `Passed=true` is required before saving.
- `UnexpectedRemovedLines` or `UnexpectedAddedLines` means an undeclared scope changed.
- `NewlyDisconnectedPorts` always fails unless explicitly allowed.
- `ExternalPIDIssues` catches dynamic PID Mask ports such as external `Kp`, `Ki`, and reset/enable inputs.
- `ChangedBlockStates` catches connection-related changes including `Commented`, port count, Goto/From tag, tag visibility, and external PID source mode.
- `Warnings` may include raw line-tree objects from commented or inactive branches; inspect them, but rely on baseline loss and newly-disconnected-port failures for deterministic regression protection.
- If a model requires run-specific workspace variables to compile, initialize them first or use `CompileModel=false` for a connection-only pass. Keep `RequireCompilePass=true` for final project validation.

## Non-Negotiable Guardrails

- Never infer integrity from successful simulation or compilation alone.
- Never save a model merely to make parallel workers see it before the guard passes.
- Never use whole-subsystem replacement as a shortcut for parameter synchronization.
- Always protect untouched modules by declaring only the scopes intended to change.
- Always preserve the baseline MAT and generated `.slx/.mdl` backup until the user accepts the result.
