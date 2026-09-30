#!/usr/bin/env bash
# Hojas de referencia del luchador (poses nativas, 32x32 por cuadro) para
# dibujar encima o usar como referencia en herramientas de IA.
# Uso: GODOT=/ruta/a/godot tools/export_rig_reference.sh [carpeta_salida]
set -euo pipefail
GODOT="${GODOT:-godot}"
OUT="$(realpath -m "${1:-assets/sprites/characters/reference}")"
cd "$(dirname "$0")/.."
mkdir -p "$OUT"
run=("$GODOT" --rendering-driver opengl3 --path . -s tools/export_rig_reference.gd -- "$OUT")
if [ -z "${DISPLAY:-}" ] && command -v xvfb-run >/dev/null; then
	xvfb-run -a -s "-screen 0 1280x720x24" "${run[@]}"
else
	"${run[@]}"
fi
