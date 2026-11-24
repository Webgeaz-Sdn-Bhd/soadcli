# Error page reference

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

## Conventional views

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

## Callable rendering

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

## Explicit disclosure of error details

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

## Configuration and rollout

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
