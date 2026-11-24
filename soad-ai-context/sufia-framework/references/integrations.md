# JSON, browser requests, and Excel

## JSON actions

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
`render.as_json(ctx, rows.toMaps())`. Use [models and SQL](models-and-sql.md) for
bound queries, pagination, and ownership constraints. Error payloads can set an
HTTP status with `status=`.

## Browser requests and fragments

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

## Excel export

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

## Outbound HTTP and AI

Use the bundled [Jetty client reference](outbound-http.md) and its tested AI endpoint example.
