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
  Delay(Int32)
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

///|
/// Parse a line-oriented scenario script for use by clients outside MoonBit.
///
/// Supported directives are `expect PACKET [qos=N]`, `send PACKET ...`,
/// `raw HEX...`, `wait MILLISECONDS`, and `close`. Each `expect` begins an
/// exchange; following response directives belong to it until the next
/// `expect`.
pub fn Script::parse(source : String) -> Result[Script, String] {
  let exchanges : Array[Exchange] = []
  let mut current_matcher : ((@codec.Packet) -> Bool)? = None
  let mut current_name = ""
  let mut current_packet_type = ""
  let mut current_qos_filter : Int32? = None
  let mut current_responses : Array[ScriptResponse] = []
  let mut current_closed = false
  let mut line_number = 0
  for raw_line in source.split("\n") {
    line_number += 1
    let line = raw_line.to_owned().trim(chars="\r\t ")
    if line == "" || line.has_prefix("#") {
      continue
    }
    let words : Array[String] = []
    for raw_word in line.replace_all(old="\t", new=" ").split(" ") {
      let word = raw_word.trim(chars="\t ")
      if word != "" {
        words.push(word.to_owned())
      }
    }
    if words.is_empty() {
      continue
    }
    match words[0] {
      "expect" => {
        if current_closed {
          return Err(
            "line " +
            line_number.to_string() +
            ": cannot expect another packet after close",
          )
        }
        match current_matcher {
          Some(matcher) =>
            exchanges.push(
              exchange_from_script(current_name, matcher, current_responses),
            )
          None => ()
        }
        match parse_script_matcher(words) {
          Ok((name, packet_type, qos_filter, matcher)) => {
            current_name = name
            current_packet_type = packet_type
            current_qos_filter = qos_filter
            current_matcher = Some(matcher)
            current_responses = []
            current_closed = false
          }
          Err(error) =>
            return Err("line " + line_number.to_string() + ": " + error)
        }
      }
      "send" | "raw" | "wait" | "close" => {
        if current_matcher is None {
          return Err(
            "line " +
            line_number.to_string() +
            ": response directive must follow an expect",
          )
        }
        if current_closed {
          return Err(
            "line " +
            line_number.to_string() +
            ": response directive cannot follow close",
          )
        }
        match
          parse_script_response(words, current_packet_type, current_qos_filter) {
          Ok(response) => {
            current_responses.push(response)
            if response is CloseResponse {
              current_closed = true
            }
          }
          Err(error) =>
            return Err("line " + line_number.to_string() + ": " + error)
        }
      }
      directive =>
        return Err(
          "line " +
          line_number.to_string() +
          ": unknown directive `" +
          directive +
          "`",
        )
    }
  }
  match current_matcher {
    Some(matcher) =>
      exchanges.push(
        exchange_from_script(current_name, matcher, current_responses),
      )
    None =>
      return Err("scenario script must contain at least one expect directive")
  }
  Ok(Script::new(exchanges))
}

///|
/// Private representation of one response directive in a text script.
priv enum ScriptResponse {
  ConnackResponse(@codec.ConnackReturnCode, Bool)
  PublishResponse(String, @codec.QoS, ScriptPacketId?, Bytes, Bool, Bool)
  PacketIdResponse(String, ScriptPacketId)
  SubackResponse(ScriptPacketId, Array[Int32])
  PingrespResponse
  RawResponse(Bytes)
  DelayResponse(Int32)
  CloseResponse
}

///|
priv enum ScriptPacketId {
  FromRequest
  Fixed(Int32)
}

