---
type: "index"
project: "pixel-brawl"
---

# Engram — Memoria del proyecto

Este folder es un export **opcional y de solo lectura** de la base de memoria
Engram del proyecto, para consulta visual/offline en Obsidian.

- **No es la fuente de verdad.** La memoria viva está en Engram (via MCP) y se
  consulta con `mem_context` / `mem_search` / `mem_get_observation`.
- No escribir ni editar notas acá directamente: cualquier cambio se pierde en el
  próximo sync y contradice la base real.
- Para guardar memoria, usar `mem_save`. Para aprobar/descartar decisiones, ver
  [[docs/WORKFLOW]].

## Qué encontrás acá (cuando haya export)

| Categoría | Contenido |
| --- | --- |
| `session_summary/` | Resúmenes de cierre de sesión |
| `decision/` | Decisiones (status: draft/reviewed/approved/discarded) |
| `bugfix/` | Bugs y su root cause |
| `discovery/` | Descubrimientos y gotchas |
| `config/` | Configuración y setup |
| `preference/` | Preferencias del usuario |
| `architecture/` | Arquitectura y patrones |

## Cómo se puebla

- Automático si el cliente Engram soporta export a vault, o manual cuando haga
  falta contexto offline. El procedimiento de sync entre PCs está en
  [[docs/pc-setup]].