# Transaction filters

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

## Mapping and chaining

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
[security](security.md).

## Shared state and reloads

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

## Lifecycle exemptions and restrictions

The four `default/errors/err403`, `err404`, `err500`, `errexc` transactions
are dedicated error handlers, never ordinary endpoints. Error dispatch bypasses
filters, authorization, database transactions and layouts. Filters also cannot
be invoked as ordinary `/t/filter/*` actions; they have no view or ACCESS_POLICY
and cannot be entry points. Filter dispatch additionally exempts declared
management paths and reserved framework paths. These exemptions are not grants
of access: the installed extension must secure its own management routes.
