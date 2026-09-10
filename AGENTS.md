# Pixel Brawl — Project instructions

Juego pixel art tipo **Superfighters** en **Godot 4**, con mapas destructibles,
ragdoll physics y multiplayer local + online. Stack 100% gratis.

## Punto de entrada

Cualquier agente/persona que trabaje en este repo:

1. Leer `vault/Home.md` — índice del proyecto.
2. Leer `vault/docs/WORKFLOW.md` — **contrato operativo** (memoria, status, commits).
3. Leer `vault/docs/engram-quick-reference.md` — cómo y cuándo usar Engram.
4. Leer `vault/docs/commit-conventions.md` — cómo committear.
5. Mirar `vault/System/Status-Registry.md` — qué está listo/en progreso/descartado.

## Reglas duras

- **Nunca** marcar `approved` una decisión/conocimiento por cuenta propia. Solo
  cuando el humano lo pide explícito ("aprobá esto", "esto quedó descartado").
- **Nunca** "Co-Authored-By" ni atribución de IA en commits. Conventional Commits.
- **Commits por unidad de trabajo**, no por tipo de archivo. Tests con el código.
- **Guardar memoria en Engram** tras cada decisión/fix/descubrimiento
  (`mem_save`), y `mem_session_summary` antes de decir "done".
- **Actualizar el Status-Registry** cuando cambie cualquier status de fase/tarea.
- **No inicializar Git** en este repo sin instrucción explícita del humano.
- Si una PC/agente no tiene contexto, primero revisar memoria con
  `mem_context` → `mem_search`, y leer docs del vault antes de tocar código.

## Stack y pipeline de arte

| Componente | Elección |
| --- | --- |
| Motor | Godot 4.x (MIT, export Web/desktop/Android) |
| Paleta | Endesga 32 (Lospec) — consistencia visual |
| Generación sprites | Retro Diffusion (50 créditos gratis) / Pixler.dev |
| Editor pixel | LibreSprite (gratis) |
| Tilemaps | Tiled |
| Import a Godot | Plugin Importality |
| SFX | BFXR/sfxr + Audacity |
| Online | WebRTC P2P (Godot 4), escalar a Nakama |

## Multi-PC

Todo el estado vive en este vault (texto plano) + Engram. Para levantar en otra
máquina: ver `vault/docs/pc-setup.md`.