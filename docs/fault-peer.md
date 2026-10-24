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
