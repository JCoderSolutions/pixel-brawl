---
type: "phase"
status: "in-progress"
project: "pixel-brawl"
phase_id: "PHASE-1"
goals: "Core mechanics: movimiento, combate básico, mapa destructible, export web"
---

# PHASE-1 — Core mechanics

## Objetivos de la fase

- Setup Godot 4 con pixel-perfect
- Player: run / jump / crouch
- Combate básico: melee punch + 1 ranged
- 1 mapa con bloques destructibles

## Tareas

- [x] [[project/tasks/TASK-001-setup-godot-project|TASK-001 — Setup Godot project]] — `done`
- [ ] [[project/tasks/TASK-002-player-movement|TASK-002 — Player movement]] — `in-progress`
- [ ] [[project/tasks/TASK-003-melee-combat|TASK-003 — Basic melee combat]] — `in-progress`
- [ ] [[project/tasks/TASK-004-destructible-tiles|TASK-004 — Destructible tile layer]] — `in-progress`

## Criterio de salida

Código listo; falta el test manual: [[docs/manual-test-checklist]] (sesión 1).


- [ ] Player se mueve y pega
- [ ] Un mapa con plataformas que explotan se destruye
- [x] Export a Web funcional en browser (Pages, TASK-017; Jose jugó la versión web 2026-09-30)