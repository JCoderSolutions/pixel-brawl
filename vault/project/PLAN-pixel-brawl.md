# PIXEL BRAWL — Plan de Desarrollo

Juego pixel art tipo Superfighters con mapas destructibles, ragdoll physics y multiplayer.
Stack: **Godot 4.x** + pipeline de arte híbrido (AI + manual). 100% gratis.

---

## 1. VISIÓN Y DIFERENCIACIÓN

### Referente: Superfighters (Mythologic Interactive, 2011)
- Arena 2D de un solo screen, hasta 4 luchadores
- Melee + armas de fuego + granadas
- Mapas multi-nivel
- Existe remaster HTML5 y Superfighters 2

### Referentes actuales del género (2026) a estudiar
| Juego | Plataforma | Lección clave |
|---|---|---|
| Bloxel Arena | iOS/Android | Mobile-first 5v5, entornos 100% destructibles, matches de 2-3 min |
| Broforce | Steam | Gold standard de destrucción pixel art y caos |
| Noita | Steam | Simulación física de cada pixel del mapa |
| B.E.A.S.T.S. | itch.io | Brawler con entornos destructibles |
| Collateral Damage | itch.io | "Every pixel can be destroyed" |
| Bugspeed Collider | itch.io | Multiplayer local + física |

### Innovaciones vs el original
| Innovación | Descripción | Complejidad |
|---|---|---|
| **Mapas 100% destructibles** | Cada bloque atacable se rompe; cambia el flujo de pelea | Media |
| **Ragdoll physics** | Al morir el personaje se desarma con física | Baja-Media |
| **Power-ups combinables** | Escudo + granada = explosion shield; combos emergentes | Media |
| **Mapas que evolucionan** | Al destruir suficiente, cambia la fase (se inunda, cae el techo) | Media-Alta |
| **Modo BR simplificado** | 4-8 jugadores, el mapa se reduce cada 30s | Media |
| **Controles touch inteligentes** | Joystick virtual + botones contextuales | Baja |

**3 factibles para prototipo:** mapas destructibles (core), ragdoll (diversión), touch (mobile).

---

## 2. STACK TECNOLÓGICO — 100% GRATIS

### Motor: Godot 4.x
- MIT license, sin royalties, sin splash
- 2D nativo + pixel-perfect rendering (configurar Filter=Nearest, una vez)
- Exporta a Web (HTML5), Windows, Mac, Linux, Android, iOS
- GDScript (parecido a Python) + C#
- Comunidad creciente; Brotato, Cassette Beasts, Dome Keeper ya salieron en Godot

**Por qué NO otras opciones:** Unity (overkill 2D, pricing turbio), GameMaker (gratis solo no-commercial), Construct (web-only, subscripción), Phaser (sin editor visual, lento para prototipar).

### Online multiplayer
- **Prototipo:** WebRTC P2P (built-in en Godot 4, gratis, sin servidor, límite ~2-4 jugadores)
- **Escalar:** Nakama (open source self-host, gratis en tu VPS ~$5/mes)

### Herramientas de desarrollo
| Herramienta | Costo | Uso |
|---|---|---|
| Godot 4.x | Gratis | Motor |
| VS Code | Gratis | Editor de código |
| Tiled | Gratis (GPL) | Editor de tilemaps |
| Audacity | Gratis | Audio/SFX |
| BFXR / sfxr | Gratis | SFX chip 8-bit |
| LibreSprite | Gratis | Editor pixel art (fork de Aseprite) |
| Importality (plugin Godot) | Gratis | Importar .aseprite/.piskel directo a Godot |

### Publicación
- itch.io (gratis, sin listing fee)

---

## 3. PIPELINE DE ARTE — A PROFUNDIDAD

