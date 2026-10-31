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
async fn broker_write_bytes(tcp : @socket.Tcp, bytes : Array[Byte]) -> Unit {
  let data : Bytes = [ for byte in bytes => byte ]
  tcp.write(data)
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
async test "MQTT client keeps alive through idle time and delivers later events" {
  @async.with_task_group <| root => {
    let server = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:0"))
    let address = server.addr
    root.spawn_bg(no_wait=true, () => {
      let (tcp, _) = server.accept()
      match broker_read_packet(tcp) {
        @codec.ConnectPacket(connect) => assert_eq(connect.keep_alive, 4)
        _ => fail("expected CONNECT")
      }
      broker_write_packet(
        tcp,
        @codec.ConnackPacket({
          session_present: false,
          return_code: @codec.ConnectionAccepted,
        }),
      )
      let subscription_id = match broker_read_packet(tcp) {
        @codec.SubscribePacket(request) => {
          assert_eq(request.topics.length(), 2)
          request.message_id
        }
        _ => fail("expected command and event SUBSCRIBE")
      }
      broker_write_packet(
        tcp,
        @codec.SubackPacket({
          message_id: subscription_id,
          return_codes: [@codec.SuccessQoS1, @codec.SuccessQoS1],
        }),
      )

      broker_write_packet(
        tcp,
        @codec.PublishPacket({
          topic: "demo/device/device-7/cmd",
          payload: b"SET_TEMP=22.0",
          qos: @codec.QoS1,
          message_id: Some(70),
          retain: false,
          dup: false,
        }),
      )
      match broker_read_packet(tcp) {
        @codec.PubackPacket(packet_id) => assert_eq(packet_id.message_id, 70)
        _ => fail("expected command PUBACK")
      }

      // Keep the connection idle across two keep-alive intervals before
      // delivering the event.
      let delayed_event = @codec.encode_packet(
        @codec.PublishPacket({
          topic: "demo/service/orders/created",
          payload: b"order_id=delayed-1",
          qos: @codec.QoS1,
          message_id: Some(71),
          retain: false,
          dup: false,
        }),
      ).unwrap()
      match broker_read_packet(tcp) {
        @codec.PingreqPacket => broker_write_packet(tcp, @codec.PingrespPacket)
        _ => fail("expected first keep-alive PINGREQ")
      }
      match broker_read_packet(tcp) {
        @codec.PingreqPacket => ()
        _ => fail("expected second keep-alive PINGREQ")
      }
      broker_write_bytes(tcp, delayed_event)
      broker_write_packet(tcp, @codec.PingrespPacket)
      match broker_read_packet(tcp) {
        @codec.PubackPacket(packet_id) => assert_eq(packet_id.message_id, 71)
        _ => fail("expected delayed event PUBACK")
      }

      // A subsequent call must not see the PINGRESP as an unexpected
      // packet; the delayed event was returned only after it was consumed.
      broker_write_packet(
        tcp,
        @codec.PublishPacket({
          topic: "demo/service/orders/created",
          payload: b"order_id=delayed-2",
          qos: @codec.QoS0,
          message_id: None,
          retain: false,
          dup: false,
        }),
      )
      match broker_read_packet(tcp) {
        @codec.DisconnectPacket => ()
        _ => fail("expected DISCONNECT")
      }
    })
    let client = @client.Client::connect(
      "127.0.0.1",
      port=address.port(),
      client_id="scantling-idle-keep-alive",
      keep_alive=4,
    )
    client.subscribe_many(topics=[
      @client.Subscription::{
        topic: "demo/device/device-7/cmd",
        qos: @codec.QoS1,
      },
      @client.Subscription::{
        topic: "demo/service/orders/created",
        qos: @codec.QoS1,
      },
    ])
    let command = client.receive()
    assert_eq(command.topic, "demo/device/device-7/cmd")
    assert_eq(command.payload, b"SET_TEMP=22.0")

    let event = client.receive_with_keep_alive()
    assert_eq(event.topic, "demo/service/orders/created")
    assert_eq(event.payload, b"order_id=delayed-1")
    assert_eq(event.qos, @codec.QoS1)
    let next_event = client.receive()
    assert_eq(next_event.payload, b"order_id=delayed-2")
    client.disconnect()
    server.close()
  }
}

///|
#cfg(target="native")
async test "MQTT client closes after a keep-alive PINGRESP deadline expires" {
  @async.with_task_group <| root => {
    let server = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:0"))
    let address = server.addr
    root.spawn_bg(no_wait=true, () => {
      let (tcp, _) = server.accept()
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
      match tcp.read_some(max_len=1) {
        None => ()
        Some(_) => fail("expected the client to close after missing PINGRESP")
      }
    })
    let client = @client.Client::connect(
      "127.0.0.1",
      port=address.port(),
      client_id="scantling-keep-alive-timeout",
      keep_alive=2,
    )
    let result : Result[@client.Message, @client.ClientError] = Ok(
      client.receive_with_keep_alive(),
    ) catch {
      error => Err(error)
    }
    match result {
      Err(@client.ClientError::KeepAliveTimeout) => ()
      _ => fail("expected a keep-alive timeout")
    }
    server.close()
  }
}

///|
#cfg(target="native")
async test "MQTT client completes QoS2 publish and inbound delivery handshakes" {
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
        let subscription_id = match broker_read_packet(tcp) {
          @codec.SubscribePacket(request) => {
            assert_eq(request.topics[0].qos, @codec.QoS2)
            request.message_id
          }
          _ => fail("expected QoS 2 SUBSCRIBE")
        }
        broker_write_packet(
          tcp,
          @codec.SubackPacket({
            message_id: subscription_id,
            return_codes: [@codec.SuccessQoS2],
          }),
        )

        let outgoing_id = match broker_read_packet(tcp) {
          @codec.PublishPacket(message) => {
            assert_eq(message.topic, "demo/qos2/out")
            assert_eq(message.payload, b"client-qos2")
            assert_eq(message.qos, @codec.QoS2)
            message.message_id.unwrap()
          }
          _ => fail("expected QoS 2 PUBLISH")
        }
        broker_write_packet(
          tcp,
          @codec.PubrecPacket({ message_id: outgoing_id, }),
        )
        match broker_read_packet(tcp) {
          @codec.PubrelPacket(packet_id) =>
            assert_eq(packet_id.message_id, outgoing_id)
          _ => fail("expected PUBREL")
        }
        // A duplicate PUBREC requires the sender to retransmit PUBREL.
        broker_write_packet(
          tcp,
          @codec.PubrecPacket({ message_id: outgoing_id, }),
        )
        match broker_read_packet(tcp) {
          @codec.PubrelPacket(packet_id) =>
            assert_eq(packet_id.message_id, outgoing_id)
          _ => fail("expected retransmitted PUBREL")
        }
        broker_write_packet(
          tcp,
          @codec.PubcompPacket({ message_id: outgoing_id, }),
        )

        broker_write_packet(
          tcp,
          @codec.PublishPacket({
            topic: "demo/qos2/in",
            payload: b"broker-qos2",
            qos: @codec.QoS2,
            message_id: Some(81),
            retain: false,
            dup: false,
          }),
        )
        match broker_read_packet(tcp) {
          @codec.PubrecPacket(packet_id) => assert_eq(packet_id.message_id, 81)
          _ => fail("expected PUBREC for inbound QoS 2 PUBLISH")
        }
        broker_write_packet(tcp, @codec.PubrelPacket({ message_id: 81, }))
        match broker_read_packet(tcp) {
          @codec.PubcompPacket(packet_id) => assert_eq(packet_id.message_id, 81)
          _ => fail("expected PUBCOMP")
        }

        // A duplicate completed PUBLISH/PUBREL pair is acknowledged without
        // queueing a second application delivery.
        match broker_read_packet(tcp) {
          @codec.PingreqPacket => ()
          _ => fail("expected PINGREQ")
        }
        broker_write_packet(
          tcp,
          @codec.PublishPacket({
            topic: "demo/qos2/in",
            payload: b"broker-qos2",
            qos: @codec.QoS2,
            message_id: Some(81),
            retain: false,
            dup: true,
          }),
        )
        match broker_read_packet(tcp) {
          @codec.PubrecPacket(packet_id) => assert_eq(packet_id.message_id, 81)
          _ => fail("expected PUBREC for duplicate QoS 2 PUBLISH")
        }
        broker_write_packet(tcp, @codec.PubrelPacket({ message_id: 81, }))
        match broker_read_packet(tcp) {
          @codec.PubcompPacket(packet_id) => assert_eq(packet_id.message_id, 81)
          _ => fail("expected PUBCOMP for duplicate PUBREL")
        }
        broker_write_packet(
          tcp,
          @codec.PublishPacket({
            topic: "demo/qos2/control",
            payload: b"control",
            qos: @codec.QoS0,
            message_id: None,
            retain: false,
            dup: false,
          }),
        )
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
      client_id="scantling-qos2-handshake",
    )
    client.subscribe(topic="demo/qos2/#", qos=@codec.QoS2)
    client.publish_qos2(topic="demo/qos2/out", payload=b"client-qos2")
    let received = client.receive()
    assert_eq(received.topic, "demo/qos2/in")
    assert_eq(received.payload, b"broker-qos2")
    assert_eq(received.qos, @codec.QoS2)
    client.ping()
    let next_message = client.receive()
    assert_eq(next_message.topic, "demo/qos2/control")
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
    let peer = @fault_peer.Peer::new(@fault_peer.Scenario::RejectConnect)
    root.spawn_bg(no_wait=true, () => peer.run())
    let result : Result[@client.Client, @client.ClientError] = Ok(
      @client.Client::connect(
        "127.0.0.1",
        port=peer.port(),
        client_id="scantling-rejected-client",
      ),
    ) catch {
      error => Err(error)
    }
    match result {
      Err(@client.ClientError::Rejected(5)) => ()
      _ => fail("expected broker rejection code 5")
    }
  }
}

