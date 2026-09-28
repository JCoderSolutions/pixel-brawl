---
type: "task"
status: "in-progress"     # allowed: todo | in-progress | done | discarded
priority: "high"
phase: "PHASE-3"
depends_on: "TASK-019, TASK-020, TASK-018"
source_memory_id: ""
discarded_reason: ""
---

# TASK-009 — Set de mapas temáticos

## Objetivo

Mapas grandes (960x544, 60x34 tiles de 16 px) al estilo Superfighters, cada
uno con su identidad y sus trampas, jugables por humanos y por bots, y un
selector de mapa en el menú.

## Criterios de done

- [x] 4 mapas nuevos en `scenes/maps/`, todos con `arena_match.gd`,
      `DestructibleMap`, peligros, 4 spawns y `WeaponSpawner` con granadas
- [x] Cada mapa fija su `kill_zone_y` (600) en el `GameManager`; la arena
      original sigue con 400
- [x] `MapCatalog` (`scenes/maps/map_catalog.gd`) lista los mapas jugables
- [x] Menú: opción de mapa (aleatorio o uno fijo; se recuerda al volver)
- [x] Test headless `scripts/test_maps.gd`
- [ ] Test manual: jugar cada mapa en PC y teléfono (PC: Jose confirmó que el
      mapa se ve y funciona bien, 2026-09-28; falta teléfono)
- [x] Todas las armas (PR #21) y los power-ups en los spawners de los mapas
      y de `test_arena`
- [x] Bots terminan la partida en lab y fundición: saltan pozos, suben a
      islas sobre la lava y bajan escalones de hasta 72 px (PR #23 y #24)

## Mapas

| Mapa | Escena | Peligros |
| --- | --- | --- |
| Fábrica | `factory.tscn` | foso de pinchos, lanzallamas en ciclo, 2 prensas que suelta un interruptor (se le dispara desde las pasarelas) |
| Obra en la azotea | `rooftop.tscn` | caída al vacío entre edificios y por los bordes, puente de madera que se rompe, viga de la grúa que suelta un interruptor |
| Laboratorio | `lab.tscn` | canal de ácido bajo una pasarela de madera, piletas de ácido, goteras de ácido en ciclo, géiser de ácido con interruptor |
| Fundición | `foundry.tscn` | lago de lava con islas de metal, lanzallamas en ciclo, 2 crisoles que suelta un interruptor |

## Reglas de diseño (para mapas nuevos)

- Suelo en la fila 30 (y = 480). Los niveles caminables van cada **2 filas**
  (32 px): el salto llega a ~57 px y los bots bajan escalones de hasta 72 px
  (4 filas), así que no hace falta escalonar de a una fila para bajar.
- Plataformas en pirámide de tablones `=` (atravesables desde abajo).
- Huecos saltables de 3 tiles como máximo; si el hueco tiene un peligro
  vivo, mejor 2 tiles. Los bots buscan dónde aterrizar entre 56 y 80 px
  adelante, hasta 32 px más arriba (`GAP_JUMP_MAX`, `JUMP_RISE` en
  `bot_input_source.gd`); un salto completo llega a ~92 px en llano.
- Ningún punto de arma con algo donde pararse justo encima (1-3 filas): un
  bot parado arriba no alcanza el arma y se queda esperando.
- Pozos 4 px o más por debajo del borde del suelo.

## Evidencia

- Commit: `feat(maps): add factory, rooftop, lab and foundry maps with a map choice in the menu`
- Memoria Engram: pendiente (sin acceso a Engram desde la sesión en la nube)
- Verificación: `godot --headless --path . -s scripts/test_maps.gd` → `OK: map catalog, ...`
  (una partida de 4 bots en difícil termina en cada mapa en 500-1500 frames);
  `tools/run_tests.sh` → todos los tests pasan
- Capturas: `screenshots/mapas/{factory,rooftop,lab,foundry}.png`
