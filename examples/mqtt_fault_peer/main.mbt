///|
async fn main {
  let script_path = @env.get_env_var("SCANTLING_FAULT_SCRIPT")
  let scenario_value = match script_path {
    Some(_) => None
    None => @env.get_env_var("SCANTLING_FAULT_SCENARIO")
  }
  let (scenario_name, scenario) = match scenario_value {
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
  let server = match script_path {
    Some(path) => {
      let source = @fs.read_file(path).text()
      let script = match @peer.Script::parse(source) {
        Ok(script) => script
        Err(error) => fail("invalid MQTT scenario script: \{error}")
      }
      @stdio.stdout.write("Scenario script: \{path}\n")
      @peer.Peer::with_script(script, port~)
    }
    None => @peer.Peer::new(scenario, port~)
  }
  @stdio.stdout.write(
    "Scantling MQTT test peer listening on 127.0.0.1:\{server.port()}\n",
  )
  if script_path is None {
    @stdio.stdout.write("Scenario: \{scenario_name}\n")
  }
  server.run()
}
