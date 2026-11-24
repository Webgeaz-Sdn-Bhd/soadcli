# Application-owned security

The runtime supplies transactions, servlet filters, and an optional authorizer
hook. Applications supply account storage, credential verification, login/logout,
sessions, roles, record ownership checks, and CSRF enforcement. Inspect the actual
application security before changing protected behavior. A controller dictionary
alone does not install authentication or permissions.

The [simple authentication example](https://docs.sufia.my/framework/examples/simple-auth/)
contains a login transaction, a servlet filter, protected account actions, and
an extension module. It demonstrates one configured account and session-owned
data; persistent accounts and their lifecycle require application design.

## Requests, sessions, and forms

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

## Transaction authorizer

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

## Filter and extension boundaries

Transaction filters can gate requests before controller dispatch. They receive
raw servlet objects, not a `WebContext`, and have no automatically opened
ActiveJDBC transaction; see [filters](filters.md). Request parameter parsing also
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
