# homebrew-tap

Homebrew tap for [cratestack](https://github.com/cratestack) tools.

```bash
brew install cratestack/tap/corntchap-cli
```

(or `brew tap cratestack/tap` once, then `brew install corntchap-cli`). macOS (Apple silicon and Intel) and Linux (x86_64 and aarch64); the formula installs the prebuilt binary from the [corntchap releases](https://github.com/cratestack/corntchap/releases), nothing is compiled. Check it with `corntchap-cli --version`.

Windows users: see the [Scoop bucket](https://github.com/cratestack/scoop-bucket).

## How updates work

Nobody edits `Formula/corntchap-cli.rb` by hand. The `update` workflow runs hourly (and on demand: Actions, update, Run workflow, optionally with a tag) on the default branch only, in three jobs:

1. **render**: checks that `cratestack/corntchap` exists and is public, asks GitHub for its latest release (no release yet means it exits quietly; an explicit tag that does not exist is an error), downloads the release's four `corntchap-cli-<platform>.tar.gz.sha256` files and runs `scripts/render-formula.sh`;
2. **test**: installs the rendered formula on real runners (the `test` workflow, macOS arm64 and Intel, Linux x86_64 and aarch64), before anything is pushed;
3. **publish**: only if the test passed, commits `corntchap-cli <version>` as `github-actions[bot]`, and only if the formula changed.

### What is and is not verified

This is **trust on first use** of a release. `scripts/render-formula.sh` checks:

| Check | Effect |
| --- | --- |
| the tag is exactly `vMAJOR.MINOR.PATCH` | anything else (quotes, `;`, pre-release suffixes, newlines) fails before it reaches the formula |
| every needed archive and `.sha256` is an asset of the release | missing asset: fail, nothing is committed |
| each `.sha256` is one line, `<64 lowercase hex>  <archive name>` | fail |
| that hash equals the `digest` GitHub computed for the archive asset | a `.sha256` that disagrees with the archive it names, or an asset without a digest: fail |
| a version already pinned with a real hash is never re-pinned to a different hash | a swapped asset under the same tag: fail, the file is untouched |
| the release is not older than the formula | exit 10, left alone (never a downgrade) |
| the formula's own current version can be read | fail (the two checks above cannot run) |

Only validated values are substituted into the formula. **What this does not catch:** a release that was already malicious when the workflow first saw it (the first release seen for a version is trusted), or a compromised `cratestack/corntchap` release pipeline. The renderer prints a note when a release is not immutable. GitHub's *immutable releases* would stop assets being swapped after publishing; as of this writing they are not enabled on `cratestack/corntchap` (repository Settings, General, Releases, "Enable release immutability", or an organisation policy; it applies to releases published afterwards, and the release job must then publish a draft that already holds its assets).

Runs are serialised (`concurrency`), jobs have least-privilege tokens (only `publish` can write contents, and only the job token is used), and every action is pinned to a full commit SHA.

## If the schedule stops

GitHub disables scheduled workflows in public repositories after 60 days without repository activity. The `keepalive` workflow re-enables `update.yml` (and itself) monthly, which resets that timer. If both still lapse (for example Actions was turned off), the formula simply stays at the last published version and nothing breaks; re-enable the workflows in the Actions tab, or run `update` by hand.

`tests/render-formula.test.sh` runs the script against fake releases, one test per check; `tests/mutate.sh` removes each check in turn and fails if the tests still pass. Both run in the `test` workflow.

## Before the first release

Until corntchap `v0.1.0` exists, the formula carries all-zero placeholder hashes (`sha256 "000…0"`) and installing it fails on purpose. The first `update` run after the release replaces them; the install test is skipped while they are present. The default branch must accept pushes from `github-actions[bot]` (no PR-only branch protection), otherwise the commit step fails.

## Layout

```
Formula/corntchap-cli.rb      generated
scripts/formula.rb.tpl        the template
scripts/render-formula.sh     release -> formula, with the checks above
tests/                        script tests + mutation check
.github/workflows/            update.yml (render, test, publish), test.yml (style, install), keepalive.yml
```

MIT licensed, see `LICENSE`.
