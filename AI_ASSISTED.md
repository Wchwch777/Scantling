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

No claims are made that the repository owner personally authored or verified
these new changes. The owner asked for a reality-based revision, prohibited
inventing demand evidence, and has not yet reviewed this local diff. Before
submission, the owner should inspect the implementation, run the native tests
with a C toolchain, and decide whether the listed scenarios accurately
describe intended uses.

[`docs/owner-review.md`](docs/owner-review.md) records an earlier GraphQL
client review at commit `079629f`. It is historical evidence only; it does not
review, approve, or authorize pushing the current MQTT changes.
