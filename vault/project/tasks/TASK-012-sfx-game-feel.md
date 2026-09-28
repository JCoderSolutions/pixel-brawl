---
type: "task"
status: "in-progress"
priority: "high"
phase: "PHASE-3"
depends_on: "TASK-003, TASK-004, TASK-005, TASK-006"
source_memory_id: ""
discarded_reason: ""
---

# TASK-012 — SFX + game feel (sonido, partículas, hit-stop)

## Objetivo

Que cada golpe, disparo, explosión y bloque roto se sienta: sonido, partículas
de pixel y un micro-freeze (hit-stop) en los golpes fuertes. Todo con assets
gratuitos CC0.

## Criterios de done

- [x] `AudioManager` (autoload, `scripts/audio/audio_manager.gd`): buses `Music` y `SFX` creados en runtime, pool de voces, throttle por efecto, variación de pitch, volumen por bus (0..1) y música con fade
- [x] 14 SFX CC0 generados por `assets/audio/generate_sfx.py` (fuente y licencia en `assets/audio/CREDITS.md`)
- [x] `ImpactBurst` (`scenes/effects/impact_burst.gd`): partículas CPU sin textura (píxeles cuadrados), presets HIT, SPARK, DUST, DEBRIS, EXPLOSION con paleta Endesga 32
- [x] `GameFeel` (autoload, `scenes/effects/game_feel.gd`): se engancha solo a las señales existentes (`Hitbox.hit_landed`, `Projectile.impacted`, `WeaponHolder.fired/weapon_equipped`, `Explosion.exploded`, `DestructibleBlock.destroyed`, `HealthComponent.died`) y detecta salto/aterrizaje de los luchadores sin tocar `player.gd`
- [x] Hit-stop en golpes melee (0.06 s) y explosiones (0.09 s), en tiempo real
- [x] Música chiptune propia (CC0) generada por `assets/audio/generate_music.py`:
      `menu` (100 BPM, La menor, 19.2 s) y `battle` (150 BPM, Mi menor, 25.6 s),
      en loop sin cortes e importadas en IMA-ADPCM (~490 KB en total).
      `AudioManager.play_track()` no reinicia la pista que ya suena; el menú pone
      `menu` y cada partida `battle`. Los `.import` de `assets/audio/music/` se
      versionan (excepción en `.gitignore`). Test `scripts/audio/test_music.gd`
- [ ] Test manual de la música (volumen frente a los SFX, que el loop no se note)
- [ ] Menú de opciones con sliders de volumen (la API ya está)
- [ ] Test manual de sensación (volúmenes, duración del hit-stop)

## Tabla de eventos

| Evento | Sonido | Partículas | Hit-stop |
| --- | --- | --- | --- |
| Golpe melee a luchador/prop | `punch` | HIT | 0.06 s |
| Golpe melee a bloque | `block_hit` | DUST | — |
| Bala a luchador/prop | `hit` | HIT | — |
| Bala a bloque | `block_hit` | DUST | — |
| Bala a pared/piso | `ricochet` | SPARK | — |
| Disparo pistola / escopeta | `shot` / `shotgun` | SPARK en el cañón | — |
| Katana / granada lanzada | `swing` / `throw` | — | — |
| Recoger arma | `pickup` | — | — |
| Explosión | `explosion` | EXPLOSION + DUST | 0.09 s |
| Bloque destruido | `block_break` | DEBRIS | — |
| Muerte (no bloques) | `death` | HIT | — |
| Salto / aterrizaje fuerte | `jump` / `land` | DUST | — |

## Detalles

- `GameFeel` no se engancha en headless (tests, futuro servidor dedicado): no
  hay nada que ver ni oír y no debe alterar `Engine.time_scale` bajo la
  simulación. Los tests crean su propia instancia y la conectan a mano.
- Las partículas cuelgan del autoload (no de la arena), con `z_index` 20, así
  sobreviven al nodo que las causó y no ensucian la lógica por árbol de escena.
- Scripts compilados antes de las autoloads (`godot -s`) no ven el nombre
  `AudioManager`; `GameFeel` lo busca por ruta (`/root/AudioManager`).
- Online (TASK-013): el hit-stop es local y visual, no debe entrar en la
  simulación sincronizada.

## Evidencia

- Tests: `scripts/audio/test_audio_manager.gd` y `scripts/audio/test_game_feel.gd`.
- `tools/run_tests.sh` con Godot 4.2.2: todos pasan.
- Capturas: `screenshots/feel/` en los archivos del proyecto.
- Memoria Engram: pendiente (Engram no es accesible desde sesiones cloud).
