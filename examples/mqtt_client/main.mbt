///|
async fn main {
  let broker = "127.0.0.1"
  let application = @mqtt.Client::connect(
    broker,
    port=1883,
    client_id="scantling-example-application",
    keep_alive=4,
  )
  let device = @mqtt.Client::connect(
    broker,
    port=1883,
    client_id="scantling-example-device",
    keep_alive=30,
  )

  let telemetry_topic = "demo/sensor/temperature"
  let command_topic = "demo/device/device-7/cmd"
  let report_topic = "demo/device/device-7/reported"
  let event_topic = "demo/service/orders/created"

  application.subscribe(topic=telemetry_topic, qos=@codec.QoS1)
  application.subscribe(topic=report_topic, qos=@codec.QoS1)
  application.subscribe(topic=event_topic, qos=@codec.QoS1)
  device.subscribe(topic=command_topic, qos=@codec.QoS1)

  device.publish_qos1(topic=telemetry_topic, payload=b"21.5")
  let telemetry = application.receive()
  println("telemetry \{telemetry.topic}: \{telemetry.payload}")

  application.publish_qos1(topic=command_topic, payload=b"SET_TEMP=22.0")
  let command = device.receive()
  println("device applied command: \{command.payload}")
  device.publish_qos1(topic=report_topic, payload=b"temperature=22.0")
  let report = application.receive()
  println("reported state \{report.topic}: \{report.payload}")

  // Leave the application idle beyond the Broker's 1.5x Keep Alive timeout
  // while the independent device waits, then deliver an event on the same
  // subscription. The application must send PINGREQ while receive is waiting.
  @async.with_task_group <| root => {
    root.spawn_bg(no_wait=false, () => {
      @async.sleep(10000)
      device.publish_qos1(topic=event_topic, payload=b"order_id=demo-1")
    })
    let event = application.receive_with_keep_alive()
    println("event \{event.topic}: \{event.payload}")
  }

  application.unsubscribe(topic=telemetry_topic)
  application.unsubscribe(topic=report_topic)
  application.unsubscribe(topic=event_topic)
  device.unsubscribe(topic=command_topic)
  device.disconnect()
  application.disconnect()
}
