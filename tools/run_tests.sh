#!/usr/bin/env bash
# Corre los tests headless del proyecto (scripts/**/test_*.gd + verify_launch.gd).
# Uso: GODOT=/ruta/a/godot tools/run_tests.sh
# Cada test es un SceneTree script que imprime "OK: ..." y hace quit(1) al fallar.
set -uo pipefail

GODOT="${GODOT:-godot}"
TIMEOUT="${TEST_TIMEOUT:-120}"
cd "$(dirname "$0")/.."

tests=(scripts/test_*.gd scripts/*/test_*.gd scripts/verify_launch.gd)
failed=0

for test in "${tests[@]}"; do
	[ -f "$test" ] || continue
	echo "::group::$test"
	output="$(timeout "$TIMEOUT" "$GODOT" --headless --path . -s "$test" 2>&1)"
	code=$?
	echo "$output"
	echo "::endgroup::"
	# Un error de parseo puede terminar con código 0: exigir también la línea OK.
	if [ "$code" -ne 0 ] || grep -q "SCRIPT ERROR" <<<"$output" || ! grep -q "^OK:" <<<"$output"; then
		echo "FAIL: $test (exit $code)"
		failed=$((failed + 1))
	else
		echo "PASS: $test"
	fi
done

if [ "$failed" -ne 0 ]; then
	echo "$failed test(s) fallaron"
	exit 1
fi
echo "Todos los tests pasaron"
