#!/usr/bin/env bash
# Downloads the markmap runtime into Resources/ so the mindmap WebView works
# fully offline (no CDN at runtime). These files are copied flat into the app
# bundle, so markmap.html references them by bare name. Re-run to update.
set -euo pipefail

cd "$(dirname "$0")/.."
DEST="Resources"
mkdir -p "$DEST"

fetch() {
  local url="$1" out="$2"
  echo "→ $DEST/$out"
  curl -fsSL "$url" -o "$DEST/$out"
}

# Pin exact versions; bump deliberately.
fetch "https://cdn.jsdelivr.net/npm/d3@7/dist/d3.min.js"                     "d3.min.js"
fetch "https://cdn.jsdelivr.net/npm/markmap-lib@0.18/dist/browser/index.js"  "markmap-lib.min.js"
fetch "https://cdn.jsdelivr.net/npm/markmap-view@0.18/dist/browser/index.js" "markmap-view.min.js"

echo "Done. These three files are gitignored — re-run this after a fresh clone or in CI."
