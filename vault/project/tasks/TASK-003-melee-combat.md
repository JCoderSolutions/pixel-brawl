---
type: "task"
status: "in-progress"     # allowed: todo | in-progress | done | discarded
priority: "high"
phase: "PHASE-1"
depends_on: "TASK-002"
source_memory_id: ""
discarded_reason: ""
---

# TASK-003 — Basic melee combat

## Objetivo

El jugador puede golpear cuerpo a cuerpo, el golpe hace daño y empuja al rival,
con un pipeline de daño reutilizable para armas, props y tiles destructibles.

## Criterios de done

- [x] `HealthComponent` reutilizable (daño, curación, muerte una sola vez)
- [x] `Hitbox` / `Hurtbox` desacoplados, un golpe por ventana, sin autogolpe
- [x] Ataque del player con startup / active / recovery, hitstun, knockback e i-frames
- [x] Acción `attack` (J; desde TASK-008 `p1_attack` J, `p2_attack` Ctrl / Enter) y dummy de práctica en `test_arena`
- [x] Test headless `scripts/test_melee.gd`
- [ ] Test manual de sensaciones: el golpe se siente con peso y el alcance es justo

## Detalles

- Capas de física: 1 `world`, 2 `players`, 3 `hitboxes`, 4 `hurtboxes`.
  Los players no chocan entre sí (layer 2, mask 1), como en Superfighters.
- `Hitbox` ataca solo `Hurtbox` (mask 4) y abre la ventana con `activate()`.
- `is_controlled = false` desactiva el input: sirve para dummies. El input por
  jugador (slots, bots, red) vive en TASK-008.
- El origen del personaje está en los pies: shapes, hurtbox y visual crecen
  hacia arriba desde y = 0, y al agacharse se reubican (`_set_body_height`).
- Los shapes del player son `resource_local_to_scene`: sin eso, todas las
  instancias compartían el mismo shape y agacharse encogía a los demás.
- Los visuales del mapa coinciden exactamente con sus colisiones (antes el
  piso y las plataformas quedaban 4 a 8 px desalineados y el fondo no se veía).
- Los valores de feel (`attack_*`, `hitstun`, `invulnerability`, daño y
  knockback del `Hitbox`) están expuestos en el inspector para ajustarlos.

## Evidencia

- Commit: `feat(combat): add melee attack with health, hitbox and hurtbox`
- Memoria Engram: pendiente (sin acceso a Engram desde la sesión en la nube)
- Verificación: `godot --headless --path . -s scripts/test_melee.gd` →
  `OK: health, melee hit, knockback, single hit per swing, range and death verified`
