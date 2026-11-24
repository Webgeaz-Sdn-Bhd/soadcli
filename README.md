# SUFIA CLI

Use `sufia` to edit transactions in a local editor and synchronize them with a
SUFIA-IDE server. The CLI works with a configured IDE application. For a
standalone framework installation, use its bundled runtime tools.

## Install

On Linux or macOS, download and run the installer, then check the version.

```sh
curl -fLO https://raw.githubusercontent.com/Webgeaz-Sdn-Bhd/soadcli/main/install.sh
bash install.sh
sufia --version
```

To install manually, download a matching `sufia_<os>_<arch>.tar.gz` from
[GitHub Releases](https://github.com/Webgeaz-Sdn-Bhd/soadcli/releases), extract
it, and add `sufia` (or `sufia.exe` on Windows) to your PATH.

## Work in a local editor

From the directory where you want to keep the application workspace:

```sh
sufia config set server https://your-server.example
sufia login
sufia list
sufia pull site/home
```

Use a transaction listed for your application in place of `site/home`. Edit
`src/<group>/<code>/<code>.py` and the templates under
`src/<group>/<code>/_<code>/`. Review edits with `sufia changed` and use
`sufia push <group>/<code>` when you're ready to update the server.

## Use an external coding assistant

- For an assistant that accepts a single attachment, download
  [SUFIA_FRAMEWORK_AI_CONTEXT.md](soad-ai-context/SUFIA_FRAMEWORK_AI_CONTEXT.md).
  It covers framework 0.1.12, standalone development, and the SUFIA CLI v2 workflow.
- For an assistant that supports skills, copy the complete
  [sufia-framework folder](soad-ai-context/sufia-framework/) using its skill
  installation method. Keep `SKILL.md` and `references/` together.

The CLI installer installs the executable. Download the guidance above separately.
The skill and single-file context come from the
[SUFIA framework documentation](https://docs.sufia.my/framework/).

## Upgrading from SØAD CLI v1

SUFIA CLI v2 connects to SUFIA servers. For an existing workspace, rename
`.soad-checksums.json` to `.sufia-checksums.json` if the new file does not already
exist. Update any scripts to use the `sufia` command and `SUFIA_*` environment
variables.

The [SØAD v1 skill](soad-ai-context/soad-framework/) and
[legacy web IDE context](soad-ai-context/SOAD-context-coding-web.md) remain
available for older installations.
