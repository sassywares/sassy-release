# sassy-release

Shared release script and project-skill template for Sassywares repos.

- `release.sh`: one bash script, vendored into each repo as `bin/release`. It bumps the
  patch version, commits, pushes and tags, idempotently.
- `skill/SKILL.md`: a template for the per-project skill that runs it (named
  `<project>-release`, for example `sassy-code-release`).
- `tests/run.sh`: self-contained harness; builds throwaway repos under a temp dir and never
  touches GitHub.

Requires bash, git, and node (only for `package.json` projects).

## Vendor it into a project

1. Copy `release.sh` to `bin/release` at the project root and `chmod +x bin/release`.
2. Copy `skill/SKILL.md` to `.agents/skills/<project>-release/SKILL.md` and replace
   `PROJECT` in the `name` and heading with the project name.
3. Optional: add `bin/release-ignore` (see below).
4. For sassy-ship, set the hook in `.sassywares/config.yaml`:

   ```yaml
   commit:
     branch: current
   hooks:
     push:
       "*":
         after_push: [<project>-release]
   ```

`bin/` is deliberately not `.sassywares/`: that folder is project-agnostic skill metadata.

## Behaviour

- **Version source**: `package.json` `version` if present (needs node, re-serialized with
  its detected indent), else a `VERSION` file. Format `X.Y.Z`, no leading zeros.
- **Dirty tree**: refused; the work commit must already exist.
- **On `main`**: fetches tags, then compares against the highest `v*` tag **on origin**
  (the script's own version compare, not git's sort). A stale local tag origin lacks never
  counts; a local tag that differs from origin's dies; a local-only tag at HEAD is pushed.
  If consumer-facing files changed since the highest tag, it bumps the patch, commits
  `chore: release v<version>`, pushes `main`, creates an annotated tag and pushes only that
  tag. A version already bumped by hand (minor/major, first release) but untagged is
  tagged as-is.
- **Other branches**: push only, never tag.
- **Ordering**: the version must be >= the highest tag; if equal, that tag must be an
  ancestor of HEAD.
- **Prereleases** (`1.0.0-beta.1`): tagged as-is when untagged, never auto-bumped; if
  already tagged and consumer files changed, it dies and asks for a hand bump.
- **Recovery**: every step is idempotent. After any failure (rejected push, tag push
  declined, failed commit hook) fix the cause and rerun. A failed bump commit restores the
  tree. Never force-pushes, never bypasses hooks or signing.

## Ignore list

`bin/release-ignore` holds one entry per line with `#` comments. Entries are root-anchored
path prefixes (`docs/` or `docs`) and bash globs (`*.md`; `*` may cross `/`). `!` and `**`
are errors. A custom file **replaces** the defaults, so re-list what you still want:

`AGENTS.md docs/ tests/ .sassywares/ .github/ .agents/ .claude/ scripts/ bin/release bin/release-ignore`

The rest of `bin/` counts as consumer-facing.

## Updating vendored copies

The script's first lines read `# sassy-release vN`. When this repo's latest tag has a higher
N, replace `bin/release` with `release.sh` (keep it executable) and refresh the skill from
`skill/SKILL.md`, keeping the project name. Do this on request, never during a hook run.

## Tests

```bash
bash tests/run.sh
```
