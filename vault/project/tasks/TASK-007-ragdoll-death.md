---
type: "task"
status: "in-progress"     # allowed: todo | in-progress | done | discarded
priority: "medium"
phase: "PHASE-2"
depends_on: "TASK-003"
source_memory_id: ""
discarded_reason: ""
---

# TASK-007 — Ragdoll death

## Objetivo

Al morir, el personaje se convierte en un cuerpo físico que sale despedido en
la dirección del golpe final y queda tirado en el mapa, como en Superfighters.

## Criterios de done

- [x] `Ragdoll` (`scenes/effects/ragdoll.tscn`): cabeza, torso, 2 brazos y 2 piernas con `PinJoint2D`, formas nativas
- [x] `RagdollOnDeath`: nodo hijo que escucha `HealthComponent.died` sin tocar `player.gd`
- [x] El cuerpo sale en la dirección del knockback del golpe final
- [x] Los cuerpos chocan con el mapa pero no con jugadores ni hitboxes
- [x] Se desvanecen solos (`lifetime`, 0 = permanentes) y `restore()` para respawns
- [x] Escena de prueba propia `scenes/effects/ragdoll_test.tscn`
- [x] Test headless `scripts/test_ragdoll.gd`
- [ ] Test manual de sensaciones: el vuelo y la caída se ven bien
- [x] Enganchar `RagdollOnDeath` a `player.tscn`; la arena limpia los cuerpos al empezar cada ronda

## Detalles

- Capa de física nueva: **5 `debris`** (sin nombre aún en `project.godot`,
  que pertenece a otro hilo). Máscara 1: solo el mapa.
- `died` se emite dentro de `take_damage`, antes de que el `Hurtbox` aplique
  el knockback; por eso el spawn va con `call_deferred` y lee la velocidad ya
  con el golpe. Si no hay velocidad, usa `fallback_launch` alejándose del `source`.
- Para usarlo: instanciar `ragdoll_on_death.tscn` como hijo de cualquier
  personaje con `HealthComponent` y `Visual`. Toma el color del `Visual`.
- Ajustes en el inspector: `launch_multiplier`, `fallback_launch` (hook) y
  `lifetime`, `fade_time`, `spin_per_speed` (ragdoll).
- Godot 4.2 no tiene límites angulares en `PinJoint2D`: las extremidades giran
  libres y el cuerpo cae "desarmado". Si se quiere más rigidez, subir
  `angular_damp` o pasar a 4.3+.
- Para el arte: reemplazar el `Visual` de cada parte por un `Sprite2D`.

## Evidencia

- Commit: `feat(effects): add ragdoll death that launches along the killing blow`
- Memoria Engram: pendiente (sin acceso a Engram desde la sesión en la nube)
- Verificación: `godot --headless --path . -s scripts/test_ragdoll.gd` →
  `OK: ragdoll parts, joints, launch, floor rest, player pass-through, lifetime, spawn on death and restore verified`
- Capturas: `screenshots/ragdoll/vuelo.png`, `screenshots/ragdoll/reposo.png` (archivos del proyecto)
