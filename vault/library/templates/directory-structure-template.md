---
date: 2026-06-04
tags: [template, conventions]
type: concept
status: active
---

# Directory structure template

Copy this into `vault/projects/<project>/directory-structure.md`, then list it
under `## always` in that project's `context-map.md` so it loads every session.
Fill the table from the real repo (`ls -d */` + `.gitignore`). Keep it factual —
describe what exists, not an idealized layout. Companion of [[directory-structure]].

```markdown
---
date: <YYYY-MM-DD>
tags: [<project>, project-layout, conventions]
type: concept
status: active
project: <project>
---

# Directory structure — <repo name>

Where each kind of file belongs. Repo root: `<path>`.

## Layout

| Dir | Committed? | Purpose |
|-----|-----------|---------|
| `src/` | yes | Importable library modules. No top-level run logic. |
| `scripts/` | yes | Entry points that import from `src/`. |
| `<dir>/` | <yes/no> | <purpose> |

## Where new code goes

- <kind of file> — <which dir, and the pattern to follow>

## Import direction

<one-way dependency rule, e.g. scripts -> src, src imports only src + third-party>
```
