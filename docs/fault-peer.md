# MQTT fault-injection peer

`examples/mqtt_fault_peer` runs a native, one-connection MQTT 3.1.1 peer on
loopback. It gives a client a deterministic broker-side response so a developer
can inspect how that client handles selected protocol paths. It is not a full
Broker, fuzzing engine, load tool, or certification suite.

## Scenarios

| `SCANTLING_FAULT_SCENARIO` | Peer behavior | Verification |
| --- | --- | --- |
| `reject-connect` | Replies to CONNECT with CONNACK return code 5 (Not Authorized). | Native integration test expects `ClientError::Rejected(5)`. CI also runs the independent Mosquitto 3.1.1 CLI; it must report `CONNACK (5)` and exit with code 5. |
| `truncate-connack` | Sends only part of a CONNACK frame, then closes. | Native integration test expects a transport failure. CI also checks that the independent Mosquitto CLI exits with an error before the timeout. |
| `mismatched-puback` | Accepts CONNECT, reads a QoS 1 PUBLISH, then acknowledges a different packet identifier. | Native integration test expects a mismatched-acknowledgement error. |
| `unexpected-suback-response` | Accepts CONNECT and reads SUBSCRIBE, then sends PINGRESP instead of SUBACK. | Native integration test expects an unexpected-packet error and checks that the client disconnects. |
| `accept-publish-qos0` | Accepts CONNECT and receives one QoS 0 PUBLISH, then closes the one-shot connection. | CI's independent Mosquitto CLI completes a QoS 0 publish. |
| `accept-publish-qos1` | Accepts CONNECT, receives one QoS 1 PUBLISH, replies with matching PUBACK, then closes the one-shot connection. | CI's independent Mosquitto CLI completes a QoS 1 publish. |

