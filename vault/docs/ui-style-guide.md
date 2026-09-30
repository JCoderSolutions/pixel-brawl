---
type: "plan"
status: "proposed"        # proposed | approved | discarded — solo Jose aprueba
topic_key: "ui-style-guide"
created: "2026-09-30"
task: "TASK-024"
---

# Línea gráfica y sistema de UI — plan

Pedido de Jose (2026-09-30): en la pantalla de personajes y controles, según
lo que se elija, la fila se deforma y las columnas se desalinean. Quiere que se
investigue como dev de juegos, como diseñador y como jugador, que se elija la
mejor estructura y que quede una **línea gráfica única para todo el juego**
(fuentes, colores, tipos de botón, etc.) que se pueda ir definiendo por partes.

Este documento es la propuesta. Nada de acá está aprobado todavía: las
decisiones marcadas **[DECIDIR]** esperan a Jose.

---

## 1. Qué hay hoy (auditoría)

**No hay nada definido.** No existe un `Theme` de Godot, no hay fuente propia
(se usa la fuente por defecto de Godot, suave, que no es pixel art),
`assets/palettes/` está vacía y cada pantalla pone sus colores y tamaños a mano.

| Tema | Estado actual |
| --- | --- |
| Tema de Godot | No existe. Botones, sliders y desplegables usan el look por defecto del motor |
| Fuente | La de Godot por defecto. Se ve nítida y suave, no pixelada: choca con los sprites |
| Tamaños de texto | 8 distintos (6, 8, 11, 16, 20, 24, 32, 40) sin una escala |
| Colores | Mezcla de colores de Endesga 32 (`fee761`, `e43b44`...) con colores sueltos que no son de la paleta (`#1a1c2b` del fondo, `#338bcc` del jugador 1, grises `#595c6b`) |
| Botones | Rectángulos oscuros del motor. La opción elegida solo cambia el color del texto a amarillo; el foco es un borde blanco redondeado |
| Superposiciones | Opciones es casi transparente: se ve el título "PIXEL BRAWL" detrás |

### El problema de la pantalla de personajes

![[img/ui-audit/fighters-mixto.png]]

- Cada fila es un `HBoxContainer` **centrado por su cuenta**. Los botones
  tienen un ancho *mínimo*, no fijo: "WASD o mando" es más ancho que
  "Flechas" y "Sin equipo" más que "Verde". Así cada fila mide distinto y las
  columnas no quedan alineadas (P1 empieza más a la izquierda que P2).
- Las filas de bots muestran "CPU" como texto suelto en lugar de un botón, así
  que también cambian de ancho.
- El texto del control ("WASD o mando", "Mando 1") no dice qué teclas son y
  no hay íconos. El mando desconectado se marca solo con texto gris.
- El error "Dos jugadores con el mismo teclado o mando" aparece **después** de
  elegir mal: la pantalla deja elegir algo inválido y recién después avisa.

Otras capturas: [[img/ui-audit/fighters-3-humanos.png]],
[[img/ui-audit/opciones.png]], [[img/ui-audit/titulo.png]].

---

## 2. Investigación

### 2.1 Como dev de juegos (Godot 4)

- **Un solo `Theme` para todo el juego.** Godot permite fijar un tema global
  (`gui/theme/custom` en `project.godot`). Todo control lo hereda. Las
  variantes se hacen con *type variations* (`ButtonPrimary`, `LabelTitle`,
  `PanelCard`...) en vez de `theme_override_*` sueltos en cada escena. Cambiar
  el look de todo el juego pasa a ser editar un archivo.
- **Tokens en código.** Una clase `UiTokens` (constantes: colores, espacios,
  tamaños) para lo que se dibuja por código (HUD, textos flotantes, escenas de
  prueba). El `Theme` y `UiTokens` salen de los mismos valores.
- **Fuente pixel a tamaño entero.** El proyecto escala `canvas_items` desde
  480x270. Una fuente bitmap se ve nítida solo si se usa a su tamaño de diseño
  o a múltiplos enteros, sin antialias ni hinting. Por eso la escala de texto
  tiene que ser de pocos tamaños múltiplos (ver §3.2).
- **Anchos fijos por columna, no mínimos.** Las filas que forman una tabla van
  en un `GridContainer` o con anchos fijos por columna; el texto largo se
  recorta o se abrevia, nunca estira la fila.
