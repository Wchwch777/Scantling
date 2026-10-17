# Owner review status

**Status: pending owner review.** This record does not claim the repository
owner has reviewed, signed, or approved this documentation update. Add an
owner sign-off only after the owner personally completes the review.

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
- Updates the AI disclosure and keeps owner review explicitly pending.
- Does not edit the project application or runnable example in this revision.

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
WSL) completed successfully. The documentation changes do not modify MoonBit
source. The local Native run did not set `SCANTLING_MOSQUITTO_HOST`, so its
conditional Mosquitto test was skipped; the linked CI baseline is the evidence
that the real-Broker path ran. The README explains how to enable that test
locally. Check the Actions result attached to each later commit before claiming
that commit's remote CI passed.

## Owner checklist — incomplete

- [ ] Confirm the project direction and contest-facing wording.
- [ ] Review the package boundary, source references, and license statements.
- [ ] Review all three scenarios and their evidence limits.
- [ ] Confirm the AI-assistance disclosure is accurate.
- [ ] Run the example against a Broker and review its output.
- [ ] Record the actual review date and scope after personally completing this
  review.
