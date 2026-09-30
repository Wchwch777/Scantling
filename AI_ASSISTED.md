# AI assistance and review status

This repository has undergone multiple AI-assisted direction changes after
two screening decisions cited narrow scenarios and limited demand coverage.
The current local revision pivots to an MQTT 3.1.1 asynchronous client runtime
because the competition charter explicitly lists MQTT clients as a recommended
project direction and the MoonBit codec package documents that it has no
network transport or client runtime. This is an evidence-based project choice,
not proof of customer demand or of likely acceptance.

AI assistance in this local revision included:

- checking the charter's recommended project categories and current adjacent
  Mooncakes packages;
- drafting a client runtime that reuses `zbhzs1/moonbit-mqtt` packet codecs;
- adding a TCP loopback integration test, framing tests, CI changes, and a
  revised README and application draft.

The owner selected the MQTT direction, reviewed the implementation, corrected
the Native integration-test packet order, and signed the review recorded in
`docs/owner-review.md`. This does not mean the owner authored the AI-assisted
implementation. The owner also prohibited invented demand evidence and
reviewed the documentation revision through commit `63a9ab8` and the current sync,
including the three intended protocol scenarios and the demand coverage evidence section.
The owner review recorded in [`docs/owner-review.md`](docs/owner-review.md) covers
the full revision including the demand coverage analysis. Native CI passed for recent
commits in [GitHub Actions run 36738625531](https://github.com/Wchwch777/Scantling/actions/runs/36738625531)
(and earlier run 36737550535); Native was not rerun on this Windows machine.

[`docs/owner-review.md`](docs/owner-review.md) records the owner's review and sign-off
covering the MQTT revision through commit `63a9ab8` and the current documentation
synchronization.
