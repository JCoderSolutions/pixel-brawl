---
type: "task"
status: "in-progress"     # allowed: todo | in-progress | done | discarded
priority: "medium"
phase: "PHASE-3"
depends_on: "TASK-019, TASK-022"
source_memory_id: ""
discarded_reason: ""
---

# TASK-023 — Enganches para el arte (tilesets y sprites)

## Objetivo

Pedido de Jose (2026-09-29): que cuando lleguen los tilesets y sprites se
reemplacen fácil. Todo lo que hoy es forma nativa debe aceptar arte real
sin cambios de código, y si falta el arte debe volver a la forma nativa.

## Criterios de done

- [x] Tiles: `BlockMaterial.texture` y `plank_texture`, tiras de 16x16 que
      avanzan con el daño (`BlockMaterial.frame_for`). Con textura, se oculta
      el relleno de color
- [x] Luchadores: `FighterLook.frames` (SpriteFrames), que se carga solo desde
      `assets/sprites/characters/<nombre>.tres`. Una animación por
      `FighterRig.Anim` (`FighterRig.anim_name`); las que falten se dibujan
      con formas nativas. La marca de equipo y el destello siguen andando
- [x] Armas: `WeaponData.sprite` y `sprite_grip`, dibujados por
      `WeaponArt.draw` en la mano y en el piso
- [x] Guía: `vault/docs/art-swap-guide.md`
- [x] Test headless `scripts/test_art_hooks.gd`
- [ ] Probar con el primer tileset y el primer personaje reales

## Evidencia

- Commit: `feat(art): let tilesets and sprites replace the native shapes`
- Memoria Engram: pendiente (sin acceso a Engram desde la sesión en la nube)
- Verificación: `tools/run_tests.sh` → todos los tests pasan; captura con
  texturas de prueba en el PR
