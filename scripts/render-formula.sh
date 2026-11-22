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
# The tag and every hash come from a release, so they are untrusted: each is validated against a
# strict pattern before it reaches the template, and nothing else is ever substituted.
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
tag_re="^v$num\\.$num\\.$num\$"
sha_re='^[0-9a-f]{64}$'

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

if [ -f "$formula" ]; then
  cur=$(grep -oE -m1 'releases/download/v[0-9]+\.[0-9]+\.[0-9]+/' "$formula" | head -n1 | sed -E 's#releases/download/v([0-9.]+)/#\1#' || true)
  if [ -n "$cur" ]; then
    ver_lt "$ver" "$cur" && skip "release $ver is older than the formula's $cur" # GUARD:downgrade
  fi
fi

content=$(cat "$template")
for p in darwin-arm64 darwin-x86_64 linux-aarch64 linux-x86_64; do
  name=corntchap-cli-$p.tar.gz
  jq -e --arg n "$name" 'any(.assets[]?; .name == $n)' "$release" > /dev/null \
    || die "release $tag has no asset $name" # GUARD:asset-tarball
  jq -e --arg n "$name.sha256" 'any(.assets[]?; .name == $n)' "$release" > /dev/null \
    || die "release $tag has no asset $name.sha256" # GUARD:asset-sha
  f=$shas/$name.sha256
  [ -f "$f" ] || die "missing $f" # GUARD:sha-file
  line=$(cat "$f")
  hash=${line%%  *}
  [[ $hash =~ $sha_re ]] || die "$name.sha256: '${hash:0:80}' is not 64 lowercase hex characters" # GUARD:sha-format
  [ "$line" = "$hash  $name" ] || die "$name.sha256 does not name $name" # GUARD:sha-name
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
