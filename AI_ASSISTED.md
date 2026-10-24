# AI-assisted development disclosure

AI tools have assisted with code, tests, examples, and documentation in this
repository. AI-generated or AI-edited work is identified as such and is not
presented as unaided human authorship. The repository owner remains responsible
for reviewing, maintaining, and releasing the project.

## Current project direction

The maintained project includes the MoonBit MQTT 3.1.1 asynchronous TCP client
and a focused native protocol fault-injection peer described in the
[README](README.md). The peer is not a full broker or conformance suite. The
repository history also contains one-dimensional cutting-stock and
GraphQL-over-HTTP prototypes; those earlier directions are historical, not
part of the current maintained scope.

Some early commits retain the synthetic local identity
`Codex AI-assisted <codex-ai-assisted@localhost>` in their author or committer
metadata. That metadata is part of the existing history and does not identify
a GitHub user account. The repository's current GitHub contributors list
identifies `Wchwch777`; the historical commit metadata has not been rewritten.

## October documentation update

AI has assisted with repository documentation updates, including evidence
links and review-status wording. The repository owner reviewed and signed off
on the historical scopes recorded in [`docs/owner-review.md`](docs/owner-review.md);
those approvals do not cover later AI-assisted changes. The runnable example
was not edited in the October documentation refresh. The three scenario
payloads are illustrative test/demo data, not claims about customer
requirements or deployments.

AI also assisted with the October MQTT QoS 2 implementation, its protocol-peer
and Mosquitto integration tests, and the corresponding feature documentation.
The repository owner (`Wchwch777`) has personally reviewed the implementation,
verified the test results against local Mosquitto runs, and recorded sign-off in
[`docs/owner-review.md`](docs/owner-review.md).

## October 21 fault-peer implementation

AI assisted with the native fault-injection peer, its MQTT protocol scenarios,
integration tests, CI path, README, and scenario documentation. The repository
owner has not yet reviewed or signed off on these changes. The completed
October 19 owner review above applies only to its recorded QoS 2 and protocol
extension scope.

## October 23 coordinated Keep Alive update

AI assisted with the `receive_with_keep_alive()` client API, its deterministic
native protocol tests, the delayed-event example, and the related README and
use-case updates. Native tests were run in GitHub Actions for baseline commit
[`27a8ab6`](https://github.com/Wchwch777/Scantling/commit/27a8ab67300bcd14c2bf48c3bf43eba96c76ddaa):
18 Wasm and 36 Native tests passed in [run 39993827022](https://github.com/Wchwch777/Scantling/actions/runs/39993827022).
That run did not execute the runnable example. The subsequent
[CI run 39999304413](https://github.com/Wchwch777/Scantling/actions/runs/39999304413)
ran the example against Mosquitto and checked its three topic/payload outputs
and five-second idle interval. These AI-assisted changes remain pending
personal review and sign-off by the repository owner.

## October 24 end-to-end and independent-client update

AI assisted with the simulated-device command/report/event example, its longer
Mosquitto-backed idle check, the independent Mosquitto client's truncated-
CONNACK scenario, and the related workflow and documentation updates. The
repository owner has not yet reviewed or signed off on these additions. Their
verification status is the latest GitHub Actions run linked from the README;
that CI result does not replace the owner's review.
