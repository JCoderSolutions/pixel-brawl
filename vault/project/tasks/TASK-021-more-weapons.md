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
