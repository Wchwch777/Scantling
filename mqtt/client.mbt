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
/// A topic filter and the maximum quality of service requested for it.
pub(all) struct Subscription {
  topic : String
  qos : @codec.QoS
}

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
  mut pending_messages : Array[Message]
}

///|
/// Bound messages read while a request waits for its acknowledgement.
const MAX_PENDING_MESSAGES : Int32 = 64

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
pub fn validate_publish_topic(topic : String) -> Result[Unit, ClientError] {
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
pub fn validate_subscription_filter(
  topic : String,
) -> Result[Unit, ClientError] {
  if topic == "" {
    return Err(
      ClientError::InvalidConfig("subscription filter must not be empty"),
    )
  }
  // MQTT wildcards are whole topic levels: '+' matches exactly one level,
  // and '#' matches the remaining levels only when it is the final level.
  let mut hash_level_seen = false
  for level in topic.split("/") {
    if hash_level_seen {
      return Err(
        ClientError::InvalidConfig(
          "multi-level wildcard must be the final topic level",
        ),
      )
    }
    if level.contains("#".view()) {
      if level != "#".view() {
        return Err(
          ClientError::InvalidConfig(
            "multi-level wildcard must occupy a complete topic level",
          ),
        )
      }
      hash_level_seen = true
    }
    if level.contains("+".view()) && level != "+".view() {
      return Err(
        ClientError::InvalidConfig(
          "single-level wildcard must occupy a complete topic level",
        ),
      )
    }
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
/// Wait for a request response while preserving asynchronous broker publishes.
async fn Client::read_response_packet(
  self : Client,
) -> @codec.Packet raise ClientError {
  while true {
    match read_packet(self.tcp) {
      @codec.PublishPacket(message) => {
        if self.pending_messages.length() >= MAX_PENDING_MESSAGES {
          self.tcp.close()
          raise ClientError::UnexpectedPacket(
            "pending inbound message queue limit exceeded; connection closed",
          )
        }
        if message.qos == @codec.QoS2 {
          raise ClientError::UnexpectedPacket("QoS 2 delivery is not supported")
        }
        self.pending_messages.push({
          topic: message.topic,
          payload: message.payload,
          qos: message.qos,
          retain: message.retain,
        })
        if message.qos == @codec.QoS1 {
          let message_id = match message.message_id {
            Some(value) => value
            None =>
              raise ClientError::Codec("QoS 1 PUBLISH has no packet identifier")
          }
          write_packet(self.tcp, @codec.PubackPacket({ message_id, }))
        }
      }
      packet => return packet
    }
  }
  raise ClientError::UnexpectedPacket("response stream ended unexpectedly")
}

///|
fn Client::take_pending_message(self : Client) -> Message? {
  if self.pending_messages.length() == 0 {
    None
  } else {
    let message = self.pending_messages[0]
    for index in 1..<self.pending_messages.length() {
      self.pending_messages[index - 1] = self.pending_messages[index]
    }
    ignore(self.pending_messages.pop())
    Some(message)
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
fn validate_credentials(
  username : String?,
  password : Bytes?,
) -> Result[Unit, ClientError] {
  if password is Some(_) && username is None {
    return Err(ClientError::InvalidConfig("MQTT password requires a username"))
  }
  Ok(())
}

///|
/// Open a plain TCP connection and complete the MQTT 3.1.1 CONNECT handshake.
/// Credentials are sent in clear text over this plain TCP connection. TLS,
/// reconnect, and automatic keep-alive scheduling are not implemented.
pub async fn Client::connect(
  host : String,
  port~ : Int32,
  client_id~ : String,
  keep_alive~ : Int32 = 30,
  username~ : String? = None,
  password~ : Bytes? = None,
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
  match validate_credentials(username, password) {
    Ok(_) => ()
    Err(error) => raise error
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
    username,
    password,
    will_topic: None,
    will_message: None,
    keep_alive,
    flags: {
      username: username is Some(_),
      password: password is Some(_),
      will_retain: false,
      will_qos: @codec.QoS0,
      will_flag: false,
      clean_session: true,
    },
  })
  write_packet(tcp, connect_packet)
  match read_packet(tcp) {
    @codec.ConnackPacket(response) =>
      match validate_connack(response) {
        Ok(_) => { tcp, keep_alive, next_packet_id: 1, pending_messages: [], }
        Err(error) => raise error
      }
    _ => raise ClientError::UnexpectedPacket("expected CONNACK")
  }
}

///|
/// The client always requests Clean Session, so a successful CONNACK must not
/// claim that the broker resumed a session.
fn validate_connack(response : @codec.Connack) -> Result[Unit, ClientError] {
  if response.session_present {
    return Err(
      ClientError::UnexpectedPacket(
        "CONNACK session_present must be false for a clean session",
      ),
    )
  }
  match response.return_code {
    @codec.ConnectionAccepted => Ok(())
    @codec.UnacceptableProtocolVersion => Err(ClientError::Rejected(1))
    @codec.IdentifierRejected => Err(ClientError::Rejected(2))
    @codec.ServerUnavailable => Err(ClientError::Rejected(3))
    @codec.BadUserNameOrPassword => Err(ClientError::Rejected(4))
    @codec.NotAuthorized => Err(ClientError::Rejected(5))
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
  match self.read_response_packet() {
    @codec.PubackPacket(response) =>
      match validate_puback(response, message_id) {
        Ok(_) => ()
        Err(error) => raise error
      }
    _ => raise ClientError::UnexpectedPacket("expected PUBACK")
  }
}

///|
fn validate_puback(
  response : @codec.PacketId,
  expected_message_id : Int32,
) -> Result[Unit, ClientError] {
  if response.message_id == expected_message_id {
    Ok(())
  } else {
    Err(ClientError::UnexpectedPacket("PUBACK packet identifier did not match"))
  }
}

///|
fn validate_suback(
  response : @codec.Suback,
  expected_message_id : Int32,
  requested_topics : Array[Subscription],
) -> Result[Unit, ClientError] {
  if response.message_id != expected_message_id {
    return Err(ClientError::UnexpectedPacket("expected matching SUBACK"))
  }
  if response.return_codes.length() != requested_topics.length() {
    return Err(
      ClientError::UnexpectedPacket(
        "SUBACK result count must match the requested topic count",
      ),
    )
  }
  for index in 0..<requested_topics.length() {
    match response.return_codes[index] {
      @codec.SuccessQoS0 => ()
      @codec.SuccessQoS1 if requested_topics[index].qos == @codec.QoS1 => ()
      @codec.SuccessQoS1 =>
        return Err(
          ClientError::UnexpectedPacket(
            "broker granted a higher QoS than requested",
          ),
        )
      @codec.Failure => return Err(ClientError::Rejected(128))
      @codec.SuccessQoS2 =>
        return Err(
          ClientError::UnexpectedPacket("broker granted unsupported QoS 2"),
        )
    }
  }
  Ok(())
}

///|
/// Subscribe to one or more topic filters in one MQTT request.
pub async fn Client::subscribe_many(
  self : Client,
  topics~ : Array[Subscription],
) -> Unit raise ClientError {
  if topics.length() == 0 {
    raise ClientError::InvalidConfig("at least one topic filter is required")
  }
  for subscription in topics {
    match validate_subscription_filter(subscription.topic) {
      Ok(_) => ()
      Err(error) => raise error
    }
    if subscription.qos == @codec.QoS2 {
      raise ClientError::InvalidConfig("QoS 2 subscription is not supported")
    }
  }
  let message_id = self.allocate_packet_id()
  let wire_topics : Array[@codec.SubscribeTopic] = topics.map(subscription => @codec.SubscribeTopic::{
    topic: subscription.topic,
    qos: subscription.qos,
  })
  write_packet(
    self.tcp,
    @codec.SubscribePacket({ topics: wire_topics, message_id, }),
  )
  match self.read_response_packet() {
    @codec.SubackPacket(response) =>
      match validate_suback(response, message_id, topics) {
        Ok(_) => ()
        Err(error) => raise error
      }
    _ => raise ClientError::UnexpectedPacket("expected matching SUBACK")
  }
}

///|
/// Subscribe to one topic filter and wait for its SUBACK response.
pub async fn Client::subscribe(
  self : Client,
  topic~ : String,
  qos~ : @codec.QoS,
) -> Unit raise ClientError {
  self.subscribe_many(topics=[Subscription::{ topic, qos, }])
}

///|
/// Unsubscribe from one or more topic filters in one MQTT request.
pub async fn Client::unsubscribe_many(
  self : Client,
  topics~ : Array[String],
) -> Unit raise ClientError {
  if topics.length() == 0 {
    raise ClientError::InvalidConfig("at least one topic filter is required")
  }
  for topic in topics {
    match validate_subscription_filter(topic) {
      Ok(_) => ()
      Err(error) => raise error
    }
  }
  let message_id = self.allocate_packet_id()
  write_packet(self.tcp, @codec.UnsubscribePacket({ topics, message_id, }))
  match self.read_response_packet() {
    @codec.UnsubackPacket(response) =>
      match validate_unsuback(response, message_id) {
        Ok(_) => ()
        Err(error) => raise error
      }
    _ => raise ClientError::UnexpectedPacket("expected UNSUBACK")
  }
}

///|
/// Unsubscribe from one topic filter and wait for the matching UNSUBACK.
pub async fn Client::unsubscribe(
  self : Client,
  topic~ : String,
) -> Unit raise ClientError {
  self.unsubscribe_many(topics=[topic])
}

///|
fn validate_unsuback(
  response : @codec.Unsuback,
  expected_message_id : Int32,
) -> Result[Unit, ClientError] {
  if response.message_id == expected_message_id {
    Ok(())
  } else {
    Err(
      ClientError::UnexpectedPacket("UNSUBACK packet identifier did not match"),
    )
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
  match self.read_response_packet() {
    @codec.PingrespPacket => ()
    _ => raise ClientError::UnexpectedPacket("expected PINGRESP")
  }
}

///|
/// Read the next published message. QoS 1 deliveries are acknowledged before
/// returning to the caller; QoS 2 session state is not implemented.
pub async fn Client::receive(self : Client) -> Message raise ClientError {
  match self.take_pending_message() {
    Some(message) => return message
    None => ()
  }
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

///|
test "MQTT CONNACK rejects resumed sessions when Clean Session was requested" {
  assert_eq(
    validate_connack({
      session_present: false,
      return_code: @codec.ConnectionAccepted,
    }),
    Ok(()),
  )
  assert_eq(
    validate_connack({
      session_present: true,
      return_code: @codec.ConnectionAccepted,
    }),
    Err(
      ClientError::UnexpectedPacket(
        "CONNACK session_present must be false for a clean session",
      ),
    ),
  )
}

///|
test "MQTT CONNACK preserves broker rejection reason codes" {
  assert_eq(
    validate_connack({
      session_present: false,
      return_code: @codec.NotAuthorized,
    }),
    Err(ClientError::Rejected(5)),
  )
}

///|
test "MQTT PUBACK must match the request packet identifier" {
  assert_eq(validate_puback({ message_id: 7, }, 7), Ok(()))
  assert_eq(
    validate_puback({ message_id: 8, }, 7),
    Err(ClientError::UnexpectedPacket("PUBACK packet identifier did not match")),
  )
}

///|
test "MQTT SUBACK must match every requested filter and granted QoS" {
  let requested_topics = [
    Subscription::{ topic: "sensors/+", qos: @codec.QoS0, },
    Subscription::{ topic: "devices/#", qos: @codec.QoS1, },
  ]
  assert_eq(
    validate_suback(
      {
        message_id: 42,
        return_codes: [@codec.SuccessQoS0, @codec.SuccessQoS1],
      },
      42,
      requested_topics,
    ),
    Ok(()),
  )
  assert_eq(
    validate_suback(
      { message_id: 42, return_codes: [@codec.SuccessQoS1], },
      42,
      requested_topics,
    ),
    Err(
      ClientError::UnexpectedPacket(
        "SUBACK result count must match the requested topic count",
      ),
    ),
  )
  assert_eq(
    validate_suback(
      {
        message_id: 42,
        return_codes: [@codec.SuccessQoS0, @codec.SuccessQoS1],
      },
      43,
      requested_topics,
    ),
    Err(ClientError::UnexpectedPacket("expected matching SUBACK")),
  )
  assert_eq(
    validate_suback(
      {
        message_id: 42,
        return_codes: [@codec.SuccessQoS1, @codec.SuccessQoS1],
      },
      42,
      requested_topics,
    ),
    Err(
      ClientError::UnexpectedPacket(
        "broker granted a higher QoS than requested",
      ),
    ),
  )
  assert_eq(
    validate_suback(
      { message_id: 42, return_codes: [@codec.SuccessQoS0, @codec.Failure], },
      42,
      requested_topics,
    ),
    Err(ClientError::Rejected(128)),
  )
}

///|
test "MQTT UNSUBACK must match the request packet identifier" {
  assert_eq(validate_unsuback({ message_id: 7, }, 7), Ok(()))
  assert_eq(
    validate_unsuback({ message_id: 8, }, 7),
    Err(
      ClientError::UnexpectedPacket("UNSUBACK packet identifier did not match"),
    ),
  )
}

///|
test "MQTT CONNECT credentials require a username when password is present" {
  assert_eq(validate_credentials(None, None), Ok(()))
  assert_eq(validate_credentials(Some("device-1"), None), Ok(()))
  assert_eq(validate_credentials(Some("device-1"), Some(b"secret")), Ok(()))
  match validate_credentials(None, Some(b"secret")) {
    Err(ClientError::InvalidConfig(message)) =>
      assert_eq(message, "MQTT password requires a username")
    _ => fail("expected a password-without-username configuration error")
  }
}
