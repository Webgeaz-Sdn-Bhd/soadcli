# SUFIA framework AI context

Framework version: 0.1.12

SUFIA runs Jython 2.7 transactions, Handlebars.java views, and generated
ActiveJDBC models on Java 21. Use **SUFIA** in prose; preserve existing `sufia`,
`soad`, and Java package identifiers in code and commands.

## Locate the code

For an application, edit its source home: controllers are
`webapp/WEB-INF/jython/default/<group>/<code>.py`, and views are
`<group>/_<code>/<view>.html`. Keep Python packages importable with `__init__.py`.
Work in the application's installed or source directory. For an IDE-backed
application synchronized with the `sufia` CLI, edit controllers at
`src/<group>/<code>/<code>.py` and views at
`src/<group>/<code>/_<code>/<view>.html` in the CLI workspace. See the
[runtime reference](#reference-runtime) for synchronization and local testing.
Runtime settings are in `conf/sufia.properties`; application extension defaults
belong in `webapp/WEB-INF/extensions.properties`.

Inspect the target application's schema, configuration, and existing code before
changing behavior. Use the API contracts for the installed runtime version and verify your
application's behavior after changes. Authentication and authorization belong to the application.

## Essential coding rules

- Write Jython/Python 2.7 syntax: use `%` or `.format()`, and import Java classes
  directly. Python 3 syntax, pip dependencies, and CPython extensions do not work
  in transaction code.
- Routing follows names. `address_book.py` defines `class Address_book(object)`;
  `/t/<group>/<code>` defaults to `view(self, ctx)`. Public methods are actions;
  prefix internal helpers with `_`.
- Declare ordinary mutating actions with the exact `"""POST"""` method docstring.
  HTTP method restrictions do not supply authorization or CSRF protection.
- Import generated models rather than writing model classes. For lowercase table
  names, `persons` becomes `Persons`, and `hr_employee` becomes `Hr_employee`.
  Do not singularize. Alias a model import when its name conflicts with a
  transaction or base class.
- Match persistence code to the real schema. Database-generated IDs use
  `saveIt()` without setting the ID. Manual UUID creation generates the ID
  server-side and uses `insert()`; updates use `saveIt()`.
- Leave ActiveJDBC-managed `created_at` and `updated_at` alone. Set only columns
  that exist, converting form strings to the required Java field types.
- Validate before writing, bind SQL values, and check record ownership before
  reading or changing private data. Routed actions commit on normal completion
  and roll back on exceptions; rendering an error does not itself undo writes.
- Leave `ctx.go_to` unset for the default view. Assign a renderer callable for
  another response, or a string for a redirect. Prefix application URLs with
  `ctx.ctxPath` in Python and `{{ctxPath}}` in views.
- Preserve the application's authentication, authorization, and CSRF checks.
  Neither login routes nor a current-user view variable are supplied by default.
  Use its existing security extension, or the bundled authentication example
  when implementing one.
- The reserved `default/filter` package uses servlet lifecycle methods, not
  `view(ctx)` or Handlebars views. Consult the filter reference before editing it.

## Load only the relevant references

| Task | Read |
| --- | --- |
| Controllers, routing, request context, or a complete feature | [Transactions](#reference-transactions) |
| Schema, IDs, queries, typed values, or migrations | [Models and SQL](#reference-models-and-sql) |
| Templates, helpers, forms, or shared layouts | [Views](#reference-views) |
| Login, sessions, permissions, CSRF, or the authorizer hook | [Application security](#reference-security) |
| HTTP errors, 403 overrides, lifecycle restrictions | [Error pages](#reference-errors) |
| Servlet filters, mappings, lifecycle, or development reloads | [Transaction filters](#reference-filters) |
| Multipart inputs, file storage, or BLOBs | [File upload](#reference-file-upload) |
| Rendering, logging, email, PDF, or date conversion | [Render and utilities](#reference-render-and-utils) |
| Outbound HTTP, AI endpoints, JSON requests, timeouts | [Outbound HTTP](#reference-outbound-http) |
| JSON, browser requests, fragments, or Excel | [Integrations](#reference-integrations) |
| Standalone startup, CLI synchronization, configuration, or Docker packaging | [Runtime and packaging](#reference-runtime) |

When installing the skill as a folder, copy `SKILL.md` and `references/`
together. Read the references relevant to your task. Validate changes using
the target runtime and application tests to exercise Java imports and runtime
behavior.

Copyright 2020-2026 Webgeaz Sdn Bhd. Licensed under Apache-2.0.

<a id="reference-errors"></a>

## Error page reference

The public runtime bundles four generic HTML error pages. They use
`/assets/sufia-errors/error.css`, include a context-aware home link, and never display
exception messages or stack traces. Responses use UTF-8 and `Cache-Control: no-store`.

| Error | Transaction override | Class | Conventional template |
| --- | --- | --- | --- |
| 403 (authorization or CSRF denial) | `default/errors/err403.py` | `Err403` | `errors/_err403/err403.html` |
| 404 (including missing resources and transactions) | `default/errors/err404.py` | `Err404` | `errors/_err404/err404.html` |
| Explicit `sendError(500)` | `default/errors/err500.py` | `Err500` | `errors/_err500/err500.html` |
| Uncaught exception (HTTP 500) | `default/errors/errexc.py` | `Errexc` | `errors/_errexc/errexc.html` |

Paths are relative to `WEB-INF/jython/`; template paths are relative to
its `default/` directory. Include `__init__.py` in `default/` and `default/errors/`
when creating the files manually. Each override is optional and discovered
independently. Default-app overrides handle application requests, including other
application names. Paths declared in `sufia.management.paths` and internal
`/_sufia` routes use the bundled pages. SUFIA-IDE configures its management paths
when installed.

403 support requires framework 0.1.9 or later. To customize access denied, use
group `errors`, code `err403` in the default app. `auth/error` customizes only
the built-in authentication flow and does not handle ordinary application 403s.
Call `ctx.getResponse().sendError(403)` to trigger error dispatch; setting the
status alone does not dispatch an error page.

### Conventional views

Create `default/errors/err404.py`:

```python
class Err404:
    def view(self, ctx):
        ctx.output['heading'] = 'This page is no longer available'
        ctx.output['home_url'] = ctx.getCtxPath() + '/'
```

Create `default/errors/_err404/err404.html`:

```html
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Page not found</title>
  <link rel="stylesheet" href="{{ctxPath}}/assets/sufia-errors/error.css">
</head>
<body>
  <main class="error-card">
    <h1>{{heading}}</h1>
    <p>Please return home to continue.</p>
    <a class="error-button" href="{{home_url}}">Go home</a>
  </main>
</body>
</html>
```

Only `view(ctx)` runs: no automatic database connection or transaction,
authentication check, application filter, routed action, or page-layout hook.
These overrides are exempt from an installed IDE authentication extension's action-policy audit, including in an
authenticated application. Do not add `ACCESS_POLICY` or inherit the application
layout. The four reserved default-app error transactions cannot be called as
ordinary `/t/errors/<code>` endpoints or used as application entry points.
`ctx.output` and `ctxPath` work as usual. Any database access explicitly added by
an override is its responsibility and may fail during an outage.

### Callable rendering

An explicit 500 override can reuse a named template. Create
`default/errors/err500.py`:

```python
from utils import render

class Err500:
    def view(self, ctx):
        ctx.output['heading'] = 'Please try again later'
        ctx.output['home_url'] = ctx.getCtxPath() + '/'
        ctx.go_to = render.as_view(ctx, 'err404', group='errors', code='err404')
```

This uses the complete template above. Any callable `ctx.go_to` is supported;
its returned text is written to the buffered response. It may instead write to
`ctx.getResponse()` and return `None`. A renderer setting status 200 does not
change the original 403, 404 or 500 status. Output is published as UTF-8 HTML; override
headers, cookies and content types are not published.

Redirects (including string `ctx.go_to`) and secondary `sendError` calls fail the
override. Output, including flushed output, is buffered and discarded on failure.
The failure is logged and the matching bundled page is used. If the bundled
page also fails, the runtime emits minimal generic HTML. Recursive dispatch is
rejected. A response already committed before error handling cannot be replaced.

### Explicit disclosure of error details

`ctx.getError()` returns `None` outside the dedicated error dispatch. During it,
it returns the captured original error map:

- `status`: original HTTP status (500 for exceptions).
- `kind`: `err403`, `err404`, `err500`, or `errexc`.
- `message`: servlet error message, possibly `None`.
- `request_uri`: original request URI, including the context path.
- `exception`: Java/Jython exception object, or `None`.
- `stack_trace`: preserved runtime Jython traceback followed by the Java stack
  when an exception exists; an empty string for responses without an exception.

The map is not automatically included in template data. To opt in, create
`default/errors/errexc.py`:

```python
from webgeaz.sufia.core import Application


def should_show_details(ctx):
    # Example policy: deliberately opt in only on a private development server.
    return (Application.getProperty('sufia.mode') == 'development'
            and Application.getProperty('errors.show_details') == 'true')


class Errexc:
    def view(self, ctx):
        error = ctx.getError()
        ctx.output['show_stack'] = should_show_details(ctx)
        if ctx.output['show_stack']:
            ctx.output['stack_trace'] = error['stack_trace']
```

Create `default/errors/_errexc/errexc.html`:

```html
<!doctype html>
<html lang="en">
<head><meta charset="utf-8"><title>Request failed</title></head>
<body>
  <h1>Something went wrong</h1>
  <a href="{{ctxPath}}/">Go home</a>
  {{#if show_stack}}<pre>{{stack_trace}}</pre>{{/if}}
</body>
</html>
```

Use escaped `{{stack_trace}}`, never triple braces. Exception messages may contain
user-controlled text. The disclosure policy belongs entirely to override code;
the runtime never enables it automatically, even in development.

### Configuration and rollout

Existing `error.page.<status>` settings replace the corresponding status mapping.
`error.page_exception` replaces the uncaught-exception mapping. Exception routing
is separate from explicit 500 routing; configure `error.page_exception` to replace
the exception page. Explicit configured pages retain their existing servlet
lifecycle; the dedicated lifecycle described above applies to the built-in route.

Publish these runtime files through the container release workflow supplied with
your SUFIA installation, then restart the runtime. Restart after changing error
mappings or production override code. In `sufia.mode=development`, overrides
reload on each error request, following transaction conventions. Bundled HTML is
read on each error. No migration is needed. Existing PDF rendering error handling
is unchanged.

<a id="reference-file-upload"></a>

## Multipart uploads and file storage

Use a POST form with `enctype="multipart/form-data"`, and apply the application's
authorization and CSRF checks. See [security](#reference-security) for the distinction
between raw servlet filters and engine-parsed multipart parameters.

For `<input type="file" name="document">`, the engine exposes:

| Parameter | Value |
| --- | --- |
| `document` | Request-scoped `UploadedFile` |
| `document_fn` | Client-supplied original filename |
| `document_ft` | Client-supplied MIME type |

Files are spooled to temporary disk and cleaned up after transaction execution,
including failures. Consume or persist them during the request. Do not keep an
upload object for background work. An upload with no filename or zero bytes is
false in a Python conditional.

### Store on disk

```python
from java.io import File
from java.util import UUID
from org.apache.commons.io import FilenameUtils
from utils import render

class Document(object):
    def upload(self, ctx):
        """POST"""
        request = ctx.getRequest()
        upload = request.getParameter("document")
        if not upload:
            ctx.go_to = render.as_string(ctx, "Choose a nonempty file", status=400)
            return
        if upload.getSize() > 5 * 1024 * 1024:
            ctx.go_to = render.as_string(ctx, "File is too large", status=413)
            return
        original_name = FilenameUtils.getName(upload.getFileName())
        if not original_name:
            raise ValueError("Invalid filename")
        # Replace with the application's configured private storage directory.
        directory = File("/tmp/sufia-document-example")
        if not directory.isDirectory() and not directory.mkdirs():
            raise IOError("Cannot create storage directory")
        stored_name = str(UUID.randomUUID())
        upload.writeTo(File(directory, stored_name))
        ctx.go_to = render.as_json(ctx, {"name": original_name})
```

This illustrates storage, not a complete authenticated upload service. Keep
private files outside static assets, validate allowed contents and sizes before
persisting, and retain a server-generated storage identifier with authorized
metadata. Filename and MIME type are untrusted metadata, not proof of contents.
Database rollback does not remove a file written to storage; design cleanup for
failed multi-step operations.

Use `getInputStream()` or `writeTo(File_or_path)` for large files. Close streams
you open. `getBytes()` loads the whole file into memory and is appropriate only
after a small size limit. `getSize()`, `getFileName()`, and `getContentType()`
provide metadata.

### Store a bounded BLOB

For an existing model whose schema includes `document`, `document_fn`, and
`document_ft`:

```python
if upload.getSize() > 1024 * 1024:
    raise ValueError("Database document is too large")
record.set("document", upload.getBytes())
record.set("document_fn", FilenameUtils.getName(upload.getFileName()))
record.set("document_ft", upload.getContentType())
```

Persist according to the table's ID strategy. Raw SQL must define all three
columns; see [models and SQL](#reference-models-and-sql). Serve private documents through
an authorized action with `render.as_blob` or `render.as_file`, not a public path.
For a JDBC `Blob`, convert bounded values with `blob.getBytes(1, int(blob.length()))`
before using the byte-array renderer.

### Limits and temporary storage

| Property | Meaning |
| --- | --- |
| `max.file.upload.size` | Per-file byte limit; distributed defaults set 50 MiB |
| `maxrequestuploadsize` | Total multipart request byte limit |
| `fileuploadtempdir` | Writable temporary spool directory |

The per-file legacy alias is `maxfileuploadsize`. Total-request and temporary
directory aliases `max.request.upload.size` and `file.upload.temp.dir` are also
accepted. Prefer the existing application's settings when choosing a spelling.
The default request limit is the file limit plus 1 MiB; the default spool path is
`${java.io.tmpdir}/soad-uploads`. The engine returns 413 for limit violations and
400 for malformed multipart content.

<a id="reference-filters"></a>

## Transaction filters

Place application transaction filters in
`webapp/WEB-INF/jython/default/filter/<code>.py`, with package `__init__.py` files.
The dispatcher discovers only `default/filter`, including when requests target
named applications. It invokes matching filters alphabetically by code.

A filter is a servlet lifecycle object rather than an MVC transaction. It needs
all three methods and the conventional capitalized class:

```python
class Request_logger(object):
    url_mapping = "/t/*"

    def filter_init(self, config):
        pass

    def do_filter(self, request, response, chain):
        chain.doFilter(request, response)

    def destroy(self):
        pass
```

Do not create `view(ctx)` or view templates for this contract. A missing lifecycle
method causes a warning and skips that filter. Import, construction, mapping,
initialization, request, and destruction errors propagate; missing-method
warnings must be investigated when a security filter is expected to run.

### Mapping and chaining

`url_mapping` defaults to `/*`. It can be one string or a list of strings.
Supported servlet patterns are:

| Pattern | Matches |
| --- | --- |
| `/*` | All eligible paths |
| `/health` | That exact path |
| `/t/api/*` | That prefix and its descendants |
| `*.json` | Paths with that suffix |

Matching uses the path relative to the servlet context, excluding the query.
Use `ManagementPaths.relativePath(request.getRequestURI(), request.getContextPath())`
for application path checks rather than arbitrary string-prefix comparisons.

Call `chain.doFilter(request, response)` exactly once to continue. Code before
it performs pre-processing; code after it performs post-processing. To deny or
complete a request, write the response and return without calling the chain.
Propagate downstream errors rather than hiding them in a blanket handler.

Declared `sufia.management.paths` and reserved framework internal paths bypass
application transaction filters. No management paths are configured by default.
Extensions on bypassed paths must authorize their own requests; see
[security](#reference-security).

### Shared state and reloads

Instances are shared between concurrent requests. Keep request/session identity
in local variables or request attributes, never on `self`. Make any intentionally
shared mutable state thread-safe. These are raw servlet objects; the framework
has not created a `WebContext` or opened a database transaction for the filter.

In development mode, the dispatcher hashes filter source files on requests.
Adding, changing, removing, or renaming a filter causes the filter set to reload;
replacement instances are initialized and old instances destroyed. Production
loads filters at startup, so restart or redeploy after changing them. Imported
helper-module changes are not part of the filter source signature; restart when
those dependencies change. Configuration changes also require a restart.

Use `filter_init` for initialization and `destroy` for releasing resources.
Choose narrow mappings when a check should apply only to certain endpoints.
The [simple authentication example](https://docs.sufia.my/framework/examples/simple-auth/)
demonstrates a session/CSRF gate.

### Lifecycle exemptions and restrictions

The four `default/errors/err403`, `err404`, `err500`, `errexc` transactions
are dedicated error handlers, never ordinary endpoints. Error dispatch bypasses
filters, authorization, database transactions and layouts. Filters also cannot
be invoked as ordinary `/t/filter/*` actions; they have no view or ACCESS_POLICY
and cannot be entry points. Filter dispatch additionally exempts declared
management paths and reserved framework paths. These exemptions are not grants
of access: the installed extension must secure its own management routes.

<a id="reference-integrations"></a>

## JSON, browser requests, and Excel

### JSON actions

Use an explicit payload and the existing application security checks:

```python
from utils import render

class Api(object):
    def view(self, ctx):
        ctx.page_layout = False
        ctx.go_to = render.as_json(ctx, {"status": "ok"})

    def echo(self, ctx):
        """POST"""
        payload = ctx.json()
        message = payload.get("message") if payload else None
        if not isinstance(message, basestring) or len(message) > 200:
            ctx.go_to = render.as_json(ctx, {"error": "Invalid message"}, status=400)
            return
        ctx.page_layout = False
        ctx.go_to = render.as_json(ctx, {"message": message})
```

For `api/api.py` these actions are `/t/api/api` and `/t/api/api/echo`. `ctx.json()`
parses JSON request bodies; it does not turn them into form parameters. The
application must define how API authentication and CSRF are supplied. A filter
expecting form fields will not automatically read a JSON token.

Convert authorized model results to maps for simple JSON responses:
`render.as_json(ctx, rows.toMaps())`. Use [models and SQL](#reference-models-and-sql) for
bound queries, pagination, and ownership constraints. Error payloads can set an
HTTP status with `status=`.

### Browser requests and fragments

Load any jQuery, htmx, DataTables, or other frontend dependencies through the
application's own asset setup. They are not supplied by the runtime. Reuse the
existing application conventions for browser requests and protected mutations.

For example, after including jQuery, a read action can populate a list:

```html
<button id="load" type="button">Load contacts</button>
<ul id="contacts"></ul>
<script>
  $("#load").on("click", function () {
    $.getJSON("{{ctxPath}}/t/example/api/contacts", function (rows) {
      $("#contacts").empty();
      rows.forEach(function (row) {
        $("<li>").text(row.name).appendTo("#contacts");
      });
    });
  });
</script>
```

Implement the corresponding `contacts` action before using that URL. Use text
insertion for untrusted values, not HTML concatenation. POST requests must carry
the token in the field/header expected by the application's security extension.

For htmx, return a fragment template rather than a full page, and set
`ctx.page_layout = False`. Use `render.as_view(ctx, "fragment")` for escaped
dynamic HTML or `as_string` for trusted literal markup. Protect `hx-post` just
like ordinary POST forms.

DataTables can enhance an existing table for modest datasets. For large datasets,
implement its server-side response shape in an authorized JSON action, with
bounded pagination and allowlisted sort expressions.

### Excel export

Apache POI is bundled. Build an `.xlsx` workbook with `XSSFWorkbook`, close
resources, and return its bytes with a filename:

```python
from java.io import ByteArrayOutputStream
from org.apache.poi.xssf.usermodel import XSSFWorkbook
from utils import render

class Report(object):
    def export(self, ctx):
        workbook = XSSFWorkbook()
        output = ByteArrayOutputStream()
        try:
            sheet = workbook.createSheet("Summary")
            sheet.createRow(0).createCell(0).setCellValue("Export ready")
            workbook.write(output)
            content = output.toByteArray()
        finally:
            workbook.close()
            output.close()
        ctx.page_layout = False
        ctx.go_to = render.as_blob(
            ctx, content,
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            "summary.xlsx", attachment=True)
```

Read uploaded workbooks from `upload.getInputStream()` and close both workbook
and stream. An `UploadedFile` is not a byte array. Bound input size and exported
row counts appropriately; the example builds the entire workbook in memory.
Apply the application's authorization to both imports and exports.

### Outbound HTTP and AI

Use the bundled [Jetty client reference](#reference-outbound-http) and its tested AI endpoint example.

<a id="reference-models-and-sql"></a>

## Models and SQL

### Schema determines persistence

Inspect the actual schema using available database access, existing migrations,
or schema supplied by the developer. Record table names, generated model names,
primary keys, field types, timestamps, and file columns before writing CRUD.
Use the configured database's SQL dialect. H2, MySQL, PostgreSQL, and SQL Server
drivers are bundled; their DDL and generated-ID syntax differ.

The runtime creates model classes at startup under `webapp/WEB-INF/classes/models`.
Do not author or publish generated `.class` files as application sources.
Restart after schema changes to regenerate models. For conventional lowercase
names, `contact` maps to `Contact`, `persons` to `Persons`, and `hr_employee` to
`Hr_employee`. The generator uppercases the first character and lowercases the
rest without singularizing; inspect generated names for unusual schemas.

Alias models when names overlap with transaction/base classes:

```python
from models import Contact as ContactModel

class Contact(object):
    def view(self, ctx):
        ctx.output["contacts"] = ContactModel.findAll()
```

### Queries and updates

```python
record = ContactModel.findById(record_id)
record = ContactModel.first("email = ?", email)
rows = ContactModel.where("name LIKE ?", "%" + search + "%")
rows = ContactModel.findAll().orderBy("name ASC").limit(20)
maps = rows.toMaps()
```

Use `Model.first(condition, ...)` for a single conditional result; a `LazyList`
returned by `where(...)` has no `.first()` method. `findById` accepts the request
ID string, so unnecessary integer conversion can break empty or UUID inputs.
An empty ID can mean create; a nonempty update ID that is absent must produce a
missing-record result rather than silently inserting a new record.

Bind values using `?`; allowlist table/column names and sort expressions. Retrieve
private records with the relevant ownership/tenant condition as well as their ID.
Set named fields explicitly rather than mass-assigning request parameters.

```python
record = ContactModel.first("id = ? AND owner_id = ?", record_id, owner_id)
if record is None:
    raise ValueError("Contact not found")
record.set("name", validated_name)
record.saveIt()
# For deletion after the same checks: record.delete()
```

`owner_id` comes from the application's verified identity, not a submitted form.
The example requires that both fields exist in the table.

### Primary keys

Preserve existing keys. For new schemas, prefer a single database-generated
`id` column unless another strategy is required; match foreign-key types to it.

| Strategy | Create | Update |
| --- | --- | --- |
| Database-generated ID | Do not set `id`; call `saveIt()` | Load, change fields, call `saveIt()` |
| Manual UUID/string ID | Generate server-side, set once, call `insert()` | Load, change fields, call `saveIt()` |

For example, this MySQL DDL uses the first strategy:

```sql
CREATE TABLE contact (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    created_date DATETIME,
    updated_date DATETIME
);
```

```python
record = ContactModel()
record.set("name", "Jane")
record.saveIt()
```

For a deliberately chosen `VARCHAR(36)` UUID primary key without auto-increment:

```python
from java.util import UUID

record = ContactModel()
record.set("id", str(UUID.randomUUID()))
record.set("name", "Jane")
record.insert()
```

Never use the submitted create-form ID as a new UUID. Do not mix database-generated
integer keys with UUID generation. Composite-key schemas need an explicit design
review against the model generator; do not assume ordinary single-ID CRUD applies.

### Field types and timestamps

Normal form parameters are strings. Validate accepted formats and ranges, then
convert values to the Java types required by the schema/driver:

```python
from java.lang import Integer, Long
from java.math import BigDecimal
from java.sql import Date, Time
from java.time import LocalDateTime

request = ctx.getRequest()
age = request.getParameter("age")
amount = request.getParameter("amount")
date = request.getParameter("start_date")
event_time = request.getParameter("event_time")
record.set("age", Integer.valueOf(age) if age else None)
record.set("amount", BigDecimal(amount) if amount else None)
record.set("start_date", Date.valueOf(date) if date else None)
record.set("event_time", LocalDateTime.parse(event_time) if event_time else None)
record.set("active", request.getParameter("active") == "on")
```

Reject missing required values instead of storing `None`. Signed BIGINT values
commonly use `Long`; use `BigInteger` where the column/driver requires it, such
as unsigned values outside the signed range. MySQL DATETIME commonly uses
`LocalDateTime`; verify other databases' JDBC mappings rather than assuming them.

Do not set ActiveJDBC-managed `created_at` or `updated_at`. For application-managed
timestamps, use columns such as `created_date` and `updated_date` if they exist;
set creation time once and update time on changes. There is no requirement to add
timestamp columns to every table.

### Schema changes and file columns

Deliver SQL in application-owned files. Packaging does not execute migrations.
The runtime's `bin/soad-sql DATASOURCE SQL_FILE` can execute simple SQL scripts
against configured connections; see [runtime](#reference-runtime). DDL may implicitly
commit, so application transaction rollback is not a schema rollback mechanism.

For a BLOB upload field, define the metadata columns explicitly in raw SQL:

```sql
CREATE TABLE employee_document (
    id INT PRIMARY KEY AUTO_INCREMENT,
    document BLOB,
    document_fn VARCHAR(255),
    document_ft VARCHAR(100)
);
```

Those companion columns are an application convention, not automatically created
by the database. Check existing columns before adding them. See
[file upload](#reference-file-upload) for request-scoped uploads and persistence.

For H2, configure `db.default.schema=PUBLIC` to restrict model generation to the
application schema rather than including system metadata tables.

<a id="reference-outbound-http"></a>

## Outbound HTTP and AI integrations with Jetty

### Bundled client and lifecycle

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

### JSON requests, headers, status and decoding

Create `client.POST(url)`, add headers with
`request.headers(lambda headers: headers.put("Accept", "application/json"))`,
and send `StringRequestContent("application/json", json.dumps(payload))` as its
body. Set the Authorization header on that request. The synchronous `send()`
returns a ContentResponse: check `getStatus()` before decoding
`unicode(response.getContentAsString())` with `json.loads`. Validate response
shape before using nested fields. The buffered synchronous API suits bounded
responses; use streaming for large downloads or SSE.

### Timeouts and failures

`setConnectTimeout(ms)` bounds establishing a connection; `setIdleTimeout(ms)`
bounds inactivity; `request.timeout(n, TimeUnit.MILLISECONDS)` bounds the entire
exchange. A total timeout can raise `java.util.concurrent.TimeoutException`;
transport failures can be wrapped in `ExecutionException`. Catch Java failures
alongside Python exceptions, release resources, and return recoverable feedback.
Check non-2xx responses explicitly: they are responses, not transport exceptions.
Do not print raw upstream bodies or exception messages containing configuration.
Disable redirects for credentialed calls; never trust user-submitted URLs.

### AI endpoint workflow

For a chat-completions-compatible service, configure the full URL, model and key
server-side. Send a JSON model and messages array with `stream: false`, then
extract `choices[0].message.content`. Other AI protocols have different request
and response shapes: consult their contract and keep the same HTTP lifecycle.
Protect the transaction and CSRF mutation with the installed application's
security extension. Render output with ordinary escaped Handlebars values.

API provenance: [Jetty 12 client guide](https://jetty.org/docs/jetty/12/programming-guide/client/http.html)
and [StringRequestContent](https://javadoc.jetty.org/jetty-12/org/eclipse/jetty/client/StringRequestContent.html).
The runnable example is verified against this repository's pinned Jetty version.

<a id="reference-render-and-utils"></a>

## Rendering, logging, and utilities

### Renderers

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

### Logging and errors

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

### Email

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

### PDF and dates

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

### Java libraries

Import Java classes directly. Bundled libraries include Gson, Guava, Apache POI,
JDBC drivers, Jakarta Mail, and the rendering libraries. Your installed release's
`lib/` and `third-party/ARTIFACTS.txt` list the available libraries and versions.
Additional application JARs belong in `webapp/WEB-INF/lib/`.

Useful imports include `com.google.common.io.ByteStreams` for stream copying and
`com.google.common.io.BaseEncoding` for Base64. Do not assume a library version
or Java API solely because an inherited example uses it.

<a id="reference-runtime"></a>

## Runtime, configuration, and packaging

### Use an installed SUFIA runtime

Install Java 21 and extract `sufia0-standalone-<version>.zip` or
`sufia0-standalone-<version>.tar.gz` into a writable directory. From that
directory, run `./start.sh` and open `http://127.0.0.1:8080/`. The package ships
the Hello application with a persistent H2 datasource. Edit
`webapp/WEB-INF/jython/default/site/home.py` and refresh `/t/site/home` to see your
change in development mode. Use `./start.sh 9090` if port 8080 is busy, inspect
`console.log` for startup errors, and stop with `./stop.sh`. Run `./bin/soad-run`
for a foreground process. The scripts run on Linux, macOS, and Windows via WSL.
See [Getting started](https://docs.sufia.my/framework/guide/).

### Application files

| Path | Purpose |
| --- | --- |
| `webapp/WEB-INF/jython/default/` | Application controllers and views |
| `webapp/WEB-INF/sufia-app.properties` | Welcome transaction |
| `webapp/WEB-INF/lib/` | Additional application Java libraries |
| `webapp/WEB-INF/extensions/` | Application extension modules, when registered |
| `webapp/WEB-INF/deploy/` | Application SQL scripts |
| `webapp/assets/` | Application public assets |
| `conf/sufia.properties` | Runtime and datasource settings |

Use the [hello example](https://docs.sufia.my/framework/examples/hello/) for a first transaction,
and [simple authentication](https://docs.sufia.my/framework/examples/simple-auth/) for
application-owned login and session checks. Preserve Python package files and
save controllers and templates at their matching paths.

Development mode reloads ordinary transactions and filter source changes.
Production requires restart or redeployment. Restart after changes to
configuration, database schema, or imported helper modules.

### Synchronize with SUFIA CLI

The `sufia` v2 CLI synchronizes transactions in a local editor workspace with a
server that exposes the SUFIA-IDE `/_studio` API. A standalone runtime runs
directly from its `webapp/` tree using the bundled `start.sh` and `bin/soad-*`
tools. Check `sufia --version` and use a CLI compatible with the server.

From the CLI workspace, set the development server with
`sufia config set server https://your-server.example`. Use `sufia login`,
`sufia list`, and `sufia pull site/home`. Edit `src/site/home/home.py` and
`src/site/home/_home/home.html`, then review with `sufia changed` or
`sufia compare --group site --code home`. `sufia push site/home` updates the
configured remote. If supported by the server, `sufia db show <table>` reads
schema metadata. Apply schema migrations through the application's database workflow.

For noninteractive login, use the environment pairs `SUFIA_API_KEY` and
`SUFIA_APP_ID`, or `SUFIA_LOGIN` and `SUFIA_PASSWORD`. TOTP can use `SUFIA_OTP`.
Email two-factor login needs an interactive terminal. Keep `.config.json`
private and let the CLI maintain `.sufia-checksums.json`.

`sufia deploy TARGET_FOLDER` copies local controllers and templates into the
runtime layout. For local testing, target a writable test copy of the app's
`webapp/WEB-INF/jython/default/`. Preserve its `__init__.py` files, assets,
configuration, and extensions. Verify with that app's runtime and datasource.

### Configuration and extensions

Both modes read `$SUFIA_HOME/conf/sufia.properties`. Precedence is application
`webapp/WEB-INF/extensions.properties` defaults, operator `conf/sufia.properties`,
environment overrides, then Java system-property overrides. Environment names
normally replace dots with underscores; existing property spellings containing
underscores are also supported.

Configure `db.<name>.url`, `driver_class`, `username`, `password`, and optionally
`schema`. Create tables before startup; the engine generates models then. Even
an application without model queries needs a datasource for transaction dispatch.
For H2 application tables, set `db.default.schema=PUBLIC` so model generation
does not include system metadata tables.

`max.form.content.size` (`max_form_content_size` in the environment) caps
URL-encoded form bodies in bytes. The default is 4194304 (4 MiB). Larger forms
return HTTP 400. Multipart uploads have their own [limits](#reference-file-upload).

For production over HTTPS use `sufia.mode=production` and
`session.cookie.secure=true`. Shared cookie defaults are HttpOnly and SameSite=LAX.
The runtime Dockerfile sets production mode and secure cookies through environment
overrides; datasource credentials come from deployment configuration.

Extensions register through `listener.*`, `servlet.*`, `filter.*`, `static.*`,
and `jython.extra_path`. Servlet/listener class names follow their file stems.
An application authorizer uses `sufia.transaction.authorizer=module:function`;
see [security](#reference-security). Generic extension registration does not install
authentication automatically.

`bin/soad-sql DATASOURCE SQL_FILE` executes simple SQL scripts through the
configured connection. It is not a migration ledger, and custom procedure
delimiter syntax is outside its executor contract. Stop file-backed H2 runtimes
before offline SQL operations unless shared access is explicitly configured.

### Package and deploy your application

The installed runtime provides `bin/soad-prepare APPLICATION_HOME NEW_OUTPUT`
for preparing an application source directory. Use a fresh output directory.
It copies supported application sources, assets, extension modules and libraries,
deployment SQL, and extension registration, and provides an application
Dockerfile. Apply your schema migrations separately.

Pass `BASE_IMAGE` explicitly with the runtime image and version for the target
deployment. A locally built image uses `sufia0-runtime:<version>`; the standard
registry path is `<registry>/sufia/runtime:<version>`. When building from a
prepared release directory:

```sh
cd /path/to/application-release
docker build --build-arg BASE_IMAGE=registry.example.com/sufia/runtime:VERSION \
  -t registry.example.com/apps/myapp:1.0 .
```

Supply datasource credentials and other secrets through deployment configuration.
Use production mode, HTTPS, secure cookies, persistent application data, and
reviewed database migrations. Confirm routes, forms, uploads, error responses,
authorization, and the public context path in the deployed application.

<a id="reference-security"></a>

## Application-owned security

The runtime supplies transactions, servlet filters, and an optional authorizer
hook. Applications supply account storage, credential verification, login/logout,
sessions, roles, record ownership checks, and CSRF enforcement. Inspect the actual
application security before changing protected behavior. A controller dictionary
alone does not install authentication or permissions.

The [simple authentication example](https://docs.sufia.my/framework/examples/simple-auth/)
contains a login transaction, a servlet filter, protected account actions, and
an extension module. It demonstrates one configured account and session-owned
data; persistent accounts and their lifecycle require application design.

### Requests, sessions, and forms

Identity must come from a verified server-side session or another configured
application mechanism. Check roles and record ownership before returning private
data or changing it. A submitted user ID or hidden record ID is not authorization.
There is no automatic `ctx.current_user` or `ctx.output["current_user"]`; populate
view data deliberately from the application's verified identity.

For browser applications:

- Validate credentials before storing identity; rotate the session ID and CSRF
  token after successful login, and invalidate the session on logout.
- Check a session-bound CSRF token on protected mutations, including login and
  logout where appropriate. Method docstrings and cookie SameSite settings do
  not replace this check.
- Escape user content in templates. Keep credentials and signing secrets out of
  application source, images, and rendered responses.
- Serve production traffic through HTTPS with secure, HttpOnly cookies. Add
  throttling and account controls appropriate to the authentication design.

```html
<form action="{{ctxPath}}/t/member/account/update" method="post">
  <input type="hidden" name="csrf_token" value="{{csrf_token}}">
  <input name="note" maxlength="200">
  <button type="submit">Save</button>
</form>
```

Here the controller must supply `csrf_token`, and the application filter/action
must verify it. An empty field does not provide protection.

After denying inside a transaction, stop execution and prevent default rendering:

```python
session = ctx.getRequest().getSession(False)
user = session.getAttribute("application.user") if session else None
if not user:
    ctx.getResponse().sendError(401)
    ctx.go_to = lambda: None
    return
```

Adapt the session attribute to the application's existing contract. This denial
does not roll back earlier writes; perform checks before mutation.

### Transaction authorizer

Configure an application-owned module through properties:

```properties
sufia.transaction.authorizer = application_security:authorize
jython.extra_path = webapp/WEB-INF/extensions
```

The runtime imports that function and calls `authorize(ctx, controller, action)`
before the routed controller action. Return exactly `True` or `False`; other
values, import failures, and exceptions fail the request. The action comes from
the URL, or defaults to `view` when omitted.

```python
def authorize(ctx, controller, action):
    session = ctx.getRequest().getSession(False)
    user = session.getAttribute("application.user") if session else None
    if not user:
        ctx.getResponse().sendError(401)
        ctx.go_to = lambda: None
        return False
    return True
```

This example requires identity for every routed action. An application needs
deliberate public login routes and any role/action rules its design calls for.
A `False` result must set a response through `ctx.go_to` or suppress rendering;
it must not leave the protected default template to render automatically.

### Filter and extension boundaries

Transaction filters can gate requests before controller dispatch. They receive
raw servlet objects, not a `WebContext`, and have no automatically opened
ActiveJDBC transaction; see [filters](#reference-filters). Request parameter parsing also
depends on that stage: a raw servlet filter does not receive the engine's
multipart upload wrapper. Design multipart CSRF verification deliberately,
for example with an application-supported request header.

Match the routes and static resources actually being protected. A filter mapped
only to `/t/*` does not protect every static mount. Keep private files outside
public assets and serve them through authorized actions.

`sufia.management.paths` excludes declared paths from transaction filters and
application error overrides; it grants no access. Such extensions must enforce
their own security. Validate return URLs with the framework's context-aware
`ManagementPaths` helper rather than accepting arbitrary redirect targets.

<a id="reference-transactions"></a>

## Transactions and request context

### Files, imports, and URLs

Application controllers live under `webapp/WEB-INF/jython/default/`. For example:

```text
default/
  __init__.py
  example/
    __init__.py
    contact.py
    _contact/
      contact.html
      form.html
```

`contact.py` defines `Contact`; `address_book.py` defines `Address_book`. The
runtime selects the class using Python's `code.capitalize()`, so use lowercase
filenames. `/t/example/contact` calls `view(ctx)`, and
`/t/example/contact/form` calls `form(ctx)`. Actions are selected only by the
URL; request parameters do not override the routed action.
Trailing path segments are application-owned parameters: for example,
`/t/example/contact/form/42` still calls `form(ctx)`. Controllers can read them
from the request URI and must validate and authorize the referenced resources.

Import another transaction with `from default.example.contact import Contact`.
Import framework utilities with `from utils import render`, and generated models
with `from models import Contact as ContactModel`. Use aliases to avoid replacing
a transaction/base class with a model of the same name.

Named applications use their configured application/datasource name instead of
`default`; inspect their configuration and URL prefix before extending them.

### A controller

This example assumes a `contact` table with a database-generated integer `id`
and a `name` column. Integrate the application's security and record ownership
checks before using it for private records; see [security](#reference-security).

```python
from models import Contact as ContactModel
from utils import render

class Contact(object):
    def view(self, ctx):
        ctx.output["contacts"] = ContactModel.findAll().orderBy("name ASC")
        # The default template is example/_contact/contact.html.

    def form(self, ctx):
        record_id = ctx.getRequest().getParameter("id")
        if record_id:
            record = ContactModel.findById(record_id)
            if record is None:
                raise ValueError("Contact not found")
            ctx.output["contact"] = record
        ctx.go_to = render.as_view(ctx, "form")

    def save(self, ctx):
        """POST"""
        request = ctx.getRequest()
        name = (request.getParameter("name") or "").strip()
        if not name or len(name) > 100:
            raise ValueError("Name must contain 1 to 100 characters")
        record_id = request.getParameter("id")
        if record_id:
            record = ContactModel.findById(record_id)
            if record is None:
                raise ValueError("Contact not found")
        else:
            record = ContactModel()
        record.set("name", name)
        record.saveIt()
        ctx.go_to = "%s/t/example/contact" % ctx.ctxPath
```

Keep internal methods private with `_`. The runtime recognizes action docstrings
beginning with `POST`, `PUT`, or `DELETE`; place the method marker first. Ordinary
HTML mutations use `"""POST"""`, including deletion forms.

### WebContext

| API | Meaning |
| --- | --- |
| `ctx.getRequest()` / `ctx.getResponse()` | Jakarta servlet request and response |
| `ctx.output` | Map exposed to the template |
| `ctx.go_to` | `None`: default view; string: redirect; callable: custom rendering |
| `ctx.ctxPath` / `ctx.getCtxPath()` | Servlet context path for links and redirects |
| `ctx.getAppName()`, `getGroup()`, `getCode()` | Current transaction identity |
| `ctx.getMethod()` | Uppercase HTTP method |
| `ctx.getParameter(name)` / `ctx.getHeader(name)` | Convenient request access |
| `ctx.json()` | Parse the request's JSON body into a map |
| `ctx.getRequest().getSession(False)` | Existing session without creating one |
| `ctx.page_layout` | Set `False` for a custom response that must bypass layouts |

The engine opens a datasource and database transaction around each routed
action, including actions that do not query models. Supply a datasource even for
a simple application. Do not open or commit another transaction around ordinary
controller CRUD. Exceptions roll back; a successful redirect still commits.

After writing directly to the servlet response, set `ctx.go_to = lambda: None`
to prevent automatic template rendering. This suppresses rendering, not commit:
validate before writes, and propagate exceptions when rollback is required.

### Building a complete feature

Start from the application's existing structure, UI conventions, schema, and
security. Deliver matching schema changes, controllers, views, assets, and
navigation. Store SQL in application-owned migration files or
`webapp/WEB-INF/deploy/`; schema execution is separate from source packaging.
Restart after schema changes so startup regenerates models.

Check create/update/delete behavior, missing-record handling, typed parameters,
escaping, actual authorization/ownership, and CSRF on mutations. Exercise routes
with the application's context path. State any unapplied schema changes or
unverified runtime dependencies rather than claiming the feature runs.

Start with the [hello example](https://docs.sufia.my/framework/examples/hello/)
and the [simple authentication example](https://docs.sufia.my/framework/examples/simple-auth/). Application
preparation and deployment are covered in [runtime and packaging](#reference-runtime).

<a id="reference-views"></a>

## Handlebars views and layouts

Views live in `<group>/_<code>/` and read `ctx.output`. The default
`_<code>/<code>.html` renders when `ctx.go_to` is unset. For an additional
template in the same directory use `ctx.go_to = render.as_view(ctx, "form")`.
The view argument selects the filename, not another transaction; use `group=`
and `code=` to select that transaction's directory.

Use complete HTML pages unless a shared layout or fragment response is intended.
Follow the application's styles and asset setup. Frontend libraries and styles
must be supplied by the application; the runtime does not bundle a UI toolkit.

```html
<!doctype html>
<html lang="en">
<head><meta charset="utf-8"><title>Contacts</title></head>
<body>
  {{#if contacts}}
    <ul>
      {{#each contacts}}
        <li>{{name}}
          <a href="{{../ctxPath}}/t/example/contact/form?id={{id}}">Edit</a>
        </li>
      {{/each}}
    </ul>
  {{else}}
    <p>No contacts yet.</p>
  {{/if}}
</body>
</html>
```

Ordinary `{{value}}` interpolation escapes text. Reserve unescaped interpolation
and `{{get ...}}` for trusted content. Prefix application links and form actions
with `{{ctxPath}}`; inside loops use the correct parent context, such as
`{{../ctxPath}}` and `{{../csrf_token}}`.

### Helpers

Standard helpers include `if`, `unless`, `each`, and `else`. The runtime registers
`eq`, `neq`, `gt`, `gte`, `lt`, `lte`, `and`, `or`, and `not`:

```html
{{#eq status "pending"}}Pending{{else}}Active{{/eq}}
{{#if (gt (size contacts) 0)}}Contacts available{{/if}}
```

| Helper | Example or behavior |
| --- | --- |
| `in` | `{{#in role allowed_roles}}Allowed{{else}}Denied{{/in}}` |
| `length`, `size` | `{{size items}}`; missing values return zero |
| `dateFmt` | `{{dateFmt created_date "yyyy-MM-dd"}}`; default `dd/MM/yyyy` |
| `ref_lookup` | `{{ref_lookup country_id table="countries" label="name" value="id"}}` |
| `select`, `option` | Table-backed dropdowns or controller-supplied `refs` |
| `html` | Escape text, render newlines, and link recognized URLs |
| `session` | Read an application session attribute |
| `get` | Read an output key as unescaped content; use only trusted values |
| `i18n` | `{{i18n "welcome.message"}}`, using a Java resource bundle |

There is no `if_eq`, `range`, or template method-call syntax such as
`{{items.size()}}`. Build ranges in the transaction and use the `size` helper.
Localized messages use `messages.properties` / locale variants available on the
classpath; the `__locale__` session attribute can select the locale.

```html
{{select refs=countries selected=country_id label="name" value="id" name="country_id"}}
```

For private dropdown data, prepare authorized `refs` in the controller rather
than letting a helper read the entire table. A helper's `filter` is SQL syntax,
not a place for unchecked request values. Use trusted literal identifiers and
labels in helper options.

Reference label values are text, including when `readonly=true` renders a select
as a paragraph. Single and composite labels are escaped once. `ref_lookup`
returns plain text for normal Handlebars interpolation; do not use triple braces
to display lower-trust labels. Labels previously used as raw HTML now display
literally.

### Shared layouts

A layout is an application transaction, for example `org/layout.py`:

```python
class Layout(object):
    def view(self, ctx):
        ctx.output["application_name"] = "Contacts"

    def page_layout(self, ctx):
        return ("org", "layout")
```

Its template `org/_layout/layout.html` uses the injected `{{title}}`,
`{{{head}}}`, and `{{{body}}}` values. These head/body values are framework-created
HTML fragments. A page controller inherits the layout:

```python
from default.org.layout import Layout

class Dashboard(Layout):
    def view(self, ctx):
        ctx.output["page_title"] = "Dashboard"
```

`page_layout` may return `(group, code)` or `(group, code, view)`. The engine
extracts title/head/body from the page HTML and renders the layout template.
Keep ordinary shared helpers private. Set `ctx.page_layout = False` when
returning JSON, files, or fragments from a controller that inherits a layout.

Mutation forms submit the application's CSRF token and use POST; see
[application security](#reference-security). A redirect message or a flash-session helper
is optional application behavior, not built-in runtime state.
