#!/usr/bin/env bash
# Build Interface/AddOns-style zip for a GitHub Release.
# Usage: scripts/package-release.sh [version]
# Output: dist/CrusaderStrike-<version>.zip with top-level folder CrusaderStrike/
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  VERSION="$(sed -n 's/^## Version: //p' "$ROOT/CrusaderStrike.toc" | head -1 | tr -d '\r')"
fi
OUT_DIR="$ROOT/dist"
STAGE_ROOT="$OUT_DIR/stage"
STAGE="$STAGE_ROOT/CrusaderStrike"
ZIP_PATH="$OUT_DIR/CrusaderStrike-${VERSION}.zip"
rm -rf "$STAGE_ROOT"
mkdir -p "$STAGE"

find "$ROOT" -mindepth 1 -maxdepth 1 ! -name '.git' ! -name 'dist' ! -name 'tests' \
  ! -name 'scripts' ! -name '.github' ! -name '.gitignore' ! -name '*.md' \
  -exec cp -a {} "$STAGE/" \;

[[ -f "$ROOT/CHANGELOG.md" ]] && cp "$ROOT/CHANGELOG.md" "$STAGE/"
[[ -f "$ROOT/README.md" ]] && cp "$ROOT/README.md" "$STAGE/"

mkdir -p "$OUT_DIR"
rm -f "$ZIP_PATH"

if command -v zip >/dev/null 2>&1; then
  (cd "$STAGE_ROOT" && zip -qr "$ZIP_PATH" CrusaderStrike)
else
  python3 - "$STAGE_ROOT" "$ZIP_PATH" <<'PY'
import sys, zipfile
from pathlib import Path
stage_root = Path(sys.argv[1])
zip_path = Path(sys.argv[2])
with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED) as zf:
    for path in stage_root.rglob("*"):
        if path.is_file():
            zf.write(path, path.relative_to(stage_root).as_posix())
print("python zip ok")
PY
fi

echo "Wrote $ZIP_PATH ($(wc -c < "$ZIP_PATH") bytes)"
if command -v unzip >/dev/null 2>&1; then
  unzip -l "$ZIP_PATH" | head -25
else
  python3 - "$ZIP_PATH" <<'PY'
import sys, zipfile
with zipfile.ZipFile(sys.argv[1]) as zf:
    for i, n in enumerate(zf.namelist()[:25]):
        print(n)
    print(f"... {len(zf.namelist())} entries total")
PY
fi
