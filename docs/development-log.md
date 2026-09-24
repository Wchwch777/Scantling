# Development and verification log

This log records material decisions and the commands actually used to verify them. It is intentionally kept in the repository so that the development process can be reviewed without relying on an unreproducible narrative.

## 2026-09-22 to 2026-09-24 — initial vertical slices

The original `main` history was built in separate domain slices:

1. `core`: stock, demand, cutting-piece, pattern, and summary entities;
2. `optimizer`: FFD/BFD one-dimensional cutting-stock heuristics;
3. `pricing`: the parameterized cost and remnant-recovery model;
4. `scripts`: local CI and optional Wasm build entry points;
5. `docs`: the mathematical formulation and architecture retrospective;
6. `cmd` and `web`: the CLI visualizer and browser workbench.

That sequence explains the current package boundaries. It does not imply that the heuristic is globally optimal or that the example data is a field measurement.

## 2026-09-24 — validation and claim-alignment refactor

The refactor focused on making the implementation and its claims agree:

- input validation now runs at the checked optimizer entry points;
- invalid demand lengths and negative reusable-length thresholds are reported;
- compatibility wrappers preserve the original summary-returning APIs while failing fast on invalid input;
- the repository has a real GitHub Actions workflow;
- README, CLI, Web labels, and pricing terminology now describe parameterized model output instead of unsupported audit or savings claims;
- the browser documentation states that the current page uses a JavaScript reference engine.

Verification performed before recording this entry:

```text
moon fmt --check                         PASS
moon check --target wasm                 PASS
moon test --target wasm                  13 passed, 0 failed
moon run cmd --target wasm               PASS
.\scripts\ci.ps1                        PASS
```

The shell script was not run on the Windows development host because Bash is unavailable there. The GitHub Actions workflow runs the shell equivalent on Ubuntu.

## Verification policy for future changes

Each behavior change should follow this order:

1. write or update the smallest focused test;
2. run the focused test and inspect the failure or result;
3. implement the change;
4. run formatting, type checking, the full test suite, and the CLI when affected;
5. update this log only with commands that actually ran.
