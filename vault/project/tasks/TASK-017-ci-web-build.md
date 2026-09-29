---
type: "task"
status: "in-progress"
priority: "high"
phase: "PHASE-4"
depends_on: ""
source_memory_id: ""
discarded_reason: ""
---

# TASK-017 — CI headless + build Web en GitHub Pages

## Objetivo

Cada push/PR corre los tests headless, y cada merge a `main` publica el build Web
en GitHub Pages para probar desde teléfono o PC sin instalar nada.

## Criterios de done

- [x] Workflow `.github/workflows/ci.yml`: tests → build Web → deploy (solo `main`)
- [x] `tools/run_tests.sh` corre `scripts/test_*.gd` + `verify_launch.gd`
- [x] Build Web corre en un host sin headers COOP/COEP (verificado en Chromium)
- [x] Pages activado con Source = GitHub Actions (Jose, 2026-09-29)
- [x] Primer deploy abre en https://jcodersolutions.github.io/pixel-brawl/ (deploy del CI de main, 2026-09-29)

## Detalles

- Godot fijado a **4.2.2** (`GODOT_VERSION` en el workflow). Binario y templates
  Web van en `actions/cache`; del `.tpz` (~900 MB) solo se extraen los de Web.
- **Tests:** `GODOT=/ruta/godot tools/run_tests.sh`. Un test pasa solo si sale con
  código 0, imprime una línea `OK:` y no hay `SCRIPT ERROR`. Ojo: en 4.2,
  `quit(1)` llamado dentro de `_init()` sale con código 0; por eso se exige el `OK:`.
  Tests nuevos: nombrarlos `scripts/test_<algo>.gd` y se suman solos.
- **Cross-origin isolation:** el export Web de 4.2 usa hilos (SharedArrayBuffer) y
  necesita COOP/COEP, que Pages no permite configurar. `web/coi-serviceworker.js`
  es un service worker que agrega esos headers; el preset Web lo carga vía
  `html/head_include` y la primera visita recarga una vez. El CI lo copia a
  `build/web/`. Si exportás a mano, copialo también. Se puede quitar al pasar a
  Godot 4.3+ con `variant/thread_support=false`.
- El preset Web excluye los scripts de test del `.pck`.
- Si Pages no está activado con Source = GitHub Actions, el job de deploy deja un
  warning con el link a Settings → Pages y omite el deploy (main no queda en rojo).
- En PRs el build queda como artifact descargable del run (`github-pages`), sin deploy.

## Evidencia

- Commit: `ci: run headless tests and publish web build to github pages`
- Memoria Engram: pendiente (Engram no es accesible desde sesiones cloud).
- Verificación: local con Godot 4.2.2 — `tools/run_tests.sh` pasa (2/2) y falla con
  un test roto y uno con error de parseo; export Web servido con `python3 -m
  http.server` (sin headers) arranca en Chromium con `crossOriginIsolated=true`.
