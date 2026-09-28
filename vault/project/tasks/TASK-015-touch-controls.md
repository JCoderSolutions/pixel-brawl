---
type: "task"
status: "in-progress"     # allowed: todo | in-progress | done | discarded
priority: "high"
phase: "PHASE-4"
depends_on: "TASK-008"
source_memory_id: ""
discarded_reason: ""
---

# TASK-015 — Touch controls

## Objetivo

Jugar desde el teléfono (build Web en GitHub Pages) con controles en pantalla
que alimentan las mismas acciones `p1_*` que el teclado y el gamepad.

## Criterios de done

- [x] Stick flotante a la izquierda: mueve (`p<slot>_move_left/right` con fuerza analógica) y agacha al tirar hacia abajo
- [x] Botones Golpe, Salto, Disparar y Coger (`p<slot>_attack/jump/fire/pickup`), multitoque
- [x] Solo aparecen en pantallas táctiles (o con el primer toque); `ALWAYS`/`NEVER` para pruebas
- [x] Layout calculado desde el tamaño visible: escala con la resolución, horizontal y vertical
- [x] Escena de prueba `scenes/ui/touch/touch_test.tscn` (el mouse hace de dedo en PC)
- [x] Test headless `scripts/test_touch_controls.gd`
- [x] Instanciar `scenes/ui/touch/touch_controls.tscn` en la escena de partida (P1, modo AUTO)
- [x] `p1_fire`/`p1_pickup` en `project.godot` con teclas y leídas por `DeviceInputSource` (llegó por main)
- [x] Vertical real: `window/stretch/aspect="expand"` en `project.godot` (llegó con PR #10)
- [ ] Test manual en un teléfono real (tamaño de botones, zona del stick)

## Detalles

- Sin código táctil en el player: `VirtualJoystick` y `TouchActionButton` hacen
  `Input.action_press/release`, y `DeviceInputSource` los lee como cualquier
  otro dispositivo. Así el input sigue siendo un `InputFrame` determinista.
- Cada control guarda el índice de su dedo: stick + salto + golpe a la vez.
  Un dedo que se desliza fuera del botón lo mantiene hasta levantarse.
- Ocultar o liberar la escena suelta todas las acciones (nunca queda una
  tecla "pegada").
- `fire`/`pickup` se crean vacías en runtime si faltan, como en `weapons_demo.gd`.
- Tamaños en unidades de 270 px (lado corto): 480x270 = 1:1, 1920x1080 = 4x.
- Tests headless: los eventos se inyectan con `root.push_input(event, true)`;
  sin `true` Godot los reescala por el stretch de la ventana y no caen donde
  se espera.

## Evidencia

- Commit: `feat(input): add touch controls for phones`
- Memoria Engram: pendiente (sin acceso a Engram desde la sesión en la nube)
- Verificación: `godot --headless --path . -s scripts/test_touch_controls.gd` →
  `OK: touch stick math, layout in landscape/portrait, visibility, per-slot actions, multi-touch and player movement verified`
- Capturas: `screenshots/touch/horizontal.png`, `screenshots/touch/vertical.png` (carpeta del proyecto)
