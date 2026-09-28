---
type: "task"
status: "in-progress"     # allowed: todo | in-progress | done | discarded
priority: "high"
phase: "PHASE-2"
depends_on: "TASK-004, TASK-005"
source_memory_id: ""
discarded_reason: ""
---

# TASK-006 — Grenade + explosion destroys tiles

## Objetivo

Una granada que se lanza, rebota por el mapa y explota al terminar la mecha:
daña y empuja a los jugadores cercanos y rompe los bloques del mapa usando
`DestructibleMap.damage_area()` de TASK-004.

## Criterios de done

- [x] `GrenadeData` (extiende `WeaponData`): la granada es un `.tres` más del
      sistema de armas y sale del `WeaponSpawner`
- [x] `WeaponHolder.try_use()` lanza la granada según `facing`
- [x] `Grenade` (RigidBody2D) rebota en el mapa, atraviesa jugadores y se
      frena en el piso; la luz de la mecha parpadea más rápido al final
- [x] `Explosion`: daño con caída por distancia, knockback hacia afuera con
      empuje hacia arriba, un solo golpe por `HealthComponent`
- [x] La explosión rompe bloques con `damage_area` (los indestructibles no)
- [x] Escena de prueba `scenes/items/grenade_test_arena.tscn`
- [x] Test headless `scripts/weapons/test_grenades.gd`
- [ ] Integrar en `player.gd` / `test_arena` (lo hace el hilo de integración)
- [ ] Test manual: lanzar, rebotar y volar la pared se siente bien

## Detalles

- Valores de `grenade.tres`: 3 granadas, mecha 2 s, lanzamiento (260, -220),
  radio 40 px, 45 de daño en el centro y 35 % en el borde, 30 de daño a
  bloques (rompe cualquier bloque que toque el radio).
- La granada es layer 0 / mask 1, como los pickups: no choca con jugadores
  ni balas. `lock_rotation` + fricción 1 para que se frene en vez de rodar.
- `Explosion.detonate()` busca `Hurtbox` en el radio (layer 4) con una query
  de círculo. Ignora los de `DestructibleBlock`: los bloques reciben daño solo
  por `DestructibleMap.damage_area()` para no pegarles dos veces.
- El daño a jugadores respeta la invulnerabilidad del player (su `Hurtbox`
  deja de ser `monitorable`). El que lanza también se daña si está cerca.
- Único cambio fuera de archivos nuevos: rama `GrenadeData` en
  `WeaponHolder.try_use()` + `_throw()`.
- Visual provisorio: círculo verde con mecha naranja y flash naranja (Endesga
  32 `63c74d`, `feae34`).

## Evidencia

- Commit: `feat(weapons): add throwable grenades that explode and break tiles`
- Memoria Engram: pendiente (sin acceso a Engram desde la sesión en la nube)
- Verificación: `godot --headless --path . -s scripts/weapons/test_grenades.gd` →
  `OK: grenade data, throw, fuse, bounce, damage falloff, knockback, block destruction, player launch and full throw-to-hole verified`
- Capturas: `screenshots/granada/explosion.png`, `screenshots/granada/hueco.png`
