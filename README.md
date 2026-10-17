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
- One topic filter per SUBSCRIBE or UNSUBSCRIBE call, awaiting SUBACK or
  UNSUBACK.
- QoS 0 publish and QoS 1 publish that waits for the matching PUBACK.
- QoS 0/1 PUBLISH receive; QoS 1 deliveries are acknowledged before the
  message is returned.
- PINGREQ/PINGRESP, DISCONNECT, topic/filter validation, and a 1 MiB inbound
  packet-body limit.
- Sequential API calls on each connection. Do not issue concurrent operations
  on the same client.

October code work added an independent Mosquitto interoperability path and
explicit protocol-error handling for broker rejection, invalid Clean Session
state, mismatched acknowledgements, and truncated frames. The implementation
and tests are visible in [`ecbda25`](https://github.com/Wchwch777/Scantling/commit/ecbda25b94f463e534e3efa9c4fa11e6bb66f2f2) and
[`84538b8`](https://github.com/Wchwch777/Scantling/commit/84538b8).

## Boundaries

This is a small MQTT 3.1.1 TCP client, not a production-complete SDK or a
conformance certification. TLS, MQTT authentication, automatic reconnection,
automatic Keep Alive scheduling, operation timeouts, persistent sessions,
QoS 2, MQTT 5.0, and WebSocket transport are not implemented. The application
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
Mosquitto `2.0.22`, and runs both test targets. Without that environment
variable, the real-Broker test is skipped. The protocol checks are not a full
MQTT conformance suite. Code-baseline CI evidence is recorded in
[`docs/owner-review.md`](docs/owner-review.md).

## Project records

- [Project application](docs/project-application.md)
- [Use cases and evidence boundaries](docs/use-cases.md)
- [AI-assisted development disclosure](AI_ASSISTED.md)
- [Owner review status](docs/owner-review.md)
