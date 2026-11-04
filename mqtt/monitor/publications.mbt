///|
fn Monitor::reserve(
  self : Monitor,
  sender : Side,
  id : Int32,
  flight : Flight,
) -> Bool {
  if id < 1 || id > 65535 {
    return self.reject("MQTT-2.3.1", "packet identifier must be in 1..65535")
  }
  let flights = self.flights(sender)
  if flights.contains(id) {
    return self.reject(
      "MQTT-2.3.1-2", "packet identifier is still owned by an unfinished exchange",
    )
  }
  if flights.length() >= self.max_inflight {
    return self.reject(
      "TRACE-LIMIT", "configured in-flight observation limit reached",
    )
  }
  flights[id] = flight
  true
}

///|
fn same_publication(a : @codec.Publish, b : @codec.Publish) -> Bool {
  a.topic == b.topic &&
  a.payload == b.payload &&
  a.qos == b.qos &&
  a.retain == b.retain
}

///|
fn Monitor::publish(
  self : Monitor,
  sender : Side,
  message : @codec.Publish,
) -> Bool {
  if message.topic == "" ||
    message.topic.contains("+") ||
    message.topic.contains("#") ||
    message.topic.contains("\u{0}") {
    return self.reject(
      "MQTT-3.3.2-2", "PUBLISH requires a nonempty topic name without wildcards or NUL",
    )
  }
  if message.qos == @codec.QoS0 {
    if message.message_id is Some(_) || message.dup {
      return self.reject(
        "MQTT-3.3.1-2", "QoS 0 must have DUP=0 and no packet identifier",
      )
    }
    self.completed += 1
    return true
  }
  let id = match message.message_id {
    Some(id) => id
    None =>
      return self.reject(
        "MQTT-2.3.1-1", "QoS 1/2 PUBLISH requires a packet identifier",
      )
  }
  let flights = self.flights(sender)
  match flights.get(id) {
    Some(flight) =>
      match (flight.stage, flight.publication) {
        (AwaitPuback | AwaitPubrec | AwaitPubrel, Some(original)) => {
          if !message.dup || !same_publication(original, message) {
            return self.reject(
              "TRACE-RETRANSMIT", "occupied identifier requires DUP=1 and identical publication content",
            )
          }
          self.retransmissions += 1
          true
        }
        _ =>
          self.reject(
            "MQTT-4.3.3", "PUBLISH cannot restart an exchange after PUBREL or overwrite another request",
          )
      }
    None =>
      self.reserve(sender, id, {
        stage: if message.qos == @codec.QoS1 {
          AwaitPuback
        } else {
          AwaitPubrec
        },
        publication: Some(message),
      })
  }
}

///|
fn Monitor::ack(
  self : Monitor,
  sender : Side,
  kind : String,
  id : Int32,
) -> Bool {
  if id < 1 || id > 65535 {
    return self.reject(
      "MQTT-2.3.1", "acknowledgement identifier must be in 1..65535",
    )
  }
  // PUBREL is sent by the original publisher; the other acks by its receiver.
  let owner = if kind == "PUBREL" { sender } else { other(sender) }
  let flights = self.flights(owner)
  match flights.get(id) {
    None => {
      // MQTT requires PUBCOMP in response to an unknown/repeated PUBREL.
      // Represent the obligation without pretending a second delivery occurred.
      if kind == "PUBREL" {
        return self.reserve(owner, id, {
          stage: AwaitPubcomp,
          publication: None,
        })
      }
      self.reject(
        "TRACE-ACK-ORPHAN", "acknowledgement has no matching observed exchange",
      )
    }
    Some(flight) =>
      match (kind, flight.stage) {
        ("PUBACK", AwaitPuback) => {
          flights.remove(id)
          self.completed += 1
          true
        }
        ("PUBREC", AwaitPubrec) => {
          flights[id] = { stage: AwaitPubrel, publication: flight.publication, }
          true
        }
        ("PUBREC", AwaitPubrel | AwaitPubcomp) => {
          self.retransmissions += 1
          true
        }
        ("PUBREL", AwaitPubrel) => {
          flights[id] = {
            stage: AwaitPubcomp,
            publication: flight.publication,
          }
          true
        }
        ("PUBREL", AwaitPubcomp) => {
          self.retransmissions += 1
          true
        }
        ("PUBCOMP", AwaitPubcomp) => {
          flights.remove(id)
          if flight.publication is Some(_) {
            self.completed += 1
          }
          true
        }
        ("UNSUBACK", AwaitUnsuback) if sender == Server => {
          flights.remove(id)
          true
        }
        _ =>
          self.reject(
            "TRACE-ACK-STAGE", "acknowledgement type or direction conflicts with the in-flight stage",
          )
      }
  }
}
