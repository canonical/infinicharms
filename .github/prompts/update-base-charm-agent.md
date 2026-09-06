# Base charm update agent

You are working inside a checkout of this repository, on the branch the
workflow is running against. Your job is to update the charm
`${CHARM_NAME}` so its copy of the base charm template incorporates the
changes made upstream in `canonical/infinicharms-base`, while preserving
every charm-specific customization that was layered on top of that template
when this charm was originally generated (its shape, its config/actions,
and its independent `_evolved` implementation).

You have full `bash`, `read`, `edit`, `grep`, and `glob` access for this
task, and are running non-interactively -- do not ask the user questions,
make the best judgment call you can and proceed.

## Useful environment variables (already exported in your shell)

- `CHARM_NAME` - the charm name, e.g. `mycharm`
- `CHARM_DIR` - `charms/${CHARM_NAME}` (the base-derived charm)
- `EVOLVED_DIR` - `charms/${CHARM_NAME}/_evolved` (the independent evolved charm)
- `OLD_BASE_VERSION` / `OLD_BASE_SHA` - the version and commit currently
  recorded in `${CHARM_DIR}/base-version`
- `NEW_BASE_VERSION` / `NEW_BASE_SHA` - the version and commit you should
  update `${CHARM_DIR}/base-version` to
- `OLD_BASE_DIR` - a full checkout of `canonical/infinicharms-base` at
  `OLD_BASE_SHA`
- `NEW_BASE_DIR` - a full checkout of `canonical/infinicharms-base` at
  `NEW_BASE_SHA`
- `DIFF_FILE` - a unified diff (`git diff OLD_BASE_SHA NEW_BASE_SHA`)
  restricted to the files a charm actually copies from the base template
  (`src/`, `charmcraft.yaml`, `pyproject.toml`, `uv.lock`, `tox.ini`,
  `SOUL.md`, `prompts/`, `tests/`)

## Step 1: Understand what changed upstream

```
cat "$DIFF_FILE"
```

This shows what changed in the base charm template between the version
this charm was built from and the version you're updating to. If anything
is unclear from the diff alone (e.g. you need to see a whole new helper
function, or how a file looked before it was restructured or renamed),
read the full files under `$OLD_BASE_DIR` and `$NEW_BASE_DIR` directly.

## Step 2: Understand this charm's own customizations

Read, in this order:

- `${CHARM_DIR}/purpose.md` - why this charm exists / what it's meant to do
- `${CHARM_DIR}/charmcraft.yaml`, diffed conceptually against
  `$OLD_BASE_DIR/charmcraft.yaml` - this tells you exactly which blocks were
  added or changed for this charm's shape (name, title, summary,
  description, containers, resources, requires, provides, extra config
  options, extra actions) versus what came verbatim from the base
- `${CHARM_DIR}/src/charm.py`, compared the same way against
  `$OLD_BASE_DIR/src/charm.py` - the renamed class/docstring, and any extra
  observers wired up for this charm's own relations/containers/actions,
  versus base logic that was left untouched
- `${CHARM_DIR}/pyproject.toml`
- All of `${EVOLVED_DIR}` - its own `charmcraft.yaml` (name/title tweaked,
  the `soul-and-prompts` part removed) and its own `src/charm.py`. This is a
  fully independent, hand-written implementation that does **not** inherit
  logic from the base charm -- treat it separately, per Step 4.

## Step 3: Apply the upstream base changes to `${CHARM_DIR}`

For each change you found in Step 1, apply the equivalent change here,
adapting it to fit this charm's customizations rather than blindly
overwriting anything:

- Shared plumbing -- helper functions/methods, dependency bumps in
  `pyproject.toml`, the `base`/`platforms`/`assumes`/`parts` blocks in
  `charmcraft.yaml`, `tox.ini`, `SOUL.md`, `prompts/`, `tests/`, and so on --
  carry these changes over faithfully.
- If upstream changed a method in `charm.py` that this charm's rewrite step
  left untouched, apply the same edit here verbatim.
- If upstream changed a method that this charm's rewrite step already
  modified (e.g. renamed, extended with extra observers), merge the
  upstream change into the modified version so both the upstream fix/logic
  *and* this charm's specialization survive.
- If upstream changed a shared `charmcraft.yaml` field that's common to
  every charm (e.g. `base`, `platforms`, `assumes`, a `parts` entry, or a
  config option/action that exists in the base template), adopt the new
  value or definition as-is.
- Never remove or revert this charm's own additions: its name, title,
  summary, description, containers, resources, requires, provides, extra
  config options, extra actions, or the specialization in `charm.py` (class
  name, docstring, extra observers).
- If the base template renamed or restructured files, mirror that
  restructuring here too, while preserving this charm's own content in the
  moved/renamed files.
- If upstream made no relevant change to a file, leave that file alone.

## Step 4: Update `${EVOLVED_DIR}` only if the base's *shape* changed

`${EVOLVED_DIR}` does not share code with the base charm and must not
receive the base's logic changes. Only touch it if Step 3 added, removed,
or renamed a relation, container, config option, or action in
`${CHARM_DIR}/charmcraft.yaml` (i.e. a shape change coming from upstream).
In that case, mirror the same shape change into
`${EVOLVED_DIR}/charmcraft.yaml` and add a matching no-op stub observer in
`${EVOLVED_DIR}/src/charm.py` (just `pass` in the handler body), exactly
like the original evolve step would have produced. Leave everything else in
`${EVOLVED_DIR}` alone.

## Step 5: Record the new base version

Overwrite `${CHARM_DIR}/base-version` with exactly:

```
${NEW_BASE_VERSION}
${NEW_BASE_SHA}
```

Do not touch `${CHARM_DIR}/version` -- that's bumped automatically by the
release workflow once this change is released.

## Step 6: Regenerate lockfiles and lint

For `${CHARM_DIR}`, and for `${EVOLVED_DIR}` too if you changed anything in
it in Step 4:

```
(cd <dir> && uv lock)
(cd <dir> && ruff format src/ && ruff check src/ --fix)
```

## Step 7: Verify both charms still pack

Use the repo's own packing helper (it wipes any stale `.charm` file first):

```
CHARM_DIR="${CHARM_DIR}" ARTIFACT_NAME="${CHARM_NAME}" bash .github/scripts/pack-charm.sh
CHARM_DIR="${EVOLVED_DIR}" ARTIFACT_NAME="${CHARM_NAME}-evolved" bash .github/scripts/pack-charm.sh
```

Fix any errors these surface before finishing. Once both pack cleanly,
remove the produced `.charm` files (`rm -f ${CHARM_DIR}/*.charm
${EVOLVED_DIR}/*.charm`) -- they're gitignored, but there's no need to
leave them lying around.

## You're done once both charms pack cleanly

Do **not** run `git add`, `git commit`, `git push`, or open a PR yourself.
The workflow takes over after you finish: it checks that you only touched
files under `${CHARM_DIR}/`, and if so, commits and pushes your changes
directly. If you can't get both charms packing cleanly, leave the working
tree as-is and explain what's blocking you in your final response -- the
workflow will fail that step and nothing will be pushed.

## Things you must not do

- Don't touch other charms under `charms/`.
- Don't bump `${CHARM_DIR}/version`.
- Don't rewrite parts of `${CHARM_DIR}` or `${EVOLVED_DIR}` that the
  upstream diff didn't touch and that aren't required by a shape change.
- Don't copy base charm logic into `${EVOLVED_DIR}` beyond the stub shape
  mirroring described in Step 4.
- Don't run `git commit`, `git push`, or any `gh` command.