- **Sin esquinas redondeadas ni antialias.** `StyleBoxFlat` con
  `anti_aliasing = false`, radio 0 y bordes de 1 px (2 px al tener foco). Más
  adelante se puede pasar a `StyleBoxTexture` con 9-slice cuando haya arte.
- **Verificable.** Un test headless que recorra `scenes/ui` y falle si
  aparece un `Color(...)` o un `font_size` fuera de los tokens, y capturas con
  Xvfb (`xvfb-run godot --rendering-driver opengl3`) de cada pantalla para
  revisar en cada PR. Ya se comprobó que las capturas funcionan en la nube.

### 2.2 Como diseñador

- **Una sola familia tipográfica pixel**, con dos pesos como mucho. Un
  "display" opcional solo para el logo y los carteles grandes ("¡PELEA!").
- **Colores por rol, no por pantalla.** Fondo, superficie, borde, texto,
  texto apagado, acento, peligro, éxito. Todos de Endesga 32, que ya es la
  paleta del proyecto.
- **Grilla de 4 px** en la resolución base 480x270: márgenes, separaciones y
  alturas son múltiplos de 4.
- **Pocos componentes, siempre iguales:** botón primario, botón secundario,
  selector "‹ valor ›", chip (etiqueta de color), panel/tarjeta, barra. Cada
  uno con los mismos cinco estados: normal, foco, presionado, elegido,
  deshabilitado.
- **El estado no depende solo del color.** Elegido = fondo lleno de acento más
  un marcador; foco = borde grueso más un leve "salto" de 1 px. Así se
  entiende con daltonismo y en pantallas chicas.
- **Jerarquía clara por pantalla:** título arriba, contenido al centro,
  navegación siempre en el mismo lugar (Atrás abajo a la izquierda, acción
  principal abajo a la derecha).

### 2.3 Como jugador

- En juegos de pelea de sillón (Smash, Brawlhalla, TowerFall, Duck Game) el
  control **no se elige de una lista**: cada jugador **aprieta un botón en su
  teclado o mando para unirse** y el juego ya sabe qué dispositivo usa. Sin
  errores de "mismo mando" posibles.
- Cada jugador quiere ver **su propia columna**: su personaje grande, su
  color, su equipo y su dispositivo, sin buscar en una tabla.
- Tiene que quedar claro **qué teclas usa**: "WASD · J K L I" o el ícono del
  mando con su número, no solo "WASD o mando".
- En el teléfono juega uno solo contra bots: la pantalla tiene que andar
  con toques grandes (mínimo 24 px base, ~1 cm en un teléfono).
- Navegable con teclado, mando y táctil. El foco siempre visible.

---

## 3. Propuesta

### 3.1 Estructura de la pantalla de luchadores (recomendada)

**Tarjetas por jugador, lado a lado, de ancho fijo, con "apretá para
unirte".** Es lo que hacen los juegos de pelea de referencia y resuelve de raíz
el problema: cada tarjeta mide lo mismo sin importar el texto.

```
 LUCHADORES                                              (480x270 base)
┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐
│ P1       │ │ P2       │ │ BOT 1    │ │    +     │
│   (rig   │ │   (rig   │ │   (rig   │ │ Apretá   │
│  grande) │ │  grande) │ │  grande) │ │ un botón │
│ ‹ Bruno ›│ │ ‹ Roja  ›│ │ ‹  Kai  ›│ │ para     │
│ [■ Rojo ]│ │ [■ Azul ]│ │ [  —    ]│ │ unirte   │
│ ⌨ WASD   │ │ 🎮 1     │ │ CPU Norm.│ │          │
└──────────┘ └──────────┘ └──────────┘ └──────────┘
 Hacen equipo los del mismo color
 [Atrás]                                     [Siguiente]
```

- 4 tarjetas de 112 px + 3 separaciones de 4 px = 460 px: entran en 480.
- Cada campo de la tarjeta tiene ancho fijo; los textos largos se abrevian
  ("Mando 1" → ícono + "1").
- **Unirse:** apretar Ataque o Saltar en un teclado o mando libre toma la
  próxima tarjeta vacía con ese dispositivo. Salir = Atrás en ese dispositivo.
  Los bots se suman con un botón "+ Bot".
