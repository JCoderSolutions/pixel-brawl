---
type: "task"
status: "in-progress"     # allowed: todo | in-progress | done | discarded
priority: "high"
phase: "PHASE-2"
depends_on: "TASK-004, TASK-011"
source_memory_id: ""
discarded_reason: ""
---

# TASK-020 — Trampas y peligros del mapa

## Objetivo

Que los mapas maten como en Superfighters: huecos al vacío, pozos de fuego y
ácido, trampas que se accionan a golpes o a balazos, daño por caída y muerte
por aplastamiento. Todo el daño pasa por `HealthComponent`, así ragdoll, HUD,
rondas y sonido reaccionan sin saber que existen los peligros.

## Estado previo

- Solo existía la kill zone global de `GameManager` (`kill_zone_y = 400`),
  y solo para jugadores de una partida. No había daño por caída,
  aplastamiento, pozos ni trampas.

## Criterios de done

- [x] `HazardZone` (Area2D): vacío, fuego, ácido y pinchos; daño por segundo
      o muerte instantánea, empujón al entrar (el fuego te hace saltar),
      encendido por `trigger()` o en ciclos
- [x] Escenas: `void_zone`, `fire_pit`, `acid_pit`, `spike_trap`, `flame_jet`
- [x] `FallDamage`: componente hijo del jugador; aterrizar a más de 420 px/s
      (~6 tiles de caída) quita vida según la velocidad
- [x] `FallingBlock`: bloque colgado que suelta un interruptor; aplasta
      (mata) a quien está en el suelo, lastima por velocidad a quien está en
      el aire y no rompe los tiles donde cae
- [x] `TrapSwitch`: se acciona con golpe, bala o explosión (entra por su
      `Hurtbox`), con recarga o de un solo uso; llama `trigger()` en sus
      objetivos
- [x] Arena de prueba `scenes/hazards/hazards_test_arena.tscn`
- [x] Test headless `scripts/hazards/test_hazards.gd`
- [ ] Test manual: abrir la arena de peligros y probar cada trampa

## Detalles

| Peligro | Escena | Efecto |
| --- | --- | --- |
| Vacío | `void_zone.tscn` | muerte instantánea |
| Fuego | `fire_pit.tscn` | 60 hp/s y salto hacia arriba |
| Ácido | `acid_pit.tscn` | 80 hp/s, no te suelta |
| Pinchos | `spike_trap.tscn` | muerte instantánea |
| Lanzallamas | `flame_jet.tscn` | apagado; 90 hp/s por 1,5 s al accionarlo |
| Bloque que cae | `falling_block.tscn` | aplasta contra el suelo; en el aire, daño por velocidad |
| Interruptor | `trap_switch.tscn` | acciona sus `targets` al recibir un golpe |

- El origen de `HazardZone` y `FallingBlock` es su esquina superior
  izquierda, para alinearlos con celdas del `DestructibleMap` (celda × 16).
- Los pozos empiezan 4 px por debajo del borde del suelo para que caminar
  junto al borde no lastime.
- `FallDamage` va como nodo hijo en `player.tscn`; `player.gd` no cambió.
- Colores de marcador de posición (Endesga 32) hasta el pase de arte.

## Evidencia

- Commit: `feat(hazards): add pits, fall damage, crushing blocks and trap switches`
- Memoria Engram: pendiente (sin acceso a Engram desde la sesión en la nube)
- Verificación: `godot --headless --path . -s scripts/hazards/test_hazards.gd` →
  `OK: fall damage, void, fire, acid, spikes, flame jets, trap switches, crushing blocks and hazards arena verified`;
  `tools/run_tests.sh` → todos los tests pasan
- Capturas: `screenshots/peligros/arena.png`, `screenshots/peligros/trampas-activadas.png`
