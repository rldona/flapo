#!/usr/bin/env bash
# Ejecuta todas las comprobaciones headless de tests/test_*.gd.
# Sale con 0 solo si todas pasan. Ver docs/testing.md.
set -uo pipefail

GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ ! -x "$GODOT" ]]; then
  echo "No encuentro el binario de Godot en: $GODOT" >&2
  echo "Ajusta la variable GODOT. Ver docs/environment.md." >&2
  exit 127
fi

fallos=0
for test in "$RAIZ"/tests/test_*.gd; do
  "$GODOT" --headless --path "$RAIZ" -s "$test" || fallos=$((fallos + 1))
done

if [[ $fallos -gt 0 ]]; then
  echo "==> $fallos fichero(s) de test con fallos"
  exit 1
fi
echo "==> todo en verde"
