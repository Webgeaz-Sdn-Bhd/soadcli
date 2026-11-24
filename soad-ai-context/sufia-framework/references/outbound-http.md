# Outbound HTTP and AI integrations with Jetty

## Bundled client and lifecycle

SUFIA bundles Jetty 12 `org.eclipse.jetty.client.HttpClient` and
`StringRequestContent` in its runtime classpath. Jython 2.7 can import these Java
classes directly. Python AI SDKs, `requests`, pip, and extra dependencies are
unnecessary. Generated applications must never import `_studio.ai.provider` or
other private IDE modules: exports run without the IDE.

Use the [tested AI summary example](https://docs.sufia.my/framework/examples/ai-summary/) for a
complete controller and view. It creates one client per operation, calls
`start()` before sending, and `stop()` in `finally`. For high throughput an
application-owned lifecycle extension can reuse a thread-safe client and stop it
at shutdown; do not retain per-user headers or identity on a shared instance.

## JSON requests, headers, status and decoding

Create `client.POST(url)`, add headers with
`request.headers(lambda headers: headers.put("Accept", "application/json"))`,
and send `StringRequestContent("application/json", json.dumps(payload))` as its
body. Set the Authorization header on that request. The synchronous `send()`
returns a ContentResponse: check `getStatus()` before decoding
`unicode(response.getContentAsString())` with `json.loads`. Validate response
shape before using nested fields. The buffered synchronous API suits bounded
responses; use streaming for large downloads or SSE.

## Timeouts and failures

`setConnectTimeout(ms)` bounds establishing a connection; `setIdleTimeout(ms)`
bounds inactivity; `request.timeout(n, TimeUnit.MILLISECONDS)` bounds the entire
exchange. A total timeout can raise `java.util.concurrent.TimeoutException`;
transport failures can be wrapped in `ExecutionException`. Catch Java failures
alongside Python exceptions, release resources, and return recoverable feedback.
Check non-2xx responses explicitly: they are responses, not transport exceptions.
Do not print raw upstream bodies or exception messages containing configuration.
Disable redirects for credentialed calls; never trust user-submitted URLs.

## AI endpoint workflow

For a chat-completions-compatible service, configure the full URL, model and key
server-side. Send a JSON model and messages array with `stream: false`, then
extract `choices[0].message.content`. Other AI protocols have different request
and response shapes: consult their contract and keep the same HTTP lifecycle.
Protect the transaction and CSRF mutation with the installed application's
security extension. Render output with ordinary escaped Handlebars values.

API provenance: [Jetty 12 client guide](https://jetty.org/docs/jetty/12/programming-guide/client/http.html)
and [StringRequestContent](https://javadoc.jetty.org/jetty-12/org/eclipse/jetty/client/StringRequestContent.html).
The runnable example is verified against this repository's pinned Jetty version.
