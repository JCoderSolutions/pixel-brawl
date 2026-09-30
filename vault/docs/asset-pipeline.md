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
- **Paleta Endesga 32** (`assets/palettes/endesga-32.hex`, y
  `endesga-32.gpl` para importarla en editores). Cargarla en el
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

## Personajes con IA sin perder la consistencia

La IA es buena para el **estilo** y el **diseño** de un personaje; es mala
para dibujar el mismo personaje en poses exactas (un uppercut, colgarse de
una cornisa) cuadro a cuadro. Por eso el método es: la IA diseña, el juego
pone las proporciones y las poses, y la mano une todo.

### Paso 0: las hojas de referencia del juego

`tools/export_rig_reference.sh` exporta el luchador de formas nativas en
todas sus poses a `assets/sprites/characters/reference/`:

- `base.png` (maniquí gris) y una por personaje (`bruno.png`, `roja.png`...).
- **Una fila por animación, un cuadro de 32x32 por frame**, en este orden:
  idle, run, jump, fall, crouch, attack, hurt, aim, victory, dive, ride,
  block, roll, uppercut, kick, air_kick, grab, held, hang.
- `x4/`: las mismas hojas ampliadas 4x para subirlas a la IA.
- `poses/`: una imagen por pose del maniquí (`idle.png`, `run.png`...),
  128x128 con fondo blanco, para el "input image" de Retro Diffusion.
- La paleta como imagen para las herramientas: `assets/palettes/endesga-32.png`.
- `guide.png` (y `x4/guide.png`): el cuadro del luchador para usar como
  capa guía en el editor. Caja cyan = zona de golpe (16x28, el cuerpo va
  adentro; guantes, pelo o arma pueden salirse hacia los costados), fila
  verde = el piso (pies en la última fila), línea roja = el centro, marcas
  amarillas = proporción chibi (cabeza ~11 px, torso ~8, piernas ~9).

Son **el tamaño, los pies y las poses exactas** que espera el juego: se
dibuja encima (capa aparte en Pixelorama) o se suben como referencia.

### Paso 1: la ficha del personaje (se escribe una vez)

Un bloque de texto fijo por personaje que se pega **igual** en cada pedido.
Ejemplo para Bruno:

```
ESTILO: 16-bit pixel art game sprite, side view, facing right, full body,
clean 1px dark outline, flat shading with one highlight, no anti-aliasing,
transparent background, 32x32.
PERSONAJE: Bruno, street brawler, short dark hair with a cyan headband
(#2ce8f5), light skin (#e8b796), blue t-shirt (#0099db), dark navy pants
(#3a4466), dark shoes, athletic build, 16 px wide and 28 px tall.
```

Los colores con su hex de Endesga 32 (los de `FighterLook`) y las
proporciones van siempre. Lo único que cambia entre pedidos es la pose.

### Paso 1b: que parezca un luchador, no un NPC

Si la ficha solo describe ropa ("remera azul, pantalón oscuro"), el modelo
devuelve un extra genérico. El carácter sale de cuatro cosas, en este orden:

1. **Arquetipo con tema**: no "street brawler", sino *quién* es: boxeador
   de barrio, luchador enmascarado, obrero de la construcción. En SFD casi
   todos son "un tipo de la calle + un oficio o una tribu" (mafioso, motero,
   soldado, agente) y se reconocen por eso.
2. **Silueta**: un rasgo que se lea en negro puro: casco, cresta, gorro,
   melena, capucha, bufanda al viento, hombros enormes. Prueba: pintar el
   sprite todo negro; si no se sabe quién es, falta silueta.
3. **Proporciones exageradas** (dentro de los 16x28): cabeza un poco
   grande, torso y hombros anchos, puños grandes, piernas cortas y
   separadas. "Robusto" se dibuja con el torso, no con la altura.
4. **Actitud**: pose de guardia (puños arriba, peso adelante, rodillas
   flexionadas), ceño fruncido o sonrisa torcida, un detalle de historia
   (cicatriz, vendas en los puños, diente de oro, curita en la nariz).

Palabras que ayudan en el prompt: `tough`, `burly`, `broad shoulders`,
`big fists`, `fists raised`, `fighting stance`, `confident smirk`,
`angry eyebrows`, `bold silhouette`, `chunky proportions`, `thick dark
outline`, `high contrast`. Palabras que lo vuelven NPC: `relaxed`,
`standing`, `casual`, `simple`, `athletic`.

