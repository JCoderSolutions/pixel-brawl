---
type: "guide"
topic_key: "asset-pipeline"
created: "2026-09-30"
---

# Cómo hacer los assets (herramientas, medidas y cómo meterlos al juego)

Pedido de Jose (2026-09-30): herramientas gratis (y de IA) para hacer el arte
y el sonido, con medidas exactas para que entren al juego sin tocar código.
Dónde va cada archivo y qué campo completar: [[docs/art-swap-guide]].

## Reglas que valen para todo

- **Resolución base 480x270**, escalada en múltiplos enteros. Un pixel del
  arte = un pixel del juego: nada de dibujar a 2x.
- **Paleta Endesga 32** (`assets/palettes/endesga-32.hex`). Cargarla en el
  editor y usar solo esos 32 colores. Los roles de la UI están en
  [[docs/ui-style-guide]].
- **PNG con transparencia**, sin suavizado ni antialias en los bordes.
- **Todo mira a la derecha**: el juego lo espeja.
- En Godot el filtro ya es **Nearest** en todo el proyecto; no hay que
  cambiar nada al importar.

## Herramientas

### Para dibujar y animar (gratis)

| Herramienta | Para qué | Nota |
| --- | --- | --- |
| **Pixelorama** | Sprites, animaciones y tilesets | Gratis y open source, hecho con Godot. Exporta hojas de sprites (sprite sheets) y se usa en el navegador o instalado. Recomendado |
| **LibreSprite** | Lo mismo, estilo Aseprite | Ya estaba en el stack. Gratis |
| **Piskel** | Bocetos rápidos en el navegador | Gratis, muy simple, exporta hoja PNG |
| Aseprite | El estándar de la industria | Pago (unos USD 20) o gratis compilándolo uno mismo |

### IA para arrancar el dibujo

La IA sirve para **bocetos y primeras versiones**; casi siempre hay que
limpiar a mano (bordes, paleta, que las poses coincidan entre cuadros).

| Herramienta | Qué da gratis | Para qué sirve más |
| --- | --- | --- |
| **Retro Diffusion** | 50 créditos al crear la cuenta, no vencen; después se paga por imagen | Pixel art con buena paleta; tiles y objetos |
| **Retro Diffusion "Pixel Art Fixer"** | Gratis | Convertir una imagen de IA común en pixel art real (grilla y colores) |
| **PixelLab** | Prueba de 40 generaciones sin tarjeta; después suscripción | Personajes en varias direcciones y animaciones simples |
| **Pixler.dev** | Plan gratis limitado | Sprites sueltos |

Los precios y cupos cambian seguido: revisarlos antes de gastar créditos.

### Sonido (gratis)

| Herramienta | Para qué |
| --- | --- |
| `assets/audio/generate_sfx.py` | Los efectos del juego ya salen de acá (CC0). Para uno nuevo se agrega una receta |
| **jsfxr / BFXR / ChipTone** (web) | Efectos retro a mano, exportan WAV |
| **BeepBox / JummBox** (web) | Música chiptune, exportan WAV |
| **Audacity** | Cortar, normalizar, pasar a mono 22 050 Hz |

**Ojo con la música de IA:** en el plan gratis de Suno no se puede usar lo
generado en algo comercial, y pasar después a un plan pago no lo habilita.
Para el juego, mejor BeepBox o pagar el plan antes de generar.

### Assets ya hechos

Kenney.nl (todo CC0), OpenGameArt e itch.io (buscar "CC0"). Revisar
siempre la licencia y anotarla en `assets/.../CREDITS.md`.

## Medidas por tipo de asset

### Luchadores: cuadros de 32x32

- Un personaje ocupa unos **16 px de ancho y 28 de alto** (el tamaño de su cuerpo físico) dentro del cuadro,
  **centrado y con los pies en el borde de abajo**, mirando a la derecha.
- Una hoja horizontal por animación (por ejemplo `run` de 6 cuadros =
  192x32), o una hoja con todas las animaciones en filas.
- Nombres y cantidad de cuadros sugerida (FPS entre paréntesis):

| Animación | Cuadros | | Animación | Cuadros |
| --- | --- | --- | --- | --- |
| `idle` | 4 (6) | | `hurt` | 2 (10) |
| `run` | 6 (12) | | `victory` | 4 (8) |
| `jump` | 2 (10) | | `dive` | 2 (12) |
| `fall` | 2 (10) | | `roll` | 4 (16) |
| `crouch` | 1 | | `ride` | 2 (8) |
| `attack` (golpe) | 3 (16) | | `block` | 1 |
| `uppercut` | 3 (16) | | `grab` | 2 (10) |
| `kick` | 3 (16) | | `held` | 2 (10) |
| `air_kick` | 2 (12) | | `hang` | 2 (6) |
| `aim` | 1 | | | |

