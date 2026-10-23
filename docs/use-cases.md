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
  [topic and subscription](../examples/mqtt_client/main.mbt#L17) and the
  [publish/receive calls](../examples/mqtt_client/main.mbt#L25).
- **Implementation evidence:** [`subscribe`](../mqtt/client.mbt#L772) waits for
  SUBACK; [`publish_qos1`](../mqtt/client.mbt#L583) waits for the matching
  PUBACK; [`receive`](../mqtt/client.mbt#L849) acknowledges QoS 1 delivery
  before returning the message. The [loopback protocol test](../mqtt/integration_test/client_test.mbt#L40)
  checks subscription and inbound QoS 1 acknowledgement. The
  [Mosquitto round-trip test](../mqtt/integration_test/client_test.mbt#L854)
  checks one generic payload between separate clients in CI.
- **Not established:** no sensor, gateway, measurement schema, or deployed
  telemetry system is included. The Mosquitto test uses its own test topic and
  payload; it does not run this example's telemetry scenario.

## 2. Command-shaped message

- **Illustrative task:** a publisher sends opaque bytes to
  `demo/device/device-7/cmd` for a subscriber to receive.
- **Example flow:** the payload is `SET_TEMP=22.0`; the example prints what the
  subscriber receives. See the [topic and subscription](../examples/mqtt_client/main.mbt#L18)
  and the [publish/receive calls](../examples/mqtt_client/main.mbt#L29).
- **Implementation evidence:** the same [`publish_qos1`](../mqtt/client.mbt#L583)
  and [`receive`](../mqtt/client.mbt#L849) methods carry the bytes; the
  [QoS 1 loopback test](../mqtt/integration_test/client_test.mbt#L40) verifies
  a generic publish, matching PUBACK, and delivery path. The broker round trip
  provides a separate interoperability check, not a command-specific test.
- **Not established:** Scantling does not validate command syntax, identify or
  authorize a device, execute an action, or measure command latency/reliability.

## 3. Command-to-event flow with idle Keep Alive

- **Illustrative task:** an application receives opaque bytes on
  `demo/service/orders/created` and could pass them to its own event handler.
- **Example flow:** the subscriber first receives the command-shaped message,
  then waits on the same connection for an event while the publisher delays
  five seconds. With subscriber Keep Alive set to four seconds,
  `receive_with_keep_alive()` exchanges PINGREQ/PINGRESP before the event is
  published; it then returns `order_id=demo-1`. See the
  [subscriptions](../examples/mqtt_client/main.mbt#L21), [delayed publisher](../examples/mqtt_client/main.mbt#L39),
  and [keep-alive receive call](../examples/mqtt_client/main.mbt#L41).
- **Implementation evidence:** `receive_with_keep_alive()` schedules a ping
  during its own message wait, consumes PINGRESP, and returns a later delivery.
  The native [idle Keep Alive integration test](../mqtt/integration_test/client_test.mbt#L151)
  verifies two ping exchanges, receipt and QoS 1 acknowledgement of a complete
  delayed event, and receipt of a subsequent event. A second native
  [peer test](../mqtt/integration_test/client_test.mbt#L277) checks that a
  missing PINGRESP closes the connection and reports a keep-alive timeout.
  Both deterministic peer tests passed in the latest baseline CI run. The CI
  workflow now also runs the complete example against Mosquitto and checks the
  three printed topic/payload pairs and that the example spans the five-second
  idle interval; see the [current workflow runs](https://github.com/Wchwch777/Scantling/actions/workflows/ci.yml)
  for the current commit's result.
- **Not established:** there is no event schema, decoder, ordering guarantee
  across reconnects, durable delivery, or business processing in this project.

## October protocol checks

The October code changes also add evidence beyond the sample payloads:
unit tests cover Clean Session CONNACK validation, broker return-code mapping,
matching PUBACK identifiers, and UNSUBACK validation in
[the client unit tests](../mqtt/client.mbt#L1046). Native local-peer tests
cover invalid session state, broker rejection, mismatched PUBACK, and
truncated CONNACK bodies in
[`client_test.mbt`](../mqtt/integration_test/client_test.mbt#L616),
[broker rejection](../mqtt/integration_test/client_test.mbt#L658),
[mismatched PUBACK](../mqtt/integration_test/client_test.mbt#L680), and
[truncated CONNACK body](../mqtt/integration_test/client_test.mbt#L743). The
frame-reader unit tests cover truncated Remaining Length and the configured
1 MiB packet-body cap in [`client_test.mbt`](../mqtt/client_test.mbt#L2).
The earlier [CI run for code commit `ecbda25`](https://github.com/Wchwch777/Scantling/actions/runs/39027210274)
passed with its Mosquitto service enabled. The latest baseline for the Keep
Alive changes is [commit `27a8ab6` and CI run 39993827022](https://github.com/Wchwch777/Scantling/actions/runs/39993827022),
which passed 18 Wasm and 36 Native tests. The updated workflow additionally runs
the example against Mosquitto; its result is linked from the current workflow
runs above.

## Shared scope

Scantling is a sequential MQTT 3.1.1 TCP client. It handles single and batched
topic filters, and the exercised QoS 0/1/2 paths. The ordinary `receive()` can
wait indefinitely without sending pings. `receive_with_keep_alive()` sends
and validates MQTT pings only while it waits for a message, provided it is
called before the configured Keep Alive deadline; it does not impose a message-arrival
timeout, run in the background during other application work, or support
concurrent operations on one client. The client does not provide TLS,
automatic reconnect, general operation timeouts, persistent sessions, MQTT
5.0, or WebSocket transport. The packet codec comes from the separately licensed
[`zbhzs1/moonbit-mqtt` package](https://mooncakes.io/docs/zbhzs1/moonbit-mqtt);
the runtime and dependency boundary are summarized in the
[README](../README.md#source-and-license-boundaries).

Optional username/password CONNECT authentication is exercised against a
separate authenticated Mosquitto Broker in CI. Credentials use plain TCP and
are not encrypted because TLS is outside the current project scope.

## QoS 2 protocol path

- **Outbound:** [`publish_qos2`](../mqtt/client.mbt) sends a QoS 2 PUBLISH,
  validates the matching PUBREC, sends PUBREL, retransmits PUBREL if a duplicate
  PUBREC arrives, and completes after the matching PUBCOMP.
- **Inbound:** [`receive`](../mqtt/client.mbt) records each packet identifier,
  sends PUBREC, and exposes the payload only after PUBREL, then sends PUBCOMP.
  Duplicate in-flight PUBLISH packets are acknowledged without adding a second
  delivery; unknown or repeated PUBREL packets receive PUBCOMP without
  redelivery.
- **Evidence:** a native local-peer test checks the full outbound handshake,
  duplicate PUBREC handling, QoS 2 subscription grant, inbound delivery, and
  duplicate PUBREL handling. A separate CI Mosquitto test covers a real Broker
  QoS 2 subscribe/publish/receive round trip. Both are in
  [`mqtt/integration_test/client_test.mbt`](../mqtt/integration_test/client_test.mbt).
- **Boundary:** the exchange state is in memory and scoped to the current clean
  session. Persistent session recovery after disconnect is not implemented.
