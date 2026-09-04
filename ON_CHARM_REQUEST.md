# STEPS

A self-contained sequence for generating a charm (and its evolved variant)
from a GitHub issue that describes a charm to be built. Each step is
numbered. Steps marked **[agent]** require an LLM agent; all others are
deterministic shell/script logic.

Inputs available to every step:
- `<issue-body>` — the full text of the triggering GitHub issue.
- `<issue-number>` — the number of the triggering issue (for commenting).
- `<repo-root>` — the root of the repository (contains `charms/`).
- `<repo-slug>` — the slug of the repository the workflow runs in
  (e.g. `canonical/infinicharms`).
- `<base-charm-repo>` — the repo slug of the base charm (e.g. `canonical/infinicharms-base`).

Conventions used throughout:
- `<PascalCaseName>` is derived from `<spec.name>` by splitting on hyphens,
  capitalising each part, and joining: `myblog` → `Myblog`, `my-blog` →
  `MyBlog`, `fastapi-demo` → `FastapiDemo`.

---

## 1. Parse the issue into a charm spec  **[agent]**

Run an agent against `<issue-body>` to extract a structured charm spec.

**Prompt:**
> You are given a GitHub issue body that describes a charm to be generated.
> Extract three things and return them as JSON:
> 1. `name` — the charm name (a single token, lowercase, hyphens allowed).
> 2. `purpose` — one or two sentences describing what the charm does.
> 3. `shape` — a structured object with keys:
>    - `containers`: list of `{name, resource}` (resource is `oci-image` when
>      the OCI image is specified at deploy-time).
>    - `requires`: list of `{name, interface}` relations the charm needs.
>    - `provides`: list of `{name, interface}` relations the charm offers
>      (optional).
>    - `config_options`: list of `{name, type, default, description}`.
>    - `actions`: list of `{name}` (optional).
> Return ONLY the JSON, no prose.

Parse the returned JSON. Fail the workflow immediately if:
- the JSON is invalid,
- `name` is missing or not a valid charm name (`^[a-z][a-z0-9-]*[a-z0-9]$`,
  no leading digit, no trailing hyphen, lowercase only),
- any required `shape` key is missing.

Store the parsed spec as `<spec>` for use by later steps.

## 2. Abort if the charm name is already taken

If a directory `<repo-root>/charms/<spec.name>/` already exists, stop. Comment
on the issue: "A charm named `<spec.name>` already exists; aborting." Exit the
workflow without creating anything.

## 3. Create the charm directory

```
mkdir -p <repo-root>/charms/<spec.name>
```

## 4. Write `purpose.md`

Write `<spec.purpose>` (followed by a newline) to
`<repo-root>/charms/<spec.name>/purpose.md`.

## 5. Fetch the latest base charm release

Determine the latest release tag of the base charm:

```
gh release view --repo <base-charm-repo> --json tagName -q .tagName
```

Download the source archive asset from that release to a temp directory and
extract it. GitHub auto-generates `Source code (zip)` and `Source code
(tar.gz)` assets for every release; download the tarball:

```
gh release download <base-version> --repo <base-charm-repo> --pattern "*.tar.gz" --dir /tmp/base-charm
```

If the release also publishes a custom source archive, prefer that asset
instead. Record:
- `<base-version>` — the release tag (e.g. `0.0.1`).
- `<base-sha>` — the target commit sha (from `gh release view ... --json targetCommitish -q .targetCommitish`), if available.

## 6. Copy the base charm source into the charm directory

Copy these paths from the extracted base charm into
`<repo-root>/charms/<spec.name>/`:
- `src/` (the whole directory)
- `charmcraft.yaml`
- `pyproject.toml`
- `uv.lock`

Do **not** copy build artifacts: `.tox/`, `.ruff_cache/`, `__pycache__/`,
`*.charm`, `*.egg-info/`.

**Precondition:** the base charm's holistic handler must be a valid instance
method, i.e. `def _run(self): ...` (not `def _run(): ...`). If the base charm
has a bare `_run()` with no `self`, treat it as a base-charm bug and fix it
in the copied `src/charm.py` before proceeding (add `self` as the first
parameter).

## 7. Write `base-version`

Write `<base-version>` (followed by a newline) to
`<repo-root>/charms/<spec.name>/base-version`. If `<base-sha>` is available,
append it as a second line.

## 8. Rewrite `charmcraft.yaml`, `pyproject.toml`, and observers  **[agent]**

Run an agent scoped to `<repo-root>/charms/<spec.name>/` to specialise the
copied base charm for the issue spec.

