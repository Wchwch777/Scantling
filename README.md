# Scantling — MoonBit MQTT 3.1.1 Client

Scantling is an asynchronous MQTT 3.1.1 client runtime over TCP for MoonBit.
The current project direction is a protocol client: the repository's earlier
history includes a one-dimensional cutting-stock optimizer/visualizer and an
intervening GraphQL-over-HTTP prototype; neither is the maintained project.
The MQTT runtime starts at [`679c721`](https://github.com/Wchwch777/Scantling/commit/679c721),
after the [GraphQL pivot](https://github.com/Wchwch777/Scantling/commit/d424a6f)
and the earlier [cutting-stock work](https://github.com/Wchwch777/Scantling/commit/458215b).

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
- Sequential API calls on each connection. Do not issue concurrent operations
  on the same client.

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

This is a small MQTT 3.1.1 TCP client, not a production-complete SDK or a
conformance certification. TLS, automatic reconnection,
automatic Keep Alive scheduling, operation timeouts, persistent sessions,
MQTT 5.0, and WebSocket transport are not implemented. QoS 2 exchange state is
kept in memory for the current clean-session connection; it is not persisted
across disconnects. The application
must schedule PINGREQ within the configured Keep Alive interval. The sample
topics and payloads below are protocol demonstrations; they are not evidence
of customer deployments, physical devices, user research, or measured demand.
This repository does not claim a Scantling Mooncakes release.

## Three protocol demonstrations

The runnable example uses separate publisher and subscriber connections for
three representative message flows:

1. **Telemetry-shaped message:** `demo/sensor/temperature` carries `21.5`.
2. **Command-shaped message:** `demo/device/device-7/cmd` carries
   `SET_TEMP=22.0`.
3. **Event-shaped message:** `demo/service/orders/created` carries
   `order_id=demo-1`.

In each case the subscriber receives the opaque payload; the example does not
simulate a sensor, execute a device command, or parse a business event. See the
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

Scantling's scope is the MQTT client runtime: it opens TCP connections and
drives client-side request/response and delivery flows. The existing
[`zbhzs1/moonbit-mqtt` package](https://mooncakes.io/docs/zbhzs1/moonbit-mqtt)
provides MQTT 3.1.1 packet encoding and decoding, while its README places
network transport and client runtime outside its current scope. A separate
[`ChaonanShen/moonbit-mqtt-broker` package](https://mooncakes.io/docs/ChaonanShen/moonbit-mqtt-broker%400.4.0)
implements a Broker, which serves the opposite role in the client/Broker
connection. These are adjacent ecosystem components, not evidence that
Scantling is the only MQTT implementation or that user demand has been
validated. This comparison describes scope only; package capabilities can
change and should be rechecked against their linked sources.

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

The native integration tests include a local protocol peer and an independent
Mosquitto round trip. CI sets `SCANTLING_MOSQUITTO_HOST=127.0.0.1`, starts
Mosquitto `2.0.22`, and runs both test targets. CI also starts a separate
username/password-protected Broker on port `1884` and runs authentication
success and rejection tests; set `SCANTLING_MOSQUITTO_AUTH_HOST=127.0.0.1` to
run those tests locally against an equivalently configured Broker. A successful
full CI snapshot
for the batched-subscription and bounded-queue tests
[`2c30c01`](https://github.com/Wchwch777/Scantling/commit/2c30c0142e0ebb5ca15870940f1700beabbff6cd)
passed 15 Wasm tests and 27 Native tests, including the real-Broker path:
[GitHub Actions run 39122468377](https://github.com/Wchwch777/Scantling/actions/runs/39122468377).
See the [main-branch workflow runs](https://github.com/Wchwch777/Scantling/actions/workflows/ci.yml)
for newer commits.
Without that environment variable, the real-Broker test is skipped. The
protocol checks are not a full MQTT conformance suite. Review and verification
records are in [`docs/owner-review.md`](docs/owner-review.md).

## Project records

- [Project application](docs/project-application.md)
- [Use cases and evidence boundaries](docs/use-cases.md)
- [AI-assisted development disclosure](AI_ASSISTED.md)
- [Owner review status](docs/owner-review.md)
