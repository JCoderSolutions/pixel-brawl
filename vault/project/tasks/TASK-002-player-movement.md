---
type: "task"
status: "in-progress"
priority: "high"
phase: "PHASE-1"
---

# TASK-002 — Player movement (run/jump/crouch)

## Objetivo

Personaje jugable que corre, salta y agacha con física cómoda (feel over perfect).

## Criterios de done

- [x] Script `player.gd` con `move_and_slide` + gravedad ajustable
- [x] Cuelga del mapa: colisiones con las plataformas
- [x] Flip horizontal según dirección
- [x] Salto variable estilo Superfighters: soltar el salto mientras sube lo
      corta (`jump_cut` 0.45: un toque salta ~18 px, 6 frames ~41 px, mantenido ~60 px) y la caída
      usa gravedad x1.4 (`fall_gravity_multiplier`). Los empujes de golpes y
      explosiones no se cortan. `FallDamage.safe_speed` pasa a 500 para que
      caer 6 tiles siga sin doler; los bots mantienen el salto hasta la cima.
      Test headless `scripts/test_jump.gd`
- [ ] Test manual del salto variable en PC y teléfono
- [x] Zambullida estilo Superfighters (pedido de Jose, 2026-09-28): agacharse
      corriendo (>= 80 % de `run_speed`) tira al luchador hacia adelante
      (250 px/s, saltito bajo), agachado, sin dirección ni salto hasta que
      aterriza; los primeros 0.3 s no lo tocan golpes ni balas y aterriza sin
      daño por caída. Pose `DIVE` en el rig. Test `scripts/test_dive.gd`
- [ ] Test manual de la zambullida en PC y teléfono
- [ ] Rápido test manual: moverse con WASD (P1) se siente responsivo (las flechas son de P2 desde TASK-008)