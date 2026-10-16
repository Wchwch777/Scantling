///|
test "MQTT frame reader rejects a truncated fixed header" {
  match packet_body_length([0x30]) {
    Err(ClientError::Codec(_)) => ()
    _ => fail("expected an incomplete-header error")
  }
}

///|
test "MQTT frame reader accepts one- and multi-byte Remaining Length" {
  assert_eq(packet_body_length([0x30, 0x7F]), Ok(127))
  assert_eq(packet_body_length([0x30, 0x80, 0x01]), Ok(128))
}

///|
test "MQTT frame reader rejects malformed Remaining Length" {
  match packet_body_length([0x30, 0x80]) {
    Err(ClientError::Codec(_)) => ()
    _ => fail("expected a truncated Remaining Length error")
  }
}

///|
test "MQTT frame reader caps inbound packets at one MiB" {
  let encoded_length = @codec.encode_remaining_length(1_048_577).unwrap()
  let frame : Array[Byte] = [0x30, ..encoded_length]
  match packet_body_length(frame) {
    Err(ClientError::Codec(message)) =>
      assert_eq(message, "packet exceeds the configured 1 MiB limit")
    _ => fail("expected an oversized packet error")
  }
}

///|
test "MQTT subscription filters accept wildcards in complete levels" {
  assert_eq(validate_subscription_filter("#"), Ok(()))
  assert_eq(validate_subscription_filter("factory/#"), Ok(()))
  assert_eq(validate_subscription_filter("+/temperature"), Ok(()))
  assert_eq(validate_subscription_filter("factory/+/temperature"), Ok(()))
  assert_eq(validate_subscription_filter("factory//temperature"), Ok(()))
}

///|
test "MQTT subscription filters reject malformed wildcards" {
  match validate_subscription_filter("factory/temp+") {
    Err(ClientError::InvalidConfig(_)) => ()
    _ => fail("expected an embedded single-level wildcard error")
  }
  match validate_subscription_filter("factory/#/temperature") {
    Err(ClientError::InvalidConfig(_)) => ()
    _ => fail("expected a non-final multi-level wildcard error")
  }
  match validate_subscription_filter("factory/#/") {
    Err(ClientError::InvalidConfig(_)) => ()
    _ => fail("expected a non-final multi-level wildcard error")
  }
  match validate_subscription_filter("factory/te#mp") {
    Err(ClientError::InvalidConfig(_)) => ()
    _ => fail("expected an embedded multi-level wildcard error")
  }
}

///|
test "MQTT publish topics reject wildcards and empty names" {
  assert_eq(validate_publish_topic("factory/temperature"), Ok(()))
  match validate_publish_topic("") {
    Err(ClientError::InvalidConfig(_)) => ()
    _ => fail("expected an empty publish topic error")
  }
  match validate_publish_topic("factory/+") {
    Err(ClientError::InvalidConfig(_)) => ()
    _ => fail("expected a wildcard publish topic error")
  }
}
