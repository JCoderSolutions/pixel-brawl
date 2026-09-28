---
type: "task"
status: "in-progress"     # allowed: todo | in-progress | done | discarded
priority: "high"
phase: "PHASE-2"
depends_on: "TASK-004, TASK-006"
source_memory_id: ""
discarded_reason: ""
---

# TASK-019 — Materiales de bloque + arena destructible

## Objetivo

Que las granadas rompan de verdad el escenario de la partida y que cada tile
tenga un material que decide qué lo rompe: las balas astillan puertas de
madera pero rebotan en el ladrillo, y el metal aguanta todo.

## Criterios de done

- [x] Causa del bug: el suelo y las plataformas de `test_arena` eran
      `StaticBody2D` sueltos, no tiles, así que las explosiones no tenían
      nada que romper
- [x] `BlockMaterial` (Resource) con vida, qué daño lo rompe y colores
- [x] Madera (`#`, `=` tablón one-way), ladrillo (`B`) y metal (`X`)
- [x] Las balas dañan madera aunque el rayo toque el cuerpo del tile
- [x] Arena rehecha con tiles: suelo de ladrillo sobre cama de metal,
      plataformas de tablones, puente con extremos de metal
- [x] Test headless `scripts/test_materials.gd`
- [ ] Test manual: granadas, balas y golpes contra cada material se sienten bien

## Detalles

| Material | Char | Balas / golpes | Explosiones | Color (Endesga 32) |
| --- | --- | --- | --- | --- |
| Madera | `#` `=` | sí | sí | `b86f50` → `733e39` |
| Ladrillo | `B` | no | sí | `be4a2f` → `3e2731` |
| Metal | `X` | no | no | `5a6988` |

- Materiales en `scenes/maps/materials/*.tres`; un mapa nuevo solo usa el
  layout de texto. Para un material nuevo: crear el `.tres` y sumarlo a
  `DestructibleMap.LEGEND`.
- Golpes y balas entran por el `Hurtbox` del tile; si el material no los
  acepta, el hurtbox queda apagado (la bala igual se frena contra el cuerpo).
  Las explosiones entran por `DestructibleBlock.take_blast()`.
- `=` es un tablón one-way de 6 px visibles: se atraviesa saltando desde
  abajo y se pisa desde arriba.
- Dibujo nativo por material (vetas, juntas, remaches) hasta el pase de arte.
- La cama de metal (fila 17) evita que las granadas abran el suelo hacia el
  vacío; la kill zone sigue igual.

## Evidencia

- Commit: `feat(map): add block materials and make the match arena destructible`
- Memoria Engram: pendiente (sin acceso a Engram desde la sesión en la nube)
- Verificación: `godot --headless --path . -s scripts/test_materials.gd` →
  `OK: material data, layout legend, bullets/melee/blasts per material, one-way planks, tile arena and grenade craters in the match arena verified`;
  `tools/run_tests.sh` → todos los tests pasan
- Capturas: `screenshots/materiales/arena.png`, `screenshots/materiales/despues-granadas.png`
