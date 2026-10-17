# Scantling — MoonBit MQTT Client

An asynchronous MQTT 3.1.1 TCP client runtime for MoonBit. Scantling builds on
the existing [`zbhzs1/moonbit-mqtt`](https://mooncakes.io/docs/zbhzs1/moonbit-mqtt)
packet codec instead of reimplementing packet encoding. It adds connection
handshake, topic subscription, QoS 0 publish, inbound QoS 1 acknowledgement,
and a native TCP transport.

The project targets a reusable messaging protocol layer, not one industry or
one device. MQTT is used by IoT telemetry, device command channels, and
application event messaging. These are intended application areas, not claims
of existing Scantling deployments or surveyed customers; see
[`docs/project-application.md`](docs/project-application.md) for the evidence
and scope boundaries.

The proposal's rationale is checkable: the competition charter recommends an
MQTT client/runtime direction, while the existing MoonBit MQTT package documents
packet codecs without transport or a client runtime. This is evidence of an
ecosystem capability gap, not proof of user adoption; see the proposal's
"Demand coverage and verifiable evidence" section.

## Current implementation

- TCP connection by host and port, MQTT 3.1.1 CONNECT / CONNACK handshake.
- Subscribe to one topic filter at a time and wait for the matching SUBACK.
- Publish QoS 0 messages.
- Publish QoS 1 messages and wait for the matching PUBACK.
- Receive QoS 0 and QoS 1 PUBLISH packets; acknowledge QoS 1 before returning
  the message to the caller.
- Unsubscribe from one topic filter and wait for the matching UNSUBACK.
- Send a PINGREQ and wait for PINGRESP; applications schedule these calls
  within the configured Keep Alive interval.
- Decode framed MQTT packets with a 1 MiB inbound packet limit.
- Packet encoding and decoding delegated to the Apache-2.0
  [`moonbit-mqtt` codec](https://github.com/zbhzs1/moonbit-mqtt).

The client is a small sequential API: callers should not issue concurrent
operations on the same connection. It does not implement TLS, authentication,
automatic reconnection, automatic Keep Alive scheduling, QoS 2 session
handling, MQTT 5.0, WebSocket transport, or operation timeouts. Do not use it
for production connections that require these features.

## Quick start

```moonbit
import {
  "scantling_mqtt_client/mqtt" @mqtt,
  "zbhzs1/moonbit-mqtt" @codec,
}

async fn main {
  let client = @mqtt.Client::connect(
    "127.0.0.1",
    port=1883,
    client_id="scantling-demo",
  )
  client.subscribe(topic="demo/temperature", qos=@codec.QoS1)
  client.publish(topic="demo/temperature", payload=b"21.5")
  client.publish_qos1(topic="demo/temperature", payload=b"21.5")
  let message = client.receive()
  println("Received \{message.topic} at QoS \{message.qos}: \{message.payload}")
  client.unsubscribe(topic="demo/temperature")
  client.ping()
  client.disconnect()
}
```

Start an MQTT 3.1.1 broker first. For example, with Mosquitto installed:

```sh
mosquitto -p 1883
```

Then run the example:

```sh
moon run --target native examples/mqtt_client
```

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
integration tests cover both a local TCP protocol peer and an independent
Mosquitto broker. The CI starts Mosquitto 2.0.22 with the checked-in test
configuration, then verifies CONNECT, QoS 1 SUBSCRIBE, cross-client QoS 1
publish/delivery/PUBACK, PINGREQ/PINGRESP, UNSUBSCRIBE, and DISCONNECT.

To run the independent broker test locally, start Mosquitto with the same
configuration:

```sh
docker run --rm --detach --name scantling-mosquitto \
  --publish 1883:1883 \
  --volume "$PWD/.github/mosquitto.conf:/mosquitto/config/mosquitto.conf:ro" \
  eclipse-mosquitto:2.0.22
SCANTLING_MOSQUITTO_HOST=127.0.0.1 moon test --target native
docker stop scantling-mosquitto
```

On PowerShell, set `$env:SCANTLING_MOSQUITTO_HOST = "127.0.0.1"` before running
`moon test --target native`. Without that variable, the independent broker test
is skipped and the local TCP peer test still runs.

PowerShell broker startup:

```powershell
$config = (Resolve-Path .github/mosquitto.conf).Path
docker run --rm --detach --name scantling-mosquitto `
  --publish 1883:1883 `
  --mount "type=bind,source=$config,target=/mosquitto/config/mosquitto.conf,readonly" `
  eclipse-mosquitto:2.0.22
$env:SCANTLING_MOSQUITTO_HOST = "127.0.0.1"
moon test --target native
docker stop scantling-mosquitto
```

See [`AI_ASSISTED.md`](AI_ASSISTED.md) for the assistance boundary and
[`docs/owner-review.md`](docs/owner-review.md) for the owner's review of the
MQTT revision and documentation synchronization.
