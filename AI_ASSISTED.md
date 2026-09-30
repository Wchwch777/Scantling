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
implementation. The owner also prohibited invented demand evidence. The
current uncommitted changes synchronize `README.md`,
`docs/project-application.md`, `docs/use-cases.md`, and this file. The owner
has not yet reviewed these new documentation edits. Before submission,
the owner should confirm the MQTT direction and decide whether the listed
scenarios accurately describe intended uses. Native CI passed for the code
revision identified below; Native was not rerun on this Windows machine.

[`docs/owner-review.md`](docs/owner-review.md) records the owner's review of
the MQTT revision at commit `cf315a1`. The cited Linux CI run
[`36735317519`](https://github.com/Wchwch777/Scantling/actions/runs/36735317519)
succeeded on commit `009eb27`; the MQTT implementation in that commit is
unchanged from `a3d3e04`. The owner sign-off applies to its reviewed revision;
any later changes must be reviewed separately. Do not describe the prior
sign-off as approval of a later diff.
