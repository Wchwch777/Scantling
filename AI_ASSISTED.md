# AI-assisted development boundary

Scantling is human-directed and AI-assisted. This file records the boundary so that generated suggestions are not confused with project ownership or verification.

## Human-owned decisions

The project owner makes the final decisions about:

- the construction-cost and cutting-stock problem covered by the repository;
- the FFD/BFD heuristic choice and the meaning of reusable remnants, scrap, and cost differences;
- public APIs, compatibility behavior, documentation claims, and release scope;
- which tests are required and whether a result is strong enough to publish.

The optimizer is intentionally described as heuristic. It is not presented as a proof of global optimality, an independent field benchmark, or a substitute for local quantity-surveying rules.

## AI-assisted activities

AI assistance may be used for MoonBit API lookup, repetitive scaffolding, boundary-case enumeration, documentation review, and compiler or formatter diagnosis. The owner reviews the proposed change, checks the domain meaning, and decides whether it is accepted.

## Verification rule

No AI-suggested change is considered complete until it has a focused test or an explicit reason why a test is not applicable. Changes are checked with the repository formatter, type checker, tests, and the CLI example where applicable. The commands and outcomes are recorded in [`docs/development-log.md`](docs/development-log.md).

## Current limitations

- FFD and BFD are practical heuristics, not a global optimizer.
- The browser workbench currently uses a standalone JavaScript reference engine; the Wasm scripts verify an optional build, not browser Wasm loading.
- GB 50500 is represented as a parameterized formula model. Project data, local quota rules, contracts, and tax treatment must be supplied separately.
- The README benchmark is an illustrative deterministic example, not an independent construction-site measurement.
