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
    // TcpServer binds and listens in its constructor. Connections can queue
    // while the background accept loop is scheduled, so a timed sleep is not
    // needed before the client connects.
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
async test "MQTT client subscribes and unsubscribes multiple filters per request" {
  @async.with_task_group <| root => {
    let server = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:0"))
    let address = server.addr
    root.spawn_bg(no_wait=true, () => {
      server.run_forever(max_connections=1) <| ((tcp, _) => {
        match broker_read_packet(tcp) {
          @codec.ConnectPacket(_) => ()
          _ => fail("expected CONNECT")
        }
        broker_write_packet(
          tcp,
          @codec.ConnackPacket({
            session_present: false,
            return_code: @codec.ConnectionAccepted,
          }),
        )
        let subscribe_id = match broker_read_packet(tcp) {
          @codec.SubscribePacket(request) => {
            assert_eq(request.topics.length(), 2)
            assert_eq(request.topics[0].topic, "sensors/+")
            assert_eq(request.topics[0].qos, @codec.QoS0)
            assert_eq(request.topics[1].topic, "devices/#")
            assert_eq(request.topics[1].qos, @codec.QoS1)
            request.message_id
          }
          _ => fail("expected one SUBSCRIBE with both filters")
        }
        broker_write_packet(
          tcp,
          @codec.SubackPacket({
            message_id: subscribe_id,
            return_codes: [@codec.SuccessQoS0, @codec.SuccessQoS1],
          }),
        )
        let unsubscribe_id = match broker_read_packet(tcp) {
          @codec.UnsubscribePacket(request) => {
            assert_eq(request.topics, ["sensors/+", "devices/#"])
            request.message_id
          }
          _ => fail("expected one UNSUBSCRIBE with both filters")
        }
        broker_write_packet(
          tcp,
          @codec.UnsubackPacket({ message_id: unsubscribe_id, }),
        )
        match broker_read_packet(tcp) {
          @codec.DisconnectPacket => ()
          _ => fail("expected DISCONNECT")
        }
      })
    })
    let client = @client.Client::connect(
      "127.0.0.1",
      port=address.port(),
      client_id="scantling-batch-subscriptions",
    )
    client.subscribe_many(topics=[
      @client.Subscription::{ topic: "sensors/+", qos: @codec.QoS0, },
      @client.Subscription::{ topic: "devices/#", qos: @codec.QoS1, },
    ])
    client.unsubscribe_many(topics=["sensors/+", "devices/#"])
    client.disconnect()
    server.close()
  }
}

///|
#cfg(target="native")
async test "MQTT client buffers an inbound PUBLISH while awaiting PUBACK" {
  @async.with_task_group <| root => {
    let server = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:0"))
    let address = server.addr
    root.spawn_bg(no_wait=true, () => {
      server.run_forever(max_connections=1) <| ((tcp, _) => {
        match broker_read_packet(tcp) {
          @codec.ConnectPacket(_) => ()
          _ => fail("expected CONNECT")
        }
        broker_write_packet(
          tcp,
          @codec.ConnackPacket({
            session_present: false,
            return_code: @codec.ConnectionAccepted,
          }),
        )
        let request_id = match broker_read_packet(tcp) {
          @codec.PublishPacket(message) => message.message_id.unwrap()
          _ => fail("expected QoS 1 PUBLISH")
        }
        broker_write_packet(
          tcp,
          @codec.PublishPacket({
            topic: "demo/async",
            payload: b"broker-message",
            qos: @codec.QoS1,
            message_id: Some(91),
            retain: false,
            dup: false,
          }),
        )
        match broker_read_packet(tcp) {
          @codec.PubackPacket(message) => assert_eq(message.message_id, 91)
          _ => fail("expected PUBACK for the inbound message")
        }
        broker_write_packet(
          tcp,
          @codec.PubackPacket({ message_id: request_id, }),
        )
        match broker_read_packet(tcp) {
          @codec.DisconnectPacket => ()
          _ => fail("expected DISCONNECT")
        }
      })
    })
    let client = @client.Client::connect(
      "127.0.0.1",
      port=address.port(),
      client_id="scantling-buffer-inbound",
    )
    client.publish_qos1(topic="demo/outbound", payload=b"client-message")
    let received = client.receive()
    assert_eq(received.topic, "demo/async")
    assert_eq(received.payload, b"broker-message")
    assert_eq(received.qos, @codec.QoS1)
    client.disconnect()
    server.close()
  }
}

