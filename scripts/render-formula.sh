#!/usr/bin/env bash
# Render Formula/corntchap-cli.rb from a release of cratestack/corntchap.
#
#   render-formula.sh RELEASE_JSON SHA_DIR FORMULA
#
#   RELEASE_JSON  `gh release view --json tagName,assets` output
#   SHA_DIR       the release's corntchap-cli-<platform>.tar.gz.sha256 files
#   FORMULA       the formula to (re)write
#
# Exit 0: FORMULA is up to date (rewritten, or already identical). Exit 10: skipped, the release is
# older than the formula (never downgrade). Anything else: refused, FORMULA is untouched.
#
# What this does and does not protect (trust on first use of a release):
#  - the tag and every hash are validated against strict patterns before they reach the template, and
#    nothing else is ever substituted (no injection into the Ruby file);
#  - each archive's hash in its .sha256 file must equal the `digest` GitHub itself computed for the
#    asset, so a .sha256 that disagrees with the archive it names is refused;
#  - once a version is pinned with real hashes, the same version is never re-pinned to different
#    hashes (a swapped asset is refused), and an older release never replaces a newer one.
# It does NOT detect a release that was already compromised when first published: the first release
# seen is trusted. Immutable releases (`isImmutable`) would close the swap window on GitHub's side.
# Each `# GUARD:<name>` line is covered by a test in tests/render-formula.test.sh.
set -euo pipefail

die() { echo "error: $*" >&2; exit 1; }
skip() { echo "skip: $*" >&2; exit 10; }

[ $# -eq 3 ] || die "usage: render-formula.sh RELEASE_JSON SHA_DIR FORMULA"
release=$1 shas=$2 formula=$3
here=$(cd "$(dirname "$0")" && pwd)
template=$here/formula.rb.tpl
[ -f "$release" ] || die "no such file: $release"
[ -d "$shas" ] || die "no such directory: $shas"
command -v jq > /dev/null || die "jq is required"

num='(0|[1-9][0-9]{0,8})'
tag_re="^v$num\\.$num\\.$num\$" # GUARD:tag-anchors
sha_re='^[0-9a-f]{64}$' # GUARD:sha-anchors

tag=$(jq -er '.tagName | strings' "$release") || die "release JSON has no tagName"
[[ $tag =~ $tag_re ]] || die "refusing tag '${tag:0:80}': not vMAJOR.MINOR.PATCH" # GUARD:tag
ver=${tag#v}

# ver_lt A B: A < B, component by component (no overflow, no `sort -V` portability trouble)
ver_lt() {
  local IFS=. i
  local -a a b
  read -r -a a <<< "$1"
  read -r -a b <<< "$2"
  for i in 0 1 2; do
    if ((a[i] < b[i])); then return 0; fi
    if ((a[i] > b[i])); then return 1; fi
  done
  return 1
}

cur=
if [ -f "$formula" ]; then
  cur=$(grep -oE -m1 'releases/download/v[0-9]+\.[0-9]+\.[0-9]+/' "$formula" | head -n1 | sed -E 's#releases/download/v([0-9.]+)/#\1#' || true)
  [[ $cur =~ ^$num\.$num\.$num$ ]] || die "cannot read the formula's current version ('${cur:0:40}')" # GUARD:formula-version
  ver_lt "$ver" "$cur" && skip "release $ver is older than the formula's $cur" # GUARD:downgrade
fi
jq -e '.isImmutable == true' "$release" > /dev/null || echo "note: release $tag is not immutable (trust on first use)" >&2

content=$(cat "$template")
for p in darwin-arm64 darwin-x86_64 linux-aarch64 linux-x86_64; do
  name=corntchap-cli-$p.tar.gz
  jq -e --arg n "$name" 'any(.assets[]?; .name == $n)' "$release" > /dev/null \
    || die "release $tag has no asset $name" # GUARD:asset-tarball
  jq -e --arg n "$name.sha256" 'any(.assets[]?; .name == $n)' "$release" > /dev/null \
    || die "release $tag has no asset $name.sha256" # GUARD:asset-sha
  f=$shas/$name.sha256
  [ -f "$f" ] || die "missing $f" # GUARD:sha-file
  [ "$(grep -c '' "$f")" = 1 ] || die "$f must hold exactly one line" # GUARD:sha-lines
  line=$(cat "$f")
  hash=${line%%  *}
  [[ $hash =~ $sha_re ]] || die "$name.sha256: '${hash:0:80}' is not 64 lowercase hex characters" # GUARD:sha-format
  [ "$line" = "$hash  $name" ] || die "$name.sha256 does not name $name" # GUARD:sha-name
  dg=$(jq -r --arg n "$name" '[.assets[]? | select(.name == $n) | .digest // empty] | first // empty' "$release")
  [ "$dg" = "sha256:$hash" ] || die "$name: GitHub's digest '${dg:0:80}' does not match the .sha256 file's $hash" # GUARD:digest
  if [ "$cur" = "$ver" ]; then
    curhash=$(grep -A1 "releases/download/v[0-9.]*/$name\"" "$formula" | sed -n 's/^ *sha256 "\([0-9a-f]*\)"$/\1/p' | head -n1)
    if [ -n "$curhash" ] && ! [[ $curhash =~ ^0+$ ]]; then
      [ "$curhash" = "$hash" ] || die "refusing to re-pin $name at $ver: pinned $curhash, release now says $hash" # GUARD:repin
    fi
  fi
  key=$(printf '%s' "$p" | tr 'a-z-' 'A-Z_')
  content=${content//@SHA_$key@/$hash}
done
content=${content//@VERSION@/$ver}
[[ $content != *@[A-Z]*@* ]] || die "unfilled template field" # GUARD:unfilled

tmp=$(mktemp "$formula.XXXXXX")
trap 'rm -f "$tmp"' EXIT
printf '%s\n' "$content" > "$tmp"
if [ -f "$formula" ] && cmp -s "$tmp" "$formula"; then
  echo "formula already at $ver"
else
  mv "$tmp" "$formula"
  echo "formula now at $ver"
fi