- **Sin estados inválidos:** un dispositivo ya tomado no se puede elegir
  (desaparece o queda deshabilitado), así que el error "mismo mando" deja de
  existir.
- **Un jugador solo (teléfono o PC):** su tarjeta ya está unida con el
  dispositivo que usó para navegar el menú; no tiene que hacer nada extra.

**Alternativa más barata [DECIDIR]:** mantener la lista de filas pero como
tabla (`GridContainer`) con anchos fijos por columna y el control como selector
"‹ WASD ›" que saltee dispositivos tomados. Arregla la alineación en poco
tiempo, pero no mejora la experiencia de juntarse a jugar.

Recomendación: hacer primero la alternativa barata como arreglo inmediato
(Fase 2) y después las tarjetas con "apretá para unirte" (Fase 3), porque la
fase 3 también sirve para el online (TASK-013/014).

### 3.2 Tipografía [DECIDIR]

| Opción | Licencia | Acentos (á ñ ¿ ¡) | Comentario |
| --- | --- | --- | --- |
| **monogram** (datagoblin) | CC0 | Sí, versión *extended* (537 glifos) | Monoespaciada, muy legible a tamaño chico. Recomendada para todo el texto |
| Pixel Operator (Jayvee Enaguas) | CC0 | Parciales | Proporcional, tiene negrita y versión 8 px. Hay que verificar ñ y ¿ |
| m5x7 / m6x11 (Daniel Linssen) | Gratis con crédito | Verificar | Muy usadas en indies; revisar glifos en español |
| Press Start 2P | OFL | Sí | Solo para el logo o carteles: muy ancha para texto corrido |

Antes de elegir: renderizar "¡Ñandú! ¿Qué pasó? áéíóú ü PELEA 0123" con cada
una en 480x270 y compararlas en captura.

**Escala (solo estos tamaños):**

| Token | Uso |
| --- | --- |
| `text_small` | pistas, HUD secundario, créditos |
| `text_body` | botones, filas, HUD principal |
| `text_title` | título de cada pantalla |
| `text_display` | logo, "¡PELEA!", ganador |

Los valores exactos dependen de la fuente elegida: `text_body` = tamaño de
diseño de la fuente, y el resto múltiplos enteros (x1 chico si existe, x2
título, x3 o x4 display). Texto con contorno de 1 px `#181425` cuando va sobre
el juego.

### 3.3 Colores por rol (todos Endesga 32)

| Token | Hex | Uso |
| --- | --- | --- |
| `bg` | `#181425` | Fondo de menús |
| `surface` | `#262b44` | Paneles, tarjetas, botones en reposo |
| `surface_hi` | `#3a4466` | Botón con el mouse encima / campo |
| `border` | `#5a6988` | Bordes de 1 px |
| `text_muted` | `#8b9bb4` | Pistas, deshabilitado |
| `text` | `#c0cbdc` | Texto normal |
| `text_strong` | `#ffffff` | Títulos, texto elegido |
| `accent` | `#feae34` | Foco, acción principal ("¡A pelear!") |
| `accent_hi` | `#fee761` | Elegido, ganador, líder |
| `danger` | `#e43b44` | Errores, vida baja |
| `success` | `#63c74d` | Confirmaciones, vida |
| `info` | `#0099db` | Avisos neutros |
| `shade` | `#181425` al 85 % | Fondo detrás de paneles superpuestos (opciones, pausa) |

Equipos: rojo `#e43b44`, azul `#0099db`, verde `#63c74d`, amarillo `#fee761`
(ya son de la paleta). **Pendiente:** `GameManager.PLAYER_COLORS` y el fondo
del menú usan colores fuera de Endesga 32; pasarlos a la paleta. Cargar
`endesga-32.hex` en `assets/palettes/`.

### 3.4 Espaciado y forma

- Grilla de 4 px. Separación entre elementos: 4; entre grupos: 8; margen
  de pantalla: 16.
- Alturas: botón 24, selector 20, chip 16, zona táctil mínima 24.
- Esquinas rectas; bordes de 1 px, 2 px con foco.

### 3.5 Componentes (type variations del Theme)

