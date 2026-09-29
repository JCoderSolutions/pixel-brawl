---
type: "task"
status: "in-progress"     # allowed: todo | in-progress | done | discarded
priority: "high"
phase: "PHASE-2"
depends_on: "TASK-003"
source_memory_id: ""
discarded_reason: ""
---

# TASK-005 — Weapon spawn, pickup and projectiles

## Objetivo

Armas como datos (pistola, escopeta, katana) que se recogen, se sueltan,
aparecen al azar en el mapa y hacen daño por el mismo pipeline de TASK-003.

## Criterios de done

- [x] `WeaponData` (Resource): un arma nueva es un `.tres`, no código nuevo
- [x] Pistola, escopeta (6 perdigones en cono) y katana en `scripts/weapons/data/`
- [x] `Projectile` por raycast: no atraviesa paredes, alcance máximo, nunca golpea al tirador
- [x] Katana reutiliza `Hitbox`; balas golpean `Hurtbox` → `HealthComponent`
- [x] Munición: el arma vacía se descarta; al soltar conserva la munición
- [x] `WeaponHolder`: recoger el más cercano, cambiar (suelta el actual), soltar con impulso
- [x] `WeaponSpawner`: aparición aleatoria en `Marker2D`, `max_active`, semilla reproducible
- [x] Escena jugable `scenes/items/weapons_test_arena.tscn`
- [x] Test headless `scripts/weapons/test_weapons.gd`
- [x] Integrar `WeaponHolder` en `player.gd` y acciones `p1..p4_fire`/`p1..p4_pickup` en `project.godot`
  (P1 K/L, P2 punto/coma o numpad 1/2, mando RB/Y; el HUD muestra arma y munición)
- [ ] Test manual de sensaciones (cadencia, daño, retroceso)

## Detalles

- `WeaponHolder` es un componente: se agrega como hijo de cualquier cuerpo
  a la altura de la mano. El dueño sincroniza `facing` y llama `try_use()`,
  `try_pick_up()` y `drop()`. Así sirve igual para player, bots y peers remotos.
- Proyectiles sin Area2D: cada frame lanzan un rayo sobre el tramo recorrido
  (máscara 1 mundo + 4 hurtboxes), así una bala rápida no atraviesa paredes
  finas. Emiten `impacted(point, collider)` para los tiles destructibles de TASK-004.
- Un `Hurtbox` con `monitorable = false` (i-frames o muerto) no recibe balas.
- Pickups: `RigidBody2D` en capa 0, máscara 1. Caen y rebotan pero no bloquean
  jugadores ni balas; se encuentran por el grupo `weapon_pickups` y distancia,
  sin gastar una capa de física.
- Perdigones repartidos de forma uniforme en el cono (sin jitter): la
  escopeta siempre se lee igual y los tests son deterministas.
- En la escena de prueba las acciones `fire` (K/X) y `pickup` (L/E) se crean
  en runtime para no tocar `project.godot` mientras otras tareas lo editan.

## Apuntar a mano (2026-09-29)

- [x] Punto 3 del análisis de dinamismo: con pistola, rifle, escopeta,
      granada o bazuca en la mano, mantener Cubrirse apunta en vez de cubrir
      (Superfighters). El luchador se planta: Saltar gira la mira hacia
      arriba, Agacharse hacia abajo (2.5 rad/s, hasta ±81°) e
      izquierda/derecha eligen el lado. Balas, granadas y cohetes salen por
      la mira (`WeaponHolder.aim_angle`, `aim_direction()`), el arma se dibuja
      girada y aparece una mira láser punteada. Al soltar vuelve a 0. Con
      armas cuerpo a cuerpo el botón sigue cubriendo. Test
      `scripts/weapons/test_aim.gd`
- [ ] Los bots todavía no apuntan a mano: disparan en horizontal

## Evidencia

- Commit: `feat(weapons): add data-driven weapons, projectiles, pickup and random spawn`
- Memoria Engram: pendiente (sin acceso a Engram desde la sesión en la nube)
- Verificación: `godot --headless --path . -s scripts/weapons/test_weapons.gd` →
  `OK: weapon data, projectiles, walls, range, shotgun spread, katana, ammo, pickup/drop, player hit and spawner verified`
- Integración (2026-09-28): `InputFrame.FIRE`/`PICKUP`; armas automáticas
  disparan manteniendo, el resto necesita pulsar otra vez. Recoger sin nada
  cerca suelta el arma. Al morir el jugador suelta el arma (diferido).
  Test: `scripts/test_match_arena.gd`.
