# Migration decision tree

## Choose the legacy-runtime route when

- the source MATLAB release is installed and remains an accepted runtime;
- exact Specialized Power Systems behavior, `powergui` modes, or historical sweep results must be preserved;
- conversion changes device semantics or unsupported blocks cannot be reproduced confidently.

Keep the original SPS library identities. Resolve libraries only from the matching release. Validate update, short simulation, steady state, and sweep outputs in that release.

## Choose the native-migration route when

- the target release removed the required SPS runtime or blocks;
- old P-code, `powericon`, `sps_rtmsupport`, or internal libraries cannot execute;
- the model must be maintainable using current Simscape Electrical technology.

Use the official conversion assistant first, then repair unsupported blocks manually. Treat the converted model as a new implementation requiring numerical equivalence checks.

## Do not confuse these outcomes

- Adding an old toolbox folder can resolve a library path while leaving incompatible P-code or solver internals.
- Exporting a native model backward can make a file load in an older release while destroying SPS block identity.
- Zero unresolved links does not prove matching ports, units, phase order, solver configuration, or behavior.

## Required dual-version rule

Maintain two independent files when both releases matter:

1. a source-release baseline saved and tested only in the source release;
2. a target-release migrated model saved and tested only in the target release.

Never use the target model as the recovery source for the legacy baseline.
