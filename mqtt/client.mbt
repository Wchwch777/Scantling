/// MQTT 3.1.1 asynchronous TCP client runtime.
/// Packet encoding and decoding are delegated to zbhzs1/moonbit-mqtt.

///|
pub(all) struct Message {
  topic : String
  payload : Bytes
  qos : @codec.QoS
  retain : Bool
} derive(Eq, Debug)

///|
pub suberror ClientError {
  InvalidConfig(String)
  Codec(String)
  Rejected(Int32)
  TransportFailure
  UnexpectedPacket(String)
} derive(Eq, Debug)

///|
pub(all) struct Client {
  tcp : @socket.Tcp
  keep_alive : Int32
  mut next_packet_id : Int32
}

///|
fn next_packet_id(current : Int32) -> Int32 {
  if current >= 65535 || current <= 0 {
    1
  } else {
    current + 1
  }
}

///|
fn Client::allocate_packet_id(self : Client) -> Int32 {
  let message_id = self.next_packet_id
  self.next_packet_id = next_packet_id(message_id)
  message_id
}

///|
fn validate_publish_topic(topic : String) -> Result[Unit, ClientError] {
  if topic == "" {
    return Err(ClientError::InvalidConfig("publish topic must not be empty"))
  }
  if topic.contains("#") || topic.contains("+") {
    return Err(
      ClientError::InvalidConfig("publish topic must not contain wildcards"),
    )
  }
  Ok(())
}

///|
fn validate_subscription_filter(topic : String) -> Result[Unit, ClientError] {
  if topic == "" {
    return Err(
      ClientError::InvalidConfig("subscription filter must not be empty"),
    )
  }
  Ok(())
}

///|
async fn write_packet(
  tcp : @socket.Tcp,
  packet : @codec.Packet,
) -> Unit raise ClientError {
  let encoded = match @codec.encode_packet(packet) {
    Ok(value) => value
    Err(message) => raise ClientError::Codec(message)
  }
  let bytes : Bytes = [ for byte in encoded => byte ]
  tcp.write(bytes) catch {
    _ => raise ClientError::TransportFailure
  }
}

///|
async fn read_packet(tcp : @socket.Tcp) -> @codec.Packet raise ClientError {
  let first = tcp.read_exactly(1) catch {
    _ => raise ClientError::TransportFailure
  }
  let frame : Array[Byte] = [first[0]]
  let mut complete = false
  while !complete {
    let next = tcp.read_exactly(1) catch {
      _ => raise ClientError::TransportFailure
    }
    frame.push(next[0])
    complete = (next[0] & 0x80) == 0
    if frame.length() > 5 {
      raise ClientError::Codec(
        "packet remaining-length header exceeds four bytes",
      )
    }
  }
  let body_length = match packet_body_length(frame) {
    Ok(value) => value
    Err(error) => raise error
  }
  let body = tcp.read_exactly(body_length) catch {
    _ => raise ClientError::TransportFailure
  }
  for byte in body {
    frame.push(byte)
  }
  match @codec.decode_packet(frame) {
    Ok(packet) => packet
    Err(message) => raise ClientError::Codec(message)
  }
}

///|
/// Decode the Remaining Length field from a fixed-header buffer. Kept pure so
/// malformed and oversized frames can be tested without opening a socket.
pub fn packet_body_length(frame : Array[Byte]) -> Result[Int32, ClientError] {
  if frame.length() < 2 {
    return Err(ClientError::Codec("incomplete fixed header"))
  }
  let (body_length, end) = match @codec.decode_remaining_length(frame, 1) {
    Ok(value) => value
    Err(message) => return Err(ClientError::Codec(message))
  }
  if end != frame.length() {
    return Err(ClientError::Codec("unexpected bytes after Remaining Length"))
  }
  if body_length > 1_048_576 {
    return Err(ClientError::Codec("packet exceeds the configured 1 MiB limit"))
  }
  Ok(body_length)
}

