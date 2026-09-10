---
type: "operating-contract"
project: "pixel-brawl"
topic_key: "workflow-contract"
---

# Workflow — Cómo trabajar en Pixel Brawl

Este es el contrato operativo del proyecto. Toda persona o agente que trabaje
en este repo DEBE seguirlo. Es deliberadamente **liviano**: sin scripts de
trazabilidad, sin MCP Knowledge, sin ceremonia.

## Principios

1. **Engram guarda la memoria** (qué/por qué/dónde, buscable entre sesiones).
2. **Obsidian guarda los documentos** (planes, fases, tareas, decisiones, status).
3. **Status se escribe en frontmatter** de cada nota. Simple, legible, portable.
4. **El humano aprueba conocimiento; el agente solo ejecuta la instrucción**.
5. **Commits por unidad de trabajo**, Conventional Commits, nunca "Co-Authored-By".

## Estados permitidos

| Ámbito | Valores | Quién lo cambia |
| --- | --- | --- |
| Fase (`phase.md`) | `planned \| in-progress \| blocked \| done \| cancelled` | Agente al avanzar |
| Tarea (`task.md`) | `todo \| in-progress \| done \| discarded` | Agente al trabajar |
| Conocimiento/Decisión (`decision.md`, memoria) | `draft \| reviewed \| approved \| discarded` | `approved`/`discarded` SOLO por instrucción explícita del humano |

Reglas duras del status:

- Un agente puede marcar tareas `done` cuando el trabajo está verificado, y
  `discarded` cuando un requisito se descartó por decisión de diseño.
- Un agente **nunca** marca `approved` una decisión/conocimiento por su cuenta.
  Silencio, patrón previo o confianza no es aprobación. El humano dice
  "aprobá esto" / "esto quedó descartado", y ahí recién se actualiza.
- `blocked` siempre lleva el motivo en la nota (y en el checkbox `[!]`).

## Ciclo de una tarea

1. **Leer** el plan maestro [[project/PLAN-pixel-brawl]] y la fase correspondiente.
2. **Tomar** la siguiente tarea `todo` de [[System/Status-Registry]].
3. **Marcar** `in-progress` en la nota y en el registry.
4. **Implementar** + testear.
5. **Guardar memoria** en Engram si hubo decisión/fix/descubrimiento (ver [[docs/engram-quick-reference]]).
6. **Commit** por unidad de trabajo (ver [[docs/commit-conventions]]).
7. **Marcar** `done` (o `discarded` + razón) en la nota y en el registry.
8. Refrescar [[System/Status-Registry]] siempre que cambie cualquier estado.

## Ciclo de una decisión

1. Crear nota con plantilla `Templates/decision.md`, status `draft`.
2. El humano **review** (opcional) → `reviewed`.
3. El humano pide aprobación (p. ej. "aprobá esto") → **agente** marca `approved`.
4. El humano descarta (p. ej. "esto quedó descartado") → **agente** marca `discarded`
   dejando el motivo en `discarded_reason`.

## Memoria Engram ↔ Obsidian

- **Verdad de memoria:** Engram (via `mem_save`). No se duplica todo en el vault.
- **Verdad de documento:** este vault.
- Si una decisión vive en Engram pero amerita doc persistente (arquitectura,
  convención, procedimiento) → crear nota de decisión o actualizar el doc, y
  vincularla con `[[wiki-link]]` desde la memoria o referencia (Engram → doc).
- La carpeta `engram/` del vault es un export **opcional** de la base de Engram
  para consulta offline/visual. Nunca es fuente de verdad de escritura.

## Multi-PC y multi-agente

- Todo el estado relevante está en este vault (texto plano). Clonar + abrir en
  Obsidian + cargar Engram: la nueva PC está lista. Ver [[docs/pc-setup]].
- Cualquier agente de IA lee `AGENTS.md` (raíz del repo), este doc, y el
  [[System/Status-Registry]] antes de tocar cualquier cosa.
- No inicializar Git en este repo sin instrucción explícita del humano. Cuando
  se inicialice, el vault viaja en el mismo repo.