#!/usr/bin/env bash
# Regenera docs/cover/cover.png (portada del repositorio / social preview de GitHub, 1280x640)
# a partir de docs/cover/cover.html, que compone el icono, el nombre y docs/cover/screenshot.png.
#
#   ./tools/hacer_portada.sh
#
# Necesita Google Chrome (o cualquier Chromium en la variable CHROME).
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
chrome="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"

"$chrome" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
  --window-size=1280,640 --screenshot="$root/docs/cover/cover.png" "file://$root/docs/cover/cover.html"
echo "escrito docs/cover/cover.png"
