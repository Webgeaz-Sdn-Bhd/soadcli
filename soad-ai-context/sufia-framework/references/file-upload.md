# Multipart uploads and file storage

Use a POST form with `enctype="multipart/form-data"`, and apply the application's
authorization and CSRF checks. See [security](security.md) for the distinction
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

## Store on disk

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

## Store a bounded BLOB

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
columns; see [models and SQL](models-and-sql.md). Serve private documents through
an authorized action with `render.as_blob` or `render.as_file`, not a public path.
For a JDBC `Blob`, convert bounded values with `blob.getBytes(1, int(blob.length()))`
before using the byte-array renderer.

## Limits and temporary storage

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
