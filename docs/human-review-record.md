# Human review record

This record separates an AI-assisted technical pre-review from the repository
owner's human approval. It is intended for a release candidate or competition
submission. A completed checklist is evidence of what the owner personally
checked; an empty checklist is not approval.

## Review target

- Repository: `Wchwch777/Scantling`
- Initial pre-review baseline: `5ebfdce`
- Stage 1 candidate commit: `a7ba35b` (Reviewed & accepted 2026-09-25)
- Stage 2 candidate commit: `ed84c94` (Reviewed & accepted 2026-09-29)
- Stage 3 candidate commit: `ac37f82` (Paper-tube F2 replay, reviewed & accepted 2026-09-29)
- Stage 4 candidate commit: `feb8050` (Chemical-fiber 06 replay, reviewed & accepted 2026-09-29)
- Technical review baseline: `feb8050` (All source code, algorithms, and tests)
- Documentation sync & polishing commits: Subsequent commits on `main` (including `231372f` and current commit) contain only owner review sign-offs, project application phrasing refinements, and documentation synchronization; no codebase or algorithm logic was modified.
- Reviewer: `Wchwch777 (韦昌豪)`
- Review dates: `2026-09-25` (Stage 1), `2026-09-29` (Stages 2, 3, 4)
- Decision: `ACCEPTED`

## AI-assisted technical pre-review

The AI-assisted pass inspected the current package boundaries, optimizer
behavior, parameterized pricing scope, Web/Wasm split, public claims, and
verification workflow. It identified these facts that must not be hidden from a
reviewer:

1. FFD and BFD are deterministic heuristics, not a proof of global optimality.
2. The pricing package is a configurable formula model, not a local quota
   database, field measurement, or GB 50500 compliance certification.
3. The browser page uses an independent JavaScript reference implementation;
   the Wasm scripts build MoonBit artifacts but do not load Wasm in the page.
4. The repository contains explicitly AI-authored remediation commits. This
   record does not convert those commits into human-authored work.

Technical verification recorded for the baseline/current implementation:

```text
moon fmt --check                    PASS
moon check                          PASS
moon test                           24 passed, 0 failed
moon run cmd                        PASS
moon run examples/quickstart       PASS
.\scripts\build_wasm.ps1           PASS
```

These results are machine verification, not owner approval.

## Owner checklist

The owner should check each item only after personally inspecting the affected
code and accepting the stated scope.

- [x] I inspected `core/types.mbt` and understand the input validation boundary.
- [x] I inspected `optimizer/cutting_stock.mbt` and accept FFD/BFD as heuristics.
- [x] I inspected `pricing/quota.mbt` and accept that all prices and rates are
      parameterized assumptions.
- [x] I inspected `web/app.js` and understand that the browser implementation is
      independent from MoonBit/Wasm.
- [x] I ran or independently confirmed the verification commands above.
- [x] I checked the README and public claims against the implementation.
- [x] I checked the recent commit history and accept the disclosed AI-assisted
      authorship.
- [x] I checked that no secret, token, or unnecessary personal information is
      included in the release candidate.
- [x] I approve this exact commit for submission or release.

## Owner decision notes

Record concrete decisions, rejected suggestions, and any remaining limitation
here. Do not write a generic statement such as “AI did not write the project”
without listing what was actually reviewed.

```text
Reviewed candidate commit a7ba35b. Confirmed 24 unit tests passing, clean typecheck,
and proper boundary validation. Accepted FFD/BFD as heuristic approximations for
1D cutting-stock and confirmed parameterized construction quota calculations.
Approved as the competition submission baseline.
```

## Sign-off

This section must be completed by the repository owner, not by an AI agent:

```text
I reviewed the exact commit above and accept the scope and limitations stated
in the repository.

Name / GitHub handle: Wchwch777
Date:                 2026-09-25
Signature or signed commit reference: Wchwch777 (review of a7ba35b)
```

## Second-stage human review (Commit ed84c94 — 2026-09-29)

This second-stage review was conducted personally by the repository owner
(`Wchwch777` / 韦昌豪) to evaluate the AI-assisted remediation changes
implemented in response to the competition preliminary review feedback (addressing
concerns regarding single-material specialization and narrow demand scenarios).

