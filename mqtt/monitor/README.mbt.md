# MQTT stateful trace monitor

This portable library checks **observed protocol history**, independently of the
TCP client and the linear fault-peer script. It supports multiple in-flight
exchanges, separate sender identifier spaces, QoS 1/2 stages and retransmissions,
subscription acknowledgements, and bounded persistent-session resumption.

Feed frames from both endpoints in their actual capture order. Timestamps are
nonnegative monotonic milliseconds from a caller-selected origin.

```mbt check
///|
test "a decoded packet can still be semantically wrong" {
  let monitor = @monitor.Monitor::new()
  // CONNECT: client ID "c", clean session, keep alive disabled.
  assert_true(
    monitor.observe_frame(
      @monitor.Client,
      [
        0x10, 0x0d, 0x00, 0x04, 0x4d, 0x51, 0x54, 0x54, 0x04, 0x02, 0x00, 0x00, 0x00,
        0x01, 0x63,
      ],
      0L,
    ),
  )
  assert_true(
    monitor.observe_frame(@monitor.Server, [0x20, 0x02, 0x00, 0x00], 1L),
  )
  // Client PUBLISH QoS 2, id=7, topic "a", payload "x".
  assert_true(
    monitor.observe_frame(
      @monitor.Client,
      [0x34, 0x06, 0x00, 0x01, 0x61, 0x00, 0x07, 0x78],
      2L,
    ),
  )
  assert_false(monitor.report().complete)
  // A syntactically valid PUBACK is not the PUBREC required by QoS 2.
  assert_false(
    monitor.observe_frame(@monitor.Server, [0x40, 0x02, 0x00, 0x07], 3L),
  )
  assert_eq(monitor.report().diagnostics[0].rule, "TRACE-ACK-STAGE")
  assert_eq(monitor.report().diagnostics[0].event, 4)
}
```

`observe` accepts upstream codec values when bytes are unavailable;
`observe_frame` additionally validates one complete bounded wire frame.
`close` records a TCP disconnect, and `advance` records that the connection is
still open at a later logical time. Reports are detached snapshots.

`valid_prefix` means no implemented rule has rejected the observed prefix.
`complete` additionally requires a connection attempt, no outstanding exchange
or ping, no pending CONNACK, and no abandoned exchange. An incomplete capture
is not evidence of a protocol violation. A complete report does not certify
MQTT compliance or exactly-once application delivery.

Run the executable examples and state-machine tests with
`moon test mqtt/monitor --target wasm --deny-warn`.
See [rule coverage and limitations](../../docs/monitor.md) and run the native
trace CLI with `moon run --target native examples/check_trace`.
