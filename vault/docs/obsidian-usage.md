---
type: "guide"
project: "pixel-brawl"
topic_key: "obsidian-usage"
---

# Obsidian Usage — Cómo guardar info en el vault

Obsidian es la fuente de verdad documental del proyecto. Guardar información en
el vault = escribir un archivo `.md` bien estructurado con **frontmatter** y
**wiki-links**.

## Estructura esperada

| Carpeta | Qué va ahí |
| --- | --- |
| `project/PLAN-*.md` | Planes maestros (documento grande de dirección) |
| `project/phases/PHASE-N-*.md` | Fases del proyecto (etapas con objetivos) |
| `project/tasks/TASK-NNN-*.md` | Tickets de trabajo individuales |
| `project/decisions/*.md` | Decisiones de arquitectura/diseño |
| `docs/*.md` | Guías y procedimientos (metodología) |
| `System/Status-Registry.md` | Resumen vivo del estado |
| `Templates/*.md` | Plantillas (no editables directo) |
| `engram/` | Export de memoria (no escribir directo) |

## Reglas de escritura

1. **Nombre descriptivo**: `TASK-007-add-dash-mechanic.md`, no `nota.md`.
2. **Siempre frontmatter** al inicio (YAML entre `---`):
   ```yaml
   ---
   type: task
   status: todo
   priority: high
   phase: PHASE-1
   ---
   ```
3. **Siempre wiki-links** (no URLs largas). Enlazar con `[[nota]]` o `[[nota|Texto]]`.
4. **Un solo tema por nota**. Si una nota mezcla dos temas, partila.
5. **Checkboxes** para tareas dentro de fases: `- [ ] Pendiente`, `- [/] En curso`,
   `- [!] Bloqueado`, `- [x] Hecho`.
6. Si una nota cambia de status, actualizá **la nota Y el Status-Registry**.
7. No dejar notas vacías ni "placeholders sin sentido". Si está en `todo`, definela bien.

## Markdown que usamos

- Títulos: `#`, luego `##`.
- Listas: `-` (con espacio tras el guion).
- Código: entre triple backticks con lenguaje (`gdscript`, `bash`, `json`).
- Negrita: `**texto**`. Cursiva: `*texto*`.
- Tablas: `| col | col |` con separador `| --- |`.

## Plantillas

Usar siempre las plantillas de `Templates/` para notas nuevas:

- [[Templates/task|Plantilla tarea]]
- [[Templates/phase|Plantilla fase]]
- [[Templates/plan|Plantilla plan]]
- [[Templates/decision|Plantilla decisión]]
- [[Templates/engram-memory|Plantilla memoria Engram]]

## Qué NO guardar en el vault

- Credenciales, tokens, claves.
- Outputs gigantes de herramientas (eso va a temp/logs).
- Duplicados de la base de Engram (la memoria viva es Engram; el vault referencia).