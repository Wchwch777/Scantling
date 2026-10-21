# Owner review status

**Review status: reviewed by repository owner.** The repository owner
(`Wchwch777`) has personally reviewed and approved both the initial baseline
(2026-10-17) and the current QoS 2 and protocol extension update (2026-10-19).
Each sign-off applies strictly to its stated review scope and verified snapshot.

- **2026-10-17 Baseline Review:** Approved the initial MQTT 3.1.1 client direction, QoS 0/1 implementation, Mosquitto 2.0.22 integration baseline, license declarations, and the three example scenarios.
- **2026-10-19 QoS 2 and Protocol Extension Review:** Approved the MQTT QoS 2 client state machine, batched subscription APIs, username/password authentication, queue capacity protection, updated scenario boundaries, and verification on GitHub Actions run 39145118457 (18 Wasm, 34 Native passed).

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
- The historical update synchronized the AI disclosure and project application;
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

## Latest verified repository CI snapshot for QoS 2 and protocol extension

The latest full CI run for repository commit
[`344076f`](https://github.com/Wchwch777/Scantling/commit/344076f8511814b956da0232b0cd3d15c4f7bed8)
([GitHub Actions run 39145118457](https://github.com/Wchwch777/Scantling/actions/runs/39145118457))
completed successfully. It passed formatting, Wasm and Native type checks,
18 Wasm tests, and 34 Native tests with the Mosquitto `2.0.22` broker path
enabled. This verified the batched subscription APIs, username/password authentication,
QoS 2 publish and receive state machines, and queue overflow protection against
the pinned toolchain in CI. Check the [main-branch workflow runs](https://github.com/Wchwch777/Scantling/actions/workflows/ci.yml)
for later commits.

## Historical owner checklist — completed for the 2026-10-17 scope only

- [x] Confirm the project direction and contest-facing wording.
- [x] Review the package boundary, source references, and license statements.
- [x] Review all three scenarios and their evidence limits.
- [x] Confirm the AI-assistance disclosure is accurate.
- [x] Run the example against a Broker and review its output.
- [x] Record the actual review date and scope after personally completing this
  review.

## Owner review record for QoS 2 and protocol extension — completed (2026-10-19)

- **Reviewer:** Wchwch777 (Repository Owner)
- **Review date:** 2026-10-19
- **Review scope:**
  - Reviewed MQTT QoS 2 client implementation: `publish_qos2` 4-step handshake (PUBLISH -> PUBREC -> PUBREL -> PUBCOMP), duplicate PUBREC handling, exactly-once `receive` delivery, and `completed_qos2_ids` deduplication state machine.
  - Reviewed batched multi-topic subscription/unsubscription APIs (`subscribe_many`, `unsubscribe_many`) and strict SUBACK return code validation.
  - Reviewed username/password authentication parameter support and credential validation.
  - Reviewed pending message queue capacity enforcement (64-message limit protection).
  - Executed and verified local test suites: `moon fmt --check`, 18 Wasm tests passed, and 34 Native tests passed with Mosquitto `2.0.22` independently running.
  - Executed and verified runnable example `examples/mqtt_client` with output validated.

## Owner checklist for QoS 2 and protocol extension — completed (2026-10-19)

- [x] Personally inspect the QoS 2 publish and receive state machines in `mqtt/client.mbt`.
- [x] Verify batched subscription APIs, credential handling, and queue overflow protection.
- [x] Review unit tests and Mosquitto integration tests covering QoS 2 round trips and deduplication.
- [x] Run local test suite against Mosquitto 2.0.22 (18 Wasm, 34 Native passed) and check example output.
- [x] Update owner review documentation and record owner sign-off.

## Owner review status for the fault-injection peer — pending

The native MQTT fault-injection peer, its accepted QoS 0/1 scenarios, the
Mosquitto client interoperability workflow, and the related README and scenario
documentation have not yet been reviewed or signed off by the repository
owner. The October 19 review above does not cover these changes.