Scantling's included asynchronous client is not the main differentiator: its
MQTT client behavior overlaps with the public
[`moon-mqtt-client`](https://github.com/Strangelight-Merser/moon-mqtt-client)
project, whose public README describes application connectivity through an
asynchronous client runtime. The peer adds a different role: it scripts
broker-side responses and lets external clients check their wire behavior. The
`reject-connect` CI path verifies that an independent
`mosquitto_pub` process sees CONNACK code 5 and exits with the matching code;
the QoS 0/1 cases verify accepted PUBLISH exchanges. The truncated-CONNACK
case checks that Mosquitto reports a failed connection promptly when the peer
closes after an incomplete frame. Mismatched PUBACK and unexpected SUBACK are
still checked only against Scantling's own client; the peer has not been tested
against `moon-mqtt-client` or a wider set of clients. This is a small regression
and interoperability matrix, not a
general-purpose broker, complete test suite, or MQTT 3.1.1 conformance
certification.

## Caller-defined scripts

The public Script/Exchange API turns the peer into a composable test fixture.
Each named Exchange consumes one decoded packet, calls a caller-provided
matcher, then calls a responder with that packet. A responder can return
multiple actions: SendPacket for any codec-supported MQTT packet, SendRaw for
malformed or truncated bytes, Delay for a deterministic pause, and Close to
end the connection at a chosen state. The six named scenarios above are
convenience presets built on the same ordered exchange runner.

The command-line peer also accepts a caller-authored text file through
`SCANTLING_FAULT_SCRIPT`. This makes the scenario usable by an independently
launched client without editing or recompiling MoonBit code. Its current
line-oriented grammar is:

| Directive | Meaning |
| --- | --- |
| `expect PACKET [qos=N] [id=N] [topic=NAME] [payload_hex=HH[,HH...]] [retain=true\|false] [dup=true\|false]` | Consume the next decoded packet of this type; PUBLISH can be matched by QoS, identifier, exact topic, payload bytes, retain, and DUP flags. `topic=NAME` also exactly matches one SUBSCRIBE filter. |
| `send CONNACK code=N session_present=true\|false` | Send an MQTT 3.1.1 connection response (return code 0–5). |
| `send SUBACK id=request\|N codes=0,1,2,128` | Send requested or fixed packet identifier and one or more subscription results. |
| `send PUBACK\|PUBREC\|PUBREL\|PUBCOMP\|UNSUBACK id=request\|N` | Send the corresponding packet identifier response. `id=request` copies an identifier only from a compatible request. |
| `send PINGRESP` | Answer a PINGREQ. |
| `send PUBLISH topic=NAME qos=0\|1\|2 [id=N] [payload_hex=HH[,HH...]] [retain=true\|false] [dup=true\|false]` | Send a broker-to-client publication. QoS 1/2 requires a fixed identifier; QoS 0 forbids one. Payload bytes are hexadecimal; the topic is one whitespace-free MQTT topic name. |
| `raw HEX...` | Write explicit bytes, including malformed or truncated packets. |
| `wait MILLISECONDS` | Pause before the next response, from 0 through 60000 ms. |
| `close` | Close after the current exchange's preceding actions. |

Blank lines and lines beginning with `#` are ignored. Every response
directive belongs to the most recent `expect`; the peer processes exchanges in
order on one TCP connection and closes after the last one. The parser reports
the source line for invalid directives, unsupported options, invalid packet
identifiers, and malformed hexadecimal data. Each script should use an
explicit `expect DISCONNECT` when the client is expected to close normally.

For example, the included
[`subscriber-message.scantling`](../examples/mqtt_fault_peer/scripts/subscriber-message.scantling)
accepts CONNECT and SUBSCRIBE, sends SUBACK and a QoS 0 PUBLISH, then expects
DISCONNECT. Run it in one terminal:

```powershell
$env:SCANTLING_FAULT_SCRIPT = "examples/mqtt_fault_peer/scripts/subscriber-message.scantling"
$env:SCANTLING_FAULT_PORT = "1885"
moon run --target native examples/mqtt_fault_peer
```

Then use an independent Mosquitto subscriber in another terminal:

```sh
mosquitto_sub -V mqttv311 -h 127.0.0.1 -p 1885 \
  -t scantling/scripted/notice -q 0 -C 1 -W 10 -v
```

Expected output is `scantling/scripted/notice scripted-message`. The external
subscriber path passed in [GitHub Actions run 41185493873](https://github.com/Wchwch777/Scantling/actions/runs/41185493873)
on commit [`9ad42e2`](https://github.com/Wchwch777/Scantling/commit/9ad42e298dc6fb7dd7cfc1044e07be8fa47defd).

Two further reference scripts exercise distinct protocol states with
independent Mosquitto CLI clients:

| Script | Client command | What the exchange checks |
| --- | --- | --- |
| [`qos2-publish.scantling`](../examples/mqtt_fault_peer/scripts/qos2-publish.scantling) | `mosquitto_pub -V mqttv311 -q 2 -t scantling/ci/qos2 -m qos2-message` | A QoS 2 PUBLISH receives PUBREC, the matching PUBREL receives PUBCOMP, then the client disconnects. Packet identifiers are copied from the live request. |
| [`idle-event.scantling`](../examples/mqtt_fault_peer/scripts/idle-event.scantling) | `mosquitto_sub -V mqttv311 -k 5 -q 0 -C 1 -W 15 -t scantling/idle/event` | A subscriber stays connected through two PINGREQ/PINGRESP exchanges and then receives `after-idle`. |

The corresponding native integration paths use the same script language with
Scantling's client: one completes the filtered QoS 2 handshake, and one calls
`receive_with_keep_alive()` until a later event arrives. These paths passed in
[GitHub Actions run 41185493873](https://github.com/Wchwch777/Scantling/actions/runs/41185493873)
on commit [`9ad42e2`](https://github.com/Wchwch777/Scantling/commit/9ad42e298dc6fb7dd7cfc1044e07be8fa47defd),
using MoonBit `0.10.15+943464bfa` and Mosquitto `2.0.22`. The run passed all
26 Wasm and 49 Native tests and exercised the independent subscriber, QoS 2,
and idle-event scenarios. These are finite scripted checks, not broad
interoperability data or complete MQTT conformance coverage.

The native integration suite exercises this extension path directly. A custom
script copies the incoming SUBSCRIBE packet identifier into a SUBACK while
granting QoS 2 to a QoS 0 request, and verifies that the client rejects the
invalid grant. A second script drives an outbound QoS 2 exchange through a
duplicate PUBREC and retransmitted PUBREL. A third sends a truncated CONNACK
with SendRaw and closes the socket. An abbreviated custom script looks like:

~~~moonbit
let script = @fault_peer.Script::new([
  @fault_peer.Exchange::new(
    "CONNECT",
    packet => match packet {
      @codec.ConnectPacket(_) => true
      _ => false
    },
    _packet => [
      @fault_peer.Action::SendRaw([0x20, 0x02, 0x00]),
      @fault_peer.Action::Close,
    ],
  ),
])
let peer = @fault_peer.Peer::with_script(script)
~~~

The example uses the @codec and @fault_peer aliases from the package imports.
See the
[custom scripted integration test](../mqtt/integration_test/client_test.mbt)
and the [script API implementation](../mqtt/fault_peer/peer.mbt).

Eclipse Paho's Testing Utilities describe a broader toolkit with an MQTT
3.1.1/5.0 test Broker, a test client, a network proxy, packet
serialization/deserialization modules, and load/connection-loss testing.
Scantling currently covers a narrower slice: ordered broker-side scripted
exchanges for one client connection, exposed as a MoonBit API and text-file
runner, plus selected checks against Mosquitto CLI clients. It does not provide
Paho's proxy, load/connection-loss tool, broad test-client suite, or complete
conformance coverage. See the
[Paho Testing Utilities source](https://github.com/eclipse-paho/paho.mqtt.testing).

## Protocol coverage map

The broader client test suite exercises protocol paths beyond the six CLI
presets. The table distinguishes local scripted-peer coverage from checks
against an independent implementation:

| Protocol path | Current automated coverage | Independent client/Broker check |
| --- | --- | --- |
| CONNECT/CONNACK | Clean Session validation, refusal, truncated frame, early EOF. | Mosquitto CLI refusal and truncated-CONNACK paths. |
| SUBSCRIBE/SUBACK | Batched filters, response identifiers, result count and granted QoS; unexpected packet and over-grant fault scripts. | In CI, Mosquitto CLI connects, subscribes, receives a broker-scripted PUBLISH, and disconnects ([run 41185493873](https://github.com/Wchwch777/Scantling/actions/runs/41185493873)). |
| UNSUBSCRIBE/UNSUBACK | Batched filter request and matching response identifier. | Not currently tested against an independent client as a fault case. |
| PUBLISH QoS 0/1 | Successful sends, matching and mismatched PUBACK, inbound buffering during an acknowledgement. | Mosquitto CLI completes accepted QoS 0/1 publishes against the peer. |
| PUBLISH QoS 2 | Four-packet publish handshake and duplicate PUBREC/PUBREL retransmission. | Mosquitto `mosquitto_pub` completes the scripted QoS 2 PUBREC/PUBREL/PUBCOMP path in CI ([run 41185493873](https://github.com/Wchwch777/Scantling/actions/runs/41185493873)). |
| Inbound QoS 2 | PUBREC/PUBREL/PUBCOMP and duplicate-delivery suppression. | Client receives QoS 2 delivery from Mosquitto. |
| Keep Alive and DISCONNECT | Ping response, missing-PINGRESP closure, idle event delivery and orderly disconnect. | The ten-second application example runs against Mosquitto; independent `mosquitto_sub` completes two ping exchanges before the scripted event in CI ([run 41185493873](https://github.com/Wchwch777/Scantling/actions/runs/41185493873)). |

This is a traceable regression matrix, not complete MQTT 3.1.1 conformance
coverage. It does not cover every normative requirement, every state
combination, or a broad set of independent clients. Scripts are linear and
one-connection; they do not branch, schedule concurrent clients, or measure
load. The detailed example
evidence and non-goals are in the
[scenario-by-scenario use-case record](use-cases.md); the corresponding tests
are in the [native integration suite](../mqtt/integration_test/client_test.mbt).

## Run

Start the peer in one terminal. The default scenario is `reject-connect` and
the default port is `1885`:

```powershell
$env:SCANTLING_FAULT_SCENARIO = "accept-publish-qos1"
$env:SCANTLING_FAULT_PORT = "1885"
moon run --target native examples/mqtt_fault_peer
```

In another terminal, connect an MQTT 3.1.1 client to the printed loopback
address. For example:

```sh
mosquitto_pub -V mqttv311 -h 127.0.0.1 -p 1885 \
  -t scantling/smoke -m hello -q 1
```

To inspect the broker-rejection path with Mosquitto, set the peer scenario to
`reject-connect`, then run:

```sh
mosquitto_pub -V mqttv311 -d -h 127.0.0.1 -p 1885 \
  -t scantling/smoke -m hello
```

The command should fail with exit code `5` after receiving CONNACK code `5`
(Not Authorized). Mosquitto documents that a broker-level MQTT refusal returns
the CONNACK code as the command's exit status in its
[`mosquitto_pub` manual](https://mosquitto.org/man/mosquitto_pub-1.html#exit-status).
The successful QoS 0/1, rejected-CONNACK, and truncated-CONNACK CLI paths are
automated in CI.

To exercise the truncated frame, start another peer with
`SCANTLING_FAULT_SCENARIO=truncate-connack` and a free loopback port, then run
the same `mosquitto_pub` command against that port. The client should exit
nonzero promptly after the peer closes the incomplete CONNACK; CI fails if the
client accepts the response or times out.

The peer exits after its selected exchange. Choose another scenario by setting
`SCANTLING_FAULT_SCENARIO` to one of the table values. Set
`SCANTLING_FAULT_PORT=0` to request an ephemeral port; the selected port is
printed when the peer starts. The peer binds only to `127.0.0.1` and has no
authentication, TLS, retries, persistence, or concurrent-connection support.

The implementation is in [`mqtt/fault_peer/peer.mbt`](../mqtt/fault_peer/peer.mbt);
the regression and interoperability paths are in
[`mqtt/integration_test/client_test.mbt`](../mqtt/integration_test/client_test.mbt)
and [`.github/workflows/ci.yml`](../.github/workflows/ci.yml).
