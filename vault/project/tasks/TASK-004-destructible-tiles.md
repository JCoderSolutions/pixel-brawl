---
type: "task"
status: "in-progress"     # allowed: todo | in-progress | done | discarded
priority: "high"
phase: "PHASE-1"
depends_on: "TASK-003"
source_memory_id: ""
discarded_reason: ""
---

# TASK-004 — Destructible tile layer

## Objetivo

El mapa tiene bloques de 16 px con vida que se dañan y se rompen al recibir
golpes, reutilizando el pipeline de daño de TASK-003, y deja lista la API de
daño en área para las explosiones de TASK-006.

## Criterios de done

- [x] `DestructibleBlock` (tile 16 px) con `HealthComponent` + `Hurtbox`
- [x] El bloque se oscurece al perder vida y desaparece al llegar a cero
- [x] Bloques indestructibles (`X`) que no reciben daño
- [x] `DestructibleMap` arma la grilla desde un layout de texto
- [x] `damage_area(centro, radio, daño)` para explosiones
- [x] Plataforma, pared y cajas destructibles en `test_arena`
- [x] Test headless `scripts/test_destructible.gd`
- [ ] Test manual: romper la plataforma y las cajas con el golpe se siente bien

## Detalles

- Capas: el bloque es `StaticBody2D` en layer 1 (`world`) y su `Hurtbox` en
  layer 4 (`hurtboxes`), así el `Hitbox` del player lo golpea sin cambios en
  `player.gd`.
- Layout: `#` destructible (30 de vida = 3 golpes), `X` indestructible, otro
  carácter = vacío. La fila 0 es la de arriba; la celda (0, 0) empieza en el
  origen del nodo.
- Al morir, el bloque apaga su capa de colisión en el mismo paso de física,
  para que lo que esté encima caiga enseguida, y luego se libera.
- `damage_area` pasa el daño por el `Hurtbox` de cada bloque que toca el
  círculo, así explosiones y golpes comparten el mismo camino.
- Un cuerpo por tile es suficiente para mapas de pantalla única (~500 tiles).
  Si un mapa crece mucho, migrar a `TileMap` con una capa de vida por celda.
- Visual: `ColorRect` dentro del nodo `Visual`, colores Endesga 32
  (`b86f50` caja, `733e39` dañada, `5a6988` indestructible).

## Evidencia

- Commit: `feat(map): add destructible tile blocks and map layout`
- Memoria Engram: pendiente (sin acceso a Engram desde la sesión en la nube)
- Verificación: `godot --headless --path . -s scripts/test_destructible.gd` →
  `OK: block health, shading, breaking, indestructible cells, grid layout, area damage, melee breaks blocks and holes open the floor`
