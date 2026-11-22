#!/usr/bin/env bash
# Tests for scripts/render-formula.sh against fake releases (no network). Run: tests/render-formula.test.sh
# One test per guard (each `# GUARD:<name>` line in the script); RENDER overrides the script under test.
set -uo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
RENDER=${RENDER:-$root/scripts/render-formula.sh}
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
fails=0 n=0
PLATFORMS="darwin-arm64 darwin-x86_64 linux-aarch64 linux-x86_64"

hex() { printf '%064x' "$1"; }

# mk_release DIR TAG: a complete, valid release (release.json + shas/) in DIR
mk_release() {
  local d=$1 tag=$2 i=1 p
  mkdir -p "$d/shas"
  local assets=''
  for p in $PLATFORMS; do
    printf '%s  corntchap-cli-%s.tar.gz\n' "$(hex $i)" "$p" > "$d/shas/corntchap-cli-$p.tar.gz.sha256"
    assets="$assets{\"name\":\"corntchap-cli-$p.tar.gz\",\"digest\":\"sha256:$(hex $i)\"},{\"name\":\"corntchap-cli-$p.tar.gz.sha256\"},"
    i=$((i + 1))
  done
  jq -n --arg t "$tag" --argjson a "[${assets%,},{\"name\":\"install.sh\"}]" '{tagName:$t,assets:$a}' > "$d/release.json"
}

# seed_formula FILE VERSION: a formula (rendered by the script itself) at VERSION
seed_formula() {
  local d="$work/seed-$2"
  rm -rf "$d"; mk_release "$d" "v$2"
  "$RENDER" "$d/release.json" "$d/shas" "$1" > /dev/null 2>&1
}

check() { # check NAME CONDITION-STATUS [detail]
  n=$((n + 1))
  if [ "$2" = 0 ]; then echo "ok   $1"; else echo "FAIL $1 ${3:-}"; fails=$((fails + 1)); fi
}

# expect_refusal NAME EXPECTED_RC MESSAGE_FRAGMENT DIR: run on DIR with a seeded 0.1.0 formula; the formula must not change
expect_refusal() {
  local name=$1 want=$2 frag=$3 d=$4 f=${5:-"$work/formula-$((n + 1)).rb"} before err rc
  [ -n "${5:-}" ] || seed_formula "$f" 0.1.0
  before=$(cksum < "$f")
  err=$("$RENDER" "$d/release.json" "$d/shas" "$f" 2>&1 > /dev/null); rc=$?
  [ "$rc" = "$want" ] && [[ $err == *"$frag"* ]] && [ "$(cksum < "$f")" = "$before" ]
  check "$name" $? "(rc=$rc, want $want; stderr: $err)"
}

