#!/bin/bash
set -euo pipefail

VERSION="${1:?Usage: $0 <version> (e.g., 1.0.3)}"
REPO="ehkropf/Pellucid-Markdown-Viewer"
URL="https://github.com/${REPO}/archive/v${VERSION}.tar.gz"
TMPFILE=$(mktemp)

echo "Downloading v${VERSION} tarball..."
curl -sL "$URL" -o "$TMPFILE"

echo "checksums           rmd160  $(openssl dgst -rmd160 "$TMPFILE" | awk '{print $NF}') \\"
echo "                    sha256  $(shasum -a 256 "$TMPFILE" | awk '{print $1}') \\"
echo "                    size    $(stat -f%z "$TMPFILE")"

rm -f "$TMPFILE"
