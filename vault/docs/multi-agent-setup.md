---
type: "guide"
project: "pixel-brawl"
topic_key: "multi-agent-setup"
---

# Multi-Agent Setup — Rotación entre agentes

Guía para trabajar con múltiples agentes (OpenCode, Claude Code, Kiro) en el
mismo proyecto. Todos comparten la misma memoria vía Engram y el mismo estado
vía el vault Obsidian.

## Arquitectura de memoria compartida

```
┌─────────────────────────────────────────────────────────┐
│                    Engram MCP Server                     │
│  (binario único: C:\Users\Jose\AppData\Local\engram\    │
│   bin\engram.exe)                                       │
│  DB: ~/.engram/engram.db (SQLite compartido)            │
└─────────────────────────────────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
   ┌────▼────┐        ┌────▼────┐        ┌────▼────┐
   │OpenCode │        │Claude   │        │Kiro     │
   │         │        │Code     │        │         │
   └─────────┘        └─────────┘        └─────────┘
```

**Regla de oro:** Engram es la fuente de verdad de memoria. El vault es la
fuente de verdad de documentos y status.

## Agentes soportados

| Agente | Config MCP | Estado |
|--------|-----------|--------|
| **OpenCode** | `~/.config/opencode/opencode.jsonc` | ✅ Configurado |
| **Claude Code** | Plugin `engram@engram` | ✅ Configurado |
| **Kiro** | `~/.kiro/settings/mcp.json` | ✅ Configurado |

## Cómo funciona la rotación

### Flujo típico

1. **Empezar sesión** con cualquier agente
2. **Cargar contexto**: el agente llama `mem_context` automáticamente
3. **Trabajar**: el agente usa `mem_save` para persistir decisiones/fixes
4. **Cerrar sesión**: el agente llama `mem_session_summary`
5. **Rotar**: pasar al siguiente agente — él carga el contexto vía `mem_context`

### Qué se comparte

| Dato | Se comparte | Cómo |
|------|-------------|------|
| Memoria (decisiones, fixes, discoveries) | ✅ | Engram DB (`~/.engram/engram.db`) |
| Documentos (planes, fases, tareas) | ✅ | Vault Obsidian (en el repo) |
| Status del proyecto | ✅ | `Status-Registry.md` en el vault |
| Configuración de agente | ❌ | Cada uno tiene su propia config |
| Historial de chat | ❌ | No se comparte (cada sesión es independiente) |

## Configuración por agente

### OpenCode

Configuración: `~/.config/opencode/opencode.jsonc`

```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "codegraph": {
      "type": "local",
      "command": ["codegraph", "serve", "--mcp"],
      "enabled": true
    },
    "engram": {
      "type": "local",
      "command": ["C:\\Users\\Jose\\AppData\\Local\\engram\\bin\\engram.exe", "mcp"],
      "enabled": true
    }
  }
}
```

### Claude Code

Plugin instalado: `engram@engram` (via marketplace)

Verificar en `~/.claude/settings.json`:
```json
{
  "enabledPlugins": {
    "engram@engram": true
  }
}
```

### Kiro

Configuración: `~/.kiro/settings/mcp.json`

```json
{
  "mcpServers": {
    "codegraph": {
      "type": "stdio",
      "command": "codegraph",
      "args": ["serve", "--mcp"]
    },
    "engram": {
      "type": "stdio",
      "command": "C:\\Users\\Jose\\AppData\\Local\\engram\\bin\\engram.exe",
      "args": ["mcp"]
    }
  }
}
```

## Tools MCP disponibles (todas)

| Tool | Descripción | Cuándo usar |
|------|-------------|-------------|
| `mem_save` | Guardar memoria | Tras decisión/fix/discovery |
| `mem_search` | Buscar en memoria | Antes de empezar algo |
| `mem_context` | Contexto del proyecto | Al inicio de sesión |
| `mem_session_summary` | Resumen de sesión | Al cerrar sesión |
| `mem_get_observation` | Leer observación específica | Cuando se necesita detalle |
| `mem_update` | Actualizar memoria existente | Corregir/agregar info |

## Checklist por sesión

- [ ] El agente cargó contexto (`mem_context` devolvió datos)
- [ ] `Status-Registry.md` está actualizado (leído al inicio)
- [ ] Al cerrar: `mem_session_summary` ejecutado
- [ ] Al cerrar: status actualizado en `Status-Registry.md`

## Troubleshooting

### "El agente no ve memoria anterior"

1. Verificar que Engram MCP está configurado para ese agente
2. Correr `mem_context` manualmente — si devuelve vacío, la DB no tiene datos
3. Verificar que el `project` en `.engram/config.json` es `"pixel-brawl"`

### "La memoria se pierde entre PCs"

1. Engram DB vive en `~/.engram/engram.db` (local a cada PC)
2. Usar `engram sync` para exportar/importar chunks comprimidos
3. O exportar a `vault/engram/` para consulta offline (no es fuente de verdad)

### "El vault no se ve en Obsidian"

1. Abrir Obsidian → Open folder as vault → `pixel-brawl/vault/`
2. Verificar que `.obsidian/` se creó (primera vez)
