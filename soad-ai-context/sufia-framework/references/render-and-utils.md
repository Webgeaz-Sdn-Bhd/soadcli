# Rendering, logging, and utilities

## Renderers

`from utils import render` exposes factories returning callables. Assign the
callable to `ctx.go_to`; the engine invokes it. Default views need no renderer.

| Factory | Response |
| --- | --- |
| `as_view(ctx, view, group=None, code=None)` | Handlebars template in the selected transaction's view directory |
| `as_json(ctx, obj=None, status=200)` | JSON; omitting `obj` serializes `ctx.output` |
| `as_html(ctx, code=None)` | Raw HTML file without template evaluation |
| `as_string(ctx, text_string, status=200)` | Raw HTML/string response |
| `as_file(ctx, file, content_type, filename=None, attachment=True)` | File download or inline response |
| `as_blob(ctx, content, content_type, filename, attachment=False)` | In-memory binary response; filename required |
| `as_pdf(ctx, view, group=None, code=None, filename=None, attachment=False)` | Convert a view to PDF |

The table shows common arguments, not every optional parameter. Check the target
`utils/render.py` before using less common options. For instance `as_view` also
supports `loc`, `file`, and `combine_map`.

```python
ctx.go_to = render.as_view(ctx, "form")
ctx.go_to = render.as_json(ctx, {"saved": True, "id": record.getId()})
ctx.go_to = "%s/t/example/contact" % ctx.ctxPath
```

`as_view(ctx, "form")` looks under `_<current-code>/form.html`. It does not select
the `form` transaction. To obtain an HTML string for email or another utility,
invoke the callable yourself:

```python
body = render.as_view(ctx, "welcome_email")()
```

Set `ctx.page_layout = False` for JSON, files, and fragments in controllers
inheriting a layout. `as_string` does not escape untrusted HTML. Prefer an explicit
JSON object over dumping `ctx.output` when it includes identity or session data.
Choose template/download paths from trusted configuration, not unchecked input.

## Logging and errors

```python
from sufia.util import Log

Log.info(ctx, "Starting report")
Log.debug(ctx, "Preparing rows")
Log.warn(ctx, "No rows matched")
try:
    generate_report()
except Exception as error:
    Log.error(ctx, "Report failed: %s" % error)
    raise
```

`Log.trace`, `Log.print`, and `Log.fatal` are also available. Prefer these
context-aware log methods for application events, and avoid logging credentials
or tokens. A bare `raise` preserves the original traceback and lets the engine
roll back. Do not hide partial-write failures behind an ordinary successful view.

Runtime error responses use dedicated error handling. `ctx.getError()` exposes
error details during that dispatch; avoid rendering stack traces to users in
production. Examine configured logs or `console.log` when debugging.

## Email

```python
from utils import mailer, render

body = render.as_view(ctx, "welcome_email")()
mailer.send(sender, recipient, subject, body, html=True)
```

`send(fr, to, subject, content, cc=[], bcc=[], html=False, attachment=[],
inline=[], reply_to=None, plain_text=None)` sends using configured SMTP. Attachments are file
paths. With `html=True`, optional `plain_text` supplies a UTF-8 plain-text alternative
before the HTML, while preserving CID inline images and attachments. This helps
clients extract one-time codes; client-native detection remains client-controlled.
Configure `mail.smtp.host`, `mail.smtp.port`, and optional username/password
through application properties or environment overrides. `mail.sender.email`
provides the default sender when the explicit sender is absent. Inspect
`utils/mailer.py` for transport-specific behavior before changing deployment
settings; do not assume server configuration from an example.

SMTP verifies the certificate chain using the JVM trust store and checks the
configured hostname. STARTTLS is required when either username or password is
configured, including on port 25, and for every non-25 port. A peer that declines
STARTTLS fails before authentication or message transfer. Unauthenticated port-25
relays may still use plaintext. Provision private CAs in a JVM trust store (for
example with `javax.net.ssl.trustStore`); trust-all SMTP settings and custom SMTP
socket factories are not inherited. Deployments using untrusted certificates or
authenticated plaintext must configure trusted TLS before upgrading.

## PDF and dates

PDF templates must be well-formed XHTML. The utility uses Flying Saucer/OpenPDF;
conversion failures propagate. Keep asset URLs accessible to the renderer.

```python
from utils import pdf, render

html = render.as_view(ctx, "invoice")()
pdf.generate(html, "/tmp/invoice.pdf")
# Or return directly to the browser:
ctx.go_to = render.as_pdf(ctx, "invoice", filename="invoice.pdf", attachment=True)
```

`pdf.generate(content, pdf_file=None, outstream=None)` can write to a supplied
Java output stream. Keep rendering paths and external assets under application
control. `utils.dates.to_datetime(value)` converts supported JDBC date values to
`java.time.Instant`, returning `None` for missing/unparseable values. It uses the
system time zone for local date/time inputs; use explicit zone handling when the
application requires it.

## Java libraries

Import Java classes directly. Bundled libraries include Gson, Guava, Apache POI,
JDBC drivers, Jakarta Mail, and the rendering libraries. Your installed release's
`lib/` and `third-party/ARTIFACTS.txt` list the available libraries and versions.
Additional application JARs belong in `webapp/WEB-INF/lib/`.

Useful imports include `com.google.common.io.ByteStreams` for stream copying and
`com.google.common.io.BaseEncoding` for Base64. Do not assume a library version
or Java API solely because an inherited example uses it.
