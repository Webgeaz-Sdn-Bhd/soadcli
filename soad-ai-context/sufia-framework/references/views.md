# Handlebars views and layouts

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

## Helpers

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

## Shared layouts

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
[application security](security.md). A redirect message or a flash-session helper
is optional application behavior, not built-in runtime state.
