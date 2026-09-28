---
type: "task"
status: "in-progress"     # allowed: todo | in-progress | done | discarded
priority: "high"
phase: "PHASE-3"
depends_on: "TASK-003"
source_memory_id: ""
discarded_reason: ""
---

# TASK-011 — HUD + rounds + winner

## Objetivo

Una partida completa: rondas a "último en pie", respawn, barras de vida,
pantalla de ganador con revancha y un menú simple para entrar a jugar.

## Criterios de done

- [x] Autoload `GameManager` con estados IDLE → ROUND_STARTING → FIGHTING → ROUND_OVER → MATCH_OVER
- [x] Rondas al mejor de `rounds_to_win` (3 por defecto), empate si caen juntos dentro de `round_end_grace`
- [x] Respawn: cada ronda re-instancia a los jugadores; con `lives_per_round > 1` reaparecen en su spawn
- [x] Kill zone (`kill_zone_y`) para quien cae del mapa
- [x] HUD (`scenes/ui/hud.tscn`): barra de vida y marcador por jugador, banner de ronda/pelea/ganador
- [x] Pantalla de ganador con Revancha y Menú; menú principal con Jugar / Salir
- [x] Partida en `scenes/maps/test_arena.tscn` (`arena_match.gd`); `match_sandbox` se retiró
- [x] Test headless `scripts/test_game_manager.gd`
- [x] Test manual: Jose jugó una partida entera con armas y menú (2026-09-28); tiempos de pausa sin cambios por ahora
- [x] `run/main_scene` es el menú; Jugar abre la arena

## Detalles

- El manager solo escucha `HealthComponent.died`; no toca el código del player.
- Los jugadores se re-instancian en vez de "revivirse": una escena nueva
  resetea vida, hitstun y color sin que el manager conozca esos detalles.
- La UI (HUD, ganador) solo escucha señales del manager; se le puede inyectar
  otra instancia (`hud.manager = ...`), así se testea sin el autoload.
- `advance(delta)` es público para que los tests manejen el tiempo a mano.
- La arena pone `controlled_ids = [0, 1]` y el manager asigna `player_slot = id + 1`,
  así P1 y P2 juegan en local. El default del autoload sigue en `[0]`.
- `project.godot`: solo se agregó la sección `[autoload]`.

## Evidencia

- Commit: `feat(match): add round flow with HUD, winner screen and main menu`
- Memoria Engram: pendiente (sin acceso a Engram desde la sesión en la nube)
- Verificación: `godot --headless --path . -s scripts/test_game_manager.gd` →
  `OK: match start, rounds, next round respawn, match end, draw, lives respawn, kill zone, rematch, HUD, winner screen and menu verified`
- Capturas: `screenshots/rondas-hud/` en los archivos del proyecto
