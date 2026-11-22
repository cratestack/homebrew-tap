# homebrew-tap

Homebrew tap for [cratestack](https://github.com/cratestack) tools.

```bash
brew install cratestack/tap/corntchap-cli
```

(or `brew tap cratestack/tap` once, then `brew install corntchap-cli`). macOS (Apple silicon and Intel) and Linux (x86_64 and aarch64); the formula installs the prebuilt binary from the [corntchap releases](https://github.com/cratestack/corntchap/releases), nothing is compiled. Check it with `corntchap-cli --version`.

Windows users: see the [Scoop bucket](https://github.com/cratestack/scoop-bucket).

## How updates work

Nobody edits `Formula/corntchap-cli.rb` by hand. The `update` workflow runs hourly (and on demand: Actions, update, Run workflow, optionally with a tag) and:

1. asks GitHub for the latest release of `cratestack/corntchap`; no release yet means it exits quietly;
2. downloads that release's four `corntchap-cli-<platform>.tar.gz.sha256` files;
3. renders `scripts/formula.rb.tpl` through `scripts/render-formula.sh`, which refuses anything suspicious (below);
4. commits `corntchap-cli <version>` as `github-actions[bot]` only if the formula changed, then runs the install test against that commit.

`scripts/render-formula.sh` treats the release as untrusted input:

| Check | Effect |
| --- | --- |
| the tag must be exactly `vMAJOR.MINOR.PATCH` | anything else (quotes, `;`, pre-release suffixes, newlines) fails before it reaches the template |
| all four tarballs and `.sha256` files must be assets of the release | missing asset: fail, nothing is committed |
| each hash must be 64 lowercase hex characters and name its own tarball | fail |
| the release must not be older than the formula | exit 10, the formula is left alone (never a downgrade) |

Only the validated version and hashes are ever substituted into the template. Runs are serialised (`concurrency: update-formula`), the job uses only its own `GITHUB_TOKEN` (`contents: write`, scoped to this job), and actions are pinned to major versions.

`tests/render-formula.test.sh` runs the script against fake releases, one test per check; `tests/mutate.sh` removes each check in turn and fails if the tests still pass. Both run in the `test` workflow, together with `brew style` and, once the formula has real hashes, `brew audit --strict`, `brew install` and `brew test` on macOS and Linux.

## Before the first release

Until corntchap `v0.1.0` exists, the formula carries all-zero placeholder hashes (`sha256 "000…0"`) and installing it fails on purpose. The first `update` run after the release replaces them; the install test is skipped while they are present. The default branch must accept pushes from `github-actions[bot]` (no PR-only branch protection), otherwise the commit step fails.

## Layout

```
Formula/corntchap-cli.rb      generated
scripts/formula.rb.tpl        the template
scripts/render-formula.sh     release -> formula, with the checks above
tests/                        script tests + mutation check
.github/workflows/            update.yml (poll + commit), test.yml (style, install)
```

MIT licensed, see `LICENSE`.
