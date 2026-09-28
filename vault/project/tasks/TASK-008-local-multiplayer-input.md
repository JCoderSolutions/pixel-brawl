---
type: "task"
status: "in-progress"     # allowed: todo | in-progress | done | discarded
priority: "high"
phase: "PHASE-2"
depends_on: "TASK-003"
source_memory_id: ""
discarded_reason: ""
---

# TASK-008 — Local 2-player split keyboard (input por jugador)

## Objetivo

Cada jugador lee su propio input, como base para multijugador local 2–4,
controles táctiles, bots y online con input determinista.

## Criterios de done

- [x] `InputFrame`: input de un tick como datos (eje cuantizado + botones), serializable a 16 bits
- [x] `InputSource` intercambiable: `DeviceInputSource` (slot local) y `ScriptedInputSource` (tests/replays)
- [x] `player.gd` lee de su `input_source`; los "just pressed" salen de frames consecutivos
- [x] Acciones `p1_*` … `p4_*` en `project.godot` (teclado dividido P1/P2 + un gamepad por slot)
- [x] Test headless `scripts/test_input.gd`
- [ ] Segundo jugador en la arena (lo resuelve el hilo del mapa, dueño de `test_arena.tscn`)
- [ ] Test manual: dos personas en un teclado sin que se pisen las teclas

## Detalles

- Controles por slot:

  | Slot | Mover | Saltar | Agacharse | Atacar | Gamepad |
  | --- | --- | --- | --- | --- | --- |
  | P1 | A / D | W / Espacio | S | J | #0 |
  | P2 | ← / → | ↑ | ↓ | Ctrl / Enter | #1 |
  | P3 | — | — | — | — | #2 |
  | P4 | — | — | — | — | #3 |

  Gamepad: stick izquierdo o d-pad para mover/agacharse, A o d-pad arriba
  para saltar, X para atacar.
- `player_slot` (1–4) elige qué acciones lee un player controlado. Si se le
  asigna `input_source` antes de entrar al árbol, se usa esa fuente (bot,
  red, replay) en vez del dispositivo.
- `is_controlled = false` sigue apagando el input (dummies).
- La lógica del player depende solo de la secuencia de `InputFrame`: dos
  players con los mismos frames terminan en el mismo lugar. Online (TASK-013)
  puede mandar `encode()` por tick y reproducir con `decode()`.
- Touch (TASK-015): los `TouchScreenButton` apuntan a las acciones `p1_*`, sin
  tocar el player.
- Se eliminaron las acciones globales `move_left`, `jump`, etc.; las flechas
  ahora son de P2.

## Evidencia

- Commit: `feat(input): give each player its own input source`
- Memoria Engram: pendiente (sin acceso a Engram desde la sesión en la nube)
- Verificación: `godot --headless --path . -s scripts/test_input.gd` →
  `OK: input frames, per-slot devices, per-player input, edge detection and determinism verified`
  (y `test_player`, `test_melee`, `verify_launch` siguen en verde)
