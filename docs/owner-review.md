# Owner review status

**Historical owner review:** The documentation and verification baseline
recorded below were personally reviewed and approved by the repository owner
(`Wchwch777`) on 2026-10-17. That sign-off applies to the scope and repository
snapshot listed in the historical review record.

**Current evidence refresh (2026-10-18): pending owner review.** AI updated the
README's commit and CI references and added the latest verification snapshot
below. The owner has not yet reviewed or signed off on these new edits; the
historical review is not being presented as approval of this refresh.

## Review record

- **Reviewer:** Wchwch777 (Repository Owner)
- **Review date:** 2026-10-17
- **Review scope:**
  - Project direction and contest-facing wording in `README.md` and `docs/project-application.md`.
  - Package boundaries, upstream repository links, and Apache-2.0 license declarations.
  - Three protocol demonstration scenarios and evidence limits in `docs/use-cases.md`.
  - AI-assisted development disclosure in `AI_ASSISTED.md`.
  - Real Broker execution of `examples/mqtt_client` against Mosquitto `2.0.22`, validating the terminal output.
  - Verification test suites (`moon fmt --check`, 14 Wasm tests passed, and 20 Native tests passed with `SCANTLING_MOSQUITTO_HOST=127.0.0.1`).

## This documentation update

- Clarifies that the current maintained project is the MQTT 3.1.1 TCP client;
  the earlier one-dimensional cutting-stock work remains in Git history but
  is no longer the active project direction.
- Describes Scantling's client/runtime responsibilities separately from the
  `zbhzs1/moonbit-mqtt` packet codec and `moonbitlang/async` runtime, and links
  to version and Apache-2.0 license evidence.
- Maps telemetry-shaped, command-shaped, and event-shaped example messages to
  actual example code, client APIs, and protocol tests. It does not present
  these sample flows as user research, customer deployments, or device tests.
- Updates the AI disclosure and records owner sign-off.
- Synchronizes the project application with the current repository evidence;
  the runnable example itself was not edited.

## Verification evidence

The code baseline used for the documentation is commit
[`ecbda25`](https://github.com/Wchwch777/Scantling/commit/ecbda25b94f463e534e3efa9c4fa11e6bb66f2f2).
Its [GitHub Actions run 39027210274](https://github.com/Wchwch777/Scantling/actions/runs/39027210274)
completed successfully: formatting, Wasm and Native type checks, 14 Wasm tests,
and 20 Native tests passed. CI sets `SCANTLING_MOSQUITTO_HOST=127.0.0.1` and
starts Mosquitto `2.0.22`, so the independent-Broker test ran. This verifies the
tested protocol paths, not full MQTT conformance or production readiness.

For the source tree at this documentation update, `moon fmt --check`,
`moon check --target wasm`, `moon test --target wasm` (14 passed),
`moon check --target native`, and `moon test --target native` (20 passed in
WSL) completed successfully. Local Native testing with Mosquitto `2.0.22` and
`SCANTLING_MOSQUITTO_HOST=127.0.0.1` executed and passed all 20 tests. Running
`examples/mqtt_client` against the local Broker succeeded with the expected
telemetry, command, and event output. Check the Actions result attached to each
later commit before claiming that commit's remote CI passed.

## Latest verification snapshot — pending owner review

The latest full CI run before this evidence refresh is attached to repository
commit [`22a6b39`](https://github.com/Wchwch777/Scantling/commit/22a6b39c207e658e03bd74fa76630366757f867d):
[GitHub Actions run 39109088054](https://github.com/Wchwch777/Scantling/actions/runs/39109088054)
completed successfully. It passed formatting, Wasm and Native type checks,
14 Wasm tests, and 23 Native tests with the Mosquitto `2.0.22` broker path
enabled. This run predates the current documentation-only evidence refresh;
the next CI run must be checked against the documentation commit before
claiming that commit's CI passed.

## Owner checklist — completed

- [x] Confirm the project direction and contest-facing wording.
- [x] Review the package boundary, source references, and license statements.
- [x] Review all three scenarios and their evidence limits.
- [x] Confirm the AI-assistance disclosure is accurate.
- [x] Run the example against a Broker and review its output.
- [x] Record the actual review date and scope after personally completing this
  review.
