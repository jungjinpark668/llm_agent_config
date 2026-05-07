---
date: 2026-05-07
tags: [matplotlib, plotting, isscc, font]
type: concept
status: active
---

# Matplotlib subscript font mismatch fix

## Problem

When using Arial Narrow (or any custom font) with `plt.rcParams["mathtext.default"] = "regular"`, subscripts wrapped in `\mathrm{}` revert to the default mathtext roman font (DejaVu Sans), creating a visible mismatch between the main label text and the subscript.

Example of the bug:
```python
ax.set_ylabel(r"$T_{\mathrm{baseline}}$")  # "baseline" renders in DejaVu Sans
```

## Fix

Drop `\mathrm{}` in subscripts. With `mathtext.default = "regular"`, bare text inside `$...$` already inherits the body font.

```python
# wrong — subscript uses DejaVu Sans
ax.set_ylabel(r"$T_{\mathrm{update}} / T_{\mathrm{MIN}}$")

# correct — subscript inherits Arial Narrow
ax.set_ylabel(r"$T_{update} / T_{MIN}$")
```

Same applies to `ax.text()`, `ax.set_xlabel()`, legend labels, and annotations.

## When \mathrm is still needed

Only use `\mathrm{}` for actual math-mode roman symbols that should not be italic (e.g., `\mathrm{d}x` for differentials). For text subscripts that label a variable, bare text is correct.

## Scope

Affects all plotting scripts using the ISSCC style with Arial Narrow. As of 2026-05-07, ~45 files in `psylab_comm/scripts/` use `mathtext.default = "regular"` and many have `\mathrm{}` subscripts that could be fixed.

[[isscc-figure]]
