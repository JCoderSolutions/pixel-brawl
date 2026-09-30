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
- [x] Rodada y zambullida en el aire (feedback de Jose 2026-09-29: "no veo
      que pueda correr y lanzarme para rodar"): la zambullida arranca desde el
      35 % de `run_speed` (antes 80 %, casi imposible con el stick táctil),
      al aterrizar sigue rodando por el piso (0.3 s a 210 px/s, agachado,
      0.15 s sin recibir golpes) y en el aire agacharse con dirección se
      zambulle una vez por salto. Pose `ROLL` (el cuerpo gira). Test
      `scripts/test_dive.gd`
- [x] Movilidad de Superfighters (punto 2 del análisis de dinamismo, Jose
      2026-09-29): doble toque de dirección (en 0.25 s) corre a sprint (x1.45)
      mientras se mantiene; caer empujando contra una pared cuyo borde queda a
      la altura de las manos agarra la cornisa (pose `HANG`): Saltar trepa
      (90 % del salto), Agacharse o empujar al otro lado suelta; agacharse
      hasta 0.25 s antes de aterrizar hace una rodada de recuperación sin daño
      por caída (`FallDamage` ignora rodadas). Los bots trepan si quedan
      colgados. Test `scripts/test_mobility.gd`
- [x] Barrido más natural (feedback de Jose 2026-09-30: "se desplaza
      mucho"): la zambullida termina apenas toca el piso (antes se deslizaba
      a 250 px/s hasta cumplir 0.4 s) y la rodada frena de 170 a 60 px/s en
      0.25 s. Todo el movimiento pasó de ~177 px a ~76 px. El test de
      `scripts/test_dive.gd` exige que quede entre 50 y 110 px
- [ ] Test manual de la zambullida en PC y teléfono
- [ ] Rápido test manual: moverse con WASD (P1) se siente responsivo (las flechas son de P2 desde TASK-008)
- [x] Cornisas solo en el borde real (feedback de Jose 2026-09-30: "se
      agarra de diversos puntos, no es consistente"): las paredes son bloques
      de 16 px apilados y la sonda que busca el borde ignoraba el bloque
      donde arrancaba, así que la unión con el bloque de abajo contaba como
      cornisa. Saltando contra una pared un poco más alta que el alcance, el
      luchador quedaba colgado un bloque debajo del borde. Ahora las sondas
      cuentan el bloque donde arrancan (`hit_from_inside`). Test
      `scripts/test_mobility.gd`
- [x] Cornisas solo del mapa (feedback de Jose 2026-09-30: "se sigue
      subiendo donde no debe, cajas y demás"): cajas de suministro, barriles
      y bloques que caen comparten la capa del mapa, así que el luchador se
      colgaba de ellos (hasta de una caja cayendo). Ahora solo cuelga de
      `StaticBody2D`/`TileMap`, y si el bloque se rompe mientras cuelga, cae.
      Tests en `scripts/test_mobility.gd`
