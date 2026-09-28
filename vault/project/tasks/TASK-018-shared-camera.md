---
type: "task"
status: "in-progress"
priority: "high"
phase: "PHASE-2"
depends_on: "TASK-008"
source_memory_id: ""
discarded_reason: ""
---

# TASK-018 — Cámara compartida (2–4 jugadores locales)

## Objetivo

Una sola cámara que encuadra a todos los jugadores vivos en pantalla: sigue su
centro, hace zoom para que quepan, nunca muestra fuera del mapa y tiembla con
golpes y explosiones.

## Criterios de done

- [x] `SharedCamera` (`scripts/camera/shared_camera.gd`, escena `scenes/camera/shared_camera.tscn`)
- [x] Sigue el centro de los objetivos vivos (ignora muertos, ocultos y liberados)
- [x] Zoom para que quepan todos, entre `min_zoom` y `max_zoom`, y nunca más grande que `bounds`
- [x] La vista nunca sale de `bounds`, tampoco durante el shake
- [x] Screen shake por trauma reutilizable: `SharedCamera.shake(nodo, 0..1)`
- [x] Golpes a un objetivo suman trauma solos (`trauma_per_damage`)
- [x] Escena demo `scenes/camera/camera_demo.tscn` (mapa 960x544, P1 + 3 bots)
- [ ] Integrar en `test_arena` / flujo de partida (lo hace el hilo de integración)
- [ ] Test manual de sensación (suavizado, fuerza del shake)

## Uso

```gdscript
var cam: SharedCamera = preload("res://scenes/camera/shared_camera.tscn").instantiate()
cam.bounds = Rect2(0, 0, 960, 544)   # rect jugable del mapa
arena.add_child(cam)
for p in players: cam.add_target(p)  # o cam.target_group = &"players"
cam.make_current()
cam.snap()                           # al empezar ronda / respawn
# Explosión (TASK-006):
SharedCamera.shake(self, 0.8)
```

## Detalles

- Corre en `_physics_process`, igual que los jugadores, para que no haya jitter.
- `pixel_snap` redondea la posición a píxeles enteros del mundo.
- El límite del mapa gana sobre `min_zoom`: si el mapa es más chico que
  `vista / min_zoom`, jugadores muy separados pueden quedar fuera. Diseñar mapas
  pensando en 16:9 (960x544 permite zoom 0.5). `test_arena` (480x270) queda fijo
  en zoom ≥ 1: solo acerca.
- Contra un borde, el shake rebota hacia adentro en lugar de perderse en el clamp.
- No usa los `limit_*` nativos de Camera2D porque se comerían el shake.

## Evidencia

- Tests: `scripts/test_shared_camera.gd` (unitario) y `scripts/test_camera_demo.gd`
  (4 jugadores reales, 600 ticks: vista dentro del mapa y vivos en pantalla).
- `tools/run_tests.sh` con Godot 4.2.2: todos pasan.
- Capturas: `screenshots/camera/` en los archivos del proyecto.
- Memoria Engram: pendiente (Engram no es accesible desde sesiones cloud).