- La que falte se sigue dibujando con formas nativas, así que se puede ir
  de a una (empezar por `idle`, `run`, `jump`, `fall`, `attack`).
- Personajes: Bruno, Roja, Kai, Sol, Sombra, Doc, Punk, Obrero. El color de
  la camiseta del sprite debería coincidir con el de `FighterLook` (se usa
  en el HUD).
- **Cómo entra:** en Godot, nuevo recurso **SpriteFrames**, "Agregar cuadros
  desde hoja de sprites", una animación por nombre de la tabla, y guardarlo
  como `assets/sprites/characters/<nombre>.tres` (`bruno.tres`...).

### Tiles del mapa: 16x16

- Materiales: madera, ladrillo y metal.
- **Tira horizontal de daño**: 3 cuadros de 16x16 = **48x16** (sano, dañado,
  por romperse). El metal no se rompe: alcanza con **16x16**.
- Tablones `=` (se atraviesan desde abajo): otra tira igual; se ven solo los
  **6 px de arriba**.
- Que el borde de cada tile combine con el de al lado (se repiten en
  grilla).
- **Cómo entra:** `assets/sprites/tilesets/wood.png` y en
  `scenes/maps/materials/wood.tres` completar `texture` (y `plank_texture`).

### Fondos: 960x544

- Los mapas grandes miden **960x544** (60x34 tiles); el Arena, 480 de ancho (30 tiles).
- Conviene hacerlos en 2 o 3 capas (cielo, edificios lejanos, detalle
  cercano) con colores oscuros y apagados para que los luchadores resalten.
- **Cómo entra:** reemplazar los `ColorRect` del nodo `Decor` del mapa por un
  `Sprite2D` con la imagen, en la misma posición.

### Armas: mirando a la derecha

Tamaño del lienzo sugerido (el arma dibujada hoy mide lo que dice la
segunda columna):

| Arma | Lienzo | Hoy mide | Punta del caño desde la mano |
| --- | --- | --- | --- |
| Pistola | 12x8 | 7x6 | 12 px |
| Recortada | 16x8 | 9x4 | 10 px |
| Escopeta | 20x8 | 16x4 | 14 px |
| Rifle de asalto | 24x8 | 18x7 | 16 px |
| Bazuca | 24x10 | 20x8 | 14 px |
| Bate | 20x6 | — | — |
| Katana | 20x6 | 18x5 | — |
| Granada | 8x8 | 6x8 | — |
| Molotov | 8x10 | 10x6 | — |

- **Cómo entra:** en `scripts/weapons/data/<arma>.tres` completar `sprite`
  y `sprite_grip` (el pixel que va en la mano). Las balas salen a
  `muzzle_offset` px de la mano: dibujar la punta del caño ahí.

### Íconos de UI: 8x8

- Teclado, mando y bot (`scripts/ui/ui_icons.gd`), en `text` (`#c0cbdc`)
  sobre transparente. Hoy se dibujan desde mapas de texto; si se hacen en
  PNG se cambian ahí.

### Sonido

- **WAV mono, 16 bit, 22 050 Hz**, cortos (menos de 1.5 s) y sin silencio al
  principio. Nombres en minúscula: `punch.wav`, `sizzle.wav`...
- **Cómo entra:** `assets/audio/sfx/` y una línea en `SFX` de
  `scripts/audio/audio_manager.gd`.

## Flujo recomendado con IA

1. **Generar** el personaje o el objeto con Retro Diffusion o PixelLab,
   pidiendo "pixel art, side view, facing right, transparent background" y
   la medida final (32x32 para personajes).
2. **Si sale más grande**, achicar con vecino más cercano (nunca con
   suavizado) hasta la medida exacta, o pasarlo por el Pixel Art Fixer.
3. **Reducir a Endesga 32** en Pixelorama o LibreSprite (modo de color
   indexado con la paleta cargada).
4. **Limpiar a mano**: contorno de 1 px, pies en el borde de abajo, mismo
   tamaño de cuerpo en todos los cuadros.
5. **Animar** en Pixelorama copiando el cuadro base y moviendo brazos y
   piernas (la IA todavía es poco confiable para animaciones largas).
6. **Exportar** la hoja PNG y meterla en Godot como dice cada sección.
7. Correr `scripts/test_art_hooks.gd` y mirar una partida.

## Fuentes consultadas (2026-09-30)

- [Retro Diffusion vs PixelLab (GameDev AI Hub)](https://gamedevaihub.com/retro-diffusion-vs-pixellab/)
- [Retro Diffusion: Pixel Art Fixer](https://retrodiffusion.ai/tools/pixel-art-fixer/)
- [Pixelorama](https://pixelorama.org/)
- [Suno: derechos del plan gratis vs pago](https://replayedstudio.com/blog/suno-commercial-rights-explained/)