///|
#cfg(target="native")
async test "MQTT client rejects a PUBACK with a different packet identifier" {
  @async.with_task_group <| root => {
    let peer = @fault_peer.Peer::new(@fault_peer.Scenario::MismatchedPuback)
    root.spawn_bg(no_wait=true, () => peer.run())
    let client = @client.Client::connect(
      "127.0.0.1",
      port=peer.port(),
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
  }
}

///|
#cfg(target="native")
async test "fault peer executes a caller-defined SUBACK fault script" {
  @async.with_task_group <| root => {
    let script = @fault_peer.Script::new([
      @fault_peer.Exchange::new(
        "CONNECT",
        packet => {
          match packet {
            @codec.ConnectPacket(_) => true
            _ => false
          }
        },
        _packet => {
          [
            @fault_peer.Action::SendPacket(
              @codec.ConnackPacket({
                session_present: false,
                return_code: @codec.ConnectionAccepted,
              }),
            ),
          ]
        },
      ),
      @fault_peer.Exchange::new(
        "SUBSCRIBE",
        packet => {
          match packet {
            @codec.SubscribePacket(_) => true
            _ => false
          }
        },
        packet => {
          match packet {
            @codec.SubscribePacket(request) =>
              [
                @fault_peer.Action::SendPacket(
                  @codec.SubackPacket({
                    message_id: request.message_id,
                    return_codes: [@codec.SuccessQoS2],
                  }),
                ),
              ]
            _ => []
          }
        },
      ),
      @fault_peer.Exchange::new(
        "DISCONNECT",
        packet => {
          match packet {
            @codec.DisconnectPacket => true
            _ => false
          }
        },
        _packet => [],
      ),
    ])
    let peer = @fault_peer.Peer::with_script(script)
    root.spawn_bg(no_wait=true, () => peer.run())
    let client = @client.Client::connect(
      "127.0.0.1",
      port=peer.port(),
      client_id="scantling-custom-suback-script",
    )
    let result : Result[Unit, @client.ClientError] = try {
      client.subscribe(topic="demo/custom-suback", qos=@codec.QoS0)
      Ok(())
    } catch {
      error => Err(error)
    }
    match result {
      Err(
        @client.ClientError::UnexpectedPacket(
          "broker granted a higher QoS than requested"
        )
      ) => ()
      _ => fail("custom script did not inject the invalid SUBACK grant")
    }
    client.disconnect()
  }
}

///|
#cfg(target="native")
async test "text-scripted peer fragments and delays a CONNACK response" {
  @async.with_task_group <| root => {
    let script = match
      @fault_peer.Script::parse(
        "expect CONNECT\nraw 20\nwait 5\nraw 02 00 00\nexpect SUBSCRIBE\nsend SUBACK id=request codes=0\nexpect DISCONNECT\n",
      ) {
      Ok(script) => script
      Err(error) => fail("scenario parser rejected integration case: \{error}")
    }
    let peer = @fault_peer.Peer::with_script(script)
    root.spawn_bg(no_wait=true, () => peer.run())
    let client = @client.Client::connect(
      "127.0.0.1",
      port=peer.port(),
      client_id="scantling-text-scripted-peer",
    )
    client.subscribe(topic="demo/scripted", qos=@codec.QoS0)
    client.disconnect()
  }
}

///|
#cfg(target="native")
async test "text-scripted peer completes QoS 2 with filtered packet identifiers" {
  @async.with_task_group <| root => {
    let script = match
      @fault_peer.Script::parse(
        "expect CONNECT\nsend CONNACK code=0\nexpect PUBLISH qos=2 topic=demo/scripted/qos2\nsend PUBREC id=request\nexpect PUBREL\nsend PUBCOMP id=request\nexpect DISCONNECT\nclose\n",
      ) {
      Ok(script) => script
      Err(error) => fail("QoS 2 scenario parser rejected script: \{error}")
    }
    let peer = @fault_peer.Peer::with_script(script)
    root.spawn_bg(no_wait=true, () => peer.run())
    let client = @client.Client::connect(
      "127.0.0.1",
      port=peer.port(),
      client_id="scantling-scripted-qos2",
    )
    client.publish_qos2(topic="demo/scripted/qos2", payload=b"qos2-message")
    client.disconnect()
  }
}

///|
#cfg(target="native")
async test "text-scripted peer answers keep-alive before a later event" {
  @async.with_task_group <| root => {
    let script = match
      @fault_peer.Script::parse(
        "expect CONNECT\nsend CONNACK code=0\nexpect SUBSCRIBE topic=demo/idle/event\nsend SUBACK id=request codes=0\nexpect PINGREQ\nsend PINGRESP\nexpect PINGREQ\nsend PINGRESP\nsend PUBLISH topic=demo/idle/event qos=0 payload_hex=61,66,74,65,72,2d,69,64,6c,65\nexpect DISCONNECT\nclose\n",
      ) {
      Ok(script) => script
      Err(error) => fail("idle-event scenario parser rejected script: \{error}")
    }
    let peer = @fault_peer.Peer::with_script(script)
    root.spawn_bg(no_wait=true, () => peer.run())
    let client = @client.Client::connect(
      "127.0.0.1",
      port=peer.port(),
      client_id="scantling-scripted-idle-event",
      keep_alive=4,
    )
    client.subscribe(topic="demo/idle/event", qos=@codec.QoS0)
    let message = client.receive_with_keep_alive()
    assert_eq(message.topic, "demo/idle/event")
    assert_eq(message.payload, b"after-idle")
    client.disconnect()
  }
}

///|
#cfg(target="native")
async test "fault peer scripts a QoS 2 exchange with duplicate PUBREC" {
  @async.with_task_group <| root => {
    let script = @fault_peer.Script::new([
      @fault_peer.Exchange::new(
        "CONNECT",
        packet => {
          match packet {
            @codec.ConnectPacket(_) => true
            _ => false
          }
        },
        _packet => {
          [
            @fault_peer.Action::SendPacket(
              @codec.ConnackPacket({
                session_present: false,
                return_code: @codec.ConnectionAccepted,
              }),
            ),
          ]
        },
      ),
      @fault_peer.Exchange::new(
        "QoS 2 PUBLISH",
        packet => {
          match packet {
            @codec.PublishPacket(message) if message.qos == @codec.QoS2 => true
            _ => false
          }
        },
        packet => {
          match packet {
            @codec.PublishPacket(message) =>
              match message.message_id {
                Some(message_id) =>
                  [
                    @fault_peer.Action::SendPacket(
                      @codec.PubrecPacket({ message_id, }),
                    ),
                  ]
                None => [@fault_peer.Action::Close]
              }
            _ => [@fault_peer.Action::Close]
          }
        },
      ),
      @fault_peer.Exchange::new(
        "PUBREL before duplicate PUBREC",
        packet => {
          match packet {
            @codec.PubrelPacket(_) => true
            _ => false
          }
        },
        packet => {
          match packet {
            @codec.PubrelPacket(packet_id) =>
              [
                @fault_peer.Action::SendPacket(
                  @codec.PubrecPacket({ message_id: packet_id.message_id, }),
                ),
              ]
            _ => []
          }
        },
      ),
      @fault_peer.Exchange::new(
        "retransmitted PUBREL",
        packet => {
          match packet {
            @codec.PubrelPacket(_) => true
            _ => false
          }
        },
        packet => {
          match packet {
            @codec.PubrelPacket(packet_id) =>
              [
                @fault_peer.Action::SendPacket(
                  @codec.PubcompPacket({ message_id: packet_id.message_id, }),
                ),
              ]
            _ => []
          }
        },
      ),
      @fault_peer.Exchange::new(
        "DISCONNECT",
        packet => {
          match packet {
            @codec.DisconnectPacket => true
            _ => false
          }
        },
        _packet => [],
      ),
    ])
    let peer = @fault_peer.Peer::with_script(script)
    root.spawn_bg(no_wait=true, () => peer.run())
    let client = @client.Client::connect(
      "127.0.0.1",
      port=peer.port(),
      client_id="scantling-custom-qos2-script",
    )
    client.publish_qos2(topic="demo/custom-qos2", payload=b"scripted")
    client.disconnect()
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
    let script = @fault_peer.Script::new([
      @fault_peer.Exchange::new(
        "CONNECT",
        packet => {
          match packet {
            @codec.ConnectPacket(_) => true
            _ => false
          }
        },
        _packet => {
          [
            @fault_peer.Action::SendRaw([0x20, 0x02, 0x00]),
            @fault_peer.Action::Close,
          ]
        },
      ),
    ])
    let peer = @fault_peer.Peer::with_script(script)
    root.spawn_bg(no_wait=true, () => peer.run())
    let result : Result[@client.Client, @client.ClientError] = Ok(
      @client.Client::connect(
        "127.0.0.1",
        port=peer.port(),
        client_id="scantling-truncated-connack-body",
      ),
    ) catch {
      error => Err(error)
    }
    match result {
      Err(@client.ClientError::TransportFailure) => ()
      _ => fail("expected a transport failure for truncated CONNACK body")
    }
  }
}

///|
#cfg(target="native")
async test "MQTT client rejects an unexpected packet while awaiting SUBACK" {
  @async.with_task_group <| root => {
    let peer = @fault_peer.Peer::new(
      @fault_peer.Scenario::UnexpectedSubackResponse,
    )
    root.spawn_bg(no_wait=true, () => peer.run())
    let client = @client.Client::connect(
      "127.0.0.1",
      port=peer.port(),
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
  }
}

///|
#cfg(target="native")
async test "MQTT client closes the connection when the pending message queue is full" {
  @async.with_task_group <| root => {
    let server = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:0"))
    let address = server.addr
    root.spawn_bg(no_wait=true, () => {
      let (tcp, _) = server.accept()
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
async test "MQTT client completes QoS2 round trip with Mosquitto" {
  match @env.get_env_var("SCANTLING_MOSQUITTO_HOST") {
    None => ()
    Some(host) => {
      let topic = "scantling/interop/qos2/roundtrip"
      let subscriber = @client.Client::connect(
        host,
        port=1883,
        client_id="scantling-mosquitto-qos2-subscriber",
      )
      subscriber.subscribe(topic~, qos=@codec.QoS2)
      let publisher = @client.Client::connect(
        host,
        port=1883,
        client_id="scantling-mosquitto-qos2-publisher",
      )
      publisher.publish_qos2(topic~, payload=b"mosquitto-qos2-roundtrip")
      let message = subscriber.receive()
      assert_eq(message.topic, topic)
      assert_eq(message.payload, b"mosquitto-qos2-roundtrip")
      assert_eq(message.qos, @codec.QoS2)
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

///|
#cfg(target="native")
async test "MQTT client authenticates with an independent Mosquitto broker" {
  match @env.get_env_var("SCANTLING_MOSQUITTO_AUTH_HOST") {
    None => ()
    Some(host) => {
      let client = @client.Client::connect(
        host,
        port=1884,
        client_id="scantling-mosquitto-authenticated",
        username=Some("scantling-test"),
        password=Some(b"ci-password"),
      )
      client.publish_qos1(topic="scantling/auth/check", payload=b"ok")
      client.disconnect()
    }
  }
}

///|
#cfg(target="native")
async test "MQTT client reports authentication rejection from Mosquitto" {
  match @env.get_env_var("SCANTLING_MOSQUITTO_AUTH_HOST") {
    None => ()
    Some(host) => {
      let result : Result[@client.Client, @client.ClientError] = Ok(
        @client.Client::connect(
          host,
          port=1884,
          client_id="scantling-mosquitto-bad-password",
          username=Some("scantling-test"),
          password=Some(b"wrong-password"),
        ),
      ) catch {
        error => Err(error)
      }
      match result {
        Err(@client.ClientError::Rejected(4)) => ()
        Err(@client.ClientError::Rejected(5)) => ()
        _ => fail("expected Mosquitto to reject invalid credentials")
      }
    }
  }
}