///|
fn parse_script_matcher(
  words : Array[String],
) -> Result[(String, String, Int32?, (@codec.Packet) -> Bool), String] {
  if words.length() < 2 {
    return Err("expect requires an MQTT packet type")
  }
  let kind = words[1]
  let mut qos_filter : Int32? = None
  let mut id_filter : Int32? = None
  let mut topic_filter : String? = None
  let mut payload_filter : Bytes? = None
  let mut retain_filter : Bool? = None
  let mut dup_filter : Bool? = None
  let seen : Array[String] = []
  let mut index = 2
  while index < words.length() {
    match words[index].split_once("=") {
      Some((key, _)) if seen.contains(key.to_owned()) =>
        return Err("expect options must be unique")
      Some((key, value)) => {
        seen.push(key.to_owned())
        match key {
          "qos" => {
            let qos = @string.parse_int(value) catch {
              _ => return Err("qos must be 0, 1, or 2")
            }
            if qos < 0 || qos > 2 {
              return Err("qos must be 0, 1, or 2")
            }
            qos_filter = Some(qos)
          }
          "id" => {
            let id = @string.parse_int(value) catch {
              _ => return Err("id must be an integer from 1 to 65535")
            }
            if id < 1 || id > 65535 {
              return Err("id must be an integer from 1 to 65535")
            }
            id_filter = Some(id)
          }
          "topic" => {
            if value == "" {
              return Err("topic filter must not be empty")
            }
            topic_filter = Some(value.to_owned())
          }
          "payload_hex" =>
            match parse_script_hex_bytes(value.to_owned()) {
              Ok(payload) => payload_filter = Some(payload)
              Err(error) => return Err("payload_hex " + error)
            }
          "retain" =>
            match value {
              "true" => retain_filter = Some(true)
              "false" => retain_filter = Some(false)
              _ => return Err("retain filter must be true or false")
            }
          "dup" =>
            match value {
              "true" => dup_filter = Some(true)
              "false" => dup_filter = Some(false)
              _ => return Err("dup filter must be true or false")
            }
          _ => return Err("unsupported expect option `" + key.to_owned() + "`")
        }
      }
      None => return Err("expect options must use key=value form")
    }
    index += 1
  }
  if qos_filter is Some(_) && kind != "PUBLISH" {
    return Err("qos filter is only valid for PUBLISH")
  }
  if id_filter is Some(_) && !packet_type_has_identifier(kind) {
    return Err("id filter is not valid for this packet type")
  }
  if topic_filter is Some(_) && kind != "PUBLISH" && kind != "SUBSCRIBE" {
    return Err("topic filter is only valid for PUBLISH or SUBSCRIBE")
  }
  if (
      payload_filter is Some(_) ||
      retain_filter is Some(_) ||
      dup_filter is Some(_)
    ) &&
    kind != "PUBLISH" {
    return Err(
      "payload_hex, retain, and dup filters are only valid for PUBLISH",
    )
  }
  if !is_supported_packet_name(kind) {
    return Err("unsupported MQTT packet type `" + kind + "`")
  }
  let mut name = kind
  match qos_filter {
    Some(qos) => name = name + " qos=" + qos.to_string()
    None => ()
  }
  match id_filter {
    Some(id) => name = name + " id=" + id.to_string()
    None => ()
  }
  match topic_filter {
    Some(topic) => name = name + " topic=" + topic
    None => ()
  }
  let expected_kind = kind
  let matcher_kind = kind
  Ok(
    (
      name,
      expected_kind,
      qos_filter,
      packet => {
        packet_matches_filters(
          packet, matcher_kind, qos_filter, id_filter, topic_filter, payload_filter,
          retain_filter, dup_filter,
        )
      },
    ),
  )
}

///|
fn is_supported_packet_name(name : String) -> Bool {
  match name {
    "CONNECT"
    | "CONNACK"
    | "PUBLISH"
    | "PUBACK"
    | "PUBREC"
    | "PUBREL"
    | "PUBCOMP"
    | "SUBSCRIBE"
    | "SUBACK"
    | "UNSUBSCRIBE"
    | "UNSUBACK"
    | "PINGREQ"
    | "PINGRESP"
    | "DISCONNECT" => true
    _ => false
  }
}

///|
fn packet_type_has_identifier(kind : String) -> Bool {
  match kind {
    "PUBLISH"
    | "PUBACK"
    | "PUBREC"
    | "PUBREL"
    | "PUBCOMP"
    | "SUBSCRIBE"
    | "SUBACK"
    | "UNSUBSCRIBE"
    | "UNSUBACK" => true
    _ => false
  }
}

