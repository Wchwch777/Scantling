# MoonBit GraphQL HTTP Client

A small asynchronous GraphQL-over-HTTP client for MoonBit. It sends JSON POST
requests, decodes GraphQL response envelopes, and keeps partial `data` when a
response also contains `errors`.

## Scope

- Queries and mutations over HTTP POST.
- JSON `variables` and optional `operationName`.
- Configurable request headers (for example, authorization).
- Structured GraphQL errors, extensions, response status, and partial data.
- An injectable asynchronous transport for deterministic tests and custom
  environments.

This is not a schema/code generator and does not currently implement
subscriptions, WebSockets, automatic retries, persisted queries, or a typed
model layer. The default transport is based on `moonbitlang/async` (currently
experimental); check that library's platform support before adopting it in a
production target. Use `with_transport` to provide a transport suited to your
runtime.

## Quick start

Add the package to a MoonBit project, then construct a client and execute a
request:

```moonbit
import {
  "moonbit_graphql_client/graphql" @graphql,
  "moonbitlang/core/json" @json,
}

let client = @graphql.GraphQLClient::new(
  "https://api.example.test/graphql",
  headers={ "authorization": "Bearer YOUR_TOKEN" },
).unwrap()

match client.execute(
  "query Viewer($id: ID!) { user(id: $id) { name } }",
  variables=@json.Json::object({ "id": @json.Json::string("42") }),
  operation_name="Viewer",
) {
  Ok(response) => {
    // Inspect response.data and response.errors independently:
    // GraphQL may return useful partial data together with errors.
    println(response.data)
    println(response.errors)
  }
  Err(error) => println(error)
}
```

## Error behavior

`GraphQLResponse` is returned for a valid GraphQL envelope, including a valid
envelope with a non-2xx HTTP status. Callers should inspect `http_status`,
`data`, and `errors`; a GraphQL error is not necessarily a transport failure.
Malformed successful responses, non-GraphQL HTTP failures, and transport
failures use distinct `ClientError` variants.

## Development and verification

Run `moon fmt`, `moon check`, and `moon test`. A native-target test also sends a
real request to an ephemeral loopback HTTP server to exercise the default
transport; it requires a C compiler and can be run with `moon test --target
native`. The ordinary tests use an injected transport and do not contact an
external service.

See [AI_ASSISTED.md](AI_ASSISTED.md) for an accurate account of AI assistance
and [docs/owner-review.md](docs/owner-review.md) for the human review and
project-validation items that still require the project owner's own input.