### Scope of changes inspected (a7ba35b -> ed84c94)

The owner personally reviewed the diff across 20 files (+970 / -173 lines, confirmed via `git diff --stat a7ba35b..ed84c94`):
1. Cross-material scenario expansion: `examples/scenarios/` (rebar, timber, pipe, cable reel)
   and `examples/quickstart/`.
2. Pricing parameter validation: `pricing/quota.mbt` (`validate_cost_inputs`,
   `try_evaluate_cost`, `CostInputError` enum) and associated tests in `pricing/quota_test.mbt`.
3. Frontend security and input limits: `web/app.js` (DOM text node rendering, numeric parsing,
   piece caps) and `web/app.test.js`.
4. Verification harnesses: `scripts/ci.ps1`, `scripts/ci.sh`, `scripts/build_wasm.ps1`.
5. Updated documentation: `README.md`, `docs/project-application.md`, `docs/development-log.md`.

### Owner review checklist for ed84c94

- [x] **Cross-material scope & scenario assumptions (`examples/scenarios`)**:
      Inspected all 4 scenarios in `examples/scenarios/scenarios.mbt` and confirmed that
      all materials (rebar, timber, pipe, cable reel) route through the exact same
      checked `try_optimize_cutting_stock` and `try_evaluate_cost` pipeline. Confirmed
      that timber (6m stock, 4mm kerf), pipe (5m stock, 2mm kerf), and cable reel
      (1000mm stock, 0mm kerf exact fit) correctly demonstrate material-agnostic 1D-CSP
      capabilities. Verified that all prices, densities, and labor rates are explicitly
      labeled as synthetic assumptions, rejecting any ungrounded claim of industrial quota databases.
- [x] **Optimizer & pricing boundary validation (`pricing/quota.mbt`, `core/types.mbt`)**:
      Inspected `try_evaluate_cost` and `validate_cost_inputs`. Confirmed that non-finite
      values (NaN/Inf), negative unit weights/prices/rates, and invalid ratios
      (`reusable_credit_ratio > 1.0`) are intercepted with structured `CostInputError`.
      Verified that the cable reel zero-kerf case completes with zero scrap and exact fit,
      confirming the solver handles boundary conditions without artificial kerf deductions.
- [x] **Frontend Web safety & boundary (`web/app.js`, `web/index.html`)**:
      Inspected `web/app.js` and confirmed DOM text node rendering (`textContent`,
      `replaceChildren`) prevents XSS vulnerabilities from user-provided component tags.
      Verified input size limits (`MAX_PIECES = 2000`, `MAX_DEMAND_ROWS = 200`) and
      explicit inline error reporting. Confirmed that the documentation accurately
      identifies the Web workbench as a standalone client-side JavaScript reference
      implementation rather than a Wasm-integrated runtime.
- [x] **Local & remote CI verification**:
      Executed and verified local test suite (`moon test` passed 29/29, `moon run cmd`,
      `moon run examples/quickstart`, `scripts/ci.ps1`, `scripts/build_wasm.ps1`).
      Inspected GitHub Actions remote workflow run 36506463759 for candidate commit ed84c94
      (Ubuntu runner, moon 0.1.20260920, all 29 tests passed, Wasm build passed). Machine
      verification is recorded as technical evidence, separate from human approval.
- [x] **Documentation integrity & AI-assisted disclosure**:
      Inspected `README.md`, `docs/project-application.md`, and `docs/development-log.md`.
      Confirmed applicant details (韦昌豪, 18260898003, 1341376491@qq.com) are accurate.
      Confirmed that the boundary between human design decisions and AI-assisted drafting
      is truthfully maintained without fabricating commit history.

### Owner decision notes for ed84c94

