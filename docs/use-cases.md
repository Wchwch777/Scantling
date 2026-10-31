# MQTT message-flow examples and evidence

The scenarios below explain how the current client API could carry common
message shapes. They are protocol demonstrations, not validated customer
requirements, user research, hardware integrations, or deployment reports. All
three appear in the runnable [`main.mbt` example](../examples/mqtt_client/main.mbt),
which uses one application connection and one simulated-device connection in
the same process.

## 1. Telemetry-shaped message

- **Illustrative task:** an application subscribes to
  `demo/sensor/temperature` and receives a measurement payload.
- **Example flow:** the application subscribes at QoS 1, the simulated device
  publishes the opaque bytes `21.5`, and the application receives and prints
  them. See the
  [topic and subscription](../examples/mqtt_client/main.mbt#L17) and the
  [publish/receive calls](../examples/mqtt_client/main.mbt#L27).
- **Implementation evidence:** [`subscribe`](../mqtt/client.mbt#L772) waits for
  SUBACK; [`publish_qos1`](../mqtt/client.mbt#L583) waits for the matching
  PUBACK; [`receive`](../mqtt/client.mbt#L849) acknowledges QoS 1 delivery
  before returning the message. The [loopback protocol test](../mqtt/integration_test/client_test.mbt#L40)
  checks subscription and inbound QoS 1 acknowledgement. The
  [Mosquitto round-trip test](../mqtt/integration_test/client_test.mbt#L854)
  checks a generic payload between separate clients; the CI example run also
  checks this exact telemetry topic and payload against Mosquitto.
- **Not established:** no sensor, gateway, measurement schema, or deployed
  telemetry system is included. The telemetry bytes are demonstration data,
  not a real measurement source.

## 2. Command and reported state

- **Illustrative task:** an application sends a command to a device and reads
  its reported state.
- **Example flow:** the application publishes `SET_TEMP=22.0` to
  `demo/device/device-7/cmd`; the simulated device receives it and publishes
  `temperature=22.0` to `demo/device/device-7/reported`; the application then
  receives that report. See the [command and report flow](../examples/mqtt_client/main.mbt#L31).
- **Implementation evidence:** `publish_qos1` waits for PUBACK and `receive`
  acknowledges inbound QoS 1 messages before returning them. CI runs this full
  flow against Mosquitto and checks both output payloads. The client protocol
  test separately verifies the matching acknowledgement and delivery path.
- **Not established:** the device is another client in the same demo process;
  this is not a physical device, command executor, authorization layer, or
  business protocol. It does not measure command latency or reliability.

## 3. Command-to-event flow with idle Keep Alive

- **Illustrative task:** an application receives opaque bytes on
  `demo/service/orders/created` and could pass them to its own event handler.
- **Example flow:** after receiving the reported state, the application waits
  on the same connection for an event while the simulated device delays ten
  seconds. With application Keep Alive set to four seconds,
  `receive_with_keep_alive()` exchanges PINGREQ/PINGRESP before the event is
  published; it then returns `order_id=demo-1`. MQTT 3.1.1 allows the Broker
  to disconnect after 1.5 times the Keep Alive interval without client control
  traffic, so ten seconds exceeds the six-second timeout window for this
  configuration. See the [subscriptions](../examples/mqtt_client/main.mbt#L24),
  [delayed publisher](../examples/mqtt_client/main.mbt#L43), and
  [keep-alive receive call](../examples/mqtt_client/main.mbt#L46).
- **Implementation evidence:** `receive_with_keep_alive()` schedules a ping
  during its own message wait, consumes PINGRESP, and returns a later delivery.
  The native [idle Keep Alive integration test](../mqtt/integration_test/client_test.mbt#L151)
  verifies two ping exchanges, receipt and QoS 1 acknowledgement of a complete
  delayed event, and receipt of a subsequent event. A second native
  [peer test](../mqtt/integration_test/client_test.mbt#L277) checks that a
  missing PINGRESP closes the connection and reports a keep-alive timeout.
  Both deterministic peer tests and the previous Mosquitto-backed example run
  passed in [CI run 40058539939](https://github.com/Wchwch777/Scantling/actions/runs/40058539939).
  The workflow now runs the full telemetry/command/report/event example against
  Mosquitto, checks all four outputs, and requires at least ten seconds of
  runtime; see [main-branch workflow runs](https://github.com/Wchwch777/Scantling/actions/workflows/ci.yml)
  for the current commit's result.
- **Not established:** there is no event schema, decoder, ordering guarantee
  across reconnects, durable delivery, physical-device integration, or business
  processing beyond the fixed demonstration response.

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
These checks are included in the native suite. The latest pushed code snapshot
[`9ad42e2`](https://github.com/Wchwch777/Scantling/commit/9ad42e298dc6fb7dd7cfc1044e07be8fa47defd)
passed [CI run 41185493873](https://github.com/Wchwch777/Scantling/actions/runs/41185493873),
including the Broker-backed test service, the full Mosquitto client example,
and independent-client fault paths. Earlier runs remain linked in the owner
review record as historical verification for their respective snapshots.

## Scriptable peer checks

The native peer now has reference scripts for external-client behavior that is
not represented by the old fixed scenario selector:

- [`qos2-publish.scantling`](../examples/mqtt_fault_peer/scripts/qos2-publish.scantling)
  matches a QoS 2 PUBLISH by topic, copies its live packet identifier into
  PUBREC, completes PUBREL/PUBCOMP, and waits for DISCONNECT. A native
  integration test runs this sequence with Scantling's own client; CI also
  invokes Mosquitto `mosquitto_pub -q 2` against it.
- [`idle-event.scantling`](../examples/mqtt_fault_peer/scripts/idle-event.scantling)
  responds to two PINGREQ packets before delivering a later event. A native
  integration test exercises `receive_with_keep_alive()`, and CI invokes
  independent Mosquitto `mosquitto_sub -k 5` and checks both ping/pong logs and
  the delivered message.
- [`subscriber-message.scantling`](../examples/mqtt_fault_peer/scripts/subscriber-message.scantling)
  accepts CONNECT/SUBSCRIBE, returns SUBACK and one scripted PUBLISH, and waits
  for DISCONNECT; CI checks the received topic and payload with Mosquitto.

These examples make the test peer reusable with independent client
implementations and exercise multiple broker response paths. The three CLI
scenarios passed in [GitHub Actions run 41185493873](https://github.com/Wchwch777/Scantling/actions/runs/41185493873)
on commit [`9ad42e2`](https://github.com/Wchwch777/Scantling/commit/9ad42e298dc6fb7dd7cfc1044e07be8fa47defd);
the same run passed all 49 Native and 26 Wasm tests. They remain finite,
scripted checks, not broad interoperability data, a general test framework
equivalent to Paho, MQTT conformance certification, load testing, or evidence
of user adoption.

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
