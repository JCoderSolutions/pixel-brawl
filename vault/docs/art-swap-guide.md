# Guía: cambiar las formas nativas por arte

Todo lo que hoy se dibuja con formas nativas tiene un enganche para arte
real. Cuando existe el arte, se usa; si falta, queda la forma nativa. No hay
que tocar código: se sueltan archivos y se completan campos en el editor.
Paleta: Endesga 32. Test de los enganches: `scripts/test_art_hooks.gd`.

## Tiles del mapa (16x16)

- Cada material es un `.tres` en `scenes/maps/materials/` (madera, ladrillo,
  metal). En el inspector, grupo **Art**:
  - `texture`: una **tira horizontal de cuadros de 16x16**. El primero es el
    tile intacto y los siguientes, cada vez más roto. Con 3 cuadros
    (48x16 px), el tile muestra el 1º con la vida llena, el 2º desde la
    mitad y el 3º cuando está por romperse. Un solo cuadro (16x16) no cambia.
    El metal es indestructible, así que le alcanza con 1.
  - `plank_texture`: la misma idea para las plataformas `=` (tablones que se
    atraviesan desde abajo). Se ven solo los 6 px de arriba de cada cuadro.
    Si falta, usa `texture`.
- Guardar las imágenes en `assets/sprites/tilesets/` (p. ej. `wood.png`).
  En la importación: Filter **Nearest**.
- Con `texture` puesta, desaparecen el color de relleno y el dibujo de
  vetas, ladrillos o remaches.
- Los mapas siguen armándose con el texto de `DestructibleMap.layout`
  (`#`, `=`, `B`, `X`). No hace falta Tiled para el terreno destructible.

## Decoración de fondo

- La decoración de cada mapa son `ColorRect` dentro del nodo `Decor` (y el
  `Background`). Se pueden reemplazar en el editor por `Sprite2D` o
  `TextureRect` con la imagen, en la misma posición. Nada del código los
  referencia.
- Si el fondo se arma en Tiled, la capa de decoración entra como `TileMap`
  (con Importality o el importador de Tiled) debajo de `DestructibleMap`.

## Luchadores (32x32)

- Una hoja por personaje: un recurso **SpriteFrames** guardado como
  `assets/sprites/characters/<nombre en minúsculas>.tres` (`bruno.tres`,
  `roja.tres`, `kai.tres`, `sol.tres`, `sombra.tres`, `doc.tres`,
  `punk.tres`, `obrero.tres`). `FighterLook` lo carga solo si existe.
- Una animación por pose de `FighterRig.Anim`, con estos nombres: `idle`,
  `run`, `jump`, `fall`, `crouch`, `attack`, `hurt`, `aim`, `victory`,
  `dive`, `ride`, `block`, `roll`, `uppercut`, `kick`, `air_kick`, `grab`,
  `held`, `hang`. Velocidad (FPS) y loop se configuran en cada
  animación. Si falta una animación, esa pose se dibuja con formas nativas.
- Cuadros de 32x32, **mirando a la derecha** y con **los pies en el borde de
  abajo**, centrados. El juego los espeja al mirar a la izquierda.
- El destello del golpe aclara el sprite. La marca de equipo se dibuja
  sola arriba de la cabeza. El color de camiseta del personaje se sigue
  usando en el HUD, así que conviene que coincida con el sprite.

## Armas

- Cada arma es un `.tres` en `scripts/weapons/data/`. Grupo **Art**:
  - `sprite`: la imagen con el caño apuntando a la derecha.
  - `sprite_grip`: el píxel del sprite que va en la mano. Las balas salen a
    `muzzle_offset` px de la mano, así que conviene que el caño termine
    ahí.
- La misma imagen se usa en la mano y en el piso (centrada).

## Lo que todavía es forma nativa sin enganche

- Proyectiles, granada o cohete en vuelo, explosión y partículas
  (`ImpactBurst`) y power-ups. Son chicos y se ven bien así. Si se quiere
  arte, siguen el mismo patrón: un `Texture2D` opcional en su recurso o
  escena.
