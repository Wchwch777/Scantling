///|
async test "published traces have reproducible semantic outcomes" {
  for
    (name, valid, complete, rule) in [
      ("interleaved", true, true, ""),
      ("persistent-resume", true, true, ""),
      ("wrong-ack", false, false, "TRACE-ACK-STAGE"),
      ("keepalive-overdue", false, false, "MQTT-3.1.2-24"),
      ("incomplete", true, false, ""),
    ] {
    let source = @fs.read_file("examples/check_trace/traces/\{name}.trace").text()
    let report = @monitor.check_trace(source).unwrap()
    assert_eq(report.valid_prefix, valid)
    assert_eq(report.complete, complete)
    if rule != "" {
      assert_eq(report.diagnostics[0].rule, rule)
    }
  }
}
