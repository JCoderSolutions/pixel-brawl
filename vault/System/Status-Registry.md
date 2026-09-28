---
type: "status-registry"
project: "pixel-brawl"
last_updated: "2026-09-28"
---

# Status Registry — Pixel Brawl

Estado vivo del proyecto. Se actualiza con CADA cambio de status de cualquier
tarea o fase. Es el primer lugar donde un agente mira el estado global.

## Estado global del proyecto

**`in-progress`** — Fase 1 (core mechanics).

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

## Tareas por desglosar (backlog)

| Tarea | Fase |
| --- | --- |
| TASK-005 — Weapon spawn and pickup | PHASE-2 |
| TASK-006 — Grenade + explosion destroys tiles | PHASE-2 |
| TASK-008 — Local 2-player split keyboard | PHASE-2 |
| TASK-007 — Ragdoll death | PHASE-2 |
| TASK-009 — Map set (4+ maps) | PHASE-3 |
| TASK-010 — Power-up system | PHASE-3 |
| TASK-011 — HUD + rounds + winner | PHASE-3 |
| TASK-012 — SFX + chiptune | PHASE-3 |
| TASK-013 — WebRTC host/join | PHASE-4 |
| TASK-014 — Lobby con código de sala | PHASE-4 |
| TASK-015 — Touch controls | PHASE-4 |
| TASK-016 — Build + publish itch.io | PHASE-4 |

## Decisiones

| Decisión | Status |
| --- | --- |
| Stack: Godot 4 + Endesga 32 + pipeline AI | `approved` (ver [[PLAN-pixel-brawl|PLAN]]) |

## Descartadas

Nada descartado aún.

## Cómo actualizar

Al cambiar cualquier status: marcar en la nota correspondiente (frontmatter +
checkbox) y reflejar acá. Esto es manual — no hay script.