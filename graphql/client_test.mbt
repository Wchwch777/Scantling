///|
fn expect_response(
  value : Result[GraphQLResponse, ClientError],
) -> GraphQLResponse {
  match value {
    Ok(response) => response
    Err(_) => abort("expected GraphQL response")
  }
}

///|
#warnings("-unused_async")
async fn success_transport(
  request : HttpRequest,
) -> Result[HttpResponse, String] {
  assert_eq(request.url, "https://example.test/graphql")
  assert_eq(
    request.headers.get("content-type"),
    Some("application/json; charset=utf-8"),
  )
  assert_eq(request.headers.get("authorization"), Some("Bearer test"))
  let payload = @json.parse(request.body) catch {
    _ => fail("request is not JSON")
  }
  guard payload is Json::Object(fields) else {
    fail("request must be an object")
  }
  assert_eq(
    fields.get("query"),
    Some(Json::string("query User($id: ID!) { user(id: $id) { name } }")),
  )
  assert_eq(fields.get("operationName"), Some(Json::string("User")))
  assert_eq(
    fields.get("variables"),
    Some(Json::object({ "id": Json::string("42") })),
  )
  Ok({ status: 200, body: "{\"data\":{\"user\":{\"name\":\"Ada\"}}}", })
}

///|
#warnings("-unused_async")
async fn partial_error_transport(
  _request : HttpRequest,
) -> Result[HttpResponse, String] {
  Ok({
    status: 200,
    body: "{\"data\":{\"user\":null},\"errors\":[{\"message\":\"not found\",\"locations\":[{\"line\":2,\"column\":3}],\"path\":[\"user\"],\"extensions\":{\"code\":\"NOT_FOUND\"}}]}",
  })
}

///|
#warnings("-unused_async")
async fn request_error_transport(
  _request : HttpRequest,
) -> Result[HttpResponse, String] {
  Ok({ status: 400, body: "{\"errors\":[{\"message\":\"syntax error\"}]}", })
}

///|
#warnings("-unused_async")
async fn server_error_transport(
  _request : HttpRequest,
) -> Result[HttpResponse, String] {
  Ok({ status: 502, body: "upstream unavailable", })
}

///|
#warnings("-unused_async")
async fn malformed_transport(
  _request : HttpRequest,
) -> Result[HttpResponse, String] {
  Ok({ status: 200, body: "not-json", })
}

///|
#warnings("-unused_async")
async fn failing_transport(
  _request : HttpRequest,
) -> Result[HttpResponse, String] {
  Err("connection refused")
}

///|
async test "encodes GraphQL POST and decodes data" {
  let client = match
    GraphQLClient::with_transport(
      "https://example.test/graphql",
      success_transport,
      headers={ "authorization": "Bearer test" },
    ) {
    Ok(value) => value
    Err(_) => fail("valid endpoint should construct")
  }
  let response = expect_response(
    client.execute(
      "query User($id: ID!) { user(id: $id) { name } }",
      variables=Json::object({ "id": Json::string("42") }),
      operation_name="User",
    ),
  )
  assert_eq(response.http_status, 200)
  assert_eq(response.errors.length(), 0)
  assert_eq(
    response.data,
    Some(
      Json::object({ "user": Json::object({ "name": Json::string("Ada") }) }),
    ),
  )
}

///|
async test "preserves partial data and structured GraphQL errors" {
  let client = GraphQLClient::with_transport(
    "https://example.test/graphql", partial_error_transport,
  ).unwrap()
  let response = expect_response(client.execute("{ user { name } }"))
  assert_eq(response.errors.length(), 1)
  assert_eq(response.errors[0].message, "not found")
  assert_eq(response.errors[0].locations[0].line, 2)
  assert_eq(response.errors[0].locations[0].column, 3)
  assert_eq(response.errors[0].path, [Json::string("user")])
  assert_eq(response.http_status, 200)
  assert_eq(response.data, Some(Json::object({ "user": Json::null() })))
}

///|
async test "accepts GraphQL request errors returned with an HTTP error status" {
  let client = GraphQLClient::with_transport(
    "https://example.test/graphql", request_error_transport,
  ).unwrap()
  let response = expect_response(client.execute("query {"))
  assert_eq(response.http_status, 400)
  assert_eq(response.data, None)
  assert_eq(response.errors.length(), 1)
  assert_eq(response.errors[0].message, "syntax error")
}

///|
async test "reports non-GraphQL HTTP errors with status and body" {
  let client = GraphQLClient::with_transport(
    "https://example.test/graphql", server_error_transport,
  ).unwrap()
  match client.execute("{ status }") {
    Err(ClientError::HttpFailure(502, body)) =>
      assert_eq(body, "upstream unavailable")
    _ => fail("expected an HTTP failure")
  }
}

///|
async test "rejects malformed successful responses" {
  let client = GraphQLClient::with_transport(
    "https://example.test/graphql", malformed_transport,
  ).unwrap()
  match client.execute("{ status }") {
    Err(ClientError::InvalidResponse(_)) => ()
    _ => fail("expected an invalid response error")
  }
}

///|
async test "maps transport errors to a distinct client error" {
  let client = GraphQLClient::with_transport(
    "https://example.test/graphql", failing_transport,
  ).unwrap()
  match client.execute("{ status }") {
    Err(ClientError::TransportFailure(message)) =>
      assert_eq(message, "connection refused")
    _ => fail("expected a transport failure")
  }
}

///|
async test "validates endpoint and rejects empty query" {
  assert_true(GraphQLClient::new("file:///tmp/graphql") is Err(_))
  assert_true(GraphQLClient::new("https://") is Err(_))
  let client = GraphQLClient::with_transport(
    "https://example.test/graphql", malformed_transport,
  ).unwrap()
  match client.execute("  \n  ") {
    Err(ClientError::InvalidRequest(message)) =>
      assert_eq(message, "query must not be empty")
    _ => fail("expected the empty-query error")
  }
}

///|
#cfg(target="native")
async test "default transport sends a POST to a local HTTP server" {
  @async.with_task_group <| root => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let address = server.addr
    root.spawn_bg(no_wait=true, () => {
      server.run_forever() <| ((request, body, conn) => {
        assert_eq(request.meth, @http.Post)
        assert_eq(request.path, "/graphql")
        let request_body = body.read_all().text()
        assert_true(request_body.contains("\"query\":\"{ ping }\""))
        conn
        ..send_response(200, "OK", extra_headers={
          "Content-Type": "application/graphql-response+json",
        })
        ..write("{\"data\":{\"ping\":\"pong\"}}")
        .end_response()
      })
    })
    @async.sleep(50)
    let client = GraphQLClient::new("http://127.0.0.1:{address.port()}/graphql").unwrap()
    let response = expect_response(client.execute("{ ping }"))
    assert_eq(response.http_status, 200)
    assert_eq(
      response.data,
      Some(Json::object({ "ping": Json::string("pong") })),
    )
    server.close()
  }
}
