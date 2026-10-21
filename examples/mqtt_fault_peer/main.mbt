///|
async fn main {
  let (scenario_name, scenario) = match
    @env.get_env_var("SCANTLING_FAULT_SCENARIO") {
    None => ("reject-connect", @peer.Scenario::RejectConnect)
    Some("reject-connect") => ("reject-connect", @peer.Scenario::RejectConnect)
    Some("truncate-connack") =>
      ("truncate-connack", @peer.Scenario::TruncateConnack)
    Some("mismatched-puback") =>
      ("mismatched-puback", @peer.Scenario::MismatchedPuback)
    Some("unexpected-suback-response") =>
      ("unexpected-suback-response", @peer.Scenario::UnexpectedSubackResponse)
    Some("accept-publish-qos0") =>
      ("accept-publish-qos0", @peer.Scenario::AcceptPublishQoS0)
    Some("accept-publish-qos1") =>
      ("accept-publish-qos1", @peer.Scenario::AcceptPublishQoS1)
    Some(value) => fail("unknown SCANTLING_FAULT_SCENARIO: \{value}")
  }
  let port = match @env.get_env_var("SCANTLING_FAULT_PORT") {
    None => 1885
    Some(value) =>
      @string.parse_int(value) catch {
        _ => fail("SCANTLING_FAULT_PORT must be an integer")
      }
  }
  if port < 0 || port > 65535 {
    fail("SCANTLING_FAULT_PORT must be between 0 and 65535")
  }
  let server = @peer.Peer::new(scenario, port~)
  println("Scantling MQTT fault peer listening on 127.0.0.1:\{server.port()}")
  println("Scenario: \{scenario_name}")
  server.run()
}
