///|
async fn main {
  let broker = "127.0.0.1"
  let subscriber = @mqtt.Client::connect(
    broker,
    port=1883,
    client_id="scantling-example-subscriber",
    keep_alive=4,
  )
  let publisher = @mqtt.Client::connect(
    broker,
    port=1883,
    client_id="scantling-example-publisher",
    keep_alive=30,
  )

  let telemetry_topic = "demo/sensor/temperature"
  let command_topic = "demo/device/device-7/cmd"
  let event_topic = "demo/service/orders/created"

  subscriber.subscribe(topic=telemetry_topic, qos=@codec.QoS1)
  subscriber.subscribe(topic=command_topic, qos=@codec.QoS1)
  subscriber.subscribe(topic=event_topic, qos=@codec.QoS1)

  publisher.publish_qos1(topic=telemetry_topic, payload=b"21.5")
  let telemetry = subscriber.receive()
  println("telemetry \{telemetry.topic}: \{telemetry.payload}")

  publisher.publish_qos1(topic=command_topic, payload=b"SET_TEMP=22.0")
  let command = subscriber.receive()
  println("command \{command.topic}: \{command.payload}")

  // Leave the subscriber idle for longer than its Keep Alive interval while
  // the independent publisher waits, then deliver an event over the same
  // subscription. The subscriber sends PINGREQ while receive is waiting.
  @async.with_task_group <| root => {
    root.spawn_bg(no_wait=false, () => {
      @async.sleep(5000)
      publisher.publish_qos1(topic=event_topic, payload=b"order_id=demo-1")
    })
    let event = subscriber.receive_with_keep_alive()
    println("event \{event.topic}: \{event.payload}")
  }

  publisher.ping()
  subscriber.unsubscribe(topic=telemetry_topic)
  subscriber.unsubscribe(topic=command_topic)
  subscriber.unsubscribe(topic=event_topic)
  publisher.disconnect()
  subscriber.disconnect()
}
