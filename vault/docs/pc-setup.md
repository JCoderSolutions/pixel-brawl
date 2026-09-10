---
type: "guide"
project: "pixel-brawl"
topic_key: "pc-setup"
---

# PC Setup — Cómo levantar este proyecto en cualquier máquina

Objetivo: clonar el repo en una PC nueva (o vuelta a usar) y tener todo el
estado visible para trabajar con cualquier agente.

> **Importante:** cada PC usa su propio path de disco. No hay un path "canónico".
> El proyecto puede vivir en cualquier carpeta según la máquina. Lo que SÍ tiene
> que ser constante es **el nombre del repo/carpeta raíz: `pixel-brawl`**. Eso es
> lo que Engram usa para asociar la memoria al proyecto.

## Requisitos base

- Git instalado
- [Obsidian](https://obsidian.md/) (abrir el vault: `pixel-brawl/vault/`)
- [Godot 4.4+](https://godotengine.org) (motor del juego)
- VS Code (editor)
- Cliente MCP de Engram configurado en el agente que uses (opencode, Claude…)

## Pasos

1. **Clonar el repo** donde viva `pixel-brawl`:
   ```bash
   git clone <url-del-repo> && cd pixel-brawl
   ```
2. **Abrir el vault**: Obsidian → Open folder as vault → `vault/`.
3. **Revisar el punto de entrada**:
   - `AGENTS.md` (raíz) — contrato para cualquier agente
   - `vault/Home.md` — índice del proyecto
   - `vault/docs/WORKFLOW.md` — contrato operativo (leerlo primero)
4. **Cargar memoria Engram**: levantar el MCP de Engram en tu agente y correr
   `mem_context` para restaurar el contexto del proyecto.
5. **Verificar Godot**: abrir `project.godot` (cuando exista) y exportar a Web.

## Checklist de "estoy listo para trabajar"

- [ ] Vault visible con notas cargadas
- [ ] `mem_context` devuelve contexto del proyecto
- [ ] `Status-Registry.md` leíble y actualizado
- [ ] Godot abre el proyecto sin errores (cuando exista)

## Sincronización entre PCs

- El estado vive **en el repo** (vault + código). Push/pull lo transporta.
- **Regla de oro:** la carpeta raíz SIEMPRE se llama `pixel-brawl`, aunque el
  path cambie de PC en PC. Engram identifica el proyecto por nombre/cwd; si la
  carpeta cambia de nombre, la memoria no lo encuentra.
- **Engram**: usa las herramientas de sync del MCP (o export a
  `vault/engram/` si el cliente lo soporta). Verificar en cada PC que la base
  de Engram está actualizada antes de depender de ella. La memoria
  no cubierta por Engram en una PC NO existe para la otra.
- Si algo no está documentado en el vault, primero documentalo, después
  trabajalo: esa es la regla para que cualquier PC/agente retome sin perder contexto.
- Cuando se trabaje desde una PC nueva: `git pull`, abrir vault, cargar Engram,
  y arrancar desde el `Status-Registry.md`.

## Trampas conocidas

- Vault oculto o renombrado → Obsidian pierde link IDs; usar paths relativos.
- Engram sin configurar en la PC nueva → el agente no ve memoria entre sesiones.
- Godot sin export presets → no se puede exportar Web/Android; configurarlos en
  `Export` al crear el proyecto.