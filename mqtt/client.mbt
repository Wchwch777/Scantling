/// MQTT 3.1.1 asynchronous TCP client runtime.
/// Packet encoding and decoding are delegated to zbhzs1/moonbit-mqtt.

///|
pub(all) struct Message {
  topic : String
  payload : Bytes
  retain : Bool
} derive(Eq, Debug)

///|
pub suberror ClientError {
  InvalidConfig(String)
  Codec(String)
  Rejected(Int)
  TransportFailure
  UnexpectedPacket(String)
} derive(Eq, Debug)

///|
pub(all) struct Client {
  tcp : @socket.Tcp
  mut next_packet_id : Int
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
pub fn packet_body_length(frame : Array[Byte]) -> Result[Int, ClientError] {
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
  port~ : Int,
  client_id~ : String,
  keep_alive? : Int = 30,
) -> Client raise ClientError {
  if host == "" {
    raise ClientError::InvalidConfig("host must not be empty")
  }
  if port <= 0 || port > 65535 {
    raise ClientError::InvalidConfig("port must be between 1 and 65535")
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
        @codec.ConnectionAccepted => { tcp, next_packet_id: 1, }
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
  retain? : Bool = false,
) -> Unit raise ClientError {
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
fn validate_suback(
  response : @codec.Suback,
  expected_message_id : Int,
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
  if qos == @codec.QoS2 {
    raise ClientError::InvalidConfig("QoS 2 subscription is not supported")
  }
  let message_id = self.next_packet_id
  self.next_packet_id = if message_id >= 65535 { 1 } else { message_id + 1 }
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
        retain: message.retain,
      }
    }
    _ => raise ClientError::UnexpectedPacket("expected PUBLISH")
  }
}

///|
/// Send DISCONNECT and close the TCP connection.
pub async fn Client::disconnect(self : Client) -> Unit raise ClientError {
  write_packet(self.tcp, @codec.DisconnectPacket)
  self.tcp.close()
}