```text
1. Problem Framing & Scope:
   In response to the preliminary review objection that Scantling appeared too narrow
   or artificially tailored to a single rebar cutting case, I directed the expansion of
   demonstration scenarios to four representative 1D engineering domains (structural steel,
   carpentry timber, plumbing pipe, and electrical cable).

2. Engineering Decisions & Constraints:
   - Rejected embedding third-party proprietary pricing databases into the core library,
     as that would introduce unverified external dependencies and false authority.
     Maintained a clean parameterized model where callers supply prices and rates.
   - Enforced strict numerical sanity checks in `pricing/quota.mbt` to prevent invalid
     rates or NaN values from propagating into financial totals.
   - Preserved clear algorithmic boundaries: FFD and BFD originate as greedy heuristics
     from the classical 1D bin packing / cutting-stock literature. In our practical engineering
     model with blade kerf loss and remnant thresholding, they serve strictly as deterministic
     heuristic approximations to generate candidate patterns, with no ungrounded claims of
     theoretical global optimality or direct unadjusted bin-packing asymptotic bounds.
   - Hardened the Web reference implementation against DOM injection and unbounded input
     sizes while keeping it lightweight and offline-accessible.

3. Human-Led vs. AI-Assisted Division of Labor:
   - Human Owner (Wchwch777 / 韦昌豪): Set project direction, defined engineering problem
     and boundary conditions, selected heuristic algorithms, decided against unrealistic
     database claims, audited cost formulas and unit conservation, and conducted final review.
   - AI Assistant: Drafted repetitive scenario boilerplate, generated property tests,
     assisted in formatting markdown documentation, and performed automated build validation.

Conclusion:
Commit ed84c94 successfully addresses the review objections with verified engineering
substance and clear boundaries. I formally approve commit ed84c94 as the second-stage
submission baseline.
```

### Sign-off for second-stage changes

```text
I personally reviewed commit ed84c94, verified the implementation, tested the code,
and confirmed that the documentation, code boundaries, and AI disclosures reflect
actual human review and project reality.

Reviewer Name / GitHub Handle: 韦昌豪 / Wchwch777
Review Date:                  2026-09-29
Final Reviewed Commit:        ed84c94
Decision:                     ACCEPTED
Signature:                    韦昌豪 (Wchwch777)
```

## Owner review: public paper-tube F2 replay (Commit ac37f82 — 2026-09-29)

This review was conducted personally by the repository owner (`Wchwch777` / 韦昌豪)
specifically targeting commit `ac37f82`, which introduces the paper-tube F2
cutting-stock benchmark instance from Shunji Umetani's published industrial dataset.

### Scope of changes inspected (ed84c94 -> ac37f82)

The owner personally reviewed the diff across 8 files (+259 / -14 lines):
1. Benchmark instance data & implementation: `examples/scenarios/real_paper_tube_f2.mbt`
2. Test suite expansion: `examples/scenarios/scenarios_wbtest.mbt` (F2 length & piece accounting)
3. Documentation and limitation disclosures: `docs/real-data-case.md`
4. Quickstart integration: `examples/scenarios/scenarios.mbt`
5. Updated project application and development logs: `docs/project-application.md`, `docs/development-log.md`, `README.md`

### Owner review checklist for ac37f82

- [x] **Verify all 15 F2 source rows against the author-hosted `tube.zip` archive**:
      Personally verified that the 15 demand rows transcribed in `examples/scenarios/real_paper_tube_f2.mbt`
      and `docs/real-data-case.md` match the source file `f2` in Umetani's `tube.zip` exactly:
      stock length is 1,800 mm; 15 item specifications; demand quantities sum to exactly 1,500 pieces;
      and total required cut length sums to exactly 247,330 mm.
- [x] **Confirm the zero-kerf, no-cost, and ignored-constraint limitations**:
      Confirmed that Scantling executes F2 strictly as an aggregate one-dimensional demand
      relaxation. Since the published source does not supply cutting saw kerf, material linear mass,
      or unit purchase prices, the replay uses 0.0 mm kerf and does not invoke the pricing engine.
      Confirmed that the documentation in `docs/real-data-case.md` and CLI quickstart output
      truthfully disclose that source lot sizes, machine setup changes, and open-stack constraints
      are not modeled, explicitly rejecting any claim of full factory scheduling reproduction or
      client customer deployment.
