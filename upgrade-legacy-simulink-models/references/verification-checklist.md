# Verification checklist

## Source-release baseline

- Confirm the exact MATLAB release with `version('-release')`.
- Verify model metadata with `Simulink.MDLInfo`.
- Confirm critical legacy blocks retain expected `MaskType`, `ReferenceBlock`, and resolved link status.
- Run model update and a short simulation in a fresh source-release MATLAB process.
- Preserve the original release backup separately from all migrated files.

## Target-release structure

- Unresolved library links: zero.
- Remaining SPS references for a native migration: zero.
- Removed-runtime callback references: zero.
- Solver Configuration blocks: present and physically connected.
- Physical sensor/source phase order, polarity, and units: reviewed.
- PS-Simulink signal widths and vector orientation: explicit.

## Runtime

- Configure release-specific CacheFolder and CodeGenFolder before update.
- Run model update.
- Run a short simulation such as 10–20 ms.
- Run the intended full duration.
- Record warnings separately from fatal errors; do not hide new warnings before understanding them.

## Behavioral equivalence

Compare source and target runs using the same operating point and excitation:

- steady-state RMS/magnitude, phase, frequency, P, and Q;
- startup overshoot, settling time, and controller saturation;
- representative time-domain transients;
- impedance/frequency sweeps, including phase convention and injection scaling;
- tolerances justified by solver and technology changes.

## Final filename gate

After promoting a working copy:

1. reload the exact requested filename;
2. repeat structural checks;
3. repeat update and short simulation;
4. verify the source file hash or protected backup still exists;
5. report MATLAB release, stop time, warnings, and any intentional parameter floors.
