# Owner review status

**Status: pending owner review for the 2026-10-17 documentation and example update.**

This file records verifiable repository evidence and the items awaiting the
repository owner's review. It does not claim that the owner has reviewed,
signed, or approved this revision. Earlier versions of this file contained
first-person sign-off and manual-review claims; they are not carried forward as
evidence for the current code or this documentation revision.

## Changes prepared in this revision

- The project application and README describe the current MQTT 3.1.1 client
  features and limitations.
- Three protocol-level use cases point to the implementation, runnable example,
  and available integration coverage; they are explicitly not presented as
  customer or deployment evidence.
- The runnable example uses separate publisher and subscriber clients and
  telemetry, command, and event-shaped topics.
- AI assistance and the current owner-review status are disclosed in the
  repository documents.

These materials were prepared with AI assistance under the task instruction.
The owner has not yet confirmed the wording or completed a line-by-line review
of this revision.

## Verification completed for this revision

- MoonBit CLI `0.1.20261012` / compiler `0.10.15`: `moon fmt --check` passed.
- `moon check --target wasm` and `moon check --target native` passed.
- `moon test --target wasm`: 10 tests passed.
- `moon test --target native`: 12 tests passed in WSL Ubuntu with GCC and
  `SCANTLING_MOSQUITTO_HOST=127.0.0.1`; the independent Mosquitto `2.0.22`
  integration test was enabled.
- `moon run --target native examples/mqtt_client` ran against that broker and
  printed the telemetry, command-shaped, and event-shaped demo messages.
- `git diff --check` passed. Compiler warnings were emitted for existing
  deprecated implicit trait methods and unused imports; there were no errors.

The Windows Native run cannot use MSVC because Build Tools and the Windows SDK
are not installed; the Native checks and runtime tests above ran in WSL Ubuntu.
The preceding code baseline's GitHub Actions run is recorded below. For any
later push, use the Actions result associated with that exact commit before
claiming remote CI success.

## Earlier code-baseline evidence

- Preceding code work is present on `main` through commit
  [`d7112e7`](https://github.com/Wchwch777/Scantling/commit/d7112e7bc57821cbe75701344c12931088aaf128).
- That commit's GitHub Actions run completed successfully, including formatting,
  Wasm/native checks and tests, and the Mosquitto integration path:
  [run 39005161469](https://github.com/Wchwch777/Scantling/actions/runs/39005161469).
- The CI uses Mosquitto `2.0.22` and the checked-in test configuration. This
  validates the exercised MQTT 3.1.1 flow; it is not a complete conformance
  suite or a certification.

## Owner review checklist — not yet completed

- [ ] Confirm the project description and contest-facing wording.
- [ ] Review the three use-case descriptions and their evidence boundaries.
- [ ] Run or inspect the documented example against a broker.
- [ ] Confirm the AI-assistance disclosure is accurate for the repository.
- [ ] Add an owner sign-off only after the owner has personally completed this
  review; record its actual date and scope.