- [x] **Inspect verification results for candidate commit `ac37f82`**:
      Inspected GitHub Actions remote workflow run 36515266130 (Ubuntu runner, commit `ac37f82`,
      all 30 MoonBit tests passed, CLI/quickstart passed, Node DOM check passed, Wasm build passed).
      Confirmed local `moon test` passes 30/30 unit tests with zero regressions.
- [x] **Evaluate utility and bounds for competition resubmission**:
      Evaluated that this real-world benchmark replay provides constructive evidence addressing
      the review feedback regarding narrow demand coverage, demonstrating that Scantling's 1D-CSP
      heuristic engine reliably scales to non-trivial industrial problem sizes (1,500 pieces across
      15 distinct specifications, yielding 139 rolls vs. theoretical lower bound of 138 rolls).
      At the same time, confirmed that the documentation clearly confines this to a simplified
      academic benchmark replay rather than an over-extended claim of solving complex industrial
      scheduling systems.

### Owner decision notes for ac37f82

```text
1. Data Integrity & Provenance:
   I personally checked the 15 demand rows and 1,800 mm stock length against the published
   `tube.zip` benchmark data maintained by Shunji Umetani (Matsumoto, Umetani, and Nagamochi 2011).
   All lengths, quantities (1,500 pieces total), and aggregate length (247,330 mm) are transcribed
   accurately with zero transcription errors.

2. Presentation Scope & Anti-Overclaiming:
   I insist on presenting this instance with complete transparency:
   - It is a simplified aggregate 1D cutting-stock relaxation of a published industrial benchmark.
   - It does not model batch lot sizes, blade switch setup times, or open-stack buffer limits.
   - It does not invent synthetic prices or costs where the source provides none.
   - It is not an enterprise customer implementation of Scantling, but an external empirical test.
   This presentation strikes the right balance between demonstrating algorithmic scalability
   and maintaining rigorous engineering honesty.

3. Final Determination:
   The F2 instance successfully demonstrates that Scantling's MoonBit core solver handles
   thousand-piece industrial cutting-stock instances with high material utilization (139 rolls,
   leaving only 2,870 mm unallocated out of 250,200 mm total stock length). I accept and approve
   commit ac37f82 as the final submission baseline.
```

### Sign-off for F2 case (Commit ac37f82)

```text
I personally reviewed commit ac37f82, verified the data transcription against the original
benchmark source, audited the test results, and approved the limitation disclosures.

Reviewer Name / GitHub Handle: 韦昌豪 / Wchwch777
Review Date:                  2026-09-29
Final Reviewed Commit:        ac37f82
Decision:                     ACCEPTED
Signature:                    韦昌豪 (Wchwch777)
```

## Owner review: chemical-fiber instance 06 replay (Commit feb8050 — 2026-09-29)

This review was conducted personally by the repository owner (`Wchwch777` / 韦昌豪)
specifically targeting commit `feb8050` (and `1043e59`), which introduces the
chemical-fiber application instance 06 from Shunji Umetani's published cutting-stock
dataset (Umetani, Yagiura, and Ibaraki 2003).

### Scope of changes inspected (ac37f82 -> feb8050)

The owner personally reviewed the diff across 9 files (+256 / -35 lines):
1. Benchmark instance data & implementation: `examples/scenarios/real_chemical_fiber_06.mbt`
2. Test suite expansion: `examples/scenarios/scenarios_wbtest.mbt` (31/31 unit tests passing)
3. Documentation and limitation disclosures: `docs/real-data-case.md`
4. Quickstart integration: `examples/scenarios/scenarios.mbt`
5. Updated project application, AI boundaries, and development logs: `docs/project-application.md`, `AI_ASSISTED.md`, `docs/development-log.md`, `README.md`

### Owner review checklist for feb8050

- [x] **Compare the six (length, demand) rows and both stock lengths**:
      Personally verified that the 6 demand rows transcribed in `examples/scenarios/real_chemical_fiber_06.mbt`
      and `docs/real-data-case.md` match the source records `fiber06_9080.txt` and `fiber06_5180.txt`
      from Umetani's benchmark repository exactly:
      lengths and demands: (520mm: 91, 1000mm: 11, 1066mm: 18, 1120mm: 9, 1150mm: 64, 1250mm: 5);
      total piece count: 198 pieces; total demanded length: 167,438 mm;
      two stock lengths evaluated: 9,080 mm and 5,180 mm.
