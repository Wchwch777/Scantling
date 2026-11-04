///|
async fn main {
  let path = @env.get_env_var("SCANTLING_TRACE").unwrap_or(
    "examples/check_trace/traces/interleaved.trace",
  )
  let report = match @monitor.check_trace(@fs.read_file(path).text()) {
    Ok(report) => report
    Err(error) => fail("invalid trace: \{error}")
  }
  @stdio.stdout.write(report.to_json().stringify() + "\n")
  if !report.complete {
    fail("trace is invalid or incomplete; see JSON report")
  }
}
