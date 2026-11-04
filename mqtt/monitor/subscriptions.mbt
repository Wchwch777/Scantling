///|
fn valid_filter(filter : String) -> Bool {
  if filter == "" || filter.contains("\u{0}") {
    return false
  }
  let levels = filter.split("/").collect()
  for index, level in levels {
    if level.contains("#") && (level != "#" || index != levels.length() - 1) {
      return false
    }
    if level.contains("+") && level != "+" {
      return false
    }
  }
  true
}

///|
fn Monitor::subscribe(
  self : Monitor,
  sender : Side,
  request : @codec.Subscribe,
) -> Bool {
  if sender != Client || request.topics.is_empty() {
    return self.reject(
      "MQTT-3.8", "SUBSCRIBE must be client-originated with at least one filter",
    )
  }
  for topic in request.topics {
    if !valid_filter(topic.topic) {
      return self.reject("MQTT-4.7.1", "invalid SUBSCRIBE topic filter")
    }
  }
  self.reserve(Client, request.message_id, {
    stage: AwaitSuback([ for topic in request.topics => topic.qos ]),
    publication: None,
  })
}

///|
fn Monitor::suback(
  self : Monitor,
  sender : Side,
  response : @codec.Suback,
) -> Bool {
  if sender != Server {
    return self.reject("MQTT-3.9", "SUBACK must be server-originated")
  }
  match self.client_flights.get(response.message_id) {
    Some({ stage: AwaitSuback(requested), .. }) => {
      if requested.length() != response.return_codes.length() {
        return self.reject(
          "MQTT-3.9.3-1", "SUBACK count must equal the number of requested filters",
        )
      }
      for index, code in response.return_codes {
        let granted = match code {
          @codec.SuccessQoS0 => 0
          @codec.SuccessQoS1 => 1
          @codec.SuccessQoS2 => 2
          @codec.Failure => -1
        }
        if granted > qos_number(requested[index]) {
          return self.reject(
            "MQTT-3.8.4-6", "SUBACK grant exceeds the corresponding requested QoS",
          )
        }
      }
      self.client_flights.remove(response.message_id)
      true
    }
    _ => self.reject("TRACE-ACK-ORPHAN", "SUBACK has no matching SUBSCRIBE")
  }
}
