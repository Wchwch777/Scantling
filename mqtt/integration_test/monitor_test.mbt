///|
#cfg(target="native")
async test "stateful monitor validates actual client QoS2 packets on TCP" {
  @async.with_timeout(5000, () => {
    @async.with_task_group <| group => {
      let script = @fault_peer.Script::parse(
        "expect CONNECT\nsend CONNACK code=0\nexpect PUBLISH qos=2\nsend PUBREC id=request\nexpect PUBREL\nsend PUBCOMP id=request\nexpect DISCONNECT\nclose\n",
      ).unwrap()
      let peer = @fault_peer.Peer::with_script(script)
      let task = group.spawn(() => peer.run_monitored())
      let client = @client.Client::connect(
        "127.0.0.1",
        port=peer.port(),
        client_id="observed-qos2",
      )
      client.publish_qos2(topic="test/data", payload=b"real-tcp")
      client.disconnect()
      let report = task.wait()
      assert_true(report.complete)
      assert_eq(report.completed_publications, 1)
      assert_eq(report.pending, 0)
    }
  })
}

///|
#cfg(target="native")
async test "stateful monitor attributes invalid ACK to the scripted peer" {
  @async.with_timeout(5000, () => {
    @async.with_task_group <| group => {
      let script = @fault_peer.Script::parse(
        "expect CONNECT\nsend CONNACK code=0\nexpect PUBLISH qos=1\nsend PUBACK id=65535\nclose\n",
      ).unwrap()
      let peer = @fault_peer.Peer::with_script(script)
      let task = group.spawn(() => peer.run_monitored())
      let client = @client.Client::connect(
        "127.0.0.1",
        port=peer.port(),
        client_id="observed-invalid",
      )
      client.publish_qos1(topic="test/data", payload=b"real-tcp") catch {
        _ => ()
      }
      let report = task.wait()
      assert_false(report.valid_prefix)
      assert_eq(report.diagnostics[0].rule, "TRACE-ACK-ORPHAN")
    }
  })
}

///|
#cfg(target="native")
async test "monitored peer timeout bounds a silent client" {
  let peer = @fault_peer.Peer::new(@fault_peer.Scenario::AcceptPublishQoS1)
  try peer.run_monitored(timeout_ms=20) catch {
    _ => ()
  } noraise {
    _ => fail("silent peer should time out")
  }
}