///|
/// Open a plain TCP connection and complete the MQTT 3.1.1 CONNECT handshake.
/// TLS, reconnect, and automatic keep-alive scheduling are intentionally out
/// of scope for this first client runtime.
pub async fn Client::connect(
  host : String,
  port~ : Int32,
  client_id~ : String,
  keep_alive~ : Int32 = 30,
) -> Client raise ClientError {
  if host == "" {
    raise ClientError::InvalidConfig("host must not be empty")
  }
  if port <= 0 || port > 65535 {
    raise ClientError::InvalidConfig("port must be between 1 and 65535")
  }
  if client_id == "" {
    raise ClientError::InvalidConfig("client_id must not be empty")
  }
  if keep_alive < 0 || keep_alive > 65535 {
    raise ClientError::InvalidConfig("keep_alive must fit in 16 bits")
  }
  let addr = @socket.Addr::resolve(host, port~) catch {
    _ => raise ClientError::TransportFailure
  }
  let tcp = @socket.Tcp::connect(addr) catch {
    _ => raise ClientError::TransportFailure
  }
  errdefer tcp.close()
  let connect_packet = @codec.ConnectPacket({
    client_id,
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
      clean_session: true,
    },
  })
  write_packet(tcp, connect_packet)
  match read_packet(tcp) {
    @codec.ConnackPacket(response) =>
      match response.return_code {
        @codec.ConnectionAccepted => { tcp, keep_alive, next_packet_id: 1, }
        @codec.UnacceptableProtocolVersion => raise ClientError::Rejected(1)
        @codec.IdentifierRejected => raise ClientError::Rejected(2)
        @codec.ServerUnavailable => raise ClientError::Rejected(3)
        @codec.BadUserNameOrPassword => raise ClientError::Rejected(4)
        @codec.NotAuthorized => raise ClientError::Rejected(5)
      }
    _ => raise ClientError::UnexpectedPacket("expected CONNACK")
  }
}

///|
/// Publish one QoS 0 message. The call completes after bytes are written;
/// MQTT QoS 0 does not provide broker acknowledgement.
pub async fn Client::publish(
  self : Client,
  topic~ : String,
  payload~ : Bytes,
  retain~ : Bool = false,
) -> Unit raise ClientError {
  match validate_publish_topic(topic) {
    Ok(_) => ()
    Err(error) => raise error
  }
  write_packet(
    self.tcp,
    @codec.PublishPacket({
      topic,
      payload,
      qos: @codec.QoS0,
      message_id: None,
      retain,
      dup: false,
    }),
  )
}

///|
/// Publish one QoS 1 message and wait for the matching PUBACK.
pub async fn Client::publish_qos1(
  self : Client,
  topic~ : String,
  payload~ : Bytes,
  retain~ : Bool = false,
) -> Unit raise ClientError {
  match validate_publish_topic(topic) {
    Ok(_) => ()
    Err(error) => raise error
  }
  let message_id = self.allocate_packet_id()
  write_packet(
    self.tcp,
    @codec.PublishPacket({
      topic,
      payload,
      qos: @codec.QoS1,
      message_id: Some(message_id),
      retain,
      dup: false,
    }),
  )
  match read_packet(self.tcp) {
    @codec.PubackPacket(response) if response.message_id == message_id => ()
    @codec.PubackPacket(_) =>
      raise ClientError::UnexpectedPacket(
        "PUBACK packet identifier did not match",
      )
    _ => raise ClientError::UnexpectedPacket("expected PUBACK")
  }
}

///|
fn validate_suback(
  response : @codec.Suback,
  expected_message_id : Int32,
  requested_qos : @codec.QoS,
) -> Result[Unit, ClientError] {
  if response.message_id != expected_message_id {
    return Err(ClientError::UnexpectedPacket("expected matching SUBACK"))
  }
  if response.return_codes.length() != 1 {
    return Err(
      ClientError::UnexpectedPacket(
        "SUBACK must contain one result for the requested topic",
      ),
    )
  }
  match response.return_codes[0] {
    @codec.SuccessQoS0 => Ok(())
    @codec.SuccessQoS1 if requested_qos == @codec.QoS1 => Ok(())
    @codec.SuccessQoS1 =>
      Err(
        ClientError::UnexpectedPacket(
          "broker granted a higher QoS than requested",
        ),
      )
    @codec.Failure => Err(ClientError::Rejected(128))
    @codec.SuccessQoS2 =>
      Err(ClientError::UnexpectedPacket("broker granted unsupported QoS 2"))
  }
}