| Componente | Normal | Foco | Presionado | Elegido | Deshabilitado |
| --- | --- | --- | --- | --- | --- |
| Botón primario | fondo `accent`, texto `bg` | borde 2 px `text_strong` | baja 1 px | — | fondo `surface`, texto `text_muted` |
| Botón secundario | fondo `surface`, borde `border` | borde 2 px `accent` | fondo `bg` | fondo `accent_hi`, texto `bg`, marcador ▸ | texto `text_muted` |
| Selector ‹ valor › | flechas + valor de ancho fijo | flechas en `accent` | flecha baja 1 px | — | flechas `text_muted` |
| Chip | fondo del color del equipo, texto `bg` | — | — | — | contorno `border` sin relleno |
| Panel / tarjeta | fondo `surface`, borde `border` | borde `accent` (tarjeta activa) | — | — | — |
| Barra (vida, volumen) | fondo `bg`, relleno según rol, borde 1 px | — | — | — | — |

### 3.6 Íconos

Íconos pixel de 8x8 o 16x16 para: teclado, mando (con número), táctil, bot,
equipo y armas del HUD. Hacerlos con LibreSprite en la paleta y guardarlos en
`assets/sprites/ui/`. Hasta tenerlos, texto corto de ancho fijo.

### 3.7 Movimiento y sonido de UI

- Foco: el botón sube 1 px y suena un "tic" corto.
- Confirmar: "blip" (ya existe `pickup`). Volver: tono más grave.
- Cambio de pantalla: fundido de 0.1 s, sin animaciones largas.

### 3.8 Textos

Español rioplatense (como el resto del juego). Títulos en mayúscula sostenida
("LUCHADORES", "MAPA"), botones en tipo oración ("Siguiente"), mensajes cortos
y en positivo ("Elegí otro equipo" en vez de "Todos en el mismo equipo").

---

## 4. Plan por fases

Cada fase es un PR que se puede probar solo. Las capturas de antes y después
van en el PR.

### Fase 0 — Decidir (Jose)
- [ ] Aprobar la paleta por roles (§3.3)
- [ ] Elegir la fuente después de ver la comparación en captura (§3.2)
- [ ] Elegir la estructura de la pantalla de luchadores: tarjetas con
      "apretá para unirte" o tabla de anchos fijos (§3.1)

### Fase 1 — Cimientos
- [ ] `assets/palettes/endesga-32.hex` y clase `UiTokens` (colores, espacios,
      tamaños de texto)
- [ ] Fuente elegida en `assets/fonts/` con su licencia y crédito en
      `assets/CREDITS.md`
- [ ] `assets/ui/theme.tres` con los componentes de §3.5, fijado como tema
      global en `project.godot`
- [ ] Test headless: sin `Color(...)` ni `font_size` sueltos en `scenes/ui`
- [ ] Script de capturas con Xvfb de todas las pantallas de menú

### Fase 2 — Arreglo inmediato de la pantalla de luchadores
- [ ] Filas en `GridContainer` con anchos fijos por columna
- [ ] Control como selector "‹ ›" que saltea dispositivos ya tomados
- [ ] Bots con la misma celda (selector de dificultad o "CPU") del mismo ancho
- [ ] Texto del control con las teclas ("WASD · J K L I")

### Fase 3 — Tarjetas y "apretá para unirte"
- [ ] Tarjetas de ancho fijo por jugador con el luchador grande
- [ ] Unirse y salir desde cada teclado/mando; "+ Bot" para sumar bots
- [ ] Un jugador solo queda unido sin pasos extra (teléfono)

### Fase 4 — Pasar todo al sistema
- [ ] Título, modo, cantidad, mapa, dificultad, rondas
- [ ] Opciones (panel opaco con `shade`), pausa
- [ ] HUD, tabla de posiciones, pantalla de ganador, textos flotantes
- [ ] Controles táctiles con los colores y la fuente del sistema
- [ ] Colores de jugadores y fondo a Endesga 32

### Fase 5 — Pulido
- [ ] Íconos de dispositivo y de armas (§3.6)
- [ ] Sonido y movimiento de foco (§3.7)
- [ ] Revisión en teléfono, TV con mando y PC

---

## Fuentes consultadas

- [monogram — datagoblin (itch.io)](https://datagoblin.itch.io/monogram)
- [Pixel Operator — Font Library](https://fontlibrary.org/en/font/pixel-operator)
- Código del repo: `scenes/ui/main_menu.gd`, `scenes/ui/options_menu.tscn`,
  `scenes/ui/hud.gd`, `scripts/autoload/game_manager.gd`, `project.godot`