///|
fn packet_matches_filters(
  packet : @codec.Packet,
  kind : String,
  qos_filter : Int32?,
  id_filter : Int32?,
  topic_filter : String?,
  payload_filter : Bytes?,
  retain_filter : Bool?,
  dup_filter : Bool?,
) -> Bool {
  if !packet_kind_matches(packet, kind) {
    return false
  }
  match qos_filter {
    Some(qos) =>
      match packet {
        @codec.PublishPacket(message) if qos_value(message.qos) == qos => ()
        _ => return false
      }
    None => ()
  }
  match id_filter {
    Some(id) if packet_message_id(packet) != Some(id) => return false
    _ => ()
  }
  match topic_filter {
    Some(topic) if !packet_has_topic(packet, topic) => return false
    _ => ()
  }
  match payload_filter {
    Some(payload) =>
      match packet {
        @codec.PublishPacket(message) if message.payload == payload => ()
        _ => return false
      }
    None => ()
  }
  match retain_filter {
    Some(retain) =>
      match packet {
        @codec.PublishPacket(message) if message.retain == retain => ()
        _ => return false
      }
    None => ()
  }
  match dup_filter {
    Some(dup) =>
      match packet {
        @codec.PublishPacket(message) if message.dup == dup => ()
        _ => return false
      }
    None => ()
  }
  true
}

///|
fn packet_has_topic(packet : @codec.Packet, topic : String) -> Bool {
  match packet {
    @codec.PublishPacket(message) => message.topic == topic
    @codec.SubscribePacket(request) => {
      for item in request.topics {
        if item.topic == topic {
          return true
        }
      }
      false
    }
    _ => false
  }
}

///|
fn packet_kind_matches(packet : @codec.Packet, kind : String) -> Bool {
  match packet {
    @codec.ConnectPacket(_) => kind == "CONNECT"
    @codec.ConnackPacket(_) => kind == "CONNACK"
    @codec.PublishPacket(_) => kind == "PUBLISH"
    @codec.PubackPacket(_) => kind == "PUBACK"
    @codec.PubrecPacket(_) => kind == "PUBREC"
    @codec.PubrelPacket(_) => kind == "PUBREL"
    @codec.PubcompPacket(_) => kind == "PUBCOMP"
    @codec.SubscribePacket(_) => kind == "SUBSCRIBE"
    @codec.SubackPacket(_) => kind == "SUBACK"
    @codec.UnsubscribePacket(_) => kind == "UNSUBSCRIBE"
    @codec.UnsubackPacket(_) => kind == "UNSUBACK"
    @codec.PingreqPacket => kind == "PINGREQ"
    @codec.PingrespPacket => kind == "PINGRESP"
    @codec.DisconnectPacket => kind == "DISCONNECT"
  }
}

///|
fn qos_value(qos : @codec.QoS) -> Int32 {
  match qos {
    @codec.QoS0 => 0
    @codec.QoS1 => 1
    @codec.QoS2 => 2
  }
}

///|
fn parse_script_response(
  words : Array[String],
  expected_packet : String,
  expected_qos : Int32?,
) -> Result[ScriptResponse, String] {
  match words[0] {
    "close" =>
      if words.length() == 1 {
        Ok(CloseResponse)
      } else {
        Err("close takes no arguments")
      }
    "wait" => {
      if words.length() != 2 {
        return Err("wait requires one millisecond value")
      }
      let milliseconds = @string.parse_int(words[1]) catch {
        _ => return Err("wait value must be an integer")
      }
      if milliseconds < 0 || milliseconds > 60000 {
        return Err("wait value must be between 0 and 60000 milliseconds")
      }
      Ok(DelayResponse(milliseconds))
    }
    "raw" => {
      if words.length() < 2 {
        return Err("raw requires one or more hexadecimal byte values")
      }
      let bytes : Array[Byte] = []
      let mut index = 1
      while index < words.length() {
        for part in words[index].split(",") {
          let hex = part.trim()
          if hex != "" {
            let value = @string.parse_int(hex, base=16) catch {
              _ =>
                return Err(
                  "raw byte `" + hex.to_owned() + "` is not hexadecimal",
                )
            }
            if value < 0 || value > 255 {
              return Err("raw byte `" + hex.to_owned() + "` is outside 00..FF")
            }
            bytes.push(value.to_byte())
          }
        }
        index += 1
      }
      if bytes.is_empty() {
        return Err("raw requires at least one byte")
      }
      let raw_bytes : Bytes = [ for byte in bytes => byte ]
      Ok(RawResponse(raw_bytes))
    }
    "send" => parse_packet_response(words, expected_packet, expected_qos)
    _ => Err("unsupported response directive")
  }
}

///|
fn parse_packet_response(
  words : Array[String],
  expected_packet : String,
  expected_qos : Int32?,
) -> Result[ScriptResponse, String] {
  if words.length() < 2 {
    return Err("send requires an MQTT packet type")
  }
  let kind = words[1]
  match kind {
    "PINGRESP" =>
      if words.length() == 2 {
        Ok(PingrespResponse)
      } else {
        Err("PINGRESP takes no options")
      }
    "CONNACK" => {
      let code_text = script_option(words, "code")
      let code = match code_text {
        Some(value) =>
          @string.parse_int(value) catch {
            _ => return Err("CONNACK code must be an integer from 0 to 5")
          }
        None => return Err("CONNACK requires code=0..5")
      }
      let return_code = match code {
        0 => @codec.ConnectionAccepted
        1 => @codec.UnacceptableProtocolVersion
        2 => @codec.IdentifierRejected
        3 => @codec.ServerUnavailable
        4 => @codec.BadUserNameOrPassword
        5 => @codec.NotAuthorized
        _ => return Err("CONNACK code must be between 0 and 5")
      }
      let session_present = match script_option(words, "session_present") {
        None | Some("false") => false
        Some("true") => true
        Some(_) => return Err("session_present must be true or false")
      }
      if has_invalid_options(words, ["code", "session_present"]) {
        return Err("CONNACK options must be supported and unique")
      }
      Ok(ConnackResponse(return_code, session_present))
    }
    "PUBLISH" => {
      let topic = match script_option(words, "topic") {
        Some(value) if value != "" => value
        _ => return Err("PUBLISH requires a non-empty topic option")
      }
      if topic.contains("#") || topic.contains("+") {
        return Err("PUBLISH topic name must not contain wildcards")
      }
      let qos = match script_option(words, "qos") {
        Some("0") => @codec.QoS0
        Some("1") => @codec.QoS1
        Some("2") => @codec.QoS2
        _ => return Err("PUBLISH requires qos=0, qos=1, or qos=2")
      }
      let packet_id = match script_option(words, "id") {
        None if qos == @codec.QoS0 => None
        Some(value) if qos != @codec.QoS0 =>
          match parse_script_packet_id(value) {
            Ok(id) =>
              match id {
                Fixed(number) if number >= 1 && number <= 65535 => Some(id)
                _ => return Err("PUBLISH id must be between 1 and 65535")
              }
            Err(error) => return Err(error)
          }
        None => return Err("PUBLISH qos 1 or 2 requires id=<1..65535>")
        Some(_) => return Err("PUBLISH qos 0 must not include id")
      }
      let payload = match script_option(words, "payload_hex") {
        Some(value) =>
          match parse_script_hex_bytes(value) {
            Ok(bytes) => bytes
            Err(error) => return Err("PUBLISH payload_hex " + error)
          }
        None => []
      }
      let retain = match script_option(words, "retain") {
        None | Some("false") => false
        Some("true") => true
        Some(_) => return Err("PUBLISH retain must be true or false")
      }
      let dup = match script_option(words, "dup") {
        None | Some("false") => false
        Some("true") => true
        Some(_) => return Err("PUBLISH dup must be true or false")
      }
      if qos == @codec.QoS0 && dup {
        return Err("PUBLISH qos=0 must use dup=false")
      }
      if has_invalid_options(words, [
          "topic", "qos", "id", "payload_hex", "retain", "dup",
        ]) {
        return Err("PUBLISH options must be supported and unique")
      }
      Ok(PublishResponse(topic, qos, packet_id, payload, retain, dup))
    }
    "PUBACK" | "PUBREC" | "PUBREL" | "PUBCOMP" | "UNSUBACK" => {
      let id_text = match script_option(words, "id") {
        Some(value) => value
        None =>
          return Err("packet response requires id=request or id=<1..65535>")
      }
      if has_invalid_options(words, ["id"]) {
        return Err("packet identifier option must be supported and unique")
      }
      let id = match parse_script_packet_id(id_text) {
        Ok(id) => id
        Err(error) => return Err(error)
      }
      if id is FromRequest &&
        !request_id_supported(kind, expected_packet, expected_qos) {
        return Err("id=request is not valid for this expected packet type")
      }
      match id {
        Fixed(value) if value < 1 || value > 65535 =>
          return Err("packet id must be between 1 and 65535")
        _ => ()
      }
      Ok(PacketIdResponse(kind, id))
    }
    "SUBACK" => {
      let id_text = match script_option(words, "id") {
        Some(value) => value
        None => return Err("SUBACK requires id=request or id=<1..65535>")
      }
      let id = match parse_script_packet_id(id_text) {
        Ok(id) => id
        Err(error) => return Err(error)
      }
      if id is FromRequest && expected_packet != "SUBSCRIBE" {
        return Err("SUBACK id=request requires expect SUBSCRIBE")
      }
      match id {
        Fixed(value) if value < 1 || value > 65535 =>
          return Err("packet id must be between 1 and 65535")
        _ => ()
      }
      let codes_text = match script_option(words, "codes") {
        Some(value) => value
        None => return Err("SUBACK requires codes=0,1,2,128")
      }
      if has_invalid_options(words, ["id", "codes"]) {
        return Err("SUBACK options must be supported and unique")
      }
      let codes : Array[Int32] = []
      for text in codes_text.split(",") {
        let code = @string.parse_int(text) catch {
          _ => return Err("SUBACK code must be 0, 1, 2, or 128")
        }
        if code != 0 && code != 1 && code != 2 && code != 128 {
          return Err("SUBACK code must be 0, 1, 2, or 128")
        }
        codes.push(code)
      }
      if codes.is_empty() {
        return Err("SUBACK requires at least one return code")
      }
      Ok(SubackResponse(id, codes))
    }
    _ => Err("unsupported response packet type `" + kind + "`")
  }
}

///|
fn parse_script_packet_id(text : String) -> Result[ScriptPacketId, String] {
  if text == "request" {
    Ok(FromRequest)
  } else {
    let value = @string.parse_int(text) catch {
      _ => return Err("packet id must be `request` or an integer")
    }
    Ok(Fixed(value))
  }
}

///|
fn parse_script_hex_bytes(text : String) -> Result[Bytes, String] {
  let bytes : Array[Byte] = []
  if text == "" {
    return Ok([])
  }
  for part in text.split(",") {
    let hex = part.trim()
    if hex.length() != 2 {
      return Err("bytes must use two hexadecimal digits")
    }
    let value = @string.parse_int(hex, base=16) catch {
      _ =>
        return Err("contains a non-hexadecimal byte `" + hex.to_owned() + "`")
    }
    if value < 0 || value > 255 {
      return Err("contains a byte outside 00..FF")
    }
    bytes.push(value.to_byte())
  }
  Ok([ for byte in bytes => byte ])
}

///|
fn request_id_supported(
  response : String,
  expected : String,
  expected_qos : Int32?,
) -> Bool {
  match response {
    "PUBACK" => expected == "PUBLISH" && expected_qos == Some(1)
    "PUBREC" => expected == "PUBLISH" && expected_qos == Some(2)
    "PUBREL" => expected == "PUBREC"
    "PUBCOMP" => expected == "PUBREL"
    "UNSUBACK" => expected == "UNSUBSCRIBE"
    _ => false
  }
}

///|
fn script_option(words : Array[String], name : String) -> String? {
  for word in words {
    match word.split_once("=") {
      Some((key, value)) if key == name => return Some(value.to_owned())
      _ => ()
    }
  }
  None
}

///|
fn has_invalid_options(words : Array[String], allowed : Array[String]) -> Bool {
  let seen : Array[String] = []
  let mut index = 2
  while index < words.length() {
    match words[index].split_once("=") {
      Some((key, _)) if !allowed.contains(key.to_owned()) => return true
      Some((key, _)) if seen.contains(key.to_owned()) => return true
      Some((key, _)) => seen.push(key.to_owned())
      None => return true
    }
    index += 1
  }
  false
}

///|
fn exchange_from_script(
  name : String,
  matches : (@codec.Packet) -> Bool,
  responses : Array[ScriptResponse],
) -> Exchange {
  Exchange::new(name, matches, packet => {
    let actions : Array[Action] = []
    for response in responses {
      actions.push(script_response_action(response, packet))
    }
    actions
  })
}

///|
fn script_response_action(
  response : ScriptResponse,
  packet : @codec.Packet,
) -> Action {
  match response {
    ConnackResponse(return_code, session_present) =>
      SendPacket(@codec.ConnackPacket({ session_present, return_code, }))
    PublishResponse(topic, qos, id_spec, payload, retain, dup) => {
      let message_id = match id_spec {
        None => None
        Some(Fixed(value)) => Some(value)
        Some(FromRequest) => None // PUBLISH directives require a fixed id.
      }
      SendPacket(
        @codec.PublishPacket({ topic, payload, qos, message_id, retain, dup, }),
      )
    }
    PacketIdResponse(kind, id_spec) => {
      let message_id = match id_spec {
        FromRequest =>
          match packet_message_id(packet) {
            Some(value) => value
            None => 0 // Request-ID directives are validated against `expect`.
          }
        Fixed(value) => value
      }
      let packet_id = @codec.PacketId::{ message_id, }
      let response = match kind {
        "PUBACK" => @codec.PubackPacket(packet_id)
        "PUBREC" => @codec.PubrecPacket(packet_id)
        "PUBREL" => @codec.PubrelPacket(packet_id)
        "PUBCOMP" => @codec.PubcompPacket(packet_id)
        "UNSUBACK" => @codec.UnsubackPacket({ message_id, })
        _ => @codec.PingrespPacket
      }
      SendPacket(response)
    }
    SubackResponse(id_spec, codes) => {
      let message_id = match id_spec {
        FromRequest =>
          match packet_message_id(packet) {
            Some(value) => value
            None => 0 // SUBACK request IDs are validated against SUBSCRIBE.
          }
        Fixed(value) => value
      }
      let return_codes : Array[@codec.SubackReturnCode] = []
      for code in codes {
        return_codes.push(
          match code {
            0 => @codec.SuccessQoS0
            1 => @codec.SuccessQoS1
            2 => @codec.SuccessQoS2
            128 => @codec.Failure
            _ => @codec.Failure
          },
        )
      }
      SendPacket(@codec.SubackPacket({ message_id, return_codes, }))
    }
    PingrespResponse => SendPacket(@codec.PingrespPacket)
    RawResponse(bytes) => SendRaw(bytes)
    DelayResponse(milliseconds) => Delay(milliseconds)
    CloseResponse => Close
  }
}

///|
fn packet_message_id(packet : @codec.Packet) -> Int32? {
  match packet {
    @codec.PublishPacket(message) => message.message_id
    @codec.PubackPacket(id) => Some(id.message_id)
    @codec.PubrecPacket(id) => Some(id.message_id)
    @codec.PubrelPacket(id) => Some(id.message_id)
    @codec.PubcompPacket(id) => Some(id.message_id)
    @codec.SubscribePacket(request) => Some(request.message_id)
    @codec.SubackPacket(response) => Some(response.message_id)
    @codec.UnsubscribePacket(request) => Some(request.message_id)
    @codec.UnsubackPacket(response) => Some(response.message_id)
    _ => None
  }
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
            Delay(milliseconds) => @async.sleep(milliseconds)
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
