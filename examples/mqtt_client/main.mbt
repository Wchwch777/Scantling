///|
async fn main {
  let client = @mqtt.Client::connect(
    "127.0.0.1",
    port=1883,
    client_id="scantling-demo",
  )
  client.subscribe(topic="demo/temperature", qos=@codec.QoS1)
  client.publish(topic="demo/temperature", payload=b"21.5")
  let message = client.receive()
  println("Received \{message.topic}: \{message.payload}")
  client.disconnect()
}
