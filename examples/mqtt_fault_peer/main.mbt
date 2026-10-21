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
    Some(value) => fail("unknown SCANTLING_FAULT_SCENARIO: \{value}")
  }
  let server = @peer.Peer::new(scenario)
  println("Scantling MQTT fault peer listening on 127.0.0.1:\{server.port()}")
  println("Scenario: \{scenario_name}")
  server.run()
}
