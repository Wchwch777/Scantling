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
