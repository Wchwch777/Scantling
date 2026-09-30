# MQTT client use cases and evidence boundaries

The project targets the MQTT 3.1.1 client role. The use cases below describe
common workloads that use the same publish/subscribe protocol; they are not
claims of Scantling customers, deployments, or market research.

## 1. Sensor telemetry collection

- **Actor and task:** a gateway or service subscribes to a sensor topic such as
  `building/floor-2/temperature` and consumes measurements.
- **Input and flow:** connect to a broker, subscribe at QoS 1, receive a
  `PUBLISH`, acknowledge it with `PUBACK`, then pass the topic and payload to
  application code.
- **Expected output:** a message containing the original topic and bytes.
- **Implementation/evidence:** the API and a native loopback integration test
  exercise CONNECT, SUBSCRIBE, inbound QoS 1, and PUBACK. The test passed in
  [GitHub Actions run 36735317519](https://github.com/Wchwch777/Scantling/actions/runs/36735317519).
  It uses a local protocol peer, not a real sensor deployment or third-party
  broker certification; Native was not rerun on the owner's Windows machine.

## 2. Device command channel

- **Actor and task:** a command-line operator or service publishes a small
  command to a device-specific topic, for example `factory/line-1/device-7/cmd`.
- **Input and flow:** connect to an MQTT 3.1.1 broker and publish a UTF-8 or
  binary payload at QoS 0; the receiving device subscribes to the matching
  topic filter.
- **Expected output:** the broker accepts the outgoing packet and forwards it
  to matching subscribers; delivery guarantees remain those of QoS 0.
- **Implementation/evidence:** QoS 0 publish and topic-filter subscription
  methods are implemented. The CI loopback test exercises the QoS 0 publish
  packet against a local peer, not an actual device or device control flow.

## 3. Application event fan-out

- **Actor and task:** a service consumes events from a shared topic family,
  such as `service/orders/created`, without depending on the publisher's
  implementation language.
- **Input and flow:** subscribe using an MQTT topic filter; handle each message
  as opaque bytes and decode the application's chosen payload format above the
  client layer.
- **Expected output:** callers receive messages as delivered by the broker
  connection and may route them to their own handlers.
- **Implementation/evidence:** the current API returns topic and payload and
  can subscribe to one topic filter. Ordering, durable sessions, retries,
  reconnection, and end-to-end processing guarantees are not implemented or
  claimed.

## Ecosystem relationship and scope

The MoonBit package `zbhzs1/moonbit-mqtt` provides MQTT 3.1.1 packet codecs and
explicitly excludes network transport and client runtime. Scantling depends on
that codec and implements the separate client-runtime layer. A MoonBit MQTT
broker is also listed on Mooncakes; it serves the broker role, not the client
role. These projects are adjacent ecosystem components, not evidence of
Scantling deployments. Before submission, recheck Mooncakes and consider
whether a collaboration or upstream contribution is preferable to maintaining
a separate package.

The first release is a plain TCP, unauthenticated client with a limited QoS
surface. It is a runnable development foundation, not a production-complete
MQTT SDK.
