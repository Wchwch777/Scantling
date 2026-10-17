///|
#cfg(target="native")
async fn broker_read_packet(tcp : @socket.Tcp) -> @codec.Packet {
  let first = tcp.read_exactly(1)
  let frame : Array[Byte] = [first[0]]
  let mut complete = false
  while !complete {
    let next = tcp.read_exactly(1)
    frame.push(next[0])
    complete = (next[0] & 0x80) == 0
    if frame.length() > 5 {
      fail("invalid packet length header")
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
#cfg(target="native")
async fn broker_write_packet(tcp : @socket.Tcp, packet : @codec.Packet) -> Unit {
  let encoded = @codec.encode_packet(packet).unwrap()
  let bytes : Bytes = [ for byte in encoded => byte ]
  tcp.write(bytes)
}

///|
#cfg(target="native")
async test "MQTT TCP client completes CONNECT, SUBSCRIBE, publish and QoS1 ACK" {
  @async.with_task_group <| root => {
    let server = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:0"))
    let address = server.addr
    root.spawn_bg(no_wait=true, () => {
      server.run_forever(max_connections=1) <| ((tcp, _) => {
        match broker_read_packet(tcp) {
          @codec.ConnectPacket(connect) =>
            assert_eq(connect.client_id, "scantling-test")
          _ => fail("expected CONNECT")
        }
        broker_write_packet(
          tcp,
          @codec.ConnackPacket({
            session_present: false,
            return_code: @codec.ConnectionAccepted,
          }),
        )
        let message_id = match broker_read_packet(tcp) {
          @codec.SubscribePacket(subscribe) => {
            assert_eq(subscribe.topics[0].topic, "demo/temperature")
            subscribe.message_id
          }
          _ => fail("expected SUBSCRIBE")
        }
        broker_write_packet(
          tcp,
          @codec.SubackPacket({
            message_id,
            return_codes: [@codec.SuccessQoS1],
          }),
        )
        broker_write_packet(
          tcp,
          @codec.PublishPacket({
            topic: "demo/temperature",
            payload: b"21.5",
            qos: @codec.QoS1,
            message_id: Some(77),
            retain: false,
            dup: false,
          }),
        )
        match broker_read_packet(tcp) {
          @codec.PubackPacket(packet_id) => assert_eq(packet_id.message_id, 77)
          _ => fail("expected PUBACK")
        }
        let qos1_id = match broker_read_packet(tcp) {
          @codec.PublishPacket(message) => {
            assert_eq(message.topic, "demo/temperature")
            assert_eq(message.payload, b"23.0")
            assert_eq(message.qos, @codec.QoS1)
            message.message_id.unwrap()
          }
          _ => fail("expected QoS 1 PUBLISH")
        }
        broker_write_packet(tcp, @codec.PubackPacket({ message_id: qos1_id, }))
        match broker_read_packet(tcp) {
          @codec.PublishPacket(message) => {
            assert_eq(message.topic, "demo/temperature")
            assert_eq(message.payload, b"22.0")
            assert_eq(message.qos, @codec.QoS0)
          }
          _ => fail("expected QoS 0 PUBLISH")
        }
        let unsubscribe_id = match broker_read_packet(tcp) {
          @codec.UnsubscribePacket(request) => {
            assert_eq(request.topics, ["demo/temperature"])
            request.message_id
          }
          _ => fail("expected UNSUBSCRIBE")
        }
        broker_write_packet(
          tcp,
          @codec.UnsubackPacket({ message_id: unsubscribe_id, }),
        )
        match broker_read_packet(tcp) {
          @codec.PingreqPacket =>
            broker_write_packet(tcp, @codec.PingrespPacket)
          _ => fail("expected PINGREQ")
        }
        match broker_read_packet(tcp) {
          @codec.DisconnectPacket => ()
          _ => fail("expected DISCONNECT")
        }
      })
    })
    @async.sleep(100)
    let client = @client.Client::connect(
      "127.0.0.1",
      port=address.port(),
      client_id="scantling-test",
    )
    client.subscribe(topic="demo/temperature", qos=@codec.QoS1)
    let received = client.receive()
    assert_eq(received.topic, "demo/temperature")
    assert_eq(received.payload, b"21.5")
    assert_eq(received.qos, @codec.QoS1)
    client.publish_qos1(topic="demo/temperature", payload=b"23.0")
    client.publish(topic="demo/temperature", payload=b"22.0")
    client.unsubscribe(topic="demo/temperature")
    client.ping()
    client.disconnect()
    server.close()
  }
}

///|
#cfg(target="native")
async test "MQTT client interoperates with an independent Mosquitto broker" {
  match @env.get_env_var("SCANTLING_MOSQUITTO_HOST") {
    None => ()
    Some(host) => {
      let topic = "scantling/interop/roundtrip"
      let subscriber = @client.Client::connect(
        host,
        port=1883,
        client_id="scantling-mosquitto-subscriber",
      )
      subscriber.subscribe(topic~, qos=@codec.QoS1)
      let publisher = @client.Client::connect(
        host,
        port=1883,
        client_id="scantling-mosquitto-publisher",
      )
      publisher.publish_qos1(topic~, payload=b"mosquitto-roundtrip")
      let message = subscriber.receive()
      assert_eq(message.topic, topic)
      assert_eq(message.payload, b"mosquitto-roundtrip")
      assert_eq(message.qos, @codec.QoS1)
      publisher.ping()
      subscriber.unsubscribe(topic~)
      publisher.disconnect()
      subscriber.disconnect()
    }
  }
}