///|
#cfg(target="native")
async test "MQTT client rejects CONNACK session state for Clean Session" {
  @async.with_task_group <| root => {
    let server = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:0"))
    let address = server.addr
    root.spawn_bg(no_wait=true, () => {
      server.run_forever(max_connections=1) <| ((tcp, _) => {
        match broker_read_packet(tcp) {
          @codec.ConnectPacket(_) => ()
          _ => fail("expected CONNECT")
        }
        broker_write_packet(
          tcp,
          @codec.ConnackPacket({
            session_present: true,
            return_code: @codec.ConnectionAccepted,
          }),
        )
      })
    })
    let result : Result[@client.Client, @client.ClientError] = Ok(
      @client.Client::connect(
        "127.0.0.1",
        port=address.port(),
        client_id="scantling-invalid-session",
      ),
    ) catch {
      error => Err(error)
    }
    match result {
      Err(
        @client.ClientError::UnexpectedPacket(
          "CONNACK session_present must be false for a clean session"
        )
      ) => ()
      _ => fail("expected invalid Clean Session CONNACK to be rejected")
    }
    server.close()
  }
}

///|
#cfg(target="native")
async test "MQTT client reports broker rejection from CONNACK" {
  @async.with_task_group <| root => {
    let server = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:0"))
    let address = server.addr
    root.spawn_bg(no_wait=true, () => {
      server.run_forever(max_connections=1) <| ((tcp, _) => {
        match broker_read_packet(tcp) {
          @codec.ConnectPacket(_) => ()
          _ => fail("expected CONNECT")
        }
        broker_write_packet(
          tcp,
          @codec.ConnackPacket({
            session_present: false,
            return_code: @codec.NotAuthorized,
          }),
        )
      })
    })
    let result : Result[@client.Client, @client.ClientError] = Ok(
      @client.Client::connect(
        "127.0.0.1",
        port=address.port(),
        client_id="scantling-rejected-client",
      ),
    ) catch {
      error => Err(error)
    }
    match result {
      Err(@client.ClientError::Rejected(5)) => ()
      _ => fail("expected broker rejection code 5")
    }
    server.close()
  }
}

///|
#cfg(target="native")
async test "MQTT client rejects a PUBACK with a different packet identifier" {
  @async.with_task_group <| root => {
    let server = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:0"))
    let address = server.addr
    root.spawn_bg(no_wait=true, () => {
      server.run_forever(max_connections=1) <| ((tcp, _) => {
        match broker_read_packet(tcp) {
          @codec.ConnectPacket(_) => ()
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
          @codec.PublishPacket(message) => message.message_id.unwrap()
          _ => fail("expected QoS 1 PUBLISH")
        }
        broker_write_packet(
          tcp,
          @codec.PubackPacket({ message_id: message_id + 1, }),
        )
      })
    })
    let client = @client.Client::connect(
      "127.0.0.1",
      port=address.port(),
      client_id="scantling-mismatched-ack",
    )
    let result : Result[Unit, @client.ClientError] = try {
      client.publish_qos1(topic="demo/ack", payload=b"test")
      Ok(())
    } catch {
      error => Err(error)
    }
    match result {
      Err(
        @client.ClientError::UnexpectedPacket(
          "PUBACK packet identifier did not match"
        )
      ) => ()
      _ => fail("expected mismatched PUBACK to be rejected")
    }
    client.disconnect()
    server.close()
  }
}

///|
#cfg(target="native")
async test "MQTT client maps a truncated CONNACK frame to transport failure" {
  @async.with_task_group <| root => {
    let server = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:0"))
    let address = server.addr
    root.spawn_bg(no_wait=true, () => {
      server.run_forever(max_connections=1) <| ((tcp, _) => {
        match broker_read_packet(tcp) {
          @codec.ConnectPacket(_) => ()
          _ => fail("expected CONNECT")
        }
        let truncated_header : Bytes = [0x20]
        tcp.write(truncated_header)
        tcp.close()
      })
    })
    let result : Result[@client.Client, @client.ClientError] = Ok(
      @client.Client::connect(
        "127.0.0.1",
        port=address.port(),
        client_id="scantling-truncated-connack",
      ),
    ) catch {
      error => Err(error)
    }
    match result {
      Err(@client.ClientError::TransportFailure) => ()
      _ => fail("expected a transport failure for truncated CONNACK")
    }
    server.close()
  }
}

///|
#cfg(target="native")
async test "MQTT client reports EOF when a CONNACK body is truncated" {
  @async.with_task_group <| root => {
    let server = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:0"))
    let address = server.addr
    root.spawn_bg(no_wait=true, () => {
      server.run_forever(max_connections=1) <| ((tcp, _) => {
        match broker_read_packet(tcp) {
          @codec.ConnectPacket(_) => ()
          _ => fail("expected CONNECT")
        }
        let truncated_body : Bytes = [0x20, 0x02, 0x00]
        tcp.write(truncated_body)
      })
    })
    let result : Result[@client.Client, @client.ClientError] = Ok(
      @client.Client::connect(
        "127.0.0.1",
        port=address.port(),
        client_id="scantling-truncated-connack-body",
      ),
    ) catch {
      error => Err(error)
    }
    match result {
      Err(@client.ClientError::TransportFailure) => ()
      _ => fail("expected a transport failure for truncated CONNACK body")
    }
    server.close()
  }
}

