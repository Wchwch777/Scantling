/// Deterministic MQTT 3.1.1 broker-side behavior for exercising clients.
/// This is a focused test peer, not a complete MQTT broker or conformance suite.

///|
pub(all) enum Scenario {
  RejectConnect
  TruncateConnack
  MismatchedPuback
  UnexpectedSubackResponse
  AcceptPublishQoS0
  AcceptPublishQoS1
}

/// A response emitted by one scripted exchange.
///
/// SendRaw allows tests to produce malformed or truncated wire data that
/// cannot be represented by a valid MQTT packet value.

///|
pub(all) enum Action {
  SendPacket(@codec.Packet)
  SendRaw(Bytes)
  Close
}

/// One scripted protocol state transition.
///
/// The matcher receives the full decoded packet. The responder can inspect
/// packet fields such as packet identifiers and return zero or more actions.

///|
pub(all) struct Exchange {
  name : String
  matches : (@codec.Packet) -> Bool
  respond : (@codec.Packet) -> Array[Action]
}

/// An ordered, one-connection broker-side test script.
///
/// Each exchange consumes exactly one client packet. The peer closes after
/// the final exchange unless an earlier response includes Action::Close.

///|
pub(all) struct Script {
  exchanges : Array[Exchange]
}

/// Build a named exchange from a packet matcher and response function.

///|
pub fn Exchange::new(
  name : String,
  matches : (@codec.Packet) -> Bool,
  respond : (@codec.Packet) -> Array[Action],
) -> Exchange {
  { name, matches, respond, }
}

/// Build a non-empty scripted sequence.

///|
pub fn Script::new(exchanges : Array[Exchange]) -> Script {
  { exchanges, }
}

/// One-shot peer bound to a loopback ephemeral port.

///|
pub struct Peer {
  server : @socket.TcpServer
  script : Script
}

/// Bind a one-shot peer that runs one of the common protocol scenarios.

///|
pub async fn Peer::new(scenario : Scenario, port~ : Int32 = 0) -> Peer {
  Peer::with_script(script_for_scenario(scenario), port~)
}

/// Bind a one-shot peer that runs a caller-defined protocol script.
///
/// The peer accepts one connection and follows exchanges in order. It binds
/// only to loopback and is intended for local protocol testing.

///|
pub async fn Peer::with_script(script : Script, port~ : Int32 = 0) -> Peer {
  let server = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:\{port}"))
  { server, script, }
}

/// The ephemeral TCP port selected by the operating system.

///|
pub fn Peer::port(self : Peer) -> Int32 {
  self.server.addr.port()
}

/// Accept one MQTT client connection and execute the configured script.

///|
pub async fn Peer::run(self : Peer) -> Unit {
  let (tcp, _) = self.server.accept()
  run_script(tcp, self.script)
  tcp.close()
  self.server.close()
}

///|
async fn run_script(tcp : @socket.Tcp, script : Script) -> Unit {
  if script.exchanges.length() == 0 {
    fail("fault peer script must contain at least one exchange")
  }
  let mut closed = false
  for exchange in script.exchanges {
    if !closed {
      let packet = read_packet(tcp)
      if !(exchange.matches)(packet) {
        fail("fault peer script mismatch at exchange: \{exchange.name}")
      }
      for action in (exchange.respond)(packet) {
        if !closed {
          match action {
            SendPacket(response) => write_packet(tcp, response)
            SendRaw(bytes) => tcp.write(bytes)
            Close => closed = true
          }
        }
      }
    }
  }
}

