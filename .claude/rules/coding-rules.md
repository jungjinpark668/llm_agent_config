# Coding Rules

Behavioral guidelines to reduce common LLM coding mistakes. These bias toward caution over speed. For trivial tasks, use judgment.

---

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them — don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

---

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.
- No premature abstractions or helpers for one-time operations.
- No redundant error handling for internal code paths — only validate at system boundaries.
- No feature flags or backward-compat shims — just change the code.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

---

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently. If a `code-context.md` exists for this project, its Conventions section is the authoritative style reference.
- If you notice unrelated dead code, mention it — don't delete it.
- Don't add docstrings, comments, or type annotations to unchanged code.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

---

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" -> "Write tests for invalid inputs, then make them pass"
- "Fix the bug" -> "Write a test that reproduces it, then make it pass"
- "Refactor X" -> "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] -> verify: [check]
2. [Step] -> verify: [check]
3. [Step] -> verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

## 5. Class Isolation

**Each class does ONLY its own job. Orchestration belongs outside.**

The rule targets two things:
- **Orchestration** — calling classes in sequence and passing outputs between them belongs in the main script/test, not inside classes.
- **Unnecessary coupling** — a class should not instantiate another domain class when the caller could pass the result instead.

This is still a principle to follow, but apply judgment: when embedding a sub-component genuinely improves code quality and readability (e.g., a beamformer that owns internal filters as part of its signal chain), that is acceptable. The test: would removing the internal class break core functionality, or just move orchestration outside? Prefer the option that results in better readability and cleaner API for callers.

- If the code generates a plot, default to PNG output. Ask the user whether to also create SVG, EPS, or EMF files.

---

## 6. Change Strategy

**Search before writing. Extend before duplicating.**

When modifying existing code:
- Search for existing methods that already do what you need before writing new ones.
- Integrate into existing methods via optional parameters rather than duplicating logic.
- Only create new functions when integration would hurt readability or is technically impossible.
- When modifying, ensure original behavior still works — the default path must remain unchanged.

---

## 7. Naming & Structure

**Follow the project's existing conventions. Don't introduce a second style.**

- If the codebase uses `snake_case`, use `snake_case`. If it uses `camelCase`, use `camelCase`.
- Match existing patterns for file organization, module layout, and import style.
- If the project has no existing code (new project), ask the user which style to reference — or suggest a convention and confirm before writing.
- Never mix naming styles within a project.

---

## 8. Comment Style

**Default Python docstring format is Sphinx (`reST`).**

When a docstring is warranted (public API, non-obvious parameters), use Sphinx style:

```python
def compute_average(values, weights=None):
    """Compute arithmetic or weighted average.

    :param values: Sequence of numeric values.
    :param weights: Optional sequence of weights. If None, computes unweighted average.
    :returns: The computed average.
    :raises ValueError: If values is empty.
    """
```

---

## Anti-Patterns Summary

| Principle | Anti-Pattern | Fix |
|-----------|-------------|-----|
| Think Before Coding | Silently assumes format, fields, scope | List assumptions explicitly, ask for clarification |
| Simplicity First | Strategy pattern for single calculation | One function until complexity is actually needed |
| Surgical Changes | Reformats quotes, adds type hints while fixing bug | Only change lines that fix the reported issue |
| Goal-Driven | "I'll review and improve the code" | "Write test for bug X -> make it pass -> verify no regressions" |
| Class Isolation | Class orchestrates another class (sequence + pass data) | Move orchestration to script; embedded sub-components are OK |
| Change Strategy | New function duplicating existing logic | Extend existing method with optional parameter |
| Naming & Structure | Introduces camelCase into a snake_case project | Match existing conventions; ask if new project |
| Comment Style | Google-style or no-format docstrings in Python | Use Sphinx (reST) when docstrings are warranted |

## Key Insight

Overcomplicated code isn't obviously wrong — it follows design patterns and best practices. The problem is **timing**: it adds complexity before it's needed, which makes code harder to understand, introduces more bugs, takes longer to implement, and is harder to test.

Good code solves today's problem simply, not tomorrow's problem prematurely. Simple versions can always be refactored later when complexity is actually needed.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.