Colores: los dos de `FighterLook` (remera y pantalón) llevan el cuerpo y
el **color de acento** (la banda) va solo en el rasgo de silueta, para que
el ojo vaya ahí. Contorno siempre `#181425`.

Los 8 del juego, con los colores que ya tienen (el tema se puede cambiar,
los colores conviene mantenerlos porque son los que usa el juego hoy):

| Personaje | Tema | Rasgo de silueta | Prompt (se agrega a la línea de estilo) |
| --- | --- | --- | --- |
| **Bruno** | Boxeador de barrio | Vincha cyan con puntas al viento, puños vendados | `burly street boxer, broad shoulders, big taped fists raised, cyan headband with long tails, short dark hair, stubble, scar on eyebrow, blue tank top, dark navy boxing shorts over pants, confident smirk` |
| **Roja** | Kickboxer muay thai | Coleta larga naranja | `female muay thai kickboxer, long orange-tied ponytail, red sports top, red hand wraps, dark navy shorts with knee pads, fierce eyes, one knee raised in guard` |
| **Kai** | Capoeirista / callejero | Rastas atadas con pañuelo azul | `capoeira street fighter, dark skin, dreadlocks tied with a blue bandana, green sleeveless shirt open, loose grey-blue pants, barefoot, cocky grin, low wide stance` |
| **Sol** | Luchador enmascarado | Máscara roja con llamas, capa corta | `mexican luchador wrestler, red mask with sun flame pattern, yellow wrestling singlet, short red cape, huge chest, thick arms, dark brown boots, flexing pose` |
| **Sombra** | Ninja / agente | Capucha y bufanda roja larga | `shadow ninja assassin, dark navy hood and mask, only eyes visible, long red scarf flowing behind, black wrapped pants, slim, crouched ready stance` |
| **Doc** | Científico loco | Pelo blanco disparado + gafas | `mad scientist brawler, wild spiky white hair, blue goggles on forehead, long light grey lab coat, dark pants, crazy grin, fists up` |
| **Punk** | Punk callejero | Cresta verde alta | `street punk, tall green mohawk, magenta sleeveless leather vest with spikes, dark ripped jeans, heavy boots, chain belt, snarl, fists raised` |
| **Obrero** | Obrero de obra | Casco amarillo, bigote | `tough construction worker, yellow hard hat, big mustache, dark skin, orange safety vest, huge forearms, dark navy work pants, heavy boots, grumpy face` |

### Paso 1c: diseñar primero, animar después

El maniquí gris como imagen de entrada **congela el diseño**: con strength
0.55–0.7 copia su pose neutra y su cuerpo flaco, y a 32x32 no queda lugar
para inventar personalidad. Por eso se separa en dos:

1. **Diseño (concepto)**: RD Plus, **64x64 a 128x128**, **sin imagen de
   entrada y sin semilla** (si quedó cargada una imagen de una prueba
   anterior, todas las tandas salen con el mismo encuadre y la misma
   pose). Estilo: **Cartoon** (formas simples, cuerpo entero) o
   **Character Turnaround** (varias vistas de cuerpo entero: se usa la de
   perfil). "Default" tiende a medio cuerpo realista y corta los pies.
   Tandas de 4 hasta que uno "tenga cara de personaje"; anotar semilla.

   Prompt **corto (20–30 palabras), solo el personaje**: el estilo ya
   pone el pixel art (nunca escribir "pixel art") y las listas largas
   de encuadre y técnica se ignoran. Lo primero que se escribe pesa más.

   ```
   chibi street boxer, big head, spiky black hair, cyan headband,
   blue tank top, navy pants, big red boxing gloves raised, full body, boots
   ```

2. **Sprite del juego**: ese concepto se lleva a 32x32 redibujándolo en
   Pixelorama sobre `x4/base.png` (el concepto al lado como guía): el
   cuerpo lo pone el maniquí, el carácter lo ponen pelo, accesorio,
   colores y cara. Recién ahí se usan las poses de `poses/` como entrada,
   con el sprite ya dibujado como referencia (RD Pro).

### Paso 2: Retro Diffusion, el diseño base

Configuración (2026-09-30):

