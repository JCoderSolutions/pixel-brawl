#!/usr/bin/env bash
# Capturas de todas las pantallas del menú (para revisar cambios de UI en PRs).
# Uso: GODOT=/ruta/a/godot tools/ui_screenshots.sh [carpeta_salida]
# Sin pantalla usa Xvfb (xvfb-run) con el driver OpenGL por software.
set -euo pipefail
GODOT="${GODOT:-godot}"
OUT="$(realpath -m "${1:-build/ui_screenshots}")"
cd "$(dirname "$0")/.."
mkdir -p "$OUT"
run=("$GODOT" --rendering-driver opengl3 --path . -s tools/ui_screenshots.gd -- "$OUT")
if [ -z "${DISPLAY:-}" ] && command -v xvfb-run >/dev/null; then
	xvfb-run -a -s "-screen 0 1280x720x24" "${run[@]}"
else
	"${run[@]}"
fi
