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

# Fase 1: que todo compile.
#
# Los tests solo ejecutan lo que tocan. Un `connect` a una función que ya no
# existe, o un identificador mal escrito en una rama poco visitada, pasa
# desapercibido hasta que revienta en manos del jugador. `--check-only`
# compila el fichero y falla si no cuadra. Pasó de verdad: un refactor borró
# `Main._on_scored()` y el `connect` se quedó colgando; los tests siguieron
# en verde.
echo "== Compilando scripts =="
for gd in "$RAIZ"/scripts/*.gd "$RAIZ"/tests/*.gd; do
  if ! salida="$("$GODOT" --headless --path "$RAIZ" --check-only --script "$gd" 2>&1)"; then
    echo "$salida"
    fallos=$((fallos + 1))
  elif echo "$salida" | grep -qE "Parse Error|Compile Error"; then
    echo "$salida" | grep -E "Parse Error|Compile Error|^ *at:"
    fallos=$((fallos + 1))
  fi
done
if [[ $fallos -gt 0 ]]; then
  echo "==> $fallos fichero(s) no compilan"
  exit 1
fi
echo "   todos compilan"

echo "== Comprobaciones =="
for test in "$RAIZ"/tests/test_*.gd; do
  "$GODOT" --headless --fixed-fps 60 --path "$RAIZ" -s "$test" || fallos=$((fallos + 1))
done

if [[ $fallos -gt 0 ]]; then
  echo "==> $fallos fichero(s) de test con fallos"
  exit 1
fi
echo "==> todo en verde"
