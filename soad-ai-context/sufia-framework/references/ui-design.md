# UI design for SUFIA applications

Read this reference when building or refreshing a SUFIA interface with a
local coding harness. Follow the application's existing design system and the
developer's brief. When the brief leaves visual direction open for an
internal business app, use the defaults below.

## Establish a shared layout

- Give the app one visual vocabulary. Use a neutral canvas, readable
  typography, one restrained accent, and consistent spacing and borders.
  Choose a type scale and build common styles for buttons, inputs, status
  labels, and feedback.
- Put navigation, the active route, account controls, and the stylesheet
  link in one shared page layout. Reflect the current user's access in
  navigation and preserve the controller's checks. Share the visual tokens
  with standalone sign-in and public pages. [Views and shared layouts](views.md)
- Give each page a clear heading and an obvious next action. Use dashboard
  metrics that answer a real question and derive from existing data. On data
  screens, keep filters, status, and row actions easy to find. Group related
  form fields and make empty, error, and success states actionable.
- Preserve route URLs, action policies, authentication, CSRF, ownership
  checks, and existing behavior when the task is a visual refresh.
  [Application security](security.md)

## Build and link a stylesheet

Reuse the app's existing CSS pipeline. For a new SUFIA CLI workspace, Tailwind
v4 is a practical default. `sufia css build` runs a compiler on the machine
running the harness. Set `SUFIA_TAILWIND_BIN` to the local Tailwind executable,
or use the executable at `$SUFIA_IDE_HOME/bin/tailwindcss` if installed.
[Tailwind standalone releases](https://github.com/tailwindlabs/tailwindcss/releases)

For a CLI workspace, put the source CSS in `app/styles/app.css` and scan
the transaction sources under `src/`. Keep utility class names complete
and literal in templates so Tailwind can discover them.

```css
@import "tailwindcss" source(none);
@source "../../src";

@theme {
  --color-accent-600: #1d4ed8;
  --color-accent-700: #1e40af;
}

@layer base {
  body { @apply bg-slate-50 text-slate-900 antialiased; }
  :focus-visible { @apply outline-2 outline-offset-2 outline-accent-600; }
}
```

Take the app code from `development.app_code` in `sufia context --json`. This
example uses the `default` app. Build to the app-owned asset directory, then
link the generated file from the shared layout and standalone entry screens.

```sh
sufia css build app/styles/app.css app/assets/default/app.css --json
```

```html
<link rel="stylesheet" href="{{ctxPath}}/assets/default/app.css">
```

For a standalone runtime, point the CSS source scanner at the application's
transactions under `webapp/WEB-INF/jython/` and build into `webapp/assets/`.
Use the corresponding URL in the layout. Rebuild after changing CSS or
classes in either workflow. [Runtime paths and packaging](runtime.md)

## Verify the result in a browser

For an IDE-backed workspace, validate the edited source and assets together.

```sh
sufia check --target dev --app-files --json
sufia push-all --app-files --dry-run --json
```

Use the application's local preview or the authorized development IDE. To
publish through the CLI when the task calls for it, use
`sufia push-all --app-files` so the changed views and compiled stylesheet
arrive together. The IDE requires superadmin access to write application assets.

Open representative pages at desktop and phone widths. Confirm in the
browser that the compiled stylesheet returns HTTP 200 and its styles are
applied. Check focus, readable contrast, table overflow, working row
actions, and an empty or validation state. Compare screenshots of a primary
workflow and a data screen against the design brief.
