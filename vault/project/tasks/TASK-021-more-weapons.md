---
type: "task"
status: "in-progress"     # allowed: todo | in-progress | done | discarded
priority: "high"
phase: "PHASE-2"
depends_on: "TASK-005, TASK-006"
source_memory_id: ""
discarded_reason: ""
---

# TASK-021 — Más armas (rifle, escopeta recortada, bate, bazuca)

## Objetivo

Ampliar el arsenal al estilo Superfighters sin código nuevo por arma: cada
arma es un `.tres` en `scripts/weapons/data/`.

## Criterios de done

- [x] Rifle de asalto automático (dispara mientras se mantiene el botón)
- [x] Escopeta recortada: más perdigones, menos alcance, 2 cartuchos
- [x] Bate: melee que pega menos que la katana pero lanza más lejos
- [x] Bazuca: cohete recto (`GrenadeData.explode_on_contact`, `gravity_scale 0`)
      que explota al tocar pared, suelo o luchador y rompe el mapa con `Explosion`
- [x] Las 4 están en el pool por defecto de `weapon_spawner.tscn`
- [x] Test headless `scripts/weapons/test_new_weapons.gd`
- [x] Agregarlas al pool de cada mapa (`test_arena` y los 4 mapas temáticos
      sobrescriben `weapons`)
- [x] Armas sin munición y lanzar armas (Superfighters, pedido de Jose
      2026-09-29): las armas de fuego y la bazuca quedan vacías en la mano
      (`WeaponHolder.is_empty()`); el gatillo solo hace "clic" (`dry_fire`) y
      muestra "SIN BALAS". El botón Agarrar lanza el arma si no hay nada que
      agarrar: vuela recta y hace `throw_damage` (katana 22, bate 18, resto 12)
      al primero que toca, nunca a quien la lanzó. Las vacías lanzadas
      desaparecen al caer; las cargadas quedan en el piso. Los bots lanzan sus
      armas vacías. Test `scripts/weapons/test_throw.gd`
- [x] Cubrirse (Superfighters, pedido de Jose 2026-09-29): el botón "fire"
      (Disparar) pasa a ser Cubrirse (`InputFrame.BLOCK`); disparar es con
      Golpear. Cubierto, el luchador se planta y los golpes y armas lanzadas
      de frente no hacen daño (`Hurtbox.receive_hit` pregunta a
      `player.guard()`); las balas pasan. Con un arma de metal (katana,
      `WeaponData.metal`) un bloqueo de menos de 0.25 s devuelve la bala al
      que disparó (`Projectile._deflect`). Pose `BLOCK`. Test `scripts/test_block.gd`
- [x] Cubrirse ya no es infinito (feedback de Jose 2026-09-29): pasa el 25 %
      del daño (`block_chip`) y cada golpe gasta energía de guardia
      (`block_hit_cost` 0.03 por punto de daño, más 0.12/s mantenido). Sin
      energía la guardia se rompe: 0.8 s aturdido y no se puede cubrir hasta
      recuperar el 35 % (se recarga 0.35/s). Barra de energía sobre la
      cabeza mientras no está llena. Test `scripts/test_block.gd`
- [x] Montarse en el cohete (Superfighters, pedido de Jose 2026-09-29): si
      el cohete de la bazuca le pega a un luchador (no al que disparó), lo
      engancha y se lo lleva; el jinete lo dirige con izquierda/derecha
      (derecha = horario, 3 rad/s, misma velocidad). Al tocar pared, suelo u
      otro luchador explota: el jinete muere y la explosión daña a los
      cercanos; tras 3 s sin chocar explota solo. Montado, el cohete ya puede
      volver contra quien lo disparó. Los bots montados lo apuntan a su rival
      (las vueltas en U, por arriba). Pose `RIDE`. Test
      `scripts/weapons/test_rocket_ride.gd`
- [x] Cohete controlable y dentro de la vista (feedback de Jose 2026-09-30:
      "me salí por arriba del mapa y si no veo no puedo controlar"): montado,
      el cohete baja al 60 % de la velocidad del disparo (420 → ~250 px/s) y
      gira a 2 rad/s (antes 3). Da más tiempo para reaccionar sin que sea más
      fácil devolverlo: el radio de giro queda casi igual. Todo cohete explota
      al llegar a 8 px del borde de lo que puede mostrar la cámara
      (`SharedCamera.bounds`), como si chocara contra una pared, así que el
      jinete nunca sale de la pantalla
- [x] Molotov (punto 4 del orden acordado con Jose 2026-09-29): botella que
      se rompe al tocar pared, piso o luchador, prende fuego a los que agarra
      y deja un charco de fuego de 64 px por 5 s (20 de daño por segundo) en
      el piso de abajo. 2 por recogida. `GrenadeData.fire_width`,
      `fire_time`, `fire_damage_per_second`, `ignite_time`; solo los cohetes
      (`is_rocket()`) se montan y quedan en la mano vacíos. En el pool de
      todos los mapas. Test `scripts/hazards/test_fire.gd`
- [x] Las balas le pegan a cualquier cuerpo con Hurtbox (barriles, cajas),
      no solo a los bloques del mapa
- [ ] Test manual del balance en PC y teléfono

## Detalles

| Arma | Daño | Munición | Rasgo |
| --- | --- | --- | --- |
| Rifle de asalto | 7 x bala | 30 | automático, 0.1 s entre tiros |
| Escopeta recortada | 9 x 8 perdigones | 2 | cono de 36°, alcance 110 px |
| Bate | 18 | ilimitada | knockback (360, -220) |
| Bazuca | 55 (explosión r 52) | 2 | rompe ladrillo, explota al contacto |

- El cohete ignora a quien lo dispara (`add_collision_exception_with`).
- `Grenade.setup()` ahora teletransporta el cuerpo físico: antes el primer paso
  arrancaba desde el origen del mundo y podía chocar con el mapa ahí.

## Evidencia

- Commit: `feat(weapons): add assault rifle, sawed-off, bat and bazooka`
- Memoria Engram: pendiente (sin acceso a Engram desde la sesión en la nube)
- Verificación: `tools/run_tests.sh` → todos los tests pasan
- Captura: `screenshots/powerups/bazuca-pared.png` (el cohete rompe una columna de ladrillo)
