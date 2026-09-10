---
type: "guide"
project: "pixel-brawl"
topic_key: "commit-conventions"
---

# Commit Conventions

Convención global del proyecto (extiende la regla global de los AGENTS.md):
**solo Conventional Commits**, nunca `Co-Authored-By`, nunca atribución de IA.

## Formato

```
<type>(<scope>): <mensaje en resultado>
```

- `<type>`: `feat`, `fix`, `docs`, `refactor`, `chore`, `test`, `perf`, `style`.
- `<scope>`: opcional, área afectada (ej. `player`, `map`, `art`, `net`).
- `<mensaje>`: describe el **resultado**, no la lista de archivos.

## Reglas de oro

| Regla | Ejemplo |
| --- | --- |
| Commit por **unidad de trabajo** | `feat(player): add run/jump/crouch movement` |
| No commit por tipo de archivo | NO `add models` → `add services` → `add tests` |
| Tests con el código que prueban | Tests en el mismo commit que el comportamiento |
| Docs con el cambio que explican | Docs van con la feature |
| El mensaje explica el OUTCOME | "add token validation", no "add files" |

**Mal:** `update files`, `wip`, `fix stuff`, `add player controller` (ambigua).
**Bien:** `feat(net): wire WebRTC host/join on the main menu`.

## Work unit checklist (antes de commitear)

- [ ] Un solo propósito claro.
- [ ] El repo sigue teniendo sentido aplicando SOLO este commit.
- [ ] Tests o docs incluidos cuando aplican.
- [ ] Rollback razonable sin revertir trabajo no relacionado.
- [ ] Comando de test enfocado y resultado exacto registrados.

## Flujo típico

```bash
git diff --stat          # revisar el alcance
git diff --cached --stat
git log --oneline -5     # ver el estilo de commits recientes
git add <archivos de ESA unidad de trabajo>
git commit -m "feat(map): add destructible tile layer"
```

## Workload guard

Si una unidad de trabajo proyecta >400 líneas cambiadas, partila en commits
encadenados más pequeños por unidad coherente. Nunca borres docs, tests o
comentarios para "encajar" en el límite: partí el trabajo de verdad.