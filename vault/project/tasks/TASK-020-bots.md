---
type: "task"
status: "in-progress"     # allowed: todo | in-progress | done | discarded
priority: "high"
phase: "PHASE-3"
depends_on: "TASK-008, TASK-005, TASK-011"
source_memory_id: ""
discarded_reason: ""
---

# TASK-020 — Bots controlados por la computadora

## Objetivo

Poder jugar solo contra la computadora, como en Superfighters: bots que buscan
armas, se acercan, pelean cuerpo a cuerpo, disparan, esquivan granadas y no se
tiran a los huecos, con 3 niveles de dificultad.

## Criterios de done

- [x] `BotInputSource` (extiende `InputSource`) produce `InputFrame`s; el
      jugador no sabe si lo maneja un humano o un bot (determinista por seed)
- [x] `BotProfile` con Fácil / Normal / Difícil
- [x] Golpea, recoge armas, dispara, lanza granadas, usa katana
- [x] No camina a huecos ni a peligros (grupo `hazards`), salta huecos cortos,
      paredes y plataformas donde está su objetivo o un arma
- [x] Normal y Difícil huyen de granadas por explotar; Fácil no
- [x] `GameManager.configure_bots()` + spawns extra repartidos
- [x] Menú: "2 jugadores" o "Contra 1/2/3 bots" + dificultad
- [x] Escena de prueba `scenes/ai/bot_arena.tscn` (bots solos, para mirar y tunear)
- [x] Test headless `scripts/ai/test_bots.gd`
- [x] Saltan huecos de hasta 3 tiles (buscan aterrizaje a 56-80 px, hasta
      36 px más arriba) y bajan escalones de hasta 72 px (la caída duele desde
      ~98 px); cada bot piensa en un tick distinto según su semilla, así dos
      bots en espejo no se matan en el mismo frame (empates infinitos en fábrica)
- [ ] Test manual: la dificultad se siente bien en PC y teléfono

## Detalles

| Dificultad | Decide cada | Agresividad | Granadas | Prioridad a armas |
| --- | --- | --- | --- | --- |
| Fácil | 20 ticks | 45% | las ignora | baja |
| Normal | 10 ticks | 80% | huye con < 1.2 s de mecha | media |
| Difícil | 4 ticks | 100% | huye con < 2 s de mecha | alta |

- Movimiento y seguridad (bordes, peligros) corren cada tick; solo las
  decisiones (a quién perseguir, cuándo pegar) esperan `think_interval`.
- Trampas/peligros nuevos: agregar el nodo (Area2D o cuerpo) al grupo
  `hazards` y el bot trata ese suelo como un hueco.
- Los bots ocupan los ids después de los humanos; con más jugadores que
  markers, `GameManager.spread_spawns()` reparte los extra entre el primero y
  el último.

## Evidencia

- Commit: `feat(ai): add computer-controlled bots with three difficulties`
- Memoria Engram: pendiente (sin acceso a Engram desde la sesión en la nube)
- Verificación: `godot --headless --path . -s scripts/ai/test_bots.gd` → OK;
  `tools/run_tests.sh` → todos los tests pasan. Simulación 45 s con
  Difícil/Fácil/Normal: Difícil gana 3-0.
- Capturas: `screenshots/bots/menu.png`, `screenshots/bots/pelea.png`
