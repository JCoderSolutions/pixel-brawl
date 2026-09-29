---
type: "status-registry"
project: "pixel-brawl"
last_updated: "2026-09-29"
last_updated_notes: "TASK-011 menú en secuencia (modo, cantidad, personajes/equipos, mapa, dificultad, rondas) en progreso"
last_updated_notes: "TASK-011 muerte súbita: las partidas contra bots siempre terminan"
last_updated_notes: "TASK-022 festejo del ganador y efecto al agarrar power-ups"
last_updated_notes: "TASK-022 armas dibujadas con formas nativas (mano y piso)"
last_updated_notes: "TASK-012 menú de opciones (volumen, pantalla completa, táctil) en progreso"
last_updated_notes: "TASK-022 luchador animado con formas nativas en progreso"
last_updated_notes: "TASK-012 música chiptune (menú y partida) en progreso"
last_updated_notes: "TASK-009/TASK-021 armas nuevas en los mapas y bots que saltan pozos (CI verde)"
last_updated_notes: "TASK-020 trampas y peligros en progreso"
last_updated_notes: "TASK-020 bots en progreso"
last_updated_notes: "TASK-009 set de mapas en progreso"
last_updated_notes: "TASK-010 power-ups y TASK-021 más armas en progreso"
---

# Status Registry — Pixel Brawl

Estado vivo del proyecto. Se actualiza con CADA cambio de status de cualquier
tarea o fase. Es el primer lugar donde un agente mira el estado global.

## Estado global del proyecto

**`planned`** — Fase 1 (core mechanics).

## Fases

| Fase | Estado | Nota |
| --- | --- | --- |
| [[project/phases/PHASE-1-core|PHASE-1 — Core mechanics]] | `in-progress` | TASK-002, TASK-003 y TASK-004 esperan test manual |
| [[project/phases/PHASE-2-caos|PHASE-2 — Items y caos]] | `planned` | Espera PHASE-1 |
| [[project/phases/PHASE-3-content|PHASE-3 — Content + polish]] | `planned` | Espera PHASE-2 |
| [[project/phases/PHASE-4-multiplayer|PHASE-4 — Multiplayer + deploy]] | `planned` | Espera PHASE-3 |

## Tareas activas

| Tarea | Status | Prioridad | Fase |
| --- | --- | --- | --- |
| [[project/tasks/TASK-001-setup-godot-project|TASK-001 — Setup Godot]] | `done` | high | PHASE-1 |
| [[project/tasks/TASK-002-player-movement|TASK-002 — Player movement]] | `in-progress` | high | PHASE-1 |
| [[project/tasks/TASK-017-ci-web-build|TASK-017 — CI + build Web en Pages]] | `in-progress` | high | PHASE-4 |
| [[project/tasks/TASK-003-melee-combat|TASK-003 — Basic melee combat]] | `in-progress` | high | PHASE-1 |
| [[project/tasks/TASK-007-ragdoll-death|TASK-007 — Ragdoll death]] | `in-progress` | medium | PHASE-2 |
| [[project/tasks/TASK-008-local-multiplayer-input|TASK-008 — Input por jugador]] | `in-progress` | high | PHASE-2 |
| [[project/tasks/TASK-004-destructible-tiles|TASK-004 — Destructible tile layer]] | `in-progress` | high | PHASE-1 |
| [[project/tasks/TASK-018-shared-camera|TASK-018 — Cámara compartida]] | `in-progress` | high | PHASE-2 |
| [[project/tasks/TASK-015-touch-controls|TASK-015 — Touch controls]] | `in-progress` | high | PHASE-4 |
| [[project/tasks/TASK-006-grenade-explosion|TASK-006 — Grenade + explosion]] | `in-progress` | high | PHASE-2 |
| [[project/tasks/TASK-005-weapons-and-projectiles|TASK-005 — Armas y proyectiles]] | `in-progress` | high | PHASE-2 |
| [[project/tasks/TASK-011-rounds-hud-winner|TASK-011 — HUD + rondas + ganador]] | `in-progress` | high | PHASE-3 |
| [[project/tasks/TASK-012-sfx-game-feel|TASK-012 — SFX + game feel]] | `in-progress` | high | PHASE-3 |
| [[project/tasks/TASK-019-block-materials|TASK-019 — Materiales de bloque + arena destructible]] | `in-progress` | high | PHASE-2 |
| [[project/tasks/TASK-020-hazards-traps|TASK-020 — Trampas y peligros del mapa]] | `in-progress` | high | PHASE-2 |
| [[project/tasks/TASK-020-bots|TASK-020 — Bots (IA) con 3 dificultades]] | `in-progress` | high | PHASE-3 |
| [[project/tasks/TASK-009-map-set|TASK-009 — Set de mapas temáticos]] | `in-progress` | high | PHASE-3 |
| [[project/tasks/TASK-021-more-weapons|TASK-021 — Más armas (rifle, recortada, bate, bazuca)]] | `in-progress` | high | PHASE-2 |
| [[project/tasks/TASK-010-power-ups|TASK-010 — Power-ups]] | `in-progress` | high | PHASE-3 |
| [[project/tasks/TASK-022-fighter-animations|TASK-022 — Luchador animado (formas nativas)]] | `in-progress` | high | PHASE-3 |

## Tareas por desglosar (backlog)

| Tarea | Fase |
| --- | --- |
| TASK-005 — Weapon spawn and pickup | PHASE-2 |
| TASK-006 — Grenade + explosion destroys tiles | PHASE-2 |
| TASK-008 — Local 2-player split keyboard | PHASE-2 |
| TASK-007 — Ragdoll death | PHASE-2 |
| TASK-010 — Power-up system | PHASE-3 |
| TASK-009 — Map set (4+ maps) | PHASE-3 |
| TASK-013 — WebRTC host/join | PHASE-4 |
| TASK-014 — Lobby con código de sala | PHASE-4 |
| TASK-016 — Build + publish itch.io | PHASE-4 |

## Decisiones

| Decisión | Status |
| --- | --- |
| Stack: Godot 4 + Endesga 32 + pipeline AI | `approved` (ver [[PLAN-pixel-brawl|PLAN]]) |
| Multiagente: OpenCode + Claude Code + Kiro | `approved` (ver [[docs/multi-agent-setup]]) |
| Engram: guardado solo con aprobación humana | `approved` (ver [[docs/engram-quick-reference]]) |

## Descartadas

Nada descartado aún.

## Cómo actualizar

Al cambiar cualquier status: marcar en la nota correspondiente (frontmatter +
checkbox) y reflejar acá. Esto es manual — no hay script.