# Models and SQL

## Schema determines persistence

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

## Queries and updates

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

## Primary keys

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

## Field types and timestamps

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

## Schema changes and file columns

Deliver SQL in application-owned files. Packaging does not execute migrations.
The runtime's `bin/soad-sql DATASOURCE SQL_FILE` can execute simple SQL scripts
against configured connections; see [runtime](runtime.md). DDL may implicitly
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
[file upload](file-upload.md) for request-scoped uploads and persistence.

For H2, configure `db.default.schema=PUBLIC` to restrict model generation to the
application schema rather than including system metadata tables.
