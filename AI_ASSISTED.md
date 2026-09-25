# AI-assisted development boundary

Scantling is human-directed and AI-assisted. This file records the boundary so that generated suggestions are not confused with project ownership or verification.

The repository keeps commit authorship truthful. Some review and remediation
commits are explicitly attributed to `Codex AI-assisted`; that attribution is
not changed to imply human authorship. This document is not, by itself, proof
that the owner has reviewed a particular commit. The owner sign-off is recorded
separately in [`docs/human-review-record.md`](docs/human-review-record.md).

## Human-owned decisions

The project owner must make and record the final decisions about:

- the construction-cost and cutting-stock problem covered by the repository;
- the FFD/BFD heuristic choice and the meaning of reusable remnants, scrap, and cost differences;
- public APIs, compatibility behavior, documentation claims, and release scope;
- which tests are required and whether a result is strong enough to publish.

The optimizer is intentionally described as heuristic. It is not presented as a proof of global optimality, an independent field benchmark, or a substitute for local quantity-surveying rules.

## AI-assisted activities

AI assistance may be used for MoonBit API lookup, repetitive scaffolding, boundary-case enumeration, documentation review, and compiler or formatter diagnosis. AI assistance does not replace the owner's decision. Before release or submission, the owner must inspect the affected code and claims, reproduce the relevant commands, and record acceptance or rejection in the human review record. If that review has not happened, the change remains explicitly unapproved.

## Verification rule

No AI-suggested change is considered complete until it has a focused test or an explicit reason why a test is not applicable. Changes are checked with the repository formatter, type checker, tests, and the CLI example where applicable. The commands and outcomes are recorded in [`docs/development-log.md`](docs/development-log.md).

## Commit and review policy

- Do not rewrite old commits to conceal AI assistance or manufacture a human
  author.
- Keep AI-authored commits explicitly labeled when AI performed the change.
- For a release candidate, the repository owner completes the checklist in
  [`docs/human-review-record.md`](docs/human-review-record.md) and signs the
  exact reviewed commit.
- A green CI run proves that the checked commands passed; it does not prove
  domain correctness or human approval.

## Current limitations

- FFD and BFD are practical heuristics, not a global optimizer.
- The browser workbench currently uses a standalone JavaScript reference engine; the Wasm scripts verify an optional build, not browser Wasm loading.
- GB 50500 is represented as a parameterized formula model. Project data, local quota rules, contracts, and tax treatment must be supplied separately.
- The README benchmark is an illustrative deterministic example, not an independent construction-site measurement.
