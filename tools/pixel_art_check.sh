#!/usr/bin/env bash
# Revisa sprites (por ejemplo, lo que devuelve Retro Diffusion) y, con --out,
# guarda una copia limpia y editable: tamaño real de pixel, solo Endesga 32,
# transparencia sin bordes suavizados.
# Uso: GODOT=/ruta/a/godot tools/pixel_art_check.sh imagen.png [otra.png...] [--out carpeta]
set -euo pipefail
GODOT="${GODOT:-godot}"
args=()
for arg in "$@"; do
	if [ -e "$arg" ]; then args+=("$(realpath "$arg")"); else args+=("$arg"); fi
done
prev=""
for i in "${!args[@]}"; do
	[ "$prev" = "--out" ] && args[$i]="$(realpath -m "${args[$i]}")"
	prev="${args[$i]}"
done
cd "$(dirname "$0")/.."
exec "$GODOT" --headless --path . -s tools/pixel_art_check.gd -- "${args[@]}"