# ---- renders ----
d=$work/ok; mk_release "$d" v0.2.0
f=$work/formula.rb; seed_formula "$f" 0.1.0
"$RENDER" "$d/release.json" "$d/shas" "$f" > "$work/out" 2>&1
check "renders a newer release (0.1.0 -> 0.2.0)" $? "$(cat "$work/out")"
grep -q 'download/v0.2.0/corntchap-cli-darwin-arm64.tar.gz"' "$f" && grep -q "$(hex 1)" "$f" && grep -q "$(hex 4)" "$f" && ! grep -q '@[A-Z_]*@' "$f"
check "formula carries version and all four hashes" $?
[ "$(grep -c 'url "' "$f")" = 4 ] && [ "$(grep -c "download/v0.2.0/" "$f")" = 4 ]
check "four urls, all at v0.2.0" $?
if command -v ruby > /dev/null; then ruby -c "$f" > /dev/null 2>&1; check "rendered formula is valid ruby" $?; fi
before=$(cksum < "$f")
"$RENDER" "$d/release.json" "$d/shas" "$f" 2>&1 | grep -q 'already at 0.2.0'
check "second run is a no-op" $?
[ "$(cksum < "$f")" = "$before" ]; check "second run leaves the file byte-identical" $?

# the committed placeholder formula (0.1.0) is replaced by a 0.1.0 release (same version is not a downgrade)
d=$work/first; mk_release "$d" v0.1.0
f=$work/placeholder.rb; cp "$root/Formula/corntchap-cli.rb" "$f"
grep -qE 'sha256 "0{64}"' "$f" && "$RENDER" "$d/release.json" "$d/shas" "$f" > /dev/null 2>&1 && ! grep -qE 'sha256 "0{64}"' "$f"
check "first release replaces the committed placeholders" $?

# ---- guards ----
# GUARD:tag
d=$work/evil; mk_release "$d" 'v1.0.0"; system("id")#'
expect_refusal "tag: shell/ruby injection is refused" 1 "refusing tag" "$d"
d=$work/evil2; mk_release "$d" 'v1.0.0-rc1'
expect_refusal "tag: pre-release suffix is refused" 1 "refusing tag" "$d"
d=$work/evil3; mk_release "$d" $'v1.0.0\nv9.9.9'
expect_refusal "tag: trailing newline is refused" 1 "refusing tag" "$d"
# GUARD:tag-anchors
d=$work/evil4; mk_release "$d" 'evilv1.0.0'
expect_refusal "tag-anchors: a prefix before the version is refused" 1 "refusing tag" "$d"
d=$work/evil5; mk_release "$d" 'v1.0.0evil'
expect_refusal "tag-anchors: a suffix after the version is refused" 1 "refusing tag" "$d"
# GUARD:sha-format
d=$work/short; mk_release "$d" v0.2.0
printf '%s  corntchap-cli-linux-x86_64.tar.gz\n' "$(hex 4 | cut -c2-)" > "$d/shas/corntchap-cli-linux-x86_64.tar.gz.sha256"
expect_refusal "sha-format: 63 hex chars is refused" 1 "not 64 lowercase hex" "$d"
d=$work/upper; mk_release "$d" v0.2.0
printf '%s  corntchap-cli-linux-x86_64.tar.gz\n' "$(hex 4 | sed 's/^0/G/')" > "$d/shas/corntchap-cli-linux-x86_64.tar.gz.sha256"
expect_refusal "sha-format: non-hex characters are refused" 1 "not 64 lowercase hex" "$d"
d=$work/upper2; mk_release "$d" v0.2.0
printf '%s  corntchap-cli-linux-x86_64.tar.gz\n' "$(printf 'A%.0s' $(seq 64))" > "$d/shas/corntchap-cli-linux-x86_64.tar.gz.sha256"
jq '(.assets[] | select(.name == "corntchap-cli-linux-x86_64.tar.gz") | .digest) = "sha256:'"$(printf 'A%.0s' $(seq 64))"'"' "$d/release.json" > "$d/r" && mv "$d/r" "$d/release.json"
expect_refusal "sha-format: 64 UPPERCASE hex chars (digest agrees) is refused" 1 "not 64 lowercase hex" "$d"
# GUARD:sha-anchors: valid hex first, code after it
d=$work/prefixed; mk_release "$d" v0.2.0
printf '%s"; system("id"); "  corntchap-cli-linux-x86_64.tar.gz\n' "$(hex 4)" > "$d/shas/corntchap-cli-linux-x86_64.tar.gz.sha256"
expect_refusal "sha-anchors: 64 hex followed by ruby code is refused" 1 "not 64 lowercase hex" "$d"
d=$work/prefixed2; mk_release "$d" v0.2.0
printf '%s"; system("id")#' "$(hex 4)" > "$d/shas/corntchap-cli-linux-x86_64.tar.gz.sha256"
expect_refusal "sha-anchors: 64 hex then code, no filename, is refused" 1 "not 64 lowercase hex" "$d"
d=$work/prefixed3; mk_release "$d" v0.2.0
printf 'x%s  corntchap-cli-linux-x86_64.tar.gz\n' "$(hex 4)" > "$d/shas/corntchap-cli-linux-x86_64.tar.gz.sha256"
expect_refusal "sha-anchors: a leading junk character is refused" 1 "not 64 lowercase hex" "$d"
d=$work/rubyhash; mk_release "$d" v0.2.0
printf '%s  corntchap-cli-linux-x86_64.tar.gz\n' '"; system("id"); "' > "$d/shas/corntchap-cli-linux-x86_64.tar.gz.sha256"
expect_refusal "sha-format: a hash carrying ruby code is refused" 1 "not 64 lowercase hex" "$d"
# GUARD:sha-lines
d=$work/twolines; mk_release "$d" v0.2.0
printf '%s  corntchap-cli-linux-x86_64.tar.gz\n%s  other\n' "$(hex 4)" "$(hex 5)" > "$d/shas/corntchap-cli-linux-x86_64.tar.gz.sha256"
expect_refusal "sha-lines: a second line is refused" 1 "exactly one line" "$d"
d=$work/blankline; mk_release "$d" v0.2.0
printf '%s  corntchap-cli-linux-x86_64.tar.gz\n\n' "$(hex 4)" > "$d/shas/corntchap-cli-linux-x86_64.tar.gz.sha256"
expect_refusal "sha-lines: a trailing blank line is refused" 1 "exactly one line" "$d"
# GUARD:digest
d=$work/baddigest; mk_release "$d" v0.2.0
jq '(.assets[] | select(.name == "corntchap-cli-darwin-arm64.tar.gz") | .digest) = "sha256:'"$(hex 99)"'"' "$d/release.json" > "$d/r" && mv "$d/r" "$d/release.json"
expect_refusal "digest: a .sha256 that disagrees with GitHub's digest is refused" 1 "does not match" "$d"
d=$work/nodigest; mk_release "$d" v0.2.0
jq 'del(.assets[] | select(.name == "corntchap-cli-linux-aarch64.tar.gz") | .digest)' "$d/release.json" > "$d/r" && mv "$d/r" "$d/release.json"
expect_refusal "digest: an asset without a digest is refused" 1 "digest ''" "$d"
# GUARD:repin: pinned 0.1.0 with real hashes, then the same tag with different hashes
f=$work/repin.rb; seed_formula "$f" 0.1.0
d=$work/swapped; mk_release "$d" v0.1.0
printf '%s  corntchap-cli-linux-x86_64.tar.gz\n' "$(hex 44)" > "$d/shas/corntchap-cli-linux-x86_64.tar.gz.sha256"
jq '(.assets[] | select(.name == "corntchap-cli-linux-x86_64.tar.gz") | .digest) = "sha256:'"$(hex 44)"'"' "$d/release.json" > "$d/r" && mv "$d/r" "$d/release.json"
expect_refusal "repin: the same version with different hashes is refused" 1 "refusing to re-pin" "$d" "$f"
d=$work/same; mk_release "$d" v0.1.0
before=$(cksum < "$f"); "$RENDER" "$d/release.json" "$d/shas" "$f" 2>&1 | grep -q "already at 0.1.0"; check "repin: the same version with the same hashes is accepted" $? 
# GUARD:formula-version
d=$work/ok3; mk_release "$d" v0.2.0
f=$work/formula-bad.rb; echo 'class CorntchapCli < Formula; end' > "$f"
expect_refusal "formula-version: an unreadable current version is refused" 1 "cannot read the formula" "$d" "$f"
# GUARD:sha-name
d=$work/wrongname; mk_release "$d" v0.2.0
printf '%s  corntchap-cli-linux-aarch64.tar.gz\n' "$(hex 9)" > "$d/shas/corntchap-cli-linux-x86_64.tar.gz.sha256"
expect_refusal "sha-name: a hash for another file is refused" 1 "does not name" "$d"
# GUARD:asset-tarball
d=$work/notar; mk_release "$d" v0.2.0
jq '.assets |= map(select(.name != "corntchap-cli-darwin-x86_64.tar.gz"))' "$d/release.json" > "$d/r" && mv "$d/r" "$d/release.json"
expect_refusal "asset-tarball: release without a tarball is refused" 1 "has no asset corntchap-cli-darwin-x86_64.tar.gz" "$d"
# GUARD:asset-sha
d=$work/nosha; mk_release "$d" v0.2.0
jq '.assets |= map(select(.name != "corntchap-cli-linux-aarch64.tar.gz.sha256"))' "$d/release.json" > "$d/r" && mv "$d/r" "$d/release.json"
expect_refusal "asset-sha: release without a .sha256 asset is refused" 1 "has no asset corntchap-cli-linux-aarch64.tar.gz.sha256" "$d"
# GUARD:sha-file
d=$work/nofile; mk_release "$d" v0.2.0
rm "$d/shas/corntchap-cli-darwin-arm64.tar.gz.sha256"
expect_refusal "sha-file: a listed asset that was not downloaded is refused" 1 "missing" "$d"
# GUARD:downgrade
d=$work/older; mk_release "$d" v0.0.9
expect_refusal "downgrade: an older release is skipped (rc 10)" 10 "older than the formula" "$d"
d=$work/older2; mk_release "$d" v0.1.0
f=$work/formula-newer.rb; seed_formula "$f" 0.10.0
before=$(cksum < "$f"); err=$("$RENDER" "$d/release.json" "$d/shas" "$f" 2>&1 > /dev/null); rc=$?
[ "$rc" = 10 ] && [ "$(cksum < "$f")" = "$before" ]; check "downgrade: 0.1.0 is older than 0.10.0 (numeric, not lexical)" $? "(rc=$rc $err)"
d=$work/older3; mk_release "$d" v0.1.1
f=$work/formula-patch.rb; seed_formula "$f" 0.1.2
expect_refusal "downgrade: a patch-level downgrade (0.1.1 < 0.1.2) is skipped" 10 "older than the formula" "$d" "$f"
# GUARD:unfilled -- needs a template with a field the script does not know; checked on a copy
cp -R "$root/scripts" "$work/scripts-copy"; sed -i.bak 's/@VERSION@/@VERSION@@MYSTERY@/' "$work/scripts-copy/formula.rb.tpl"
d=$work/ok; f=$work/formula-unfilled.rb; seed_formula "$f" 0.1.0
err=$("$work/scripts-copy/render-formula.sh" "$d/release.json" "$d/shas" "$f" 2>&1 > /dev/null); rc=$?
[ "$rc" = 1 ] && [[ $err == *"unfilled template field"* ]]; check "unfilled: a template field nothing fills is refused" $? "(rc=$rc $err)"

echo "$((n - fails))/$n passed"
[ "$fails" = 0 ]
