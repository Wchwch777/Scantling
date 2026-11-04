///|
fn connect_packet(
  clean~ : Bool = true,
  keep_alive~ : Int32 = 0,
) -> @codec.Packet {
  @codec.ConnectPacket({
    client_id: "monitor-test",
    username: None,
    password: None,
    will_topic: None,
    will_message: None,
    keep_alive,
    flags: {
      username: false,
      password: false,
      will_retain: false,
      will_qos: @codec.QoS0,
      will_flag: false,
      clean_session: clean,
    },
  })
}

///|
fn accepted(present~ : Bool = false) -> @codec.Packet {
  @codec.ConnackPacket({
    session_present: present,
    return_code: @codec.ConnectionAccepted,
  })
}

///|
fn ready(
  clean~ : Bool = true,
  keep_alive~ : Int32 = 0,
) -> @monitor.Monitor raise {
  let m = @monitor.Monitor::new()
  assert_true(
    m.observe(@monitor.Client, connect_packet(clean~, keep_alive~), 0L),
  )
  assert_true(m.observe(@monitor.Server, accepted(), 0L))
  m
}

///|
fn publication(
  id : Int32,
  qos~ : @codec.QoS = @codec.QoS2,
  dup~ : Bool = false,
  payload~ : Bytes = b"value",
) -> @codec.Packet {
  @codec.PublishPacket({
    topic: "test/data",
    payload,
    qos,
    message_id: if qos == @codec.QoS0 {
      None
    } else {
      Some(id)
    },
    retain: false,
    dup,
  })
}

///|
test "interleaved bidirectional QoS2 uses independent identifier spaces" {
  let m = ready()
  for side in [@monitor.Client, @monitor.Server] {
    assert_true(m.observe(side, publication(7), 0L))
  }
  assert_true(m.observe(@monitor.Server, publication(8), 0L))
  assert_eq(m.report().pending, 3)
  for
    (sender, receiver, id) in [
      (@monitor.Server, @monitor.Client, 8),
      (@monitor.Client, @monitor.Server, 7),
      (@monitor.Server, @monitor.Client, 7),
    ] {
    assert_true(
      m.observe(receiver, @codec.PubrecPacket({ message_id: id, }), 1L),
    )
    assert_true(m.observe(sender, @codec.PubrelPacket({ message_id: id, }), 1L))
    assert_true(
      m.observe(receiver, @codec.PubcompPacket({ message_id: id, }), 1L),
    )
  }
  assert_true(m.report().complete)
  assert_eq(m.report().completed_publications, 3)
}

///|
test "duplicate QoS2 packets do not create extra completions" {
  let m = ready()
  assert_true(m.observe(@monitor.Client, publication(7), 0L))
  assert_true(m.observe(@monitor.Client, publication(7, dup=true), 0L))
  assert_true(
    m.observe(@monitor.Server, @codec.PubrecPacket({ message_id: 7, }), 0L),
  )
  assert_true(m.observe(@monitor.Client, publication(7, dup=true), 0L))
  assert_true(
    m.observe(@monitor.Server, @codec.PubrecPacket({ message_id: 7, }), 0L),
  )
  assert_true(
    m.observe(@monitor.Client, @codec.PubrelPacket({ message_id: 7, }), 0L),
  )
  assert_true(
    m.observe(@monitor.Client, @codec.PubrelPacket({ message_id: 7, }), 0L),
  )
  assert_true(
    m.observe(@monitor.Server, @codec.PubcompPacket({ message_id: 7, }), 0L),
  )
  assert_eq(m.report().retransmissions, 4)
  assert_eq(m.report().completed_publications, 1)
  // Receiver must acknowledge a repeated PUBREL even after freeing its state.
  assert_true(
    m.observe(@monitor.Client, @codec.PubrelPacket({ message_id: 7, }), 0L),
  )
  assert_false(m.report().complete)
  assert_true(
    m.observe(@monitor.Server, @codec.PubcompPacket({ message_id: 7, }), 0L),
  )
  assert_eq(m.report().completed_publications, 1)
}

