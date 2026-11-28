#!/usr/bin/env bash
set -euo pipefail
# Run in an authenticated checkout with push access; never log credentials.
slug="${1:?slug required}"
pdf="${2:?PDF path required}"
article="${3:?Markdown path required}"
[[ "$slug" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]
test -s "$pdf"; test -s "$article"
test "$(head -c 5 "$pdf")" = '%PDF-'
expected=$(sha256sum "$pdf" | cut -d ' ' -f1)
git switch main
git pull --ff-only origin main
mkdir -p "posts/$slug"
cp "$pdf" "posts/$slug/carousel.pdf"
cp "$article" "posts/$slug/article.md"
git add -- "posts/$slug/carousel.pdf" "posts/$slug/article.md"
if ! git diff --cached --quiet; then
  git commit -m "Publish technical article: $slug"
fi
git push origin main
commit=$(git rev-parse HEAD)
url="https://raw.githubusercontent.com/jether2011/technical-documents-for-carrousel/$commit/posts/$slug/carousel.pdf"
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
curl --fail --silent --show-error --location --retry 5 --retry-all-errors "$url" -o "$tmp"
actual=$(sha256sum "$tmp" | cut -d ' ' -f1)
test "$expected" = "$actual"
printf 'VERIFIED %s %s\n' "$actual" "$url"
