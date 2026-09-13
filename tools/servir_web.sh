#!/usr/bin/env bash
# Exporta a Web y lo sirve. En ese orden, siempre.
#
#     ./tools/servir_web.sh [puerto]
#
# Existe porque servir un build viejo no daba ningún error: el juego cargaba,
# funcionaba y le faltaban las últimas features. Pasó con las frutas. Ahora no
# hay forma de servir sin exportar antes.
set -euo pipefail

PUERTO="${1:-8060}"
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SALIDA="$RAIZ/export/Web"

if [[ ! -x "$GODOT" ]]; then
  echo "No encuentro Godot en: $GODOT" >&2
  echo "Ajusta la variable GODOT. Ver docs/environment.md." >&2
  exit 127
fi

echo "==> Exportando"
rm -rf "${SALIDA:?}"/*
mkdir -p "$SALIDA"
"$GODOT" --headless --path "$RAIZ" --export-release "Web" "$SALIDA/index.html"
test -s "$SALIDA/index.wasm" || { echo "El export no ha producido wasm" >&2; exit 1; }

echo "==> Build recién hecho: $(ls -lh "$SALIDA/index.pck" | awk '{print $5}') de datos"
echo "==> http://localhost:$PUERTO"
# Se sirve con tools/servidor.py y no con `python3 -m http.server` porque ese
# deja que el navegador cachee el .pck y el .wasm. Recargabas y seguías
# jugando al build anterior, sin ningún aviso.
exec python3 "$RAIZ/tools/servidor.py" "$PUERTO" "$SALIDA"