///|
/// Subscribe to one topic filter and wait for its SUBACK response.
pub async fn Client::subscribe(
  self : Client,
  topic~ : String,
  qos~ : @codec.QoS,
) -> Unit raise ClientError {
  match validate_subscription_filter(topic) {
    Ok(_) => ()
    Err(error) => raise error
  }
  if qos == @codec.QoS2 {
    raise ClientError::InvalidConfig("QoS 2 subscription is not supported")
  }
  let message_id = self.allocate_packet_id()
  write_packet(
    self.tcp,
    @codec.SubscribePacket({ topics: [{ topic, qos, }], message_id, }),
  )
  match read_packet(self.tcp) {
    @codec.SubackPacket(response) =>
      match validate_suback(response, message_id, qos) {
        Ok(_) => ()
        Err(error) => raise error
      }
    _ => raise ClientError::UnexpectedPacket("expected matching SUBACK")
  }
}

///|
/// Unsubscribe from one topic filter and wait for the matching UNSUBACK.
pub async fn Client::unsubscribe(
  self : Client,
  topic~ : String,
) -> Unit raise ClientError {
  match validate_subscription_filter(topic) {
    Ok(_) => ()
    Err(error) => raise error
  }
  let message_id = self.allocate_packet_id()
  write_packet(
    self.tcp,
    @codec.UnsubscribePacket({ topics: [topic], message_id, }),
  )
  match read_packet(self.tcp) {
    @codec.UnsubackPacket(response) if response.message_id == message_id => ()
    @codec.UnsubackPacket(_) =>
      raise ClientError::UnexpectedPacket(
        "UNSUBACK packet identifier did not match",
      )
    _ => raise ClientError::UnexpectedPacket("expected UNSUBACK")
  }
}

///|
/// Send one keep-alive ping and wait for the broker's PINGRESP.
/// The caller is responsible for scheduling pings within the configured interval.
pub async fn Client::ping(self : Client) -> Unit raise ClientError {
  if self.keep_alive == 0 {
    raise ClientError::InvalidConfig(
      "PINGREQ is unnecessary when keep_alive is disabled",
    )
  }
  write_packet(self.tcp, @codec.PingreqPacket)
  match read_packet(self.tcp) {
    @codec.PingrespPacket => ()
    _ => raise ClientError::UnexpectedPacket("expected PINGRESP")
  }
}

///|
/// Read the next published message. QoS 1 deliveries are acknowledged before
/// returning to the caller; QoS 2 session state is not implemented.
pub async fn Client::receive(self : Client) -> Message raise ClientError {
  match read_packet(self.tcp) {
    @codec.PublishPacket(message) => {
      if message.qos == @codec.QoS1 {
        let message_id = match message.message_id {
          Some(value) => value
          None =>
            raise ClientError::Codec("QoS 1 PUBLISH has no packet identifier")
        }
        write_packet(self.tcp, @codec.PubackPacket({ message_id, }))
      } else if message.qos == @codec.QoS2 {
        raise ClientError::UnexpectedPacket("QoS 2 delivery is not supported")
      }
      {
        topic: message.topic,
        payload: message.payload,
        qos: message.qos,
        retain: message.retain,
      }
    }
    _ => raise ClientError::UnexpectedPacket("expected PUBLISH")
  }
}

///|
/// Send DISCONNECT and close the TCP connection.
pub async fn Client::disconnect(self : Client) -> Unit raise ClientError {
  let result : Result[Unit, ClientError] = try {
    write_packet(self.tcp, @codec.DisconnectPacket)
    Ok(())
  } catch {
    error => Err(error)
  }
  self.tcp.close()
  match result {
    Ok(_) => ()
    Err(error) => raise error
  }
}

///|
test "MQTT packet identifiers wrap to the valid nonzero range" {
  assert_eq(next_packet_id(1), 2)
  assert_eq(next_packet_id(65534), 65535)
  assert_eq(next_packet_id(65535), 1)
  assert_eq(next_packet_id(0), 1)
}

///|
test "MQTT publish topics reject empty names and wildcards" {
  assert_eq(
    validate_publish_topic(""),
    Err(ClientError::InvalidConfig("publish topic must not be empty")),
  )
  assert_eq(
    validate_publish_topic("demo/#"),
    Err(ClientError::InvalidConfig("publish topic must not contain wildcards")),
  )
  assert_eq(validate_publish_topic("demo/temperature"), Ok(()))
}

///|
test "MQTT subscription filters reject empty values" {
  assert_eq(
    validate_subscription_filter(""),
    Err(ClientError::InvalidConfig("subscription filter must not be empty")),
  )
  assert_eq(validate_subscription_filter("demo/+"), Ok(()))
}
