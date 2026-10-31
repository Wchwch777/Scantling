///|
test "scenario parser accepts a caller-defined exchange sequence" {
  let script = match
    @fault_peer.Script::parse(
      "expect CONNECT\nsend CONNACK code=0\nwait 5\nexpect PUBLISH qos=1 id=7 topic=scantling/data\nsend PUBACK id=request\nclose\n",
    ) {
    Ok(script) => script
    Err(error) => fail("valid scenario was rejected: " + error)
  }
  assert_eq(script.exchanges.length(), 2)
  let actions = (script.exchanges[1].respond)(
    @codec.PublishPacket({
      topic: "scantling/data",
      payload: b"value",
      qos: @codec.QoS1,
      message_id: Some(7),
      retain: false,
      dup: false,
    }),
  )
  match actions[0] {
    @fault_peer.Action::SendPacket(@codec.PubackPacket(packet_id)) =>
      assert_eq(packet_id.message_id, 7)
    _ => fail("filtered QoS 1 script did not copy the request packet id")
  }
}

///|
test "scenario parser preserves request identifiers for filtered QoS 2 exchanges" {
  let script = match
    @fault_peer.Script::parse(
      "expect PUBLISH qos=2 id=19 topic=scantling/qos2\nsend PUBREC id=request\nexpect PUBREL id=19\nsend PUBCOMP id=request\n",
    ) {
    Ok(script) => script
    Err(error) => fail("valid filtered QoS 2 script was rejected: " + error)
  }
  let publish_actions = (script.exchanges[0].respond)(
    @codec.PublishPacket({
      topic: "scantling/qos2",
      payload: b"value",
      qos: @codec.QoS2,
      message_id: Some(19),
      retain: false,
      dup: false,
    }),
  )
  match publish_actions[0] {
    @fault_peer.Action::SendPacket(@codec.PubrecPacket(packet_id)) =>
      assert_eq(packet_id.message_id, 19)
    _ => fail("QoS 2 script did not copy the PUBLISH packet id into PUBREC")
  }
  let pubrel_actions = (script.exchanges[1].respond)(
    @codec.PubrelPacket({ message_id: 19, }),
  )
  match pubrel_actions[0] {
    @fault_peer.Action::SendPacket(@codec.PubcompPacket(packet_id)) =>
      assert_eq(packet_id.message_id, 19)
    _ => fail("QoS 2 script did not copy the PUBREL packet id into PUBCOMP")
  }
}

///|
test "scenario parser builds a scripted subscriber delivery" {
  let script = match
    @fault_peer.Script::parse(
      "expect CONNECT\nsend CONNACK code=0 session_present=false\nexpect SUBSCRIBE\nsend SUBACK id=request codes=0\nsend PUBLISH topic=scantling/scripted/notice qos=0 payload_hex=68,65,6c,6c,6f\nexpect DISCONNECT\nclose\n",
    ) {
    Ok(script) => script
    Err(error) => fail("valid subscriber scenario was rejected: " + error)
  }
  assert_eq(script.exchanges.length(), 3)
  let actions = (script.exchanges[1].respond)(
    @codec.SubscribePacket({
      message_id: 19,
      topics: [{ topic: "scantling/scripted/#", qos: @codec.QoS0, }],
    }),
  )
  assert_eq(actions.length(), 2)
  match actions[0] {
    @fault_peer.Action::SendPacket(@codec.SubackPacket(suback)) =>
      assert_eq(suback.message_id, 19)
    _ => fail("script did not copy the SUBSCRIBE identifier into SUBACK")
  }
  match actions[1] {
    @fault_peer.Action::SendPacket(@codec.PublishPacket(message)) => {
      assert_eq(message.topic, "scantling/scripted/notice")
      assert_eq(message.payload, b"hello")
      assert_true(message.message_id is None)
    }
    _ => fail("script did not build the broker-to-client PUBLISH")
  }
}

