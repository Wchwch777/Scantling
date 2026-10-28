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
malformed or truncated bytes, and Close to end the connection at a chosen
state. The six command-line scenarios above are convenience presets built on
the same ordered script runner. The CLI currently exposes those presets;
custom scripts are composed by MoonBit test code using the
scantling_mqtt_client/mqtt/fault_peer package.

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

Eclipse Paho describes a broader MQTT 3.1.1 testing project with a test broker,
a basic test client, conformance statements, and a model-based testing
component. Scantling follows the useful separation between broker-side test
behavior and explicit client coverage evidence, but it does not yet provide
an equivalent full conformance suite or model-based case generator. See the
[Paho Testing Utilities overview](https://eclipse.dev/paho/components/testing/).

## Protocol coverage map

The broader client test suite exercises protocol paths beyond the six CLI
presets. The table distinguishes local scripted-peer coverage from checks
against an independent implementation:

| Protocol path | Current automated coverage | Independent client/Broker check |
| --- | --- | --- |
| CONNECT/CONNACK | Clean Session validation, refusal, truncated frame, early EOF. | Mosquitto CLI refusal and truncated-CONNACK paths. |
| SUBSCRIBE/SUBACK | Batched filters, response identifiers, result count and granted QoS; unexpected packet and over-grant fault scripts. | Not currently tested against an independent client as a fault case. |
| UNSUBSCRIBE/UNSUBACK | Batched filter request and matching response identifier. | Not currently tested against an independent client as a fault case. |
| PUBLISH QoS 0/1 | Successful sends, matching and mismatched PUBACK, inbound buffering during an acknowledgement. | Mosquitto CLI completes accepted QoS 0/1 publishes against the peer. |
| PUBLISH QoS 2 | Four-packet publish handshake and duplicate PUBREC/PUBREL retransmission. | Client completes a QoS 2 round trip with Mosquitto. |
| Inbound QoS 2 | PUBREC/PUBREL/PUBCOMP and duplicate-delivery suppression. | Client receives QoS 2 delivery from Mosquitto. |
| Keep Alive and DISCONNECT | Ping response, missing-PINGRESP closure, idle event delivery and orderly disconnect. | Ten-second application example runs against Mosquitto. |

This is a traceable regression matrix, not complete MQTT 3.1.1 conformance
coverage. It does not cover every normative requirement, every state
combination, or a broad set of independent clients. The detailed example
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
