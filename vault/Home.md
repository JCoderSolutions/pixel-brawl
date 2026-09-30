---
type: home
project: pixel-brawl
tags:
  - home
  - index
  - game
  - godot
---

# Pixel Brawl — Vault

Juego pixel art tipo **Superfighters** con mapas destructibles, ragdoll physics y
multiplayer local + online. Motor: **Godot 4.x**. Stack 100% gratis.

Este vault es la fuente de verdad de **planes, fases, tareas y status** del
proyecto. Funciona desde cualquier PC y con cualquier agente de IA.

## Cómo navegar este vault

| Área | Qué contiene |
| --- | --- |
| [[docs/WORKFLOW]] | Cómo funciona el sistema (memoria, status, commits) — leélo primero |
| [[project/PLAN-pixel-brawl]] | El plan maestro del juego |
| [[project/phases/PHASE-1-core|Fases]] | Fases del desarrollo (cada una con sus tareas) |
| [[project/tasks|Tareas]] | Tickets de trabajo individuales |
| [[System/Status-Registry]] | Estado actual del proyecto de un vistazo |
| [[Templates]] | Plantillas para crear notas nuevas |
| [[docs/multi-agent-setup]] | Config multiagente (OpenCode, Claude, Kiro) |
| [[docs/engram-hooks-behavior]] | Qué hacen los hooks automáticos de Engram |
| [[docs/art-swap-guide]] | Cómo reemplazar las formas nativas por tilesets y sprites |
| [[docs/manual-test-checklist]] | Qué probar a mano (por dispositivo) para cerrar las tareas |
| [[docs/asset-pipeline]] | Herramientas (gratis y de IA), medidas y flujo para hacer los assets |
| [[docs/ui-style-guide]] | Línea gráfica y sistema de UI (propuesta: paleta, fuente, componentes, fases) |
| Engram (memoria) | `engram/` — export de memoria persistente (opcional) |

## Estado del proyecto

Estado global: **`planned`** — Fase 1 (core mechanics).

Resumen rápido en [[System/Status-Registry]]. Las fases se siguen en `project/phases/`.

## Sistema de trabajo

- **Memoria:** Engram (guardá con `mem_save`; cada decisión/fix/descubrimiento).
- **Docs:** Obsidian vault (este).
- **Status de tareas:** frontmatter en cada nota. Solo 4 valores: `todo | in-progress | done | discarded`.
- **Status de conocimiento/decisiones:** `draft | reviewed | approved | discarded`.
  El agente cambia a `approved`/`discarded` **solo cuando el humano lo pide explícito**.
- **Commits:** Conventional Commits por unidad de trabajo. Detalles en [[docs/commit-conventions]].

## Referencias del juego

- Paleta visual: **Endesga 32** (Lospec) — consistencia de arte
- Pipeline de arte: Retro Diffusion (AI) → LibreSprite (limpieza) → Godot (Importality)
- Roadmap de 4 semanas: [[project/PLAN-pixel-brawl]]