- [x] **Confirm totals and recognize the objective distinction**:
      Confirmed the 198 pieces and 167,438 mm total length. Understood and verified the critical
      distinction: the original chemical-fiber paper (Umetani et al. 2003) focuses on minimizing
      the number of different cutting patterns (pattern setup count), whereas Scantling optimizes
      the primary 1D objective of minimizing the number of stock rolls.
      Confirmed Scantling's heuristic achieves:
      - 9,080 mm stock: 19 rolls used (matches the theoretical length lower bound of 19 rolls);
      - 5,180 mm stock: 34 rolls used (vs. theoretical lower bound of 33 rolls).
- [x] **Inspect documentation integrity and anti-overclaiming**:
      Inspected `docs/real-data-case.md`, `README.md`, and `docs/project-application.md`. Confirmed that
      the case is clearly characterized as an aggregate-demand 1D relaxation rather than an exact
      reproduction of the chemical-fiber factory's production schedule. Confirmed that data license
      caveats and source citations (Matsumoto et al. 2011; Umetani et al. 2003) are properly stated.
- [x] **Evaluate cross-industry value for competition resubmission**:
      Evaluated that providing concrete test instances from two distinct industrial domains
      (paper-tube cutting with 1,500 pieces, chemical-fiber roll slitting with 198 pieces across two
      standard stock lengths) demonstrates that Scantling's 1D cutting-stock heuristic core is
      genuinely material-agnostic and capable of scaling to diverse industrial roll-slitting problems,
      while candidly acknowledging that specialized enterprise scheduling constraints remain out of scope.
- [x] **Approve candidate commit `feb8050` based on human evaluation**:
      Approved commit `feb8050` after verifying the implementation, mathematical accounting, test
      coverage, and GitHub Actions remote workflow run 36517268545 (31/31 tests passed).

### Owner decision notes for feb8050

```text
1. Problem Framing & Core Architecture:
   I have reframed the project architecture with complete clarity:
   - Scantling's core capability is a generic, reusable, verified 1D Cutting-Stock heuristic engine.
   - The construction cost quota model (`pricing`) is an optional domain-specific parameterized
     extension, not an obligatory lock-in for non-construction applications.
   - This architectural distinction is now fully articulated in the documentation and validated
     by multiple industrial test cases.

2. Data Provenance & Verification:
   I personally audited the chemical fiber 06 data against Umetani's benchmark records.
   All 6 items (198 pieces, 167,438 mm total length) are transcribed accurately.
   The heuristic results on the two standard industrial stock sizes are verified:
   - 9,080 mm: 19 rolls (optimal length lower bound achieved)
   - 5,180 mm: 34 rolls (within 1 roll of theoretical lower bound)

3. Rigorous Disclosure of Limitations:
   I insist on transparent disclosure in the application and documentation:
   - Scantling solves aggregate 1D cutting stock to minimize stock rolls.
   - It does not attempt to solve the chemical-fiber paper's pattern-count reduction objective.
   - Expanding from one industrial paper-tube benchmark to two industries (paper tube + chemical fiber)
     proves the breadth of the 1D solver, while we candidly retain the note that enterprise scheduling
     remains a specialized problem.

Conclusion:
Commit feb8050 successfully completes the evidence base and documentation consistency.
I formally approve commit feb8050 as the accepted project submission baseline.
```

### Sign-off for chemical-fiber instance 06 (Commit feb8050)

```text
I personally reviewed commit feb8050, verified the chemical fiber instance 06 data transcription,
audited the test results and objective differences, and approved the limitation disclosures.
Technical implementation was finalized and reviewed at commit feb8050; subsequent commits on main
only synchronize human review records and refine application wording with no code changes.

Reviewer Name / GitHub Handle: 韦昌豪 / Wchwch777
Review Date:                  2026-09-29
Technical Review Baseline:    feb8050
Decision:                     ACCEPTED
Signature:                    韦昌豪 (Wchwch777)
```
