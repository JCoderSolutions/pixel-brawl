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
- [x] Responsive: toma el tamaño de vista cada tick (teléfono vertical/horizontal, PC)
- [x] Zoom pixel-perfect: cada píxel del mundo ocupa un número entero de píxeles de pantalla
- [x] Escena demo `scenes/camera/camera_demo.tscn` (mapa 960x544, P1 + 3 bots)
- [x] Integrar en `test_arena`: `arena_match.gd` suma cada jugador que aparece y hace `snap()` al empezar la ronda
- [x] Primer plano: `focus_on(punto, zoom, segundos)` encuadra un punto con
      más zoom y después vuelve a seguir a todos (golpe final). Test
      `scripts/test_spectacle.gd`
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
- **Pixel-perfect (`pixel_perfect_zoom`, activo por defecto):** el zoom se redondea
  a pasos `n / escala_de_pantalla` (la escala sale del stretch de la ventana). En
  1080p (4x) hay pasos 0.25, 0.5, 0.75, 1…; en una ventana 1x solo 1, 2, 3…, o sea
  que **sin resolución de pantalla de sobra no se puede alejar sin deformar los
  píxeles**. El zoom suavizado avanza a saltos en vez de deslizarse.
- **Mapa con otra forma que la pantalla (`letterbox_bounds`, activo):** en un
  teléfono vertical un mapa 16:9 se ve completo a lo ancho y centrado a lo alto;
  la franja sobrante muestra fondo en vez de cortar jugadores. Apagado, la vista
  nunca sale del mapa aunque eso deje jugadores fuera.
- Con sprites de 32x32 conviene `focus_offset` ≈ (0, -16) (pecho) y `margin` ≥ 1.5 sprites.
- En tests headless no hay ventana real: usar `screen_scale_override` para simular una.
- **Suavidad (estilo Superfighters):** pan y zoom van sobre un resorte críticamente
  amortiguado (`follow_time`, `follow_time_vertical`, `zoom_out_time`, `zoom_in_time`,
  en segundos): arranca suave y frena sin pasarse. Abre el zoom al instante y solo lo
  cierra si los jugadores siguen juntos `zoom_in_delay` (0.5 s), para que saltos y
  esquives no bombeen la cámara. El zoom pixel-perfect solo se aplica al valor de
  reposo; entre pasos se desliza. La posición se redondea a píxeles de pantalla, no
  del mundo. Medido en la demo (1200 ticks, 2x): antes el zoom saltaba 0.5 en un frame
  y el pan tenía tirones de 275 px/frame²; ahora 0.025 y 4 px/frame².
- No usa los `limit_*` nativos de Camera2D porque se comerían el shake.

## Evidencia

- Tests: `scripts/test_shared_camera.gd` (unitario) y `scripts/test_camera_demo.gd`
  (4 jugadores reales, 600 ticks: vista dentro del mapa y vivos en pantalla).
- `tools/run_tests.sh` con Godot 4.2.2: todos pasan.
- Capturas: `screenshots/camera/` en los archivos del proyecto.
- Memoria Engram: pendiente (Engram no es accesible desde sesiones cloud).
