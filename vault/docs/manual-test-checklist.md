---
type: "guide"
topic_key: "manual-test-checklist"
created: "2026-09-30"
---

# Lista de chequeo manual (una sesión cierra varias tareas)

Todo lo que el código ya tiene y solo falta **jugar y sentir**. Está ordenada
por dispositivo para hacerla de corrido. Versión web:
<https://jcodersolutions.github.io/pixel-brawl/>.

Cómo usarla: marcar `[x]` lo que se sintió bien. Si algo no, anotar al lado
qué pasó (qué mapa, qué hiciste, qué esperabas) y pasarlo a la sesión con el
agente. Cuando todos los ítems de una tarea están marcados, esa tarea puede
pasar a `review` en el [[System/Status-Registry]].

Controles: ver la tabla del `README.md` (P1: WASD, J golpe, K cubrirse,
L recoger, I cambiar arma, Esc pausa).

## Sesión 1: PC, teclado, 1 jugador contra 1 bot (~20 min)

Menú: Luchadores → sumar un bot desde la tarjeta → mapa **Arena** → 3 rondas.

**Movimiento** ([[project/tasks/TASK-002-player-movement|TASK-002]])
- [ ] Moverse con A/D responde al instante, sin patinar al frenar
- [ ] Salto variable: toque corto = salto bajo; mantener = salto alto
- [ ] Sprint (doble toque A/D) se nota más rápido y no se activa sin querer
- [ ] Zambullida (S corriendo): corta, cae y rueda; no cruza medio mapa
- [ ] Cornisas: se agarra solo en el borde de arriba de una pared, nunca a mitad

**Golpes** ([[project/tasks/TASK-003-melee-combat|TASK-003]])
- [ ] El combo (J J J) termina en uppercut y se siente con peso
- [ ] El alcance es justo: si parece que tocó, pegó
- [ ] Patada en el aire: patea sin tirarse al piso
- [ ] Cubrirse (K) frena golpes y la barra de energía se entiende
- [ ] Agarrar y lanzar al rival funciona y se entiende cuándo se puede

**Bloques** ([[project/tasks/TASK-004-destructible-tiles|TASK-004]],
[[project/tasks/TASK-019-block-materials|TASK-019]])
- [ ] Romper cajas y plataformas a golpes se siente bien (partículas, sonido)
- [ ] Cada material se comporta distinto (madera, ladrillo, metal; los bloques indestructibles no se rompen)

**Armas** ([[project/tasks/TASK-005-weapons-and-projectiles|TASK-005]],
[[project/tasks/TASK-021-more-weapons|TASK-021]],
[[project/tasks/TASK-006-grenade-explosion|TASK-006]])
- [ ] Recoger (L) y cambiar (I) es rápido; el HUD muestra arma y munición
- [ ] Pistola, rifle, escopeta, recortada, bazuca: cadencia, daño y retroceso razonables
- [ ] Bate y katana se sienten distintos a los puños
- [ ] Apuntar a mano (K + W/S) es cómodo
- [ ] Granada: se lanza, rebota y rompe la pared; la cámara tiembla lo justo
- [ ] Molotov: el fuego se propaga y se apaga en un tiempo razonable
- [ ] Montar el cohete de la bazuca: se controla, no sale de la pantalla
- [ ] Ninguna arma se siente rota (demasiado fuerte o inútil)

**Muerte y ronda** ([[project/tasks/TASK-007-ragdoll-death|TASK-007]],
[[project/tasks/TASK-011-rounds-hud-winner|TASK-011]],
[[project/tasks/TASK-018-shared-camera|TASK-018]])
- [ ] El ragdoll vuela y cae de forma creíble (no atraviesa el piso)
- [ ] Golpe final en cámara lenta, tabla de posiciones entre rondas, festejo del ganador
- [ ] Muerte súbita: si la ronda se alarga, termina sola
- [ ] Cámara: siempre se ve a los dos, el suavizado no marea, el temblor no molesta
- [ ] Morir en la cuenta regresiva: la ronda sigue bien

**Bots** ([[project/tasks/TASK-020-bots|TASK-020]])
- [ ] Fácil se le gana siempre; Normal da pelea; Difícil cuesta
- [ ] Subido a una plataforma con un bot armado abajo: Normal/Difícil apuntan
  y disparan hacia arriba (no se quedan quietos debajo)

**Sonido y opciones** ([[project/tasks/TASK-012-sfx-game-feel|TASK-012]])
- [ ] Volúmenes equilibrados (música no tapa golpes); el freno en cada golpe no traba
- [ ] Opciones: volumen, pantalla completa y táctil se guardan al volver

**Pausa y menú** ([[project/tasks/TASK-024-ui-style-system|TASK-024]])
- [ ] Esc pausa; Seguir / Reiniciar partida / Menú funcionan
- [ ] Menú completo con teclado: se ve dónde está el foco y suena al moverse

## Sesión 2: los 4 mapas (~15 min)

Una ronda en cada mapa contra un bot ([[project/tasks/TASK-009-map-set|TASK-009]],
[[project/tasks/TASK-020-hazards-traps|TASK-020 trampas]],
[[project/tasks/TASK-010-power-ups|TASK-010]]).

- [ ] **Fábrica**: pinchos, lanzallamas, bloque que cae, interruptor, barriles
- [ ] **Obra en la azotea**: vacío (caer = morir), bloque que cae, interruptor, barriles
- [ ] **Laboratorio**: ácido (parpadeo, burbujas y sonido al tocarlo), lanzallamas, interruptor
- [ ] **Fundición**: pozo de fuego, lanzallamas, bloque que cae, interruptor
- [ ] Cada trampa avisa antes de dañar y el daño se entiende
- [ ] Cajas de suministro caen cada tanto y dan algo útil
- [ ] Power-ups: al tocarlo se guarda (se ve en el HUD) y se usa con O / B /
  botón Power; se entiende qué hace cada uno al usarlo
- [ ] Con un power-up guardado, el siguiente queda en el piso
- [ ] Animaciones del luchador se leen a tamaño real (correr, golpear, colgarse, rodar)
  ([[project/tasks/TASK-022-fighter-animations|TASK-022]])

## Sesión 3: 2 personas en un teclado + mandos (~10 min)

([[project/tasks/TASK-008-local-multiplayer-input|TASK-008]])
- [ ] P1 (WASD) y P2 (flechas) juegan a la vez sin que se pisen teclas
  (probar P1 saltando + corriendo mientras P2 dispara)
- [ ] Con 2 mandos más: cada uno se une apretando un botón en su tarjeta
- [ ] 4 jugadores: la cámara encuadra a todos y el HUD se entiende

## Sesión 4: teléfono (~15 min)

([[project/tasks/TASK-015-touch-controls|TASK-015]])
- [ ] Botones del tamaño justo para el pulgar; el stick responde donde se apoya
- [ ] Vertical y horizontal: se ve todo, nada tapado por los botones
- [ ] Salto variable y zambullida se pueden hacer con el táctil
- [ ] Cambiar de arma (botón) y pausa (II) funcionan
- [ ] Menú y opciones se usan cómodos con el dedo
- [ ] Una partida en cada mapa sin tirones

## Sesión 5: TV o monitor con mando (~5 min)

- [ ] Todo el menú se recorre solo con el mando (sin mouse)
- [ ] Los textos se leen desde el sillón

## Al terminar

Pasarle al agente: qué quedó sin marcar y las notas. El agente actualiza las
tareas y el Status-Registry (las tareas pasan a `review`; `done` lo decide
Jose).
