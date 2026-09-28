---
type: "task"
status: "in-progress"     # allowed: todo | in-progress | done | discarded
priority: "high"
phase: "PHASE-3"
depends_on: "TASK-002, TASK-003, TASK-005"
source_memory_id: ""
discarded_reason: ""
---

# TASK-022 — Luchador animado con formas nativas (32x32)

## Objetivo

Reemplazar el rectángulo de color por un luchador dibujado con formas nativas
(sin sprites todavía) que se anime según lo que hace, dentro de un cuadro de
32x32 anclado en los pies, como los futuros sprites.

## Criterios de done

- [x] `FighterRig` (`scenes/characters/fighter_rig.gd`): es el nodo `Visual`
      del jugador (un `Control` de 32x32), así el color por jugador, el giro,
      el ragdoll y los tests existentes siguen funcionando
- [x] Partes: cabeza con vincha y ojo, torso, brazos (manga del color del
      jugador + antebrazo), piernas con rodilla y zapato. Paleta Endesga 32
- [x] Animaciones: quieto (respira), correr (ciclo de 0.5 s, la pierna de
      atrás dobla la rodilla), saltar, caer (agita los brazos), agachado (en
      cuclillas, a la altura de su hitbox), golpe, recibir golpe y apuntar arma
- [x] El destello de golpe es `flash` (todo blanco) y no pisa el color
- [x] Test headless `scripts/test_fighter_rig.gd`
- [ ] Test manual en PC y teléfono: que cada animación se lea bien a escala real

## Detalles

- El rig lee del padre `is_on_floor()`, `velocity`, `is_crouching()`,
  `is_attacking()`, `is_in_hitstun()` y `weapons.has_weapon()`.
- Ángulos en radianes desde "colgando hacia abajo"; negativo = hacia adelante.
- `FighterRig.parts()` devuelve los polígonos de una pose: lo usan el dibujo
  y los tests (nada se sale del cuadro de 32x32; el pie más bajo apoya en y = 0).
- Cuando haya sprites de verdad, `Visual` puede pasar a ser un
  `AnimatedSprite2D` con los mismos nombres de animación (`Anim`).

## Evidencia

- Commit: `feat(player): draw fighters with animated native shapes`
- Memoria Engram: pendiente (sin acceso a Engram desde la sesión en la nube)
- Verificación: `tools/run_tests.sh` → todos los tests pasan; hoja de poses
  renderizada con Godot bajo Xvfb (adjunta en el PR)