**Prompt:**
> You are updating a charm generated from a base charm template. The charm
> lives in `charms/<spec.name>/`. Using the issue shape below, do TWO things:
>
> 1. Rewrite `charmcraft.yaml`:
>    - Set `name` to the charm name, `title` to a human-readable title.
>    - Write a concise `summary` and `description` from the purpose.
>    - Add a `containers` block (one container per shape container, each with
>      `resource: oci-image`).
>    - Add a `resources` block with an `oci-image` resource of type `oci-image`.
>    - Add a `requires` block with one entry per shape relation (use the
>      interface from the shape; default to `postgresql_client` for postgres).
>    - Add a `provides` block with one entry per shape `provides` relation, if
>      any.
>    - Add a `config` block with `options` for each config option from the
>      shape.
>    - Add an `actions` block if the shape declares actions.
>    - Keep `base`, `platforms`, `assumes`, and `parts` from the base charm
>      unchanged.
>
> 2. Update `src/charm.py`:
>    - Rename the charm class to `<PascalCaseName>Charm`.
>    - Keep the existing `config_changed` observer and the holistic `_run`
>      method.
>    - Add one observer per relation event (`relation_joined`,
>      `relation_changed`, `relation_departed`) for each `requires` **and**
>      `provides` relation, each calling `self._run()`. Use the relation name
>      from the shape: `self.on["<name>"].relation_joined`.
>    - Add a `pebble_ready` observer for each container, calling `self._run()`.
>      Use the container name from the shape: `self.on.<container>.pebble_ready`.
>    - Add an observer for each action, calling `self._run()`.
>    - Update `ops.main(<ClassName>)` at the bottom.
>
> Also update the `name` field in `pyproject.toml` to match the charm name.
>
> Issue shape: <paste <spec> as JSON>

The agent must only modify files under `charms/<spec.name>/`.

## 9. Regenerate the lockfile

