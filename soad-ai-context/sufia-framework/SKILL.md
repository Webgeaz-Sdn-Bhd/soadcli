---
name: sufia-framework
description: >-
  Build, edit, and explain SUFIA applications in a standalone runtime or a local
  SUFIA CLI workspace. Covers Jython transactions, Handlebars views, ActiveJDBC
  models, application security, servlet filters, utilities, and deployment.
license: Apache-2.0
---

# SUFIA framework

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
[runtime reference](references/runtime.md) for synchronization and local testing.
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
| Controllers, routing, request context, or a complete feature | [Transactions](references/transactions.md) |
| Schema, IDs, queries, typed values, or migrations | [Models and SQL](references/models-and-sql.md) |
| Templates, helpers, forms, or shared layouts | [Views](references/views.md) |
| Login, sessions, permissions, CSRF, or the authorizer hook | [Application security](references/security.md) |
| HTTP errors, 403 overrides, lifecycle restrictions | [Error pages](references/errors.md) |
| Servlet filters, mappings, lifecycle, or development reloads | [Transaction filters](references/filters.md) |
| Multipart inputs, file storage, or BLOBs | [File upload](references/file-upload.md) |
| Rendering, logging, email, PDF, or date conversion | [Render and utilities](references/render-and-utils.md) |
| Outbound HTTP, AI endpoints, JSON requests, timeouts | [Outbound HTTP](references/outbound-http.md) |
| JSON, browser requests, fragments, or Excel | [Integrations](references/integrations.md) |
| Standalone startup, CLI synchronization, configuration, or Docker packaging | [Runtime and packaging](references/runtime.md) |

When installing the skill as a folder, copy `SKILL.md` and `references/`
together. Read the references relevant to your task. Validate changes using
the target runtime and application tests to exercise Java imports and runtime
behavior.

Copyright 2020-2026 Webgeaz Sdn Bhd. Licensed under Apache-2.0.
