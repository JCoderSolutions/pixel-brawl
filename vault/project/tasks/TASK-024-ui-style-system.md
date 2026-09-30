---
type: "task"
status: "in-progress"            # allowed: todo | in-progress | done | discarded
priority: "high"
phase: "PHASE-3"
depends_on: "TASK-011, TASK-012"
source_memory_id: ""
discarded_reason: ""
---

# TASK-024 — Línea gráfica y sistema de UI

## Objetivo

Pedido de Jose (2026-09-30): la pantalla de personajes y controles se
desalinea según lo que se elige, y no hay una línea gráfica común. Definir un
sistema único (paleta por roles, fuente pixel, escala de texto, espaciado,
componentes) y aplicarlo a todo el juego. Plan completo y auditoría en
[[docs/ui-style-guide]].

## Criterios de done

- [x] Fase 0 (2026-09-30): Jose aprueba la paleta, deja Pixel Operator + Jersey 10 y elige las tarjetas
- [x] Fase 1: `UiTokens`, fuentes (Pixel Operator + Jersey 10, provisorias),
      `theme.tres` global generado desde los tokens, test
      `scripts/ui/test_ui_theme.gd`, capturas con `tools/ui_screenshots.sh`
- [x] Fase 2: descartada, sus puntos entraron en la Fase 3
- [x] Fase 3: tarjetas de ancho fijo con "apretá para unirte", "+ Bot" y dificultad por bot en cada tarjeta; el menú queda Título → Luchadores → Mapa → Rondas
- [ ] Fase 4: todas las pantallas y el HUD con el sistema
- [ ] Fase 5: íconos, sonido y movimiento de foco, revisión en teléfono/TV/PC

## Evidencia

- Auditoría con capturas: `vault/docs/img/ui-audit/`
- Comparación de fuentes: `vault/docs/img/fonts/`
- Después de la Fase 1: `vault/docs/img/ui-fase1/`
- Tarjetas de la Fase 3: `vault/docs/img/ui-fase3/`
- Tests: `scripts/ui/test_ui_theme.gd`, `scripts/test_control_schemes.gd`, `scripts/test_main_menu.gd`