///|
test "acknowledgement mutation matrix detects wrong stage direction and identifier" {
  for
    mutation in [
      @codec.PubackPacket({ message_id: 7, }),
      @codec.PubcompPacket({ message_id: 7, }),
      @codec.PubrecPacket({ message_id: 8, }),
    ] {
    let m = ready()
    assert_true(m.observe(@monitor.Client, publication(7), 0L))
    assert_false(m.observe(@monitor.Server, mutation, 1L))
    assert_eq(m.report().diagnostics[0].event, 4)
    assert_false(m.report().complete)
  }
  let m = ready()
  assert_true(m.observe(@monitor.Client, publication(7), 0L))
  assert_false(
    m.observe(@monitor.Client, @codec.PubrecPacket({ message_id: 7, }), 0L),
  )
}

///|
test "identifier reuse is rejected before completion and accepted afterwards" {
  let m = ready()
  assert_true(m.observe(@monitor.Client, publication(7, qos=@codec.QoS1), 0L))
  assert_true(
    m.observe(@monitor.Server, @codec.PubackPacket({ message_id: 7, }), 0L),
  )
  assert_true(m.observe(@monitor.Client, publication(7), 0L))
  assert_false(
    m.observe(
      @monitor.Client,
      @codec.SubscribePacket({
        message_id: 7,
        topics: [{ topic: "a/#", qos: @codec.QoS1, }],
      }),
      0L,
    ),
  )
  assert_eq(m.report().diagnostics[0].rule, "MQTT-2.3.1-2")
}

///|
test "DUP and payload mutation matrix is diagnosed" {
  for
    packet in [
      publication(7),
      publication(7, dup=true, payload=b"changed"),
      publication(7, qos=@codec.QoS1, dup=true),
    ] {
    let m = ready()
    assert_true(m.observe(@monitor.Client, publication(7), 0L))
    assert_false(m.observe(@monitor.Client, packet, 0L))
    assert_eq(m.report().diagnostics[0].rule, "TRACE-RETRANSMIT")
  }
}

///|
test "QoS1 retransmission can complete and incomplete prefixes remain distinguishable" {
  let m = ready()
  assert_true(
    m.observe(@monitor.Server, publication(65535, qos=@codec.QoS1), 0L),
  )
  let prefix = m.report()
  assert_true(prefix.valid_prefix)
  assert_false(prefix.complete)
  assert_true(
    m.observe(
      @monitor.Server,
      publication(65535, qos=@codec.QoS1, dup=true),
      0L,
    ),
  )
  assert_true(
    m.observe(@monitor.Client, @codec.PubackPacket({ message_id: 65535, }), 0L),
  )
  assert_true(m.report().complete)
  assert_eq(prefix.pending, 1)
}

///|
test "batch SUBACK count and each ordered QoS grant are checked" {
  for codes in [[@codec.SuccessQoS0], [@codec.SuccessQoS1, @codec.SuccessQoS1]] {
    let m = ready()
    assert_true(
      m.observe(
        @monitor.Client,
        @codec.SubscribePacket({
          message_id: 1,
          topics: [
            { topic: "a/+", qos: @codec.QoS0, },
            { topic: "b/#", qos: @codec.QoS2, },
          ],
        }),
        0L,
      ),
    )
    assert_false(
      m.observe(
        @monitor.Server,
        @codec.SubackPacket({ message_id: 1, return_codes: codes, }),
        0L,
      ),
    )
  }
  let m = ready()
  assert_true(
    m.observe(
      @monitor.Client,
      @codec.SubscribePacket({
        message_id: 1,
        topics: [
          { topic: "a/+", qos: @codec.QoS0, },
          { topic: "b/#", qos: @codec.QoS2, },
        ],
      }),
      0L,
    ),
  )
  assert_true(
    m.observe(
      @monitor.Server,
      @codec.SubackPacket({
        message_id: 1,
        return_codes: [@codec.Failure, @codec.SuccessQoS1],
      }),
      0L,
    ),
  )
  assert_true(m.report().complete)
}

