# Runtime, configuration, and packaging

## Use an installed SUFIA runtime

Install Java 21 and extract `sufia0-standalone-<version>.zip` or
`sufia0-standalone-<version>.tar.gz` into a writable directory. From that
directory, run `./start.sh` and open `http://127.0.0.1:8080/`. The package ships
the Hello application with a persistent H2 datasource. Edit
`webapp/WEB-INF/jython/default/site/home.py` and refresh `/t/site/home` to see your
change in development mode. Use `./start.sh 9090` if port 8080 is busy, inspect
`console.log` for startup errors, and stop with `./stop.sh`. Run `./bin/soad-run`
for a foreground process. The scripts run on Linux, macOS, and Windows via WSL.
See [Getting started](https://docs.sufia.my/framework/guide/).

## Application files

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

## Synchronize with SUFIA CLI

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

## Configuration and extensions

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
return HTTP 400. Multipart uploads have their own [limits](file-upload.md).

For production over HTTPS use `sufia.mode=production` and
`session.cookie.secure=true`. Shared cookie defaults are HttpOnly and SameSite=LAX.
The runtime Dockerfile sets production mode and secure cookies through environment
overrides; datasource credentials come from deployment configuration.

Extensions register through `listener.*`, `servlet.*`, `filter.*`, `static.*`,
and `jython.extra_path`. Servlet/listener class names follow their file stems.
An application authorizer uses `sufia.transaction.authorizer=module:function`;
see [security](security.md). Generic extension registration does not install
authentication automatically.

`bin/soad-sql DATASOURCE SQL_FILE` executes simple SQL scripts through the
configured connection. It is not a migration ledger, and custom procedure
delimiter syntax is outside its executor contract. Stop file-backed H2 runtimes
before offline SQL operations unless shared access is explicitly configured.

## Package and deploy your application

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
