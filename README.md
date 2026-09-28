# Pixel Brawl

Juego pixel art tipo **Superfighters** con mapas destructibles, ragdoll physics
y multiplayer local + online. Motor: **Godot 4.x**. Stack 100% gratis.

## Cómo jugar

El juego abre en el menú; **Jugar** lanza una partida local de 2 jugadores en
la arena (gana el primero en llevarse 3 rondas).

| Acción | P1 | P2 | Mando (uno por jugador) |
| --- | --- | --- | --- |
| Moverse | A / D | ← / → | Stick o cruceta |
| Saltar | W / Espacio | ↑ | A |
| Agacharse | S | ↓ | Abajo |
| Golpe | J | Ctrl / Enter | X |
| Disparar arma | K | . / Numpad 1 | RB |
| Recoger / soltar arma | L | , / Numpad 2 | Y |

### Pantalla y arte

- Resolución base 480x270, escalada en múltiplos enteros (pixel-perfect).
  En teléfono (vertical u horizontal) o pantallas anchas el espacio sobrante
  muestra más mundo en vez de franjas negras; la cámara centra el mapa.
- Sprites de 32x32 con el origen en los pies (centro inferior). El cuerpo
  del jugador (18x30) y su hurtbox caben dentro de ese marco.

## Stack

| Componente | Elección |
| --- | --- |
| Motor | Godot 4.x (MIT, export Web/desktop/Android) |
| Paleta | Endesga 32 (Lospec) — consistencia visual |
| Generación sprites | Retro Diffusion / Pixler.dev |
| Editor pixel | LibreSprite |
| Tilemaps | Tiled |
| Import a Godot | Plugin Importality |
| SFX | BFXR/sfxr + Audacity |
| Online | WebRTC P2P (Godot 4), escalar a Nakama |

## Documentación

Levantar el vault `vault/` en Obsidian. Punto de entrada: `vault/Home.md`.
Contrato operativo: `vault/docs/WORKFLOW.md`. Estado vivo: `vault/System/Status-Registry.md`.

## Git

- Conventional Commits por unidad de trabajo (detalles en `vault/docs/commit-conventions.md`).
- Configuración por-PC: la identidad git es local a cada máquina, no está versionada.