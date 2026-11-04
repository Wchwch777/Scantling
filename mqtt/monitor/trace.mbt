/// Feed exactly one complete MQTT wire frame; reject trailing bytes rather
/// than silently accepting a valid prefix. Decoding remains the upstream codec's
/// job; this adapter additionally checks canonical lengths and fixed flags.

///|
pub fn Monitor::observe_frame(
  self : Monitor,
  sender : Side,
  frame : Array[Byte],
  at_ms : Int64,
) -> Bool {
  if !self.diagnostics.is_empty() {
    return false
  }
  let error = validate_frame(frame)
  if error is Some(detail) {
    if !self.begin(at_ms) {
      return false
    }
    return self.reject("TRACE-FRAME", detail)
  }
  match @codec.decode_packet(frame) {
    Ok(packet) => self.observe(sender, packet, at_ms)
    Err(detail) => {
      if !self.begin(at_ms) {
        return false
      }
      self.reject("TRACE-CODEC", detail)
    }
  }
}

///|
fn validate_frame(frame : Array[Byte]) -> String? {
  if frame.length() < 2 {
    return Some("truncated fixed header")
  }
  let kind = frame[0].to_int() >> 4
  let flags = frame[0].to_int() & 15
  if kind < 1 || kind > 14 {
    return Some("reserved packet type")
  }
  if kind != 3 &&
    flags != (if kind == 6 || kind == 8 || kind == 10 { 2 } else { 0 }) {
    return Some("invalid fixed header flags")
  }
  if kind == 3 && ((flags >> 1) & 3) == 3 {
    return Some("reserved PUBLISH QoS")
  }
  let mut length = 0
  let mut multiplier = 1
  for i in 1..<5 {
    if i >= frame.length() {
      return Some("truncated remaining length")
    }
    let byte = frame[i].to_int()
    length += (byte & 127) * multiplier
    if byte < 128 {
      if i > 1 && byte == 0 {
        return Some("noncanonical remaining length")
      }
      if length > 1048576 {
        return Some("frame body exceeds observation limit of 1 MiB")
      }
      if frame.length() != length + i + 1 {
        return Some("frame length mismatch or trailing bytes")
      }
      return None
    }
    multiplier *= 128
  }
  Some("remaining length exceeds four bytes")
}

/// Replay a deterministic packet trace. Each noncomment line is one event:
/// `MILLISECONDS C|S HEX` (one frame), `MILLISECONDS CLOSE`, or
/// `MILLISECONDS TICK`. Hex is contiguous, whitespace separates columns.
/// Syntax errors return Err with a line number; semantic errors return a report.
/// The trace must start at CONNECT; packet capture/reassembly is not implemented.

///|
pub fn check_trace(source : String) -> Result[Report, String] {
  let monitor = Monitor::new()
  let mut line_number = 0
  for raw in source.split("\n") {
    line_number += 1
    let line = raw.trim(chars="\r\t ")
    if line == "" || line.has_prefix("#") {
      continue
    }
    let words : Array[String] = []
    for word in line.to_owned().replace_all(old="\t", new=" ").split(" ") {
      if word != "" {
        words.push(word.to_owned())
      }
    }
    if words.length() < 2 {
      return Err("line \{line_number}: expected timestamp and event")
    }
    let at_ms = @string.parse_int64(words[0]) catch {
      _ => return Err("line \{line_number}: invalid millisecond timestamp")
    }
    let _ = match words[1] {
      "CLOSE" | "TICK" => {
        if words.length() != 2 {
          return Err("line \{line_number}: event takes no frame")
        }
        if words[1] == "CLOSE" {
          monitor.close(at_ms)
        } else {
          monitor.advance(at_ms)
        }
      }
      "C" | "S" => {
        if words.length() != 3 {
          return Err("line \{line_number}: expected one contiguous hex frame")
        }
        let hex = words[2]
        if hex.length() == 0 || hex.length() % 2 != 0 || hex.length() > 2097162 {
          return Err("line \{line_number}: invalid hex frame length")
        }
        let bytes : Array[Byte] = []
        for index = 0; index < hex.length(); index = index + 2 {
          let mut value = 0
          for offset in 0..<2 {
            let digit = match hex[index + offset] {
              '0'..<='9' as digit => digit.to_int() - 48
              'a'..<='f' as digit => digit.to_int() - 87
              'A'..<='F' as digit => digit.to_int() - 55
              _ =>
                return Err(
                  "line \{line_number}: frame contains a non-hex digit",
                )
            }
            value = value * 16 + digit
          }
          bytes.push(value.to_byte())
        }
        monitor.observe_frame(
          if words[1] == "C" {
            Client
          } else {
            Server
          },
          bytes,
          at_ms,
        )
      }
      _ => return Err("line \{line_number}: event must be C, S, CLOSE, or TICK")
    }
    if !monitor.report().valid_prefix {
      return Ok(monitor.report())
    }
  }
  if monitor.events == 0 {
    return Err("trace must contain at least one event")
  }
  Ok(monitor.report())
}