| Campo | Qué poner |
| --- | --- |
| Modelo | **RD Pro** si alcanzan los créditos: es el único que baja a 32x32 y acepta imágenes de referencia. Si no, **RD Plus** |
| Estilo | Diseño: **Cartoon** o **Character Turnaround** (paso 1c). Sprite a 32: **Low Res** (hecho para assets chicos). "Default" pinta más detalle, llena el lienzo y suele cortar los pies |
| Medida | **32x32**. Si el modelo o el estilo no la aceptan (RD Plus pide mínimo 64 salvo los estilos low res), **64x64** y después se redibuja a 32 en Pixelorama usando el resultado de guía, nunca achicando |
| Input image | Para el **diseño**: ninguna (ver paso 1c). Para **poses** de un personaje ya diseñado: `assets/sprites/characters/reference/poses/<pose>.png` (128x128, fondo blanco: la herramienta no acepta transparencia) |
| Strength | Poses: **0.55 a 0.7**. Más bajo copia el maniquí gris; más alto se olvida de la pose y las proporciones. Diseño con entrada: **0.8 a 0.9** |
| Paleta | `assets/palettes/endesga-32.png` |
| Quitar fondo | **Sí** (remove background), para que salga transparente |
| Semilla | Vacía la primera vez; cuando sale uno bueno, anotarla y repetirla |
| Cantidad | 4 por tanda |

Prompt: la ficha del paso 1 sin la línea de estilo técnico (el modelo ya
es pixel art) y con la pose al final. Corto y concreto: el modelo sigue
mejor listas de rasgos que frases largas.

```
side view, facing right, full body, burly street boxer, broad shoulders,
big taped fists raised, cyan headband with long tails, short dark hair,
stubble, scar on eyebrow, blue tank top, dark navy pants, confident smirk,
chunky proportions, bold silhouette, thick dark outline, flat shading
```

1. Crear la cuenta (50 créditos gratis, no vencen).
2. Primera tanda con `poses/idle.png`, elegir **una** y anotar la
   **semilla**. Esa imagen es "el Bruno oficial".

### Paso 3: más poses del mismo personaje

- En cada pedido nuevo: **la misma ficha + la misma semilla + el Bruno
  oficial como imagen de referencia** (RD Pro acepta hasta 9 referencias:
  sumar también la pose de `x4/base.png` que se quiere). Cambiar solo la
  línea de pose: `POSE: running`, `POSE: throwing a straight punch`,
  `POSE: jumping, knees up`, `POSE: hanging from a ledge with both hands`...
- Si una pose sale con otro peinado u otra ropa, se descarta: no se
  "arregla" con otro prompt, se repite con la referencia.

### Paso 4: animaciones

- **Retro Diffusion Animation** tiene estilos listos: *Walking and Idle* y
  *Four Angle Walking* salen en **48x48** (pensados para vista de arriba)
  y *Small Sprites* en **32x32** con caminata a la derecha y a la
  izquierda. Sirven para `idle` y `run`; hay que llevar el personaje a 28 px
  de alto y los pies al borde de abajo.
- **PixelLab** anima un sprite propio con "Animate with skeleton" o
  "Animate with text" y tiene vista lateral: se sube el Bruno oficial y se
  piden 4 a 6 cuadros de la acción.
- Las poses de pelea (uppercut, patadas, agarre, colgarse) casi siempre
  conviene hacerlas **a mano sobre la hoja de referencia**: copiar el cuadro
  del Bruno oficial y mover brazos y piernas siguiendo la fila de `base.png`.

### Paso 5: los 8 personajes con el mismo cuerpo

Lo más consistente (y lo que hacen muchos juegos de pelea chicos): animar
**un solo cuerpo** (`base.png` redibujado) y cambiarle pelo, ropa y
colores para cada personaje. Todos se mueven igual, pesan lo mismo en
pantalla y el trabajo de animación se hace una vez.

### Paso 6: que se pueda editar (siempre)

Lo que sale de una IA casi nunca es pixel art "de verdad", aunque lo
parezca: cada pixel del dibujo viene como un bloque de 4x4 u 8x8 con
colores apenas distintos, bordes semitransparentes y colores cerca de la
paleta pero no en ella. Se ve bien, pero en un editor el balde de pintura
no rellena, la goma deja halos y recolorear es imposible. Editable quiere
decir:

