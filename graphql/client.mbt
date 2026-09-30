///|
/// A minimal HTTP request accepted by the transport seam. Keeping the seam
/// explicit makes request behavior deterministic to test and lets callers
/// replace the default MoonBit HTTP transport when needed.
pub(all) struct HttpRequest {
  url : String
  headers : Map[String, String]
  body : String
} derive(Eq, Debug)

///|
/// An HTTP response returned by a GraphQL transport.
pub(all) struct HttpResponse {
  status : Int
  body : String
} derive(Eq, Debug)

///|
/// An asynchronous transport callback. Implementations should return the
/// response body as UTF-8 text and report network failures as `Err`.
pub type HttpSend = async (HttpRequest) -> Result[HttpResponse, String]

///|
pub(all) struct ErrorLocation {
  line : Int
  column : Int
} derive(Eq, Debug)

///|
pub(all) struct GraphQLError {
  message : String
  locations : Array[ErrorLocation]
  path : Array[Json]
  extensions : Json?
} derive(Eq, Debug)

///|
/// A decoded GraphQL response. `data` remains optional because a request
/// error can contain `errors` without a `data` key, while `data: null` is
/// preserved as `Some(Json::Null)`.
pub(all) struct GraphQLResponse {
  http_status : Int
  data : Json?
  errors : Array[GraphQLError]
  extensions : Json?
} derive(Eq, Debug)

///|
pub suberror ClientError {
  InvalidEndpoint(String)
  InvalidRequest(String)
  TransportFailure(String)
  HttpFailure(Int, String)
  InvalidResponse(String)
} derive(Eq, Debug)

///|
/// A GraphQL-over-HTTP client. The default transport uses
/// `moonbitlang/async/http`; `with_transport` supports deterministic tests and
/// host-specific adapters.
pub(all) struct GraphQLClient {
  endpoint : String
  headers : Map[String, String]
  send : HttpSend
}

///|
pub fn GraphQLClient::new(
  endpoint : String,
  headers? : Map[String, String] = {},
) -> Result[GraphQLClient, ClientError] {
  if !is_http_endpoint(endpoint) {
    return Err(ClientError::InvalidEndpoint(endpoint))
  }
  Ok({ endpoint, headers, send: default_http_send, })
}

///|
pub fn GraphQLClient::with_transport(
  endpoint : String,
  send : HttpSend,
  headers? : Map[String, String] = {},
) -> Result[GraphQLClient, ClientError] {
  if !is_http_endpoint(endpoint) {
    return Err(ClientError::InvalidEndpoint(endpoint))
  }
  Ok({ endpoint, headers, send, })
}

///|
pub async fn GraphQLClient::execute(
  self : GraphQLClient,
  query : String,
  variables? : Json,
  operation_name? : String,
) -> Result[GraphQLResponse, ClientError] {
  if query.trim().is_empty() {
    return Err(ClientError::InvalidRequest("query must not be empty"))
  }
  let body = encode_request(query, variables, operation_name)
  let headers = Map([
    ("accept", "application/graphql-response+json, application/json;q=0.9"),
    ("content-type", "application/json; charset=utf-8"),
  ])
  for key, value in self.headers {
    headers[key] = value
  }
  let request : HttpRequest = { url: self.endpoint, headers, body, }
  let response = match (self.send)(request) {
    Ok(value) => value
    Err(message) => return Err(ClientError::TransportFailure(message))
  }
  decode_response(response.status, response.body)
}

///|
fn is_http_endpoint(endpoint : String) -> Bool {
  let has_scheme = endpoint.has_prefix("http://") ||
    endpoint.has_prefix("https://")
  if !has_scheme {
    return false
  }
  let authority_start = if endpoint.has_prefix("https://") { 8 } else { 7 }
  endpoint.length() > authority_start &&
  !endpoint[authority_start:].has_prefix("/") &&
  !endpoint[authority_start:].has_prefix("?") &&
  !endpoint[authority_start:].has_prefix("#")
}

///|
async fn default_http_send(
  request : HttpRequest,
) -> Result[HttpResponse, String] {
  let headers : @http.Headers = Map([])
  for key, value in request.headers {
    headers[@http.CaseInsensitiveString(key)] = value
  }
  let (response, body) = @http.post(request.url, request.body, headers~) catch {
    _ => return Err("HTTP request failed")
  }
  let text = body.text() catch {
    _ => return Err("HTTP response body is not valid UTF-8")
  }
  Ok({ status: response.code, body: text, })
}

///|
fn encode_request(
  query : String,
  variables : Json?,
  operation_name : String?,
) -> String {
  let fields : Map[String, Json] = { "query": Json::string(query) }
  if variables is Some(value) {
    fields["variables"] = value
  }
  if operation_name is Some(value) {
    fields["operationName"] = Json::string(value)
  }
  Json::object(fields).stringify()
}

///|
fn decode_response(
  status : Int,
  body : String,
) -> Result[GraphQLResponse, ClientError] {
  let json = @json.parse(body) catch {
    _ => {
      if status < 200 || status >= 300 {
        return Err(ClientError::HttpFailure(status, body))
      }
      return Err(ClientError::InvalidResponse("body is not valid JSON"))
    }
  }
  guard json is Json::Object(object) else {
    if status < 200 || status >= 300 {
      return Err(ClientError::HttpFailure(status, body))
    }
    return Err(ClientError::InvalidResponse("response must be a JSON object"))
  }
  let data = object.get("data")
  let errors = match object.get("errors") {
    None => []
    Some(Json::Array(items)) => {
      let decoded = []
      for item in items {
        match decode_error(item) {
          Ok(error) => decoded.push(error)
          Err(message) =>
            return Err(
              ClientError::InvalidResponse("invalid GraphQL error: " + message),
            )
        }
      }
      decoded
    }
    Some(_) =>
      return Err(ClientError::InvalidResponse("errors must be an array"))
  }
  if data is None && errors.is_empty() {
    if status < 200 || status >= 300 {
      return Err(ClientError::HttpFailure(status, body))
    }
    return Err(
      ClientError::InvalidResponse("response must contain data or errors"),
    )
  }
  Ok({
    http_status: status,
    data,
    errors,
    extensions: object.get("extensions"),
  })
}

///|
fn decode_error(value : Json) -> Result[GraphQLError, String] {
  guard value is Json::Object(object) else {
    return Err("entry must be an object")
  }
  let message = match object.get("message") {
    Some(Json::String(text)) => text
    _ => return Err("message must be a string")
  }
  let locations = match object.get("locations") {
    None => []
    Some(Json::Array(items)) => {
      let decoded = []
      for item in items {
        guard item is Json::Object(location) else {
          return Err("location must be an object")
        }
        let line = match location.get("line") {
          Some(Json::Number(value, ..)) => value.to_int()
          _ => return Err("location line must be a number")
        }
        let column = match location.get("column") {
          Some(Json::Number(value, ..)) => value.to_int()
          _ => return Err("location column must be a number")
        }
        decoded.push({ line, column, })
      }
      decoded
    }
    Some(_) => return Err("locations must be an array")
  }
  let path = match object.get("path") {
    None => []
    Some(Json::Array(items)) => items
    Some(_) => return Err("path must be an array")
  }
  Ok({ message, locations, path, extensions: object.get("extensions"), })
}
