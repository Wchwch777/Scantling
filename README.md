# Scantling — Scriptable MQTT 3.1.1 Protocol Test Peer

Scantling's project focus is a native, one-connection, scriptable broker-side
peer for repeatable MQTT 3.1.1 client behavior tests. A scenario can be run from
a text file without editing or recompiling MoonBit code; it can match incoming
packet types, send protocol responses or PUBLISH messages, emit raw bytes,
wait, and close. The included asynchronous MoonBit client is also tested by the
peer and shown in examples, but overlaps with existing MoonBit client work and
is not the project's claimed differentiator. CI exercises selected scenarios
with independent Mosquitto command-line clients. Scantling remains a focused
test tool, not a full Broker or MQTT conformance certification.

Scantling builds on the `zbhzs1/moonbit-mqtt` packet codec and the
`moonbitlang/async` runtime. It implements the client-side TCP connection and
MQTT request/response flow; it does not implement a Broker. The package
boundaries and licenses are listed below, with feature evidence in
[`docs/use-cases.md`](docs/use-cases.md).

## Implemented

- MQTT CONNECT/CONNACK over TCP, with Clean Session requested and checked.
- Optional MQTT 3.1.1 username/password CONNECT authentication. Credentials are
  sent in clear text because TLS is not implemented; only use this on a
  trusted network or with a separately secured transport.
- Single-filter and batched SUBSCRIBE/UNSUBSCRIBE calls, awaiting the matching
  SUBACK or UNSUBACK. SUBACK results are checked against every requested
  filter and QoS.
- QoS 0 publish, QoS 1 publish with matching PUBACK, and QoS 2 publish with the
  PUBREC/PUBREL/PUBCOMP handshake, including retransmitting PUBREL for a
  duplicate PUBREC.
- QoS 0/1/2 PUBLISH receive. QoS 1 is acknowledged before return; QoS 2 is
  returned only after PUBREL/PUBCOMP and duplicate in-flight PUBLISH packets
  are acknowledged without duplicate delivery.
- Retained QoS 0 messages are surfaced with the MQTT retain flag preserved.
- PINGREQ/PINGRESP, DISCONNECT, topic/filter validation, a 1 MiB inbound
  packet-body limit, and a 64-message pending queue that closes the connection
  with an explicit error on overflow.
- `receive_with_keep_alive()` sends PINGREQ while waiting for an inbound
  message, processes PINGRESP before returning a message received during the
  ping exchange, and closes with an explicit error if PINGRESP is missing.
- Sequential API calls on each connection. Do not issue concurrent operations
  on the same client.