| Regla | Por qué |
| --- | --- |
| **1 pixel del arte = 1 pixel de la imagen** (32x32 por cuadro) | Se retoca pixel por pixel y entra al juego sin escalar |
| **Solo colores de Endesga 32** | El balde rellena zonas enteras y se recolorea cambiando un color de la paleta |
| **Transparencia total o nada**, sin bordes suavizados | Sin halos al mover o espejar el sprite |
| **Pocos colores por personaje** (hasta ~16) y **zonas planas** | Cambiar ropa o hacer otro personaje es rellenar zonas |
| **Poco ruido**: nada de pixeles sueltos ni tramado | Cada pixel suelto es un retoque a mano en cada cuadro |

Para que salga así desde la IA: paleta Endesga 32 cargada, quitar fondo
activado, estilo Low Res (o el diseño a 64 redibujado a mano) y en el
prompt `flat shading, no dithering, no gradients, no anti-aliasing`.

**Control automático** (`tools/pixel_art_check.sh`): revisa la imagen y,
con `--out`, guarda una copia limpia (achica cada bloque a 1 pixel con su
color más común, pasa todo a la paleta y deja la transparencia sin
bordes). Acepta varias imágenes a la vez.

```
tools/pixel_art_check.sh descargas/bruno_rd.png --out assets/sprites/characters/bruno/
```

```
descargas/bruno_rd.png: NO EDITABLE (256x256, 4612 colores)
  error: cada pixel del arte ocupa 8x8: achicar a 32x32 (sin suavizado)
  error: 254 pixeles semitransparentes (bordes suavizados)
  error: 11518 pixeles fuera de la paleta Endesga 32
  aviso: 4612 colores: más de 16 cuesta retocar y recolorear
  limpio -> assets/sprites/characters/bruno/bruno_rd.png (32x32, 6 colores)
```

Los **errores** los arregla la copia limpia. Los **avisos** (muchos
colores, pixeles sueltos, medida fuera de la grilla de 32) se corrigen a
mano en el editor. El test `scripts/art/test_pixel_art_check.gd` garantiza
que una salida tipo IA (agrandada 8x, con ruido fuerte y bordes suaves)
vuelve exacta al sprite original, y que las hojas de referencia del juego
ya son editables.

Después, en el editor (Pixelorama, LibreSprite, Aseprite):

1. Abrir el PNG limpio e **importar la paleta** `assets/palettes/endesga-32.gpl`
   (formato GIMP, lo leen todos).
2. Revisar contra la hoja de referencia: **16x28 px, pies en la última
   fila, mirando a la derecha, contorno de 1 px**, el mismo alto en todos
   los cuadros (usar "onion skin").
3. Guardar el archivo del editor (con capas) junto al PNG para seguir
   editando; al juego entra solo el PNG.
4. Exportar la hoja, armar el `SpriteFrames` y probar en una partida.

### Otros assets con IA

- **Tiles:** RD tiene estilos de texturas repetibles; pedir 16x16,
  `seamless`, y después hacer a mano los 2 cuadros de daño (grietas).
- **Armas:** RD Plus en la medida de la tabla, `side view, facing right`.
- **Fondos:** RD Plus en tamaño grande, colores apagados, y separar capas a
  mano.

## Fuentes consultadas (2026-09-30)

- [Retro Diffusion vs PixelLab (GameDev AI Hub)](https://gamedevaihub.com/retro-diffusion-vs-pixellab/)
- [Retro Diffusion: Pixel Art Fixer](https://retrodiffusion.ai/tools/pixel-art-fixer/)
- [Pixelorama](https://pixelorama.org/)
- [Suno: derechos del plan gratis vs pago](https://replayedstudio.com/blog/suno-commercial-rights-explained/)
- [Retro Diffusion: Walking & Idle](https://retrodiffusion.ai/styles/walking-idle/) y [Four Angle Walking](https://retrodiffusion.ai/styles/four-angle-walking/)
- [Retro Diffusion Plus en Replicate](https://replicate.com/retro-diffusion/rd-plus/readme)
- [Retro Diffusion: ejemplos de la API](https://github.com/Retro-Diffusion/api-examples)
- [PixelLab: formas de usarlo](https://www.pixellab.ai/docs/ways-to-use-pixellab)