///|
test "unsubscribe reserves shared client identifiers until UNSUBACK" {
  let m = ready()
  assert_true(
    m.observe(
      @monitor.Client,
      @codec.UnsubscribePacket({ message_id: 4, topics: ["a/#"], }),
      0L,
    ),
  )
  assert_false(m.report().complete)
  assert_true(
    m.observe(@monitor.Server, @codec.UnsubackPacket({ message_id: 4, }), 0L),
  )
  assert_true(m.observe(@monitor.Client, publication(4), 0L))
}

///|
test "persistent QoS2 resumes at PUBREL across transport closure" {
  let m = ready(clean=false)
  assert_true(m.observe(@monitor.Client, publication(9), 0L))
  assert_true(
    m.observe(@monitor.Server, @codec.PubrecPacket({ message_id: 9, }), 0L),
  )
  assert_true(
    m.observe(@monitor.Client, @codec.PubrelPacket({ message_id: 9, }), 0L),
  )
  assert_true(m.close(1L))
  assert_eq(m.report().pending, 1)
  assert_true(m.observe(@monitor.Client, connect_packet(clean=false), 2L))
  assert_true(m.observe(@monitor.Server, accepted(present=true), 2L))
  assert_true(
    m.observe(@monitor.Client, @codec.PubrelPacket({ message_id: 9, }), 2L),
  )
  assert_true(
    m.observe(@monitor.Server, @codec.PubcompPacket({ message_id: 9, }), 2L),
  )
  assert_eq(m.report().connections, 2)
  assert_eq(m.report().completed_publications, 1)
  assert_true(m.report().complete)
}

///|
test "clean session discards state without claiming interrupted work completed" {
  let m = ready()
  assert_true(m.observe(@monitor.Client, publication(1), 0L))
  assert_true(m.close(1L))
  assert_eq(m.report().pending, 0)
  assert_eq(m.report().abandoned, 1)
  assert_false(m.report().complete)
  assert_true(m.observe(@monitor.Client, connect_packet(), 2L))
  assert_true(m.observe(@monitor.Server, accepted(), 2L))
  assert_true(m.observe(@monitor.Client, publication(1), 2L))
}

///|
test "unknown or lost persistent state is an explicit capture boundary" {
  let unknown = @monitor.Monitor::new()
  assert_true(unknown.observe(@monitor.Client, connect_packet(clean=false), 0L))
  assert_false(unknown.observe(@monitor.Server, accepted(present=true), 0L))
  assert_eq(unknown.report().diagnostics[0].rule, "TRACE-SESSION-UNKNOWN")
  let lost = ready(clean=false)
  assert_true(lost.observe(@monitor.Client, publication(1), 0L))
  assert_true(lost.close(0L))
  assert_true(lost.observe(@monitor.Client, connect_packet(clean=false), 1L))
  assert_false(lost.observe(@monitor.Server, accepted(), 1L))
  assert_eq(lost.report().diagnostics[0].rule, "TRACE-SESSION-LOST")
}

///|
test "keep alive boundary counts all client packets but no server packets" {
  let m = ready(keep_alive=2)
  assert_true(m.advance(3000L))
  assert_true(m.observe(@monitor.Client, @codec.PingreqPacket, 3000L))
  assert_true(m.observe(@monitor.Server, @codec.PingrespPacket, 3001L))
  assert_true(m.advance(6000L))
  assert_false(m.advance(6001L))
  assert_eq(m.report().diagnostics[0].rule, "MQTT-3.1.2-24")
  let closing = ready(keep_alive=2)
  assert_true(closing.close(9000L))
}

///|
test "zero keep alive has no invented deadline and pending ping prevents completeness" {
  let m = ready()
  assert_true(m.advance(9000000000L))
  assert_true(m.observe(@monitor.Client, @codec.PingreqPacket, 9000000000L))
  assert_true(m.advance(9000000001L))
  assert_false(m.report().complete)
}

///|
test "failure is sticky and reports are detached" {
  let m = ready()
  let before = m.report()
  assert_false(m.observe(@monitor.Server, @codec.PingrespPacket, 0L))
  let failed = m.report()
  assert_false(m.observe(@monitor.Client, publication(7), 0L))
  assert_eq(m.report().events, failed.events)
  assert_eq(before.diagnostics.length(), 0)
  failed.diagnostics.clear()
  assert_eq(m.report().diagnostics.length(), 1)
}