///|
#cfg(target="native")
async test "MQTT client rejects an unexpected packet while awaiting SUBACK" {
  @async.with_task_group <| root => {
    let server = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:0"))
    let address = server.addr
    root.spawn_bg(no_wait=true, () => {
      server.run_forever(max_connections=1) <| ((tcp, _) => {
        match broker_read_packet(tcp) {
          @codec.ConnectPacket(_) => ()
          _ => fail("expected CONNECT")
        }
        broker_write_packet(
          tcp,
          @codec.ConnackPacket({
            session_present: false,
            return_code: @codec.ConnectionAccepted,
          }),
        )
        match broker_read_packet(tcp) {
          @codec.SubscribePacket(_) => ()
          _ => fail("expected SUBSCRIBE")
        }
        broker_write_packet(tcp, @codec.PingrespPacket)
        match broker_read_packet(tcp) {
          @codec.DisconnectPacket => ()
          _ => fail("expected DISCONNECT")
        }
      })
    })
    let client = @client.Client::connect(
      "127.0.0.1",
      port=address.port(),
      client_id="scantling-unexpected-suback-response",
    )
    let result : Result[Unit, @client.ClientError] = try {
      client.subscribe(topic="demo/unexpected", qos=@codec.QoS0)
      Ok(())
    } catch {
      error => Err(error)
    }
    match result {
      Err(@client.ClientError::UnexpectedPacket("expected matching SUBACK")) =>
        ()
      _ => fail("expected an unexpected-packet error for SUBACK")
    }
    client.disconnect()
    server.close()
  }
}

///|
#cfg(target="native")
async test "MQTT client closes the connection when the pending message queue is full" {
  @async.with_task_group <| root => {
    let server = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:0"))
    let address = server.addr
    root.spawn_bg(no_wait=true, () => {
      server.run_forever(max_connections=1) <| ((tcp, _) => {
        match broker_read_packet(tcp) {
          @codec.ConnectPacket(_) => ()
          _ => fail("expected CONNECT")
        }
        broker_write_packet(
          tcp,
          @codec.ConnackPacket({
            session_present: false,
            return_code: @codec.ConnectionAccepted,
          }),
        )
        match broker_read_packet(tcp) {
          @codec.PingreqPacket => ()
          _ => fail("expected PINGREQ")
        }
        for _ in 0..<65 {
          broker_write_packet(
            tcp,
            @codec.PublishPacket({
              topic: "demo/overflow",
              payload: b"queued",
              qos: @codec.QoS0,
              message_id: None,
              retain: false,
              dup: false,
            }),
          )
        }
      })
    })
    let client = @client.Client::connect(
      "127.0.0.1",
      port=address.port(),
      client_id="scantling-pending-message-overflow",
    )
    let result : Result[Unit, @client.ClientError] = try {
      client.ping()
      Ok(())
    } catch {
      error => Err(error)
    }
    match result {
      Err(
        @client.ClientError::UnexpectedPacket(
          "pending inbound message queue limit exceeded; connection closed"
        )
      ) => ()
      _ => fail("expected a closed connection on inbound queue overflow")
    }
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
      subscriber.subscribe_many(topics=[
        @client.Subscription::{ topic, qos: @codec.QoS1, },
        @client.Subscription::{
          topic: "scantling/interop/unused/#",
          qos: @codec.QoS0,
        },
      ])
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
      subscriber.unsubscribe_many(topics=[topic, "scantling/interop/unused/#"])
      publisher.disconnect()
      subscriber.disconnect()
    }
  }
}

///|
#cfg(target="native")
async test "MQTT client receives a retained QoS 0 message from Mosquitto" {
  match @env.get_env_var("SCANTLING_MOSQUITTO_HOST") {
    None => ()
    Some(host) => {
      let topic = "scantling/interop/retained/qos0"
      let publisher = @client.Client::connect(
        host,
        port=1883,
        client_id="scantling-mosquitto-retained-publisher",
      )
      publisher.publish(topic~, payload=b"retained-value", retain=true)
      publisher.ping()
      let subscriber = @client.Client::connect(
        host,
        port=1883,
        client_id="scantling-mosquitto-retained-subscriber",
      )
      subscriber.subscribe(topic~, qos=@codec.QoS0)
      let message = subscriber.receive()
      assert_eq(message.topic, topic)
      assert_eq(message.payload, b"retained-value")
      assert_eq(message.qos, @codec.QoS0)
      assert_true(message.retain)
      publisher.publish(topic~, payload=b"", retain=true)
      publisher.ping()
      subscriber.disconnect()
      publisher.disconnect()
    }
  }
}