### 3.1 Paleta elegida: **Endesga 32**
- [Lospec Endesga 32](https://lospec.com/palette-list/endesga-32)
- 32 colores, high contrast, high saturation
- ~200k downloads (la más usada del medio)
- Ideal para acción: grises industriales + tonos cálidos para fuego/explosiones
- Exportar como `.gpl` o `.png` desde Lospec
- **Valor único para consistencia:** forzar todos los assets a estos 32 colores exactos

### 3.2 Pipeline completo (AI + manual)

```
PASO 1  Definir Style Guide (paleta + prompts base)
PASO 2  Generar sprites base con AI (Retro Diffusion / Pixler)
PASO 3  Limpiar y ajustar en LibreSprite/Piskel
PASO 4  Crear animaciones (spritesheet)
PASO 5  Importar a Godot con Importality
```

#### PASO 1 — Style Guide (clave para consistencia)
Creá un documento propio que TODOS los prompts respeten:
- **Paleta fija:** Endesga 32 (nunca colores fuera de paleta)
- **Prompt base repetible:**
  ```
  16-bit pixel art, [SUJETO], Endesga 32 palette colors, thick dark outline,
  flat shading, 2 light sources, game sprite, transparent background, 
  consistent character design, 32x32px
  ```
- **Tamaño base:** 32x32 (personajes), tiles 16x16/32x32
- **Regla áurea:** nunca generar "a ojo"; siempre snapear a grilla y paleta

#### PASO 2 — Generación AI

**Opción A: Retro Diffusion (recomendada)**
- Web gratuita, créditos gratis para empezar (sin card)
- Producen pixel art REAL (grilla alineada, paleta controlada), no "imagen pixelada"
- Estilos predefinidos: `Classic` (outline fuerte, ideal fighters), `Retro`, `Simple`, `Detailed`
- Estilo recomendado para brawler: **Classic** (medio res, outline claro)
- Truco: describir SOLO el sujeto, no escribir "pixel art" en el prompt (el estilo lo maneja)
- Trucos de consistencia:
  - Reusar el mismo **seed** para iterar sobre la misma composición
  - Pasar **reference images** para mantener personaje/estilo
  - Usar `estimate` gratis antes de generar
- Extra: **Pixel Art Fixer** (gratis en browser) para convertir imágenes raster "fake" a grilla real

**Opción B: Pixler.dev (backup)**
- 5 generaciones/día gratis, sin signup, transparent background automático

#### PASO 3 — Limpiar en LibreSprite / Piskel
- Importar el sprite generado
- Redibujar outlines (el paso que la gente se salta y marca la diferencia)
- Corregir pixels off-grid
- Snap a paleta Endesga 32 (importar `.gpl` en LibreSprite)
- Ajustar silhouette y legibilidad a 32px

#### PASO 4 — Animaciones (spritesheet)
Frames recomendados por animación (estilo Superfighters):
| Animación | Frames |
|---|---|
| Idle | 4 |
| Walk | 6 |
| Run | 8 |
| Jump | 6 |
| Punch/Melee | 3-4 |
| Shoot | 3 |
| Hurt | 3 |
| Death/Ragdoll | 5 |

- Exportar cada anim como fila del spritesheet (grid uniforme)
- Gradiente de movimiento: inicio-finicio suave

#### PASO 5 — Importar a Godot (automatizado)
- Instalar plugin **Importality** (Godot Asset Library)
- Importar `.aseprite` / `.piskel` directo con animaciones y tags
- Configurar UNA vez en project settings: Filter = Nearest (pixel-perfect), atom_save

### 3.3 Por sets de assets
| Set | Herramienta | Detalle |
|---|---|---|
| Personajes (4-6 fighters) | Retro Diffusion + LibreSprite | 32px, animaciones por personaje |
| Armas (pistola, escopeta, AK, granada, katana) | Retro Diffusion + LibreSprite | Iconos y sprite en mano |
| Tilesets de mapas | Retro Diffusion (tileset) o Tiled | 16/32px, tiles que encastran |
| Power-ups (escudo, speed, rage) | Retro Diffusion + LibreSprite | 24-32px |
| Efectos (explosión, sangre, humo) | LibreSprite manual / GitHub packs | Spawn/despawn |
| UI (health bars, botones, HUD) | LibreSprite / Inkscape | Pantalla y mobile touch |
| Audio SFX | BFXR/sfxr | Chip 8-bit, pitches |
| Música | freesound.org / chiptune CC0 | 1-2 trackeos |

---

## 4. RUTA DEL PROTOTIPO (4 semanas)

### Semana 1 — Core mechanics
- Setup Godot 4, proyecto con paleta Endesga 32
- `Player` moverse: run/jump/crouch
- Combate: melee punch + 1 ranged
- 1 mapa con bloques destructibles (tile rompible)
- Export a Web para testear en browser

### Semana 2 — Items y caos
- Spawn de armas random (pistola, escopeta, granada, katana)
- Pickup/drop
- Explosiones que destruyen tiles (arma réflex de mapa destructible)
- Ragdoll al morir
- Multiplayer local (2 jugadores, teclado dividido)

### Semana 3 — Content + polish
- 4-6 mapas (industrial, rooftop, subway, fábrica)
- 4-6 power-ups (shield, speed, rage, etc.)
- UI: health bars, rounds, winner screen
- Sound effects + música chiptune
- Animaciones completas de personaje

### Semana 4 — Multiplayer + deploy
- Online multiplayer WebRTC P2P
- Salas privadas por código
- Controles touch mobile adaptados
- Build final Web + Android
- Publicar en itch.io

---

## 5. ESTRUCTURA DE PROYECTO GODOT

```
pixel-brawl/
├── scenes/
│   ├── characters/
│   │   ├── player.tscn
│   │   └── player.gd
│   ├── maps/
│   │   ├── map_industrial.tscn
│   │   ├── map_rooftop.tscn
│   │   └── map_destroyed.tscn
│   ├── items/
│   │   ├── weapon.tscn
│   │   ├── grenade.tscn
│   │   └── powerup.tscn
│   ├── effects/
│   │   ├── explosion.tscn
│   │   └── blood_particles.tscn
│   └── ui/
│       ├── hud.tscn
│       ├── menu.tscn
│       └── mobile_controls.tscn
├── assets/
│   ├── sprites/
│   │   ├── characters/
│   │   ├── weapons/
│   │   ├── items/
│   │   └── tilesets/
│   ├── audio/
│   │   ├── sfx/
│   │   └── music/
│   └── palettes/
├── scripts/
│   ├── autoload/
│   │   ├── game_manager.gd
│   │   └── network_manager.gd
│   └── resources/
│       ├── weapon_data.tres
│       └── character_data.tres
└── project.godot
```

---

## 6. RIESGOS Y MITIGACIÓN
- **Scope creep** (el enemigo principal): congelar features del MVP en semana 1
- **Multiplayer online** es lo más riesgoso: hacer local primero, online como add-on
- **AI + consistencia:** controlarlo con paleta fija + seeds + reference images
- **Licencias AI:** verificar términos de comercialización de cada herramienta

---

## COSTO TOTAL: $0
