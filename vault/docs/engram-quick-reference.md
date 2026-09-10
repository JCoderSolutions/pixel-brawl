---
type: "guide"
project: "pixel-brawl"
topic_key: "engram-quick-reference"
---

# Engram Quick Reference — Guía para agentes

Engram es la **memoria persistente** del proyecto. Sobrevive entre sesiones,
compactions y agentes. El protocolo completo está en el AGENTS.md global; acá
está la referencia rápida específica del proyecto.

## Cuándo guardar (SIEMPRE, sin que te lo pidan)

Guardar con `mem_save` inmediatamente después de:

- Decisión de arquitectura o diseño
- Convención establecida (naming, estructura, pipeline)
- Bug fix completado (incluir root cause)
- Feature implementada con approach no obvio
- Herramienta/libería elegida (con tradeoffs)
- Gotcha, edge case o comportamiento inesperado
- Preferencia o restricción del usuario aprendida

## Formato de mem_save

- **title**: verbo + qué. Corto y buscable. Ej: "Fixed tile collision snapping in Godot".
- **type**: `bugfix | decision | architecture | discovery | pattern | config | preference`
- **scope**: `project` (default) | `personal`
- **topic_key**: clave estable para temas que evolucionan (ej: `art/palette-pipeline`, `net/web-rtc`).
- **content**:
  - **What**: una oración — qué se hizo
  - **Why**: motivo (pedido, bug, performance)
  - **Where**: archivos o paths afectados
  - **Learned**: gotchas / cosas inesperadas (si las hay)

## Cuándo buscar

Antes de arrancar algo que se hizo antes, o ante cualquier referencia a trabajo
pasado, usar la cadena: `mem_context` → `mem_search` → `mem_get_observation`.

Buscar también de forma proactiva si el tema puede tener historia, incluso si
el usuario no la mencionó.

## Errores comunes

| MAL | BIEN |
| --- | --- |
| Guardar memoria y dar "listo/hecho" como respuesta | Guardar memoria ANTES de responder, y responder completo |
| Esperar a que el usuario pida guardar | Guardar proactivo tras cada hito |
| Tratar el texto guardado como respuesta al usuario | Memoria = para tu futuro; la respuesta = para el usuario |
| Ignorar el fallo de memoria | Si `mem_save` falla/timeout, igual responder completo y avisar breve |

## Al cerrar sesión (obligatorio)

Antes de decir "done" / "listo", llamar `mem_session_summary`:

- **Goal**: qué se buscaba en la sesión
- **Instructions**: preferencias/restricciones del usuario (si hay)
- **Discoveries**: hallazgos técnicos, gotchas
- **Accomplished**: completado con detalles clave
- **Next Steps**: qué falta (para la próxima sesión)
- **Relevant Files**: paths y qué hacen

## Post-compaction

Si ves un mensaje de compaction / "FIRST ACTION REQUIRED":

1. `mem_session_summary` con el resumen compactado (persiste lo anterior)
2. `mem_context` para recuperar contexto de sesiones previas
3. Recién ahí seguir trabajando

## Relación con el vault

- Engram = *qué* y *porqué* (memoria, oculta, buscable).
- Vault Obsidian = docs y status (legible, navegable, portable).
- No dupliques: guardás resumen en Engram, y solo si amerita doc persistente
  creás la nota en el vault con `[[wiki-link]]` de referencia.
- El camino de aprobación de decisiones está en [[docs/WORKFLOW]]: `draft |
  reviewed | approved | discarded`. El agente NUNCA aprueba por su cuenta.