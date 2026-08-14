# SPS-to-native Simscape playbook

## Conversion order

1. Protect the source file and remove unsafe auto-save/path-changing initialization prefixes from the migration copy.
2. Run the official SPS conversion assistant when available.
3. Reopen any generated checkpoint, including a valid SLX payload written with an `.err` suffix.
4. Scan for remaining SPS references and removed-runtime callbacks.
5. Repair one self-contained subsystem at a time.

## Common failure patterns

### `powergui`, `powericon`, and SPS internal libraries

Native Simscape does not use legacy SPS `powergui` runtime behavior. Replace the electrical network with native blocks and connect a Solver Configuration block. Do not keep callbacks that call removed SPS runtime helpers.

### Three-phase V-I measurements

If the converter leaves unsupported VI Bus internals, replace the measurement subsystem with native three-phase voltage/current sensors and PS-Simulink Converters. Preserve:

- current direction and voltage polarity;
- A-B-C phase order;
- output width and orientation;
- SI versus per-unit scaling.

### Controlled three-phase sources

Backward export can leave a subsystem named like the original source while stripping `MaskType` and `ReferenceBlock`. Compare the source model's library identity and physical port families. Connected-looking lines alone are insufficient.

### Solver Configuration

Require one connected Solver Configuration for every topologically distinct native physical network. A block that exists but has no physical connection does not satisfy this requirement.

### Converted R/L/C parameters

Native blocks may require strictly positive resistance or inductance where an SPS model accepted zero. Use the smallest numerically insignificant positive floor, document it, and verify frequency-domain impact.

### PS-Simulink signal shape

Set converter vector format explicitly. A width-three SPS vector can become a `1x3` matrix under inherited formatting and break downstream transforms or controllers.

## Acceptance

Require zero unresolved links, zero remaining SPS references for the native route, zero removed-runtime callbacks, connected solver configuration, model update, short simulation, and behavioral comparison against the source-release baseline.
