---
type: "task"
status: "in-progress"     # allowed: todo | in-progress | done | discarded
priority: "high"
phase: "PHASE-3"
depends_on: "TASK-005, TASK-020"
source_memory_id: ""
discarded_reason: ""
---

# TASK-010 — Power-ups

## Objetivo

Power-ups que aparecen en el mapa y se toman al pasar por encima, como en
Superfighters: botiquín, velocidad, fuerza y escudo, con duración y feedback
visual. Los bots también los buscan.

## Criterios de done

- [x] `PowerUpData` (`scripts/powerups/`) con efecto, cantidad, duración y color;
      cada power-up es un `.tres` en `scripts/powerups/data/`
- [x] `PowerUpReceiver` (hijo del jugador) aplica y revierte efectos sin tocar
      `player.gd`: `run_speed`, daño del puño, `WeaponHolder.damage_multiplier`,
      `HealthComponent.shield`
- [x] `PowerUpPickup` (`scenes/powerups/`) cae al suelo y se toma al tocarlo;
      el botiquín se queda si estás con vida llena
- [x] Feedback: aura por efecto (burbuja para el escudo), parpadeo los últimos
      2 s, cruz verde al curar, sonido `pickup`
- [x] `WeaponSpawner.spawn_random()` suelta un power-up con `power_up_chance`
      (30% por defecto) y comparte puntos y `max_active` con las armas
- [x] Bots caminan hacia power-ups cercanos (ignoran el botiquín con vida llena)
- [x] Test headless `scripts/powerups/test_powerups.gd`
- [ ] Test manual en PC y teléfono

## Detalles

| Power-up | Efecto | Duración |
| --- | --- | --- |
| Botiquín | +40 vida | instantáneo |
| Velocidad | x1.5 velocidad de carrera | 8 s |
| Fuerza | x1.75 daño (puño y armas; no granadas) | 10 s |
| Escudo | absorbe 50 de daño (el knockback sí entra) | 10 s o hasta romperse |

- Tomar el mismo efecto de nuevo renueva el tiempo, no se acumula.
- Morir termina todos los efectos.

## Evidencia

- Commit: `feat(powerups): add medkit, speed, strength and shield power-ups`
- Memoria Engram: pendiente (sin acceso a Engram desde la sesión en la nube)
- Verificación: `tools/run_tests.sh` → todos los tests pasan
- Captura: `screenshots/powerups/powerups-y-armas.png`
