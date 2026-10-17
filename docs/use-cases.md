# MQTT client use cases and evidence boundaries

These are protocol-level examples for the same MQTT 3.1.1 client API. They are
not claims of Scantling customers, device deployments, user research, or measured
market demand. The runnable demonstration sends three representative message
flows through separate publisher and subscriber connections:
[`examples/mqtt_client/main.mbt`](../examples/mqtt_client/main.mbt).

## 1. Sensor telemetry collection

- **Actor and task:** a gateway subscribes to a sensor topic such as
  `building/floor-2/temperature` and consumes measurement bytes.
- **Client flow:** `subscribe` at QoS 1, then `receive`; the client acknowledges
  QoS 1 messages with PUBACK before returning them to the caller.
- **Evidence:** [`subscribe`](../mqtt/client.mbt#L321) and
  [`receive`](../mqtt/client.mbt#L392) implement the caller flow. The
  [loopback test](../mqtt/integration_test/client_test.mbt#L33) checks
  SUBSCRIBE/SUBACK and inbound QoS 1/PUBACK; the
  [Mosquitto test](../mqtt/integration_test/client_test.mbt#L142) checks a
  separate publisher and subscriber exchanging a QoS 1 message.
- **Not established:** no physical sensor or gateway is connected, and no
  telemetry format or field deployment is validated.

## 2. Device command publishing

- **Actor and task:** an application publishes a command to a topic such as
  `factory/line-1/device-7/cmd` for a device client subscribed to that topic.
- **Client flow:** `publish_qos1` sends the payload and waits for PUBACK; QoS 0
  publish is also available where the application accepts its weaker delivery
  semantics.
- **Evidence:** [`publish_qos1`](../mqtt/client.mbt#L256) waits for PUBACK. The
  [independent Mosquitto test](../mqtt/integration_test/client_test.mbt#L142)
  verifies QoS 1 publishing, acknowledgement, and delivery to a different
  subscribed client. This covers
  the generic broker message path used by the example, not a real device or
  command execution.
- **Not established:** device identity, authorization, command schema, safety,
  or downstream execution are outside this library.

## 3. Application event consumption

- **Actor and task:** a service subscribes to a topic such as
  `service/orders/created` and passes the received opaque bytes to its own event
  decoder or handler.
- **Client flow:** `subscribe` to one topic filter and call `receive`; the API
  returns topic, payload, QoS, and retain metadata.
- **Evidence:** the loopback test checks subscription and message receipt; the
  Mosquitto test checks one publisher-to-subscriber opaque payload. The
  [example](../examples/mqtt_client/main.mbt) uses an event topic and
  event-shaped payload to demonstrate the API path; CI does not assert business
  event semantics.
- **Not established:** the current tests do not verify multiple subscribers,
  durable sessions, ordering across reconnects, retries, or end-to-end business
  event processing.

## Scope shared by all three examples

The implementation is a small sequential MQTT 3.1.1 TCP client. It supports one
topic filter per subscribe/unsubscribe call and the tested QoS 0/1 paths. TLS,
authentication, automatic reconnection, automatic Keep Alive scheduling,
operation timeouts, QoS 2, MQTT 5.0, WebSocket transport, and production
certification are not included. CI results validate the checked protocol paths;
they do not establish market demand or production readiness.
