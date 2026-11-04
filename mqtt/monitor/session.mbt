/// Advance logical capture time without sleeping. The 1.5x Keep Alive check
/// diagnoses an overdue open connection; it is not an invented PINGRESP timeout.
/// A close event can arrive after the deadline, since it may be the server's
/// required timeout closure. Negative or decreasing time is always rejected.

///|
fn Monitor::begin(
  self : Monitor,
  at_ms : Int64,
  closing~ : Bool = false,
) -> Bool {
  if !self.diagnostics.is_empty() {
    return false
  }
  self.events += 1
  if at_ms < self.now_ms {
    return self.reject(
      "TRACE-TIME", "timestamps must be nonnegative and monotonic",
    )
  }
  self.now_ms = at_ms
  if !closing &&
    self.phase == Active &&
    self.keep_alive_ms > 0L &&
    at_ms - self.last_client_ms > self.keep_alive_ms * 3L / 2L {
    return self.reject(
      "MQTT-3.1.2-24", "open connection exceeded 1.5 times Keep Alive without a client control packet",
    )
  }
  true
}

///|
pub fn Monitor::advance(self : Monitor, at_ms : Int64) -> Bool {
  self.begin(at_ms)
}

/// Observe transport closure. Persistent in-flight state survives; a clean
/// session is discarded. No application-delivery claim follows from closure.

///|
pub fn Monitor::close(self : Monitor, at_ms : Int64) -> Bool {
  if !self.begin(at_ms, closing=true) {
    return false
  }
  if self.phase == Offline {
    return self.reject("TRACE-CLOSE", "transport is already closed")
  }
  self.phase = Offline
  self.ping = false
  if self.clean {
    self.session_known = false
    self.abandoned += self.client_flights.length() +
      self.server_flights.length()
    self.client_flights.clear()
    self.server_flights.clear()
  }
  true
}

/// Observe a decoded MQTT packet. Prefer observe_frame for captured wire data:
/// decoded packets cannot preserve invalid fixed headers or framing errors.

///|
pub fn Monitor::observe(
  self : Monitor,
  sender : Side,
  packet : @codec.Packet,
  at_ms : Int64,
) -> Bool {
  if !self.begin(at_ms) {
    return false
  }
  match packet {
    @codec.ConnectPacket(connect) => {
      if sender != Client || self.phase != Offline {
        return self.reject(
          "MQTT-3.1.0-2", "CONNECT must be the client's first packet on a new connection",
        )
      }
      if connect.keep_alive < 0 || connect.keep_alive > 65535 {
        return self.reject(
          "MQTT-3.1.2", "Keep Alive must fit an unsigned 16-bit value",
        )
      }
      if connect.client_id == "" && !connect.flags.clean_session {
        return self.reject(
          "MQTT-3.1.3-7", "an empty client ID requires Clean Session",
        )
      }
      if connect.flags.clean_session ||
        self.client_id != Some(connect.client_id) {
        self.session_known = false
        self.abandoned += self.client_flights.length() +
          self.server_flights.length()
        self.client_flights.clear()
        self.server_flights.clear()
      }
      self.resuming = !self.client_flights.is_empty() ||
        !self.server_flights.is_empty()
      self.client_id = Some(connect.client_id)
      self.clean = connect.flags.clean_session
      self.keep_alive_ms = connect.keep_alive.to_int64() * 1000L
      self.last_client_ms = at_ms
      self.phase = AwaitConnack
      self.connections += 1
      return true
    }
    @codec.ConnackPacket(connack) => {
      if sender != Server || self.phase != AwaitConnack {
        return self.reject(
          "MQTT-3.2.0-1", "CONNACK must acknowledge a pending CONNECT",
        )
      }
      if connack.session_present &&
        (self.clean || connack.return_code != @codec.ConnectionAccepted) {
        return self.reject(
          "MQTT-3.2.2", "Session Present conflicts with Clean Session or rejection",
        )
      }
      if connack.return_code != @codec.ConnectionAccepted {
        // Still awaiting transport closure; no application traffic is allowed.
        self.phase = Closing
        return true
      }
      if !connack.session_present && !self.clean && self.resuming {
        return self.reject(
          "TRACE-SESSION-LOST", "broker lost persistent state; reconciliation is outside this monitor's supported resumption scope",
        )
      }
      if connack.session_present && !self.session_known {
        return self.reject(
          "TRACE-SESSION-UNKNOWN", "capture starts after an unknown persistent session; its state cannot be inferred",
        )
      }
      self.phase = Active
      self.session_known = !self.clean
      return true
    }
    _ => ()
  }
  // MQTT 3.1.4 permits clients to pipeline control packets before CONNACK.
  // The server's first packet must still be CONNACK.
  if self.phase != Active && !(self.phase == AwaitConnack && sender == Client) {
    return self.reject(
      "MQTT-3.1.0-1", "application packet outside an accepted connection",
    )
  }
  if sender == Client {
    self.last_client_ms = at_ms
  }
  match packet {
    @codec.PublishPacket(publication) => self.publish(sender, publication)
    @codec.PubackPacket(id) => self.ack(sender, "PUBACK", id.message_id)
    @codec.PubrecPacket(id) => self.ack(sender, "PUBREC", id.message_id)
    @codec.PubrelPacket(id) => self.ack(sender, "PUBREL", id.message_id)
    @codec.PubcompPacket(id) => self.ack(sender, "PUBCOMP", id.message_id)
    @codec.SubscribePacket(request) => self.subscribe(sender, request)
    @codec.SubackPacket(response) => self.suback(sender, response)
    @codec.UnsubscribePacket(request) => {
      if sender != Client || request.topics.is_empty() {
        return self.reject(
          "MQTT-3.10", "UNSUBSCRIBE must be client-originated with at least one filter",
        )
      }
      for filter in request.topics {
        if !valid_filter(filter) {
          return self.reject("MQTT-4.7.1", "invalid UNSUBSCRIBE topic filter")
        }
      }
      self.reserve(Client, request.message_id, {
        stage: AwaitUnsuback,
        publication: None,
      })
    }
    @codec.UnsubackPacket(response) =>
      self.ack(sender, "UNSUBACK", response.message_id)
    @codec.PingreqPacket => {
      if sender != Client || self.ping {
        return self.reject(
          "TRACE-PING", "expected one client PINGREQ followed by its server PINGRESP",
        )
      }
      self.ping = true
      true
    }
    @codec.PingrespPacket => {
      if sender != Server || !self.ping {
        return self.reject(
          "MQTT-3.12.4", "PINGRESP without a pending client PINGREQ",
        )
      }
      self.ping = false
      true
    }
    @codec.DisconnectPacket => {
      if sender != Client {
        return self.reject(
          "MQTT-3.14", "MQTT 3.1.1 DISCONNECT is client-originated",
        )
      }
      // DISCONNECT ends MQTT traffic but leaves the explicit TCP close observable.
      self.phase = Closing
      true
    }
    _ => false
  }
}
