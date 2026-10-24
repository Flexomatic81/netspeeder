<!--
SPDX-License-Identifier: GPL-2.0-or-later
SPDX-FileCopyrightText: 2026 Flexomatic81
-->

# Contributing to Netspeeder

Thanks for wanting to help! Bug reports, translations and pull requests are all welcome.

For anything bigger than a small fix, please open an issue first, so that we can agree on the
approach before you spend time on it.

## Branches

- `main` is the released state.
- `dev` is where development happens. **Please open pull requests against `dev`.**

Please don't change the version or `CHANGELOG.md` in a pull request; both are updated when a
release is made.

## Setting up

You need KDE Plasma 6, Node.js 22.13 or newer (or 24) and [pnpm](https://pnpm.io/). Translations
need gettext.

```bash
git clone https://github.com/Flexomatic81/netspeeder.git
cd netspeeder
git switch dev
pnpm install --frozen-lockfile
scripts/dev-install.sh                 # installs the widget from your checkout
plasmawindowed io.github.flexomatic81.netspeeder
```

After changing QML files, run `scripts/dev-install.sh` again and restart `plasmawindowed` (or
Plasma) to see the result.

## Checks

CI runs all of these checks except the local-only `smoke` and `load` steps for every pull request,
and they must pass. One command runs the checks locally:

```bash
node tools/check.mjs                    # everything: ESLint, Prettier, tests, qmllint, shellcheck, smoke, load
node tools/check.mjs fast               # the Node checks: ESLint, Prettier and the tests with their coverage floor
node tools/check.mjs qmllint            # a single step
node tools/check.mjs --install-hook     # run the fast checks before every commit
```

`qmllint` (Qt 6), the QML smoke scenes and the load check need Qt 6's QML tools and a desktop
session; without them these steps are reported as skipped locally. `shellcheck` runs in the version
pinned in `tools/requirements-dev.txt` through [uv](https://docs.astral.sh/uv/), or from your
`PATH` after `python3 -m pip install -r tools/requirements-dev.txt`.

The unit tests have a coverage floor; please add tests for new behaviour and for bug fixes. Code is
formatted with Prettier (`pnpm exec prettier --write .`).

## Ground rules

- **Logic modules:** the `.mjs` files under `package/contents/code/` are imported by the QML engine
  and by Node, so they use no Node modules and no `i18n` calls.
- **QML:** `qmllint` must report nothing. If a name exists only at Plasma runtime, silence that one
  line with a `// qmllint disable <category>` comment at the end of the line and say why in a
  comment above it.
- **Language:** code, comments, docs and commit messages are in English.

## Translations

User-facing texts go through the `tr`, `trc` and `trp` wrappers. After changing texts, run
`scripts/Messages.sh` and translate the new entries in every `po/<language>/*.po`. How to add a new
language is described in the [README](README.md#translating).

## Commit messages

One sentence in the imperative that says what the change does, without a prefix, for example
"Skip a refresh while the previous one is still running". Use the body to explain why, if that is
not obvious.

## License

By contributing, you agree that your contributions are licensed under the
[GPL-2.0-or-later](LICENSE).
