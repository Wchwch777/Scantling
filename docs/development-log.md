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

## 2026-09-24 — benchmark regression tests

Before changing the README count, two focused regression tests were added:

- the optimizer test fixes the CLI example's 12 stock bars, 95,800 mm demand, 72 mm kerf, 11,255 mm reusable remnant, and 873 mm scrap values;
- the pricing test fixes the corresponding net material cost, comprehensive unit price, and cost difference against the parameterized baseline.

The focused verification after implementation was:

```text
moon fmt --check                         PASS
moon check --target wasm                 PASS
moon test --target wasm                  15 passed, 0 failed
```

This change was committed as `e5be1f0` (`test: lock down reproducible benchmark outputs`).

The repository-level PowerShell CI and optional Wasm build were then rerun:

```text
.\scripts\ci.ps1                        PASS
.\scripts\build_wasm.ps1                PASS
```

The CLI continued to produce the locked benchmark values, including 12 bars,
0.875% material loss, and a `-33.19268980046263` cost difference against the
parameterized baseline.

## 2026-09-25 — public quickstart demo

A separate `examples/quickstart` executable was added instead of expanding the
existing verbose CLI. It exercises the public package boundaries in the same
order a new user would use them: validated input, deterministic FFD/BFD
optimization, and parameterized pricing. Its output is intentionally compact
and explicitly says that the heuristic is not a proof of global optimality.

The demo was first run independently, then included in the repository CI
script. The actual verification sequence was:

```text
moon run examples/quickstart          PASS
moon fmt --check                      PASS
moon check                            PASS
moon test                             15 passed, 0 failed
.\scripts\ci.ps1                     PASS
```

The quickstart uses a small five-piece input and currently reports two stock
bars, 0.05% waste, 3,491 mm reusable remnant, and a parameterized net material
cost of `222.741759625` yuan. These numbers are demonstration outputs, not a
claim about a real project or a globally optimal plan.

## 2026-09-25 — initial review remediation, AI-assisted run

At the start of this run, `main` and `origin/main` both pointed to `c4485f0`; `git status --short --branch` showed a clean working tree. `git fetch origin --prune` succeeded and `git rev-list --left-right --count HEAD...origin/main` returned `0 0`. No history was rewritten. This entry records an AI-assisted review and edits; it does not assert that a human has reviewed or approved this run.

Issue and evidence baseline:

1. **Public claims:** README and specifications asserted high precision/performance, GB 50500 compliance, unsupported field loss percentages, and a theoretical approximation bound. The retrospective asserted millisecond feedback and zero floating-point overflow. Those claims lacked an independent benchmark, compliance review, or numerical proof. They were removed or narrowed; the implementation uses `Double`.
2. **Heuristic boundary:** `optimizer/cutting_stock.mbt` runs FFD/BFD and selects by bar count, then scrap length. A small exact example in the tests has a feasible two-bar packing while both heuristics use three; the algorithm makes no global-optimum claim. The BFD `1.0e12` sentinel caused a valid synthetic large-scale case to use two bars instead of one; selecting the first feasible bar without a fixed sentinel corrected it. Tests also check piece count and length conservation with kerf.
3. **Pricing scope:** `pricing/quota.mbt` applies configurable prices, rates, loss assumptions, and remnant credits. It has no local quota database, audit evidence, or actual inventory/transaction records. README, specifications, CLI labels, Web labels, and code comments now describe assumptions and model estimates. A hand-worked synthetic cost test is independent of the optimizer but does not validate local rules.
4. **Web/Wasm:** `web/app.js` contains a standalone JavaScript calculation; `scripts/build_wasm.*` only build MoonBit Wasm. The page badge and architecture diagram now state that split. No cross-language parity test or browser Wasm integration is claimed.
5. **Toolchain:** `.github/workflows/ci.yml` installs `latest`, so CI can drift. The upstream installer inspected during this run accepts a version argument. HEAD requests for the local `0.1.20260827` Linux binary and core returned HTTP 403 in this environment; availability of that pinned pair was not established. CI remains on `latest` pending a verified version and Linux run.
6. **Benchmark tests:** the existing CLI-number tests lock current deterministic outputs only. README now says they do not independently establish domain correctness, optimality, or field results.
7. **Provenance:** `AI_ASSISTED.md` and earlier log entries were kept. This run did not fabricate authorship, dates, results, or a human review. The repository owner should review the domain assumptions before relying on the model.

Targeted verification during the edit:

```text
moon test optimizer -f 'best fit considers a valid bar above one trillion mm'  FAIL before fix: 2 != 1
moon test optimizer -f 'best fit considers a valid bar above one trillion mm'  PASS after fix: 1/1
moon test optimizer -f 'heuristic winner preserves pieces and physical length' PASS: 1/1
moon test optimizer -f 'FFD and BFD are not globally optimal on a small exact instance' PASS: 1/1
moon test pricing -f 'independent hand-worked cost example checks formula assumptions' PASS: 1/1
moon fmt --check  FAIL on formatting of newly added tests
moon fmt          PASS
```

The first full pass then returned `moon fmt --check` PASS, `moon check` PASS, `moon test` 21/21 PASS, `moon run cmd` PASS, `moon run examples/quickstart` PASS, `moon check --target wasm` PASS, and `moon test --target wasm` 21/21 PASS. That CLI run revealed the remaining GB 50500 compliance claim in its output, which was corrected afterward. Other tests appeared in this shared working tree during the run; they were retained and verified, without assigning human authorship to them.

Final local verification after CLI and quickstart label correction:

```text
moon fmt                                  PASS
moon fmt --check                          PASS
moon check                                PASS
moon test                                 21 passed, 0 failed
moon run cmd                              PASS; output labels identify model assumptions
moon run examples/quickstart              PASS
moon check --target wasm                  PASS
moon test --target wasm                   21 passed, 0 failed
git diff --check                          PASS (Git printed CRLF conversion warnings)
```