///|
test "framing mutation matrix rejects invalid flags lengths and concatenation" {
  let frames : Array[Array[Byte]] = [
    [0xc1, 0x00],
    [0xc0, 0x80, 0x00],
    [0xc0],
    [0xc0, 0x00, 0xd0, 0x00],
    [0x00, 0x00],
    [0x36, 0x00],
    [0xc0, 0xff, 0xff, 0xff, 0xff, 0x00],
  ]
  for frame in frames {
    let m = ready()
    assert_false(m.observe_frame(@monitor.Client, frame, 0L))
    assert_eq(m.report().diagnostics[0].rule, "TRACE-FRAME")
  }
}

///|
test "trace parser reports syntax lines and semantic event indices" {
  for
    text in [
      "", "0 C z0", "0 C 0", "0 C 00 00", "now CLOSE", "0 UNKNOWN", "0 TICK extra",
    ] {
    assert_true(@monitor.check_trace(text) is Err(_))
  }
  let result = @monitor.check_trace("# comment\n\n0 C c000\n").unwrap()
  assert_false(result.valid_prefix)
  assert_eq(result.diagnostics[0].event, 1)
  assert_eq(result.diagnostics[0].rule, "MQTT-3.1.0-1")
}

///|
test "connection order direction disconnect and session flags are enforced" {
  let m = @monitor.Monitor::new()
  assert_false(m.observe(@monitor.Server, connect_packet(), 0L))
  let m = ready()
  assert_true(m.observe(@monitor.Client, @codec.DisconnectPacket, 0L))
  assert_false(m.observe(@monitor.Server, accepted(), 0L))
  let m = @monitor.Monitor::new()
  assert_true(m.observe(@monitor.Client, connect_packet(), 0L))
  assert_false(m.observe(@monitor.Server, accepted(present=true), 0L))
}

///|
test "observation bounds identifiers topic filters and monotonic time" {
  for id in [0, 65536] {
    let m = ready()
    assert_false(m.observe(@monitor.Client, publication(id), 0L))
  }
  for filter in ["", "a/#/b", "a+b", "a/##"] {
    let m = ready()
    assert_false(
      m.observe(
        @monitor.Client,
        @codec.SubscribePacket({
          message_id: 1,
          topics: [{ topic: filter, qos: @codec.QoS0, }],
        }),
        0L,
      ),
    )
  }
  let m = @monitor.Monitor::new(max_inflight=1)
  assert_true(m.observe(@monitor.Client, connect_packet(), 0L))
  assert_true(m.observe(@monitor.Server, accepted(), 0L))
  assert_true(m.observe(@monitor.Client, publication(1), 0L))
  assert_false(m.observe(@monitor.Client, publication(2), 0L))
  assert_eq(m.report().diagnostics[0].rule, "TRACE-LIMIT")
  let m = ready()
  assert_true(m.advance(2L))
  assert_false(m.advance(1L))
}

///|
test "client pipelining before CONNACK is allowed but server must send CONNACK first" {
  let m = @monitor.Monitor::new()
  assert_true(m.observe(@monitor.Client, connect_packet(clean=false), 0L))
  assert_true(m.observe(@monitor.Client, publication(1, qos=@codec.QoS1), 1L))
  assert_true(m.observe(@monitor.Server, accepted(), 2L))
  assert_true(
    m.observe(@monitor.Server, @codec.PubackPacket({ message_id: 1, }), 3L),
  )
  assert_true(m.report().complete)
  let early_server = @monitor.Monitor::new()
  assert_true(early_server.observe(@monitor.Client, connect_packet(), 0L))
  assert_false(early_server.observe(@monitor.Server, publication(1), 1L))
}

///|
test "new client identity cannot inherit another client's Session Present" {
  let m = ready()
  assert_true(m.close(0L))
  assert_true(m.observe(@monitor.Client, connect_packet(clean=false), 1L))
  assert_false(m.observe(@monitor.Server, accepted(present=true), 1L))
}