Renaming the project invalidates `uv.lock` (it still references the base
charm's project name). Regenerate it before packing, or `charmcraft pack`
will fail because its uv plugin runs with `--frozen`:

```
cd <repo-root>/charms/<spec.name> && uv lock
```

## 10. Format, lint, and pack the charm

Format and lint, then pack using the `pack-charm.sh` script (which removes
stale `.charm` files, runs `charmcraft pack`, and records the packed file
path as a step output):

```
cd <repo-root>/charms/<spec.name>
ruff format src/
ruff check src/ --fix
CHARM_DIR=<repo-root>/charms/<spec.name> \
ARTIFACT_NAME=<spec.name> \
  bash <repo-root>/.github/scripts/pack-charm.sh
```

Fail the workflow if any command returns non-zero. The packed `.charm` file(s)
will appear in `<repo-root>/charms/<spec.name>/`. The script sets
`charm_path` in `$GITHUB_OUTPUT` for downstream use.

## 11. Create the `_evolved` subdirectory and copy files

```
mkdir -p <repo-root>/charms/<spec.name>/_evolved
cp <repo-root>/charms/<spec.name>/charmcraft.yaml <repo-root>/charms/<spec.name>/_evolved/
cp -r <repo-root>/charms/<spec.name>/src <repo-root>/charms/<spec.name>/_evolved/
cp <repo-root>/charms/<spec.name>/pyproject.toml <repo-root>/charms/<spec.name>/_evolved/
cp <repo-root>/charms/<spec.name>/uv.lock <repo-root>/charms/<spec.name>/_evolved/
```

## 12. Evolve the charm  **[agent]**

Run an agent scoped to `<repo-root>/charms/<spec.name>/_evolved/` to produce
the evolved variant.

**Prompt:**
> You are evolving a charm in `charms/<spec.name>/_evolved/`. Do the
> following:
>
> 1. In `charmcraft.yaml`: change `name` to `<spec.name>-evolved` and `title`
>    accordingly. Leave all other fields (containers, resources, requires,
>    config, actions, platforms, parts) unchanged.
> 2. In `pyproject.toml`: change the project `name` to
>    `<spec.name>-evolved`.
> 3. In `src/charm.py`:
>    - Rename the charm class to `<PascalCaseName>EvolvedCharm`.
>    - Remove the holistic `_run` method entirely.
>    - For each observer method, replace the `self._run()` call with `pass`
>      (a no-op, for later implementation). Keep the method signature and
>      docstring.
>    - Update `ops.main(<ClassName>)` at the bottom.
>
> Do NOT implement any actual functionality. Each observer should be a no-op
> stub (`pass`) that can be filled in later.

The agent must only modify files under `charms/<spec.name>/_evolved/`.

## 13. Regenerate the evolved lockfile

```
cd <repo-root>/charms/<spec.name>/_evolved && uv lock
```

## 14. Format, lint, and pack the evolved charm

Format and lint, then pack using the `pack-charm.sh` script:

```
cd <repo-root>/charms/<spec.name>/_evolved
ruff format src/
ruff check src/ --fix
CHARM_DIR=<repo-root>/charms/<spec.name>/_evolved \
ARTIFACT_NAME=<spec.name>-evolved \
  bash <repo-root>/.github/scripts/pack-charm.sh
```

Fail the workflow if any command returns non-zero. The packed `.charm`
file(s) will appear in `<repo-root>/charms/<spec.name>/_evolved/`. The script
sets `charm_path` in `$GITHUB_OUTPUT` for downstream use.

## 15. Write the `version` file

Write `1` (followed by a newline) to
`<repo-root>/charms/<spec.name>/version`. This is the charm release version,
independent of the base charm version.

## 16. Commit the charm files

First, ensure packed `.charm` files and ruff caches are gitignored so they
are not committed. Append to `<repo-root>/.gitignore` (creating it if
absent):

```
charms/*/*.charm
charms/*/_evolved/*.charm
charms/*/.ruff_cache/
charms/*/_evolved/.ruff_cache/
```

Then stage and commit everything under `charms/<spec.name>/` (including
`_evolved/`) so the release points at a real tree:

```
cd <repo-root>
git add .gitignore charms/<spec.name>/
git commit -m "Add charm <spec.name> (and <spec.name>-evolved)"
```

Do not commit the packed `.charm` files — they are release artifacts, not
source.

## 17. Stage packed charms and create the GitHub release

The `publish-release.sh` script expects packed `.charm` files in
`dist/<spec.name>/` and `dist/<spec.name>-evolved/`. Copy them there first:

```
cd <repo-root>
mkdir -p dist/<spec.name> dist/<spec.name>-evolved
cp charms/<spec.name>/*.charm dist/<spec.name>/
cp charms/<spec.name>/_evolved/*.charm dist/<spec.name>-evolved/
```

Then create the release using `publish-release.sh` (which creates a release
tagged `<spec.name>-1`, attaches both `.charm` files, and targets the current
`HEAD` commit):

```
CHARM_NAME=<spec.name> \
CHARM_VERSION=1 \
GH_TOKEN=<github-token> \
  bash <repo-root>/.github/scripts/publish-release.sh
```

Only `.charm` files are attached — no source archives, no lockfiles, no other
artifacts. The script uses `git rev-parse HEAD` as the release target, so
step 16 (commit) must run first.

## 18. Comment on the issue

Comment on the triggering issue with a link to the release created in step 17
and a one-line summary, e.g.:

> Generated charm `<spec.name>` (and `<spec.name>-evolved`) and released as
> [`<spec.name>-1`](<release-url>).

---

## Conventions

- **Fail fast.** Any failed command (agent parse error, `test -d`, ruff,
  charmcraft, `gh`) should stop the workflow and, where useful, comment on the
  issue with the error.
- **Issue feedback.** Comment on the issue at key milestones: name taken
  (step 2), packing failure (steps 10/14), release created (step 18).
- **Agent scope.** Agentic steps (1, 8, 12) must only modify files under
  `charms/<spec.name>/` (or its `_evolved/` subdir). They must not touch
  anything outside the charm directory.
- **Lockfile.** Run `uv lock` after every project rename (steps 9 and 13),
  before `charmcraft pack`. The uv plugin inside charmcraft uses `--frozen`,
  so a stale lockfile causes a hard failure.
- **Stale artifacts.** `pack-charm.sh` runs `rm -f *.charm` before each
  `charmcraft pack` (steps 10 and 14) so old packs don't leak into the
  release.
- **Platforms.** `charmcraft pack` may emit one `.charm` per platform. The
  release script globs `*.charm` so all platforms are attached.
- **Git.** Commit the charm source (step 16) before creating the release so
  the release tag points at a real commit. `publish-release.sh` uses
  `git rev-parse HEAD` as the release target. Never commit `.charm` files.
- **Scripts.** `pack-charm.sh` and `publish-release.sh` live under
  `.github/scripts/`. `pack-charm.sh` takes `CHARM_DIR` and `ARTIFACT_NAME`
  env vars and outputs `charm_path` via `$GITHUB_OUTPUT`.
  `publish-release.sh` takes `CHARM_NAME`, `CHARM_VERSION`, and `GH_TOKEN`
  env vars and expects assets staged in `dist/<name>/` and
  `dist/<name>-evolved/`.