Push preflight: `gh api user` reported authenticated login `2515050242`; the configured Git author was `Wchwch <1341376491@qq.com>`, which this AI run must not impersonate. The target remote was `https://github.com/Wchwch777/Scantling.git`, its default branch was `main`, and `git ls-remote --heads origin main` still returned `c4485f0`. The GitHub repository permissions response reported `push: false` for the authenticated account. Commit `e2fad90` used the explicit author `Codex AI-assisted <codex-ai-assisted@localhost>` and did not rewrite history. `git push origin main` was attempted and failed with HTTP 403: `Permission to Wchwch777/Scantling.git denied to 2515050242`. This log update records that outcome as a second commit rather than changing the first commit.

## 2026-09-25 10:29 — scheduled second-stage recheck

This scheduled run started from a clean worktree at `04cba42`, and `git fetch origin --prune` confirmed that `main` and `origin/main` were identical. Existing remediation commits were not repeated and no history was rewritten.

The local toolchain was recorded as `moon 0.1.20260827`, `moonc v0.10.11+6ff76a5f9`, and `moonrun 0.1.20260827`. Requests for the matching Linux binary and core archives returned HTTP 403 from `cli.moonbitlang.com`, so the workflow remains on `latest`; pinning an unverified Linux pair would reduce rather than improve reproducibility. This limitation remains explicit in the CI comment and this log.

Verification actually run in this scheduled pass:

```text
.\scripts\ci.ps1                     PASS
  moon fmt --check                    PASS
  moon check                          PASS
  moon test                           21 passed, 0 failed
  moon run cmd                        PASS
  moon run examples/quickstart        PASS
moon test --target wasm               21 passed, 0 failed
.\scripts\build_wasm.ps1             PASS
git diff --check                      PASS
```

The CLI output continues to label the cost result as a parameterized model and the quickstart continues to call FFD/BFD a heuristic. No new code change was justified by this recheck; the only change from this scheduled run is this factual log entry.

## Verification policy for future changes

Each behavior change should follow this order:

1. write or update the smallest focused test;
2. run the focused test and inspect the failure or result;
3. implement the change;
4. run formatting, type checking, the full test suite, and the CLI when affected;
5. update this log only with commands that actually ran.

## 2026-09-25 10:34 — second-stage boundary and reproducibility pass

This AI-assisted run began with a clean `main` at `0cc053e`. `git ls-remote --heads origin main` returned the same commit and `git rev-list --left-right --count HEAD...origin/main` returned `0 0`. The previous commits `e2fad90`, `04cba42`, and `0cc053e` and their stated verification history were inspected; no earlier change or author attribution was rewritten. The Web page remains a standalone JavaScript reference implementation and the Wasm scripts still only build MoonBit output. Neither the cost model nor the CLI regression numbers are presented as local quota, audit, site measurement, or independent proof of business correctness.

The first new test showed that `validate_inputs` let a NaN stock length through: `moon test core -f 'validation rejects non-finite length and configuration values'` failed before the fix (`0 != 1`). `core/types.mbt` now returns typed errors for NaN or infinity in stock length, demand length, kerf width, and reusable threshold. That focused test then passed. This is an input boundary check; it does not prove that arbitrary finite `Double` aggregates cannot overflow or lose precision.

Two further independent tests passed before any implementation change was needed: the FFD/BFD kerf test checks exact fit versus a one-millimetre excess, and a synthetic hand-calculated cost test checks reusable credit, profit, tax, and baseline without using optimizer output. The earlier small counterexample proving the heuristics need not find the global optimum and the CLI-number regression tests remain in place. The README and cost-code comments were narrowed to reflect model assumptions and current behavior.

For the toolchain, GitHub Actions run `36086484531` on `ubuntu-22.04` completed successfully and reported `moon 0.1.20260920`, `moonc v0.10.14+7d59c7ec9`, and `moonrun 0.1.20260920`. The official installer accepts a version argument, so CI now requests `0.1.20260920` instead of `latest`. Direct GET requests from this Windows environment to the versioned Linux binary and core archive still returned HTTP 403; a new pinned GitHub run must establish that the versioned URLs work on the runner. The installer script URL itself is still mutable.

Local verification after the edits:

```text
moon fmt                                             PASS
moon test core -f 'validation rejects non-finite length and configuration values'  PASS 1/1
moon test optimizer -f 'kerf exact-fit and one-millimetre-over boundary for both heuristics' PASS 1/1
moon test pricing -f 'independent cost example includes reusable credit profit and tax' PASS 1/1
.\scripts\ci.ps1                                    PASS; moon test 24/24, CLI and quickstart passed
moon check --target wasm                             PASS
moon test --target wasm                              PASS 24/24
.\scripts\build_wasm.ps1                            PASS
git diff --check                                     PASS (Git emitted CRLF conversion warnings)
```

Push preflight: `gh api user` returned `Wchwch777`, repository permissions reported `push: true`, the default and intended target branch is `main`, and `git ls-remote --heads origin main` still returned `0cc053e`.

### Pinned Linux archive failure and follow-up

Commit `db69613` was pushed to `origin/main`. GitHub Actions run `36086851330` failed during installation, before the repository tests: the versioned URL `https://cli.moonbitlang.com/binaries/0.1.20260920/moonbit-linux-x86_64.tar.gz` returned HTTP 403. The earlier successful `latest` run only established the installed tool version, not that its versioned archive was published or accessible. This run therefore restores `latest` for CI, records the limitation, and leaves the toolchain pin as unresolved. No test result is inferred from the failed remote run.
