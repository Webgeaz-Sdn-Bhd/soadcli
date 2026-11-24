# Transactions and request context

## Files, imports, and URLs

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

## A controller

This example assumes a `contact` table with a database-generated integer `id`
and a `name` column. Integrate the application's security and record ownership
checks before using it for private records; see [security](security.md).

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

## WebContext

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

## Building a complete feature

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
preparation and deployment are covered in [runtime and packaging](runtime.md).
