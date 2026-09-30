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
- Receive QoS 0 and QoS 1 PUBLISH packets; acknowledge QoS 1 before returning
  the message to the caller.
- Decode framed MQTT packets with a 1 MiB inbound packet limit.
- Packet encoding and decoding delegated to the Apache-2.0
  [`moonbit-mqtt` codec](https://github.com/zbhzs1/moonbit-mqtt).

The initial runtime does not implement TLS, authentication, automatic
reconnection, scheduled keep-alive pings, QoS 1 publishing, QoS 2 session
handling, MQTT 5.0, or WebSocket transport. Do not use it for production
connections that require these features.

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
  let message = client.receive()
  println("Received \{message.topic}: \{message.payload}")
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

The portable tests cover MQTT Remaining Length framing and input limits. A
native integration test is provided for a local TCP broker peer through CONNECT,
SUBSCRIBE, QoS 0 PUBLISH, inbound QoS 1/PUBACK, and DISCONNECT. That native test
passed in [GitHub Actions run 36738625531](https://github.com/Wchwch777/Scantling/actions/runs/36738625531)
on commit `3b165ef`. The implementation is unchanged from code commit
`a3d3e04`; later commits and the current workspace contain documentation-only
changes. Native has not been rerun on this Windows machine. A local
protocol-peer test is not a substitute for interoperability testing against
an independent external broker.

See [`AI_ASSISTED.md`](AI_ASSISTED.md) for the assistance boundary and
[`docs/owner-review.md`](docs/owner-review.md) for the owner's review of the
MQTT revision and documentation synchronization.