///|
test "scenario parser rejects invalid scripted publish fields" {
  match
    @fault_peer.Script::parse(
      "expect SUBSCRIBE\nsend PUBLISH topic=bad/+/topic qos=0\n",
    ) {
    Err(error) => assert_true(error.contains("must not contain wildcards"))
    Ok(_) => fail("wildcards in a PUBLISH topic name were accepted")
  }
  match
    @fault_peer.Script::parse(
      "expect SUBSCRIBE\nsend PUBLISH topic=scantling/test qos=1\n",
    ) {
    Err(error) => assert_true(error.contains("requires id"))
    Ok(_) => fail("QoS 1 PUBLISH without a packet identifier was accepted")
  }
  match
    @fault_peer.Script::parse(
      "expect SUBSCRIBE\nsend PUBLISH topic=scantling/test qos=0 payload_hex=zz\n",
    ) {
    Err(error) => assert_true(error.contains("non-hexadecimal"))
    Ok(_) => fail("non-hexadecimal PUBLISH payload was accepted")
  }
  match
    @fault_peer.Script::parse(
      "expect SUBSCRIBE\nsend PUBLISH topic=scantling/test qos=0 qos=1\n",
    ) {
    Err(error) => assert_true(error.contains("unique"))
    Ok(_) => fail("duplicate PUBLISH options were accepted")
  }
  match
    @fault_peer.Script::parse(
      "expect CONNECT\nclose\nexpect DISCONNECT\nclose\n",
    ) {
    Err(error) => assert_true(error.contains("after close"))
    Ok(_) => fail("an exchange after close was accepted")
  }
}

///|
test "scenario expectations can constrain packet identifiers and topics" {
  let script = match
    @fault_peer.Script::parse(
      "expect PUBLISH qos=1 id=7 topic=scantling/data payload_hex=76,61,6c,75,65 retain=false dup=false\nclose\n",
    ) {
    Ok(script) => script
    Err(error) => fail("valid filtered expectation was rejected: " + error)
  }
  let matches = script.exchanges[0].matches
  let matching_packet = @codec.PublishPacket({
    topic: "scantling/data",
    payload: b"value",
    qos: @codec.QoS1,
    message_id: Some(7),
    retain: false,
    dup: false,
  })
  assert_true(matches(matching_packet))
  let different_topic = @codec.PublishPacket({
    topic: "scantling/other",
    payload: b"value",
    qos: @codec.QoS1,
    message_id: Some(7),
    retain: false,
    dup: false,
  })
  assert_false(matches(different_topic))
  let different_identifier = @codec.PublishPacket({
    topic: "scantling/data",
    payload: b"value",
    qos: @codec.QoS1,
    message_id: Some(8),
    retain: false,
    dup: false,
  })
  assert_false(matches(different_identifier))
  let different_payload = @codec.PublishPacket({
    topic: "scantling/data",
    payload: b"other",
    qos: @codec.QoS1,
    message_id: Some(7),
    retain: false,
    dup: false,
  })
  assert_false(matches(different_payload))
  let retained = @codec.PublishPacket({
    topic: "scantling/data",
    payload: b"value",
    qos: @codec.QoS1,
    message_id: Some(7),
    retain: true,
    dup: false,
  })
  assert_false(matches(retained))
  let duplicate = @codec.PublishPacket({
    topic: "scantling/data",
    payload: b"value",
    qos: @codec.QoS1,
    message_id: Some(7),
    retain: false,
    dup: true,
  })
  assert_false(matches(duplicate))
}

///|
test "scenario parser rejects unsupported packets and reports line number" {
  match @fault_peer.Script::parse("expect CONNECT\nsend WILL\n") {
    Err(error) => assert_true(error.contains("line 2"))
    Ok(_) => fail("unsupported response packet was accepted")
  }
}

///|
test "scenario parser rejects request identifiers for incompatible exchanges" {
  match
    @fault_peer.Script::parse(
      "expect PUBLISH qos=0 topic=scantling/data\nsend PUBACK id=request\n",
    ) {
    Err(error) => assert_true(error.contains("not valid"))
    Ok(_) => fail("PUBACK copied an identifier from a QoS 0 PUBLISH")
  }
  match
    @fault_peer.Script::parse(
      "expect PUBLISH qos=1 id=3 topic=scantling/data\nsend PUBREC id=request\n",
    ) {
    Err(error) => assert_true(error.contains("not valid"))
    Ok(_) => fail("PUBREC copied an identifier from a QoS 1 PUBLISH")
  }
}

///|
test "scenario parser rejects malformed raw byte and response ordering" {
  match @fault_peer.Script::parse("send PINGRESP\n") {
    Err(error) => {
      assert_true(error.contains("line 1"))
      assert_true(error.contains("must follow an expect"))
    }
    Ok(_) => fail("response without an expect was accepted")
  }
  match @fault_peer.Script::parse("expect CONNECT\nraw 20 GG 00\n") {
    Err(error) => assert_true(error.contains("not hexadecimal"))
    Ok(_) => fail("malformed raw bytes were accepted")
  }
}