The included asynchronous client overlaps materially with the public
[`moon-mqtt-client`](https://github.com/Strangelight-Merser/moon-mqtt-client)
project, which describes a native MQTT 3.1.1 client with QoS 0/1, transport,
and session features for application connectivity. Scantling does not claim a
unique or superior general client. Its additional tested component is a
native, one-connection [scriptable test peer](docs/fault-peer.md) with a public
Script/Exchange API and a text-file runner for external MQTT clients. The
CI verifies independent Mosquitto `mosquitto_pub` behavior for accepted QoS
0/1 PUBLISH exchanges, broker rejection, and a truncated CONNACK. It also runs
the text-scripted QoS 2 PUBREC/PUBREL/PUBCOMP exchange, scripted subscription
and message delivery, and two keep-alive ping exchanges before a later event.
All three CLI paths passed in GitHub Actions run
[`41185493873`](https://github.com/Wchwch777/Scantling/actions/runs/41185493873)
on commit [`9ad42e2`](https://github.com/Wchwch777/Scantling/commit/9ad42e298dc6fb7dd7cfc1044e07be8fa47defd),
along with formatting, Wasm/Native type checks, 26 Wasm tests, 49 Native tests,
the authenticated and unauthenticated Mosquitto Broker paths, and the runnable
client example. The CI run uses MoonBit `0.10.15+943464bfa` and Mosquitto
`2.0.22`. This is a finite regression matrix, not broad interoperability data
or MQTT conformance certification.
Truncated CONNACK, mismatched PUBACK, and unexpected SUBACK are tested against Scantling's own client; the peer has not been tested against moon-mqtt-client or a wider client set. Caller-defined script tests also reject an invalid SUBACK QoS grant, exercise duplicate PUBREC/PUBREL handling, and inject a truncated CONNACK from raw bytes. This focused matrix is not a general-purpose compatibility suite or an MQTT conformance certification.

October code work added an independent Mosquitto interoperability path and
explicit protocol-error handling for broker rejection, invalid Clean Session
state, mismatched acknowledgements, and truncated frames. Later changes buffer
inbound PUBLISH packets while a request awaits its acknowledgement and add
deterministic coverage for malformed responses and early EOF. See the protocol
error implementation in [`ecbda25`](https://github.com/Wchwch777/Scantling/commit/ecbda25b94f463e534e3efa9c4fa11e6bb66f2f2),
the message-buffer fix in [`9980813`](https://github.com/Wchwch777/Scantling/commit/998081389ed13e81e8c86a1f32932792b69643d6),
and the additional tests in [`eff2323`](https://github.com/Wchwch777/Scantling/commit/eff232335dc3f999161ade45dc52aedd7caf4527).
The batch subscription API checks each SUBACK result, including QoS 2 grants.
Native tests exercise multi-filter requests, QoS 2 handshakes with a protocol
peer and Mosquitto, retained-message replay, and the pending-queue overflow
policy; see the CI evidence below.

## Boundaries

The client is a small MQTT 3.1.1 TCP implementation, not a production-complete
SDK; the peer is not a conformance certification. TLS, automatic reconnection,
operation timeouts, persistent sessions, MQTT 5.0, and WebSocket transport are
not implemented. QoS 2 exchange state is kept in memory for the current
clean-session connection; it is not persisted across disconnects.
`receive_with_keep_alive()` sends and checks pings only while that call is
waiting for a message. The caller must enter it before the configured Keep
Alive deadline and must not run another operation on the same client
concurrently. The ordinary `receive()` remains an indefinite blocking read
without automatic pings; even the keep-alive variant has no message-arrival
timeout while the broker continues to answer pings. The sample topics and
payloads below are protocol demonstrations; they are not evidence of customer
deployments, physical devices, user research, or measured demand.
This repository does not claim a Scantling Mooncakes release.

## End-to-end command, report, and event example

The runnable example uses separate application and simulated-device
connections for three message flows:

1. **Telemetry:** the device publishes `21.5` to
   `demo/sensor/temperature`, and the application receives it.
2. **Command and reported state:** the application publishes `SET_TEMP=22.0`
   to `demo/device/device-7/cmd`; the simulated device receives it and returns
   `temperature=22.0` on `demo/device/device-7/reported`.
3. **Delayed event after idle:** the device publishes
   `order_id=demo-1` to `demo/service/orders/created` after the application has
   waited idle for ten seconds.

The application sends the command, receives the device's reported state, then
waits for the delayed event on that same connection with
`receive_with_keep_alive()`. Its four-second MQTT Keep Alive means a Broker
would disconnect it after roughly six seconds without a client control packet;
the ten-second idle interval therefore requires successful PINGREQ/PINGRESP
traffic before the event is delivered. A deterministic local peer test also
checks two keep-alive exchanges, delivery of a complete delayed QoS 1 event,
and receipt of a following event. CI runs the complete example against
Mosquitto, checks the telemetry, command, reported-state, and event outputs,
and requires at least ten seconds of runtime. The peer test separately checks
the ping sequence and missing-PINGRESP timeout. The device is simulated by a
second client in the same process; payloads are opaque demonstrations, not
hardware control or business-protocol implementations. See the
[scenario-by-scenario evidence and limits](docs/use-cases.md).

## Source and license boundaries

The Scantling module declares Apache-2.0 in [`moon.mod`](moon.mod), with the
full text in [`LICENSE`](LICENSE). Its pinned dependencies are:

| Module | Role in Scantling | Version and license evidence |
| --- | --- | --- |
| [`zbhzs1/moonbit-mqtt`](https://github.com/zbhzs1/moonbit-mqtt) | MQTT 3.1.1 packet encoding/decoding; it does not provide transport or a client runtime. | `0.1.0`, Apache-2.0: [Mooncakes package](https://mooncakes.io/docs/zbhzs1/moonbit-mqtt), [upstream module metadata](https://github.com/zbhzs1/moonbit-mqtt/blob/main/moon.mod), [license](https://github.com/zbhzs1/moonbit-mqtt/blob/main/LICENSE). |
| [`moonbitlang/async`](https://github.com/moonbitlang/async) | General async runtime and TCP socket APIs used for transport; it does not supply MQTT semantics. | `0.21.3`, Apache-2.0: [versioned Mooncakes package](https://mooncakes.io/docs/moonbitlang/async@0.21.3), [upstream repository](https://github.com/moonbitlang/async), [license](https://github.com/moonbitlang/async/blob/main/LICENSE). |

The versions are pinned in Scantling's [`moon.mod`](moon.mod). The CI Broker
is the separate Mosquitto `2.0.22` container described in
[`.github/workflows/ci.yml`](.github/workflows/ci.yml); it is a test service,
not part of Scantling or either MoonBit dependency.

## Position among MoonBit MQTT packages

Scantling's included MQTT client runtime opens TCP connections and drives
client-side request/response and delivery flows. This overlaps with the
existing
[`zbhzs1/moonbit-mqtt` package](https://mooncakes.io/docs/zbhzs1/moonbit-mqtt)
which provides MQTT 3.1.1 packet encoding and decoding; its README places
network transport and client runtime outside its current scope. A separate
[`ChaonanShen/moonbit-mqtt-broker` package](https://mooncakes.io/docs/ChaonanShen/moonbit-mqtt-broker%400.4.0)
implements a Broker. Neither package is evidence that Scantling is the only
MQTT implementation or that user demand has been validated. The peer's
test-tool role is distinct from a client library: it acts as a scripted
broker-side endpoint for checking an independently launched client. This
comparison describes scope only; package capabilities can change and should
be rechecked against their linked sources.

Scantling does not claim to be the only MoonBit MQTT client. The peer's public
Script/Exchange API lets MoonBit tests define packet matchers and response
handlers, while `SCANTLING_FAULT_SCRIPT` lets command-line users run a
line-oriented scenario file with an independent client. Both entry points use
the same ordered exchange runner. Text expectations can match packet type,
PUBLISH QoS, packet identifier, exact PUBLISH/SUBSCRIBE topic, PUBLISH payload
bytes, and retain/DUP flags. The peer handles one TCP connection per run
and is not a general Broker, load tester, or complete protocol suite. Its
script grammar, scenarios, and coverage limits are listed in
[`docs/fault-peer.md`](docs/fault-peer.md).

## Run the fault-injection peer

The peer listens on loopback port `1885` by default and accepts one connection.
For a successful QoS 1 publish exchange, start it in one terminal:

```powershell
$env:SCANTLING_FAULT_SCENARIO = "accept-publish-qos1"
$env:SCANTLING_FAULT_PORT = "1885"
moon run --target native examples/mqtt_fault_peer
```

Then, in another terminal with `mosquitto_pub` installed:

```sh
mosquitto_pub -V mqttv311 -h 127.0.0.1 -p 1885 \
  -t scantling/smoke -m hello -q 1
```

The peer logs its selected scenario and exits after one publish exchange.
Other scenarios can be selected with `SCANTLING_FAULT_SCENARIO`; see the
[scenario table](docs/fault-peer.md). Bind only to loopback: this one-shot test
server has no authentication or production hardening.

To run an authored text scenario without changing MoonBit source, start the
scripted CONNECT/SUBSCRIBE/PUBLISH/DISCONNECT flow:

```powershell
$env:SCANTLING_FAULT_SCRIPT = "examples/mqtt_fault_peer/scripts/subscriber-message.scantling"
$env:SCANTLING_FAULT_PORT = "1886"
moon run --target native examples/mqtt_fault_peer
```

In a second terminal, receive exactly one message with the independent
Mosquitto client:

```sh
mosquitto_sub -V mqttv311 -h 127.0.0.1 -p 1886 \
  -t scantling/scripted/notice -q 0 -C 1 -W 10 -v
```

The expected output is `scantling/scripted/notice scripted-message`. This
scenario and the QoS 2 and idle-event scripts passed with independent
Mosquitto clients in [CI run 41185493873](https://github.com/Wchwch777/Scantling/actions/runs/41185493873).

## Run the example

Start Mosquitto with the repository's test configuration. With Docker:

```sh
docker run --rm --detach --name scantling-mosquitto \
  --publish 1883:1883 \
  --volume "$PWD/.github/mosquitto.conf:/mosquitto/config/mosquitto.conf:ro" \
  eclipse-mosquitto:2.0.22
```

On PowerShell:

```powershell
$config = (Resolve-Path .github/mosquitto.conf).Path
docker run --rm --detach --name scantling-mosquitto `
  --publish 1883:1883 `
  --mount "type=bind,source=$config,target=/mosquitto/config/mosquitto.conf,readonly" `
  eclipse-mosquitto:2.0.22
```

Then run from the repository root:

```sh
moon run --target native examples/mqtt_client
```

Stop the broker with `docker stop scantling-mosquitto` after the example exits.

To connect to a Broker that requires MQTT username/password credentials, pass
`username=Some("device-1")` and `password=Some(b"example-password")` to
`Client::connect`. A password requires a username. Plain TCP does not encrypt
these credentials; TLS is not implemented.

## Development and verification

```sh
moon update
moon fmt --check
moon check --target wasm
moon test --target wasm
moon check --target native
moon test --target native
```

The native integration tests include the fault peer and an independent
Mosquitto Broker round trip. CI also runs the independent `mosquitto_pub`
client against the peer's accepted QoS 0/1 scenarios, its CONNACK code 5
rejection, and its truncated-CONNACK response. For the truncated frame, the
client must exit with an error before the timeout; the peer must complete its
one-shot exchange. CI sets
`SCANTLING_MOSQUITTO_HOST=127.0.0.1`, starts
Mosquitto `2.0.22`, and runs both test targets. CI also starts a separate
username/password-protected Broker on port `1884` and runs authentication
success and rejection tests; set `SCANTLING_MOSQUITTO_AUTH_HOST=127.0.0.1` to
run those tests locally against an equivalently configured Broker. Pushed
revisions [`9ad42e2`](https://github.com/Wchwch777/Scantling/commit/9ad42e298dc6fb7dd7cfc1044e07be8fa47defd)
and [`ffac618`](https://github.com/Wchwch777/Scantling/commit/ffac61868d9c177a2497de7ba64fe00521ead28f)
passed [GitHub Actions runs 41185493873](https://github.com/Wchwch777/Scantling/actions/runs/41185493873)
and [41185987629](https://github.com/Wchwch777/Scantling/actions/runs/41185987629):
formatting, Wasm and Native type checks, 26 Wasm tests, 49 Native tests,
authenticated and unauthenticated Mosquitto Broker paths, the ten-second
client example, and independent Mosquitto CLI checks for QoS 0/1, rejection,
truncated CONNACK, scripted QoS 2, subscription/message delivery, and idle
Keep Alive. Earlier runs [40636347859](https://github.com/Wchwch777/Scantling/actions/runs/40636347859)
and [40638010819](https://github.com/Wchwch777/Scantling/actions/runs/40638010819)
are historical baselines; runs 41185493873 and 41185987629 are the evidence
for the text-script scenarios on the current code revision.
Without that environment variable, the real-Broker test is skipped. The
protocol checks are not a full MQTT conformance suite. Review and verification
records are in [`docs/owner-review.md`](docs/owner-review.md).

## Project records

- [Project application](docs/project-application.md)
- [Use cases and evidence boundaries](docs/use-cases.md)
- [AI-assisted development disclosure](AI_ASSISTED.md)
- [Owner review status](docs/owner-review.md)