///|
fn script_for_scenario(scenario : Scenario) -> Script {
  match scenario {
    RejectConnect =>
      Script::new([Exchange::new("CONNECT", is_connect, reject_connect)])
    TruncateConnack =>
      Script::new([Exchange::new("CONNECT", is_connect, truncate_connack)])
    MismatchedPuback =>
      Script::new([
        Exchange::new("CONNECT", is_connect, accept_connect),
        Exchange::new("QoS 1 PUBLISH", is_publish_qos1, mismatch_puback),
        Exchange::new("DISCONNECT", is_disconnect, no_response),
      ])
    UnexpectedSubackResponse =>
      Script::new([
        Exchange::new("CONNECT", is_connect, accept_connect),
        Exchange::new("SUBSCRIBE", is_subscribe, unexpected_suback_response),
        Exchange::new("DISCONNECT", is_disconnect, no_response),
      ])
    AcceptPublishQoS0 =>
      Script::new([
        Exchange::new("CONNECT", is_connect, accept_connect),
        Exchange::new("QoS 0 PUBLISH", is_publish_qos0, close_peer),
      ])
    AcceptPublishQoS1 =>
      Script::new([
        Exchange::new("CONNECT", is_connect, accept_connect),
        Exchange::new("QoS 1 PUBLISH", is_publish_qos1, accept_publish_qos1),
      ])
  }
}

///|
fn is_connect(packet : @codec.Packet) -> Bool {
  match packet {
    @codec.ConnectPacket(_) => true
    _ => false
  }
}

///|
fn is_disconnect(packet : @codec.Packet) -> Bool {
  match packet {
    @codec.DisconnectPacket => true
    _ => false
  }
}

///|
fn is_subscribe(packet : @codec.Packet) -> Bool {
  match packet {
    @codec.SubscribePacket(_) => true
    _ => false
  }
}

///|
fn is_publish_qos0(packet : @codec.Packet) -> Bool {
  match packet {
    @codec.PublishPacket(message) if message.qos == @codec.QoS0 => true
    _ => false
  }
}

///|
fn is_publish_qos1(packet : @codec.Packet) -> Bool {
  match packet {
    @codec.PublishPacket(message) if message.qos == @codec.QoS1 => true
    _ => false
  }
}

///|
fn accept_connect(_packet : @codec.Packet) -> Array[Action] {
  [
    SendPacket(
      @codec.ConnackPacket({
        session_present: false,
        return_code: @codec.ConnectionAccepted,
      }),
    ),
  ]
}

///|
fn reject_connect(_packet : @codec.Packet) -> Array[Action] {
  [
    SendPacket(
      @codec.ConnackPacket({
        session_present: false,
        return_code: @codec.NotAuthorized,
      }),
    ),
  ]
}

///|
fn truncate_connack(_packet : @codec.Packet) -> Array[Action] {
  let truncated : Bytes = [0x20, 0x02, 0x00]
  [SendRaw(truncated), Close]
}

///|
fn mismatch_puback(packet : @codec.Packet) -> Array[Action] {
  match packet {
    @codec.PublishPacket(message) =>
      match message.message_id {
        Some(message_id) => {
          let wrong_id = if message_id == 65535 { 1 } else { message_id + 1 }
          [SendPacket(@codec.PubackPacket({ message_id: wrong_id, }))]
        }
        None => [Close]
      }
    _ => []
  }
}

///|
fn unexpected_suback_response(_packet : @codec.Packet) -> Array[Action] {
  [SendPacket(@codec.PingrespPacket)]
}

///|
fn close_peer(_packet : @codec.Packet) -> Array[Action] {
  [Close]
}

///|
fn accept_publish_qos1(packet : @codec.Packet) -> Array[Action] {
  match packet {
    @codec.PublishPacket(message) =>
      match message.message_id {
        Some(message_id) =>
          [SendPacket(@codec.PubackPacket({ message_id, })), Close]
        None => [Close]
      }
    _ => []
  }
}

///|
fn no_response(_packet : @codec.Packet) -> Array[Action] {
  []
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
/// Encode and send one valid MQTT packet to the connected test client.
async fn write_packet(tcp : @socket.Tcp, packet : @codec.Packet) -> Unit {
  let encoded = @codec.encode_packet(packet).unwrap()
  let bytes : Bytes = [ for byte in encoded => byte ]
  tcp.write(bytes)
}
