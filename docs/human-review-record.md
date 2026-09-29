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
- Final reviewed commit: `ed84c94`
- Reviewer: `Wchwch777 (韦昌豪)`
- Review date: `2026-09-25` (Stage 1), `2026-09-29` (Stage 2)
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

## Pending owner review: public paper-tube F2 replay

The F2 data replay and its application/documentation changes were added after
the `ed84c94` review. The four original cross-material demonstrations remain
synthetic; F2 is transcribed from the cited public paper-tube dataset and is
executed only as an aggregate-demand, zero-kerf relaxation. The source lot,
setup, and open-stack constraints are not implemented. This addition is
AI-assisted and has not yet been personally reviewed by the repository owner.

- [ ] Verify all 15 F2 source rows against the author-hosted `tube.zip` archive.
- [ ] Confirm the zero-kerf, no-cost, and ignored-constraint limitations in
      `docs/real-data-case.md` and the quickstart output.
- [ ] Run the current CI and inspect its result for the exact candidate commit.
- [ ] Decide whether this sourced relaxation is useful and accurately described
      for the competition resubmission.

These items remain unchecked until Wchwch777 completes that review.
