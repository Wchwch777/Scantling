# MQTT fault-injection peer

`examples/mqtt_fault_peer` runs a native, one-connection MQTT 3.1.1 peer on
loopback. It gives a client a deterministic broker-side response so a developer
can inspect how that client handles selected protocol paths. It is not a full
Broker, fuzzing engine, load tool, or certification suite.

## Scenarios

| `SCANTLING_FAULT_SCENARIO` | Peer behavior | Expected result for the tested client |
| --- | --- | --- |
| `reject-connect` | Replies to CONNECT with CONNACK return code 5 (Not Authorized). | Connection returns a broker-rejection error. |
| `truncate-connack` | Sends only part of a CONNACK frame, then closes. | Connection returns a transport failure. |
| `mismatched-puback` | Accepts CONNECT, reads a QoS 1 PUBLISH, then acknowledges a different packet identifier. | Publish reports a mismatched-acknowledgement error. |
| `unexpected-suback-response` | Accepts CONNECT and reads SUBSCRIBE, then sends PINGRESP instead of SUBACK. | Subscribe reports an unexpected-packet error and the client disconnects. |
| `accept-publish-qos0` | Accepts CONNECT, receives one QoS 0 PUBLISH, then expects DISCONNECT. | Client completes a QoS 0 publish and closes the one-shot session. |
| `accept-publish-qos1` | Accepts CONNECT, receives one QoS 1 PUBLISH, replies with matching PUBACK, then expects DISCONNECT. | Client completes the QoS 1 publish and closes the one-shot session. |

The four fault cases are exercised against Scantling's client in native
integration tests. CI also runs the accepted QoS 0 and QoS 1 exchanges against
the independent `mosquitto_pub` client. Those checks show the peer's observable
wire behavior for these scenarios; they do not establish complete MQTT 3.1.1
conformance.

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
mosquitto_pub -h 127.0.0.1 -p 1885 -t scantling/smoke -m hello -q 1
```

The peer exits after its selected exchange. Choose another scenario by setting
`SCANTLING_FAULT_SCENARIO` to one of the table values. Set
`SCANTLING_FAULT_PORT=0` to request an ephemeral port; the selected port is
printed when the peer starts. The peer binds only to `127.0.0.1` and has no
authentication, TLS, retries, persistence, or concurrent-connection support.

The implementation is in [`mqtt/fault_peer/peer.mbt`](../mqtt/fault_peer/peer.mbt);
the regression and interoperability paths are in
[`mqtt/integration_test/client_test.mbt`](../mqtt/integration_test/client_test.mbt)
and [`.github/workflows/ci.yml`](../.github/workflows/ci.yml).
