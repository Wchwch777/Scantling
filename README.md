# Scantling — MoonBit MQTT 3.1.1 Client

Scantling is an asynchronous MQTT 3.1.1 TCP client runtime for MoonBit. It
reuses the [`zbhzs1/moonbit-mqtt`](https://github.com/zbhzs1/moonbit-mqtt)
packet codec and implements the client-side connection and message flow. The
repository demonstrates protocol-level telemetry, command, and application
event examples; it does not claim customer deployments or measured demand.
See the [project application](docs/project-application.md) and
[use-case evidence](docs/use-cases.md).

## Implemented

- TCP connection and MQTT CONNECT/CONNACK handshake.
- Subscribe to one topic filter at a time and wait for SUBACK; unsubscribe and
  wait for UNSUBACK.
- QoS 0 publish; QoS 1 publish with matching PUBACK.
- Receive QoS 0/1 PUBLISH packets; acknowledge QoS 1 before returning the
  message's topic, payload, QoS, and retain flag.
- PINGREQ/PINGRESP and a 1 MiB inbound packet-body limit.
- Validation for publish topics, subscription filters, and client identifiers.

The API is sequential: do not run concurrent operations on the same connection.
This version does not implement TLS, authentication, automatic reconnection,
automatic Keep Alive scheduling, operation timeouts, persistent sessions, QoS
2, MQTT 5.0, or WebSocket transport. Applications must schedule PINGREQ within
the configured Keep Alive interval where needed. This is not a production
complete MQTT SDK or a conformance certification.

## Run the example

The example connects two clients to a broker. One subscribes to three
representative topics; the other publishes telemetry, command-shaped, and
event-shaped messages at QoS 1. The first client prints the messages it receives.
This is a protocol demo, not a simulated physical device or application service.

Start a local broker. With Docker:

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

Then run the example from the repository root:

```sh
moon run --target native examples/mqtt_client
```

After it exits, stop the broker with `docker stop scantling-mosquitto`.

## Development and verification

```sh
moon update
moon fmt --check
moon check --target wasm
moon test --target wasm
moon check --target native
moon test --target native
```

The portable tests cover MQTT Remaining Length framing and input limits. Native
integration tests cover a local TCP protocol peer and an independent Mosquitto
2.0.22 broker. CI starts Mosquitto with [the checked-in test config](.github/mosquitto.conf)
and runs the broker integration path. For local integration testing, start the
broker as above, then run `moon test --target native`; on PowerShell, set
`$env:SCANTLING_MOSQUITTO_HOST = "127.0.0.1"` before the test command. Without
that variable, the real-broker test is skipped while the loopback test runs.

The preceding client/runtime baseline, commit
[`d7112e7`](https://github.com/Wchwch777/Scantling/commit/d7112e7bc57821cbe75701344c12931088aaf128),
passed [GitHub Actions run 39005161469](https://github.com/Wchwch777/Scantling/actions/runs/39005161469).
The current documentation/example revision has also passed the local checks
listed in [`docs/owner-review.md`](docs/owner-review.md); that prior CI run does
not establish production readiness or device deployment.

## Project records

- [Project application](docs/project-application.md)
- [Use cases and evidence boundaries](docs/use-cases.md)
- [AI-assisted development disclosure](AI_ASSISTED.md)
- [Owner review status](docs/owner-review.md)
