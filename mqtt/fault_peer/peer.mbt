/// Deterministic MQTT 3.1.1 broker-side behaviors for exercising clients.
/// This is a focused test peer, not a complete MQTT broker or conformance suite.

///|
pub(all) enum Scenario {
  RejectConnect
  TruncateConnack
  MismatchedPuback
  UnexpectedSubackResponse
}

/// One-shot peer bound to a loopback ephemeral port.

///|
pub struct Peer {
  server : @socket.TcpServer
  scenario : Scenario
}

///|
/// Bind a one-shot peer to an available loopback port.
pub async fn Peer::new(scenario : Scenario) -> Peer {
  let server = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:0"))
  { server, scenario, }
}

///|
/// The ephemeral TCP port selected by the operating system.
pub fn Peer::port(self : Peer) -> Int32 {
  self.server.addr.port()
}

///|
/// Accept one MQTT client connection and perform the selected behavior.
pub async fn Peer::run(self : Peer) -> Unit {
  self.server.run_forever(max_connections=1) <| ((tcp, _) => {
    match read_packet(tcp) {
      @codec.ConnectPacket(_) => ()
      _ => fail("fault peer expected CONNECT as the first packet")
    }
    match self.scenario {
      RejectConnect =>
        write_packet(
          tcp,
          @codec.ConnackPacket({
            session_present: false,
            return_code: @codec.NotAuthorized,
          }),
        )
      TruncateConnack => {
        let truncated : Bytes = [0x20, 0x02, 0x00]
        tcp.write(truncated)
      }
      MismatchedPuback => {
        accept_connection(tcp)
        let message_id = match read_packet(tcp) {
          @codec.PublishPacket(message) => {
            if message.qos != @codec.QoS1 {
              fail("fault peer expected a QoS 1 PUBLISH")
            }
            message.message_id.unwrap()
          }
          _ => fail("fault peer expected PUBLISH after CONNECT")
        }
        let wrong_id = if message_id == 65535 { 1 } else { message_id + 1 }
        write_packet(tcp, @codec.PubackPacket({ message_id: wrong_id, }))
      }
      UnexpectedSubackResponse => {
        accept_connection(tcp)
        match read_packet(tcp) {
          @codec.SubscribePacket(_) => ()
          _ => fail("fault peer expected SUBSCRIBE after CONNECT")
        }
        write_packet(tcp, @codec.PingrespPacket)
        match read_packet(tcp) {
          @codec.DisconnectPacket => ()
          _ => fail("fault peer expected DISCONNECT after unexpected response")
        }
      }
    }
  })
  self.server.close()
}

///|
/// Complete an accepted MQTT 3.1.1 connection handshake.
async fn accept_connection(tcp : @socket.Tcp) -> Unit {
  write_packet(
    tcp,
    @codec.ConnackPacket({
      session_present: false,
      return_code: @codec.ConnectionAccepted,
    }),
  )
}

///|
/// Read exactly one MQTT packet from the connected test client.
async fn read_packet(tcp : @socket.Tcp) -> @codec.Packet {
  let first = tcp.read_exactly(1)
  let frame : Array[Byte] = [first[0]]
  let mut complete = false
  while !complete {
    let next = tcp.read_exactly(1)
    frame.push(next[0])
    complete = (next[0] & 0x80) == 0
    if frame.length() > 5 {
      fail("fault peer received an invalid remaining-length header")
    }
  }
  let (body_length, _) = @codec.decode_remaining_length(frame, 1).unwrap()
  let body = tcp.read_exactly(body_length)
  for byte in body {
    frame.push(byte)
  }
  @codec.decode_packet(frame).unwrap()
}

///|
/// Encode and send one MQTT packet to the connected test client.
async fn write_packet(tcp : @socket.Tcp, packet : @codec.Packet) -> Unit {
  let encoded = @codec.encode_packet(packet).unwrap()
  let bytes : Bytes = [ for byte in encoded => byte ]
  tcp.write(bytes)
}
