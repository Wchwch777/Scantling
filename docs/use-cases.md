# MQTT message-flow examples and evidence

The scenarios below explain how the current client API could carry common
message shapes. They are protocol demonstrations, not validated customer
requirements, user research, hardware integrations, or deployment reports. All
three appear in the runnable [`main.mbt` example](../examples/mqtt_client/main.mbt),
which uses one subscriber connection and one publisher connection.

## 1. Telemetry-shaped message

- **Illustrative task:** an application subscribes to
  `demo/sensor/temperature` and receives a measurement payload.
- **Example flow:** the subscriber requests QoS 1, the publisher sends the
  opaque bytes `21.5`, and the subscriber receives and prints them. See the
  [topic and subscription](../examples/mqtt_client/main.mbt#L15) and the
  [publish/receive calls](../examples/mqtt_client/main.mbt#L23).
- **Implementation evidence:** [`subscribe`](../mqtt/client.mbt#L350) waits for
  SUBACK; [`publish_qos1`](../mqtt/client.mbt#L273) waits for the matching
  PUBACK; [`receive`](../mqtt/client.mbt#L435) acknowledges QoS 1 delivery
  before returning the message. The [loopback protocol test](../mqtt/integration_test/client_test.mbt#L33)
  checks subscription and inbound QoS 1 acknowledgement. The
  [Mosquitto round-trip test](../mqtt/integration_test/client_test.mbt#L313)
  checks one generic payload between separate clients in CI.
- **Not established:** no sensor, gateway, measurement schema, or deployed
  telemetry system is included. The Mosquitto test uses its own test topic and
  payload; it does not run this example's telemetry scenario.

## 2. Command-shaped message

- **Illustrative task:** a publisher sends opaque bytes to
  `demo/device/device-7/cmd` for a subscriber to receive.
- **Example flow:** the payload is `SET_TEMP=22.0`; the example prints what the
  subscriber receives. See the [topic and subscription](../examples/mqtt_client/main.mbt#L16)
  and the [publish/receive calls](../examples/mqtt_client/main.mbt#L27).
- **Implementation evidence:** the same [`publish_qos1`](../mqtt/client.mbt#L273)
  and [`receive`](../mqtt/client.mbt#L435) methods carry the bytes; the
  [QoS 1 loopback test](../mqtt/integration_test/client_test.mbt#L33) verifies
  a generic publish, matching PUBACK, and delivery path. The broker round trip
  provides a separate interoperability check, not a command-specific test.
- **Not established:** Scantling does not validate command syntax, identify or
  authorize a device, execute an action, or measure command latency/reliability.

## 3. Event-shaped message

- **Illustrative task:** an application receives opaque bytes on
  `demo/service/orders/created` and could pass them to its own event handler.
- **Example flow:** the example publishes `order_id=demo-1`, receives it on the
  separate subscriber connection, and prints the payload. See the
  [topic and subscription](../examples/mqtt_client/main.mbt#L17) and the
  [publish/receive calls](../examples/mqtt_client/main.mbt#L31).
- **Implementation evidence:** [`receive`](../mqtt/client.mbt#L435) returns the
  topic, bytes, QoS, and retain flag. The
  [loopback test](../mqtt/integration_test/client_test.mbt#L33) and
  [Mosquitto round trip](../mqtt/integration_test/client_test.mbt#L313)
  exercise generic message receipt, but neither checks event semantics.
- **Not established:** there is no event schema, decoder, ordering guarantee
  across reconnects, durable delivery, or business processing in this project.

## October protocol checks

The October code change also adds evidence beyond the three sample payloads:
unit tests cover broker return-code mapping, Clean Session CONNACK validation,
and matching PUBACK/UNSUBACK identifiers in
[`client.mbt`](../mqtt/client.mbt#L506); native local-peer tests cover broker
rejection, an invalid session flag, a mismatched PUBACK, and a truncated
CONNACK in [`client_test.mbt`](../mqtt/integration_test/client_test.mbt#L145).
The frame-reader unit tests cover truncated Remaining Length and the configured
1 MiB packet-body cap in [`client_test.mbt`](../mqtt/client_test.mbt#L2).
The [CI run for code commit `ecbda25`](https://github.com/Wchwch777/Scantling/actions/runs/39027210274)
passed with its Mosquitto service enabled.

## Shared scope

Scantling is a sequential MQTT 3.1.1 TCP client. It handles one topic filter
per subscribe/unsubscribe call and the exercised QoS 0/1 paths. It does not
provide TLS, MQTT authentication, automatic reconnect, automatic Keep Alive
scheduling, operation timeouts, persistent sessions, QoS 2, MQTT 5.0, or
WebSocket transport. The packet codec comes from the separately licensed
[`zbhzs1/moonbit-mqtt` package](https://mooncakes.io/docs/zbhzs1/moonbit-mqtt);
the runtime and dependency boundary are summarized in the
[README](../README.md#source-and-license-boundaries).
