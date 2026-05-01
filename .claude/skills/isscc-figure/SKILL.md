---
name: isscc-figure
description: Fix and format matplotlib figures to ISSCC/IEEE publication standards. Use when asked to "format this figure", "make this publication-quality", "fix the figure style", or when reviewing figures for paper submission.
---

# ISSCC Figure Formatter

Apply strict ISSCC-style formatting checklist to matplotlib code.

**Canonical reference:** `scripts/beamforming/gsc_bf/plot_gsc_blocking_convergence.py`
(see `figures/beamforming/gsc_blocking_convergence/gsc_blocking_convergence_k99.png`).
Every new plotting script in `scripts/` and `examples/` should mirror this
file's style.

## Exact Style Specification

### Colors
```python
CLR_NAVY   = "#1a1f7a"   # primary
CLR_RED    = "#C0392B"   # secondary
CLR_GREEN  = "#27AE60"   # tertiary  — third curve in 3+ curve panels
CLR_PURPLE = "#8E44AD"   # quaternary — twin-axis or fourth curve
```

### Font + mathtext
```python
_ISSCC_FONT_LOADED = False
try:
    _fm = matplotlib.font_manager.FontManager()
    _arial_narrow_paths = [
        f.fname for f in _fm.ttflist if "Arial Narrow" in f.name
    ]
    if _arial_narrow_paths:
        matplotlib.font_manager.fontManager.addfont(_arial_narrow_paths[0])
        plt.rcParams["font.family"] = "Arial Narrow"
        _ISSCC_FONT_LOADED = True
except Exception:
    pass
if not _ISSCC_FONT_LOADED:
    plt.rcParams["font.family"] = "sans-serif"
    plt.rcParams["font.weight"] = "bold"

# Bare $x$ math inherits the body font; keep the default `dejavusans`
# fontset so \mathbf / \hat render sans-serif (matches the body).
plt.rcParams["mathtext.default"] = "regular"
```

### Axes helper (copy verbatim)
```python
def apply_isscc_style(ax):
    ax.spines["top"].set_linewidth(0)
    ax.spines["right"].set_linewidth(0)
    ax.spines["left"].set_linewidth(2.0)
    ax.spines["bottom"].set_linewidth(2.0)
    ax.tick_params(axis="both", which="major", labelsize=22, width=2)
    for label in ax.get_xticklabels() + ax.get_yticklabels():
        label.set_fontweight("bold")
    ax.patch.set_facecolor("none")
```

### Saving
```python
def _save_fig(fig, out_base):
    fig.savefig(f"{out_base}.png", transparent=True, bbox_inches="tight")
    fig.savefig(f"{out_base}.svg", format="svg",
                transparent=True, bbox_inches="tight")
    fig.savefig(f"{out_base}.eps", format="eps",
                transparent=True, bbox_inches="tight")
    plt.close(fig)
```

## Checklist (Every Figure)

1. Spines: top/right linewidth 0, left/bottom linewidth 2.0
2. Ticks: `labelsize=22`, `fontweight="bold"`, `width=2`
3. Background: transparent (`ax.patch.set_facecolor("none")` + `fig.patch.set_facecolor("none")`)
4. Font: Arial Narrow with sans-serif-bold fallback
5. Mathtext: `mathtext.default = "regular"`; do NOT override `mathtext.fontset`
6. Colors: `CLR_NAVY`, `CLR_RED` as primary / secondary
7. Axis labels: `fontsize=24, weight="bold"`. Color = `"black"` by default; when an axis represents **one specific data curve** (e.g. twin-axis, single-curve dedicated panel), color the ylabel to match that curve.
8. Legend: `prop={"size": 18, "weight": "bold"}`; default `framealpha=0.7`
9. Markers (when plotting points): `markersize=10`, `markerfacecolor="white"`, `markeredgewidth=2.5`
10. Line widths: `linewidth=3` for data curves, `2–2.5` for reference / dashed lines
11. Triple save: PNG + SVG + EPS, all `transparent=True`, `bbox_inches="tight"`
12. `apply_isscc_style(ax)` on every axes object

## NOT defaults — add only when justified

- **Grid** (`ax.grid(...)`): off by default. Turn on only when reference lines
  are genuinely required, e.g. log-log convergence sweeps. Never use grid as
  decoration on clean line plots.
- **Panel titles** (`ax.set_title(...)`): off by default. Only add when a
  multi-panel figure truly needs labels; then use `fontsize=22, weight="bold",
  pad=12` with `"(a)  "` / `"(b)  "` prefixes.

## Layout Sizes

| Layout | `figsize` |
|--------|-----------|
| Single | `(6, 6)` |
| 1x2    | `(12, 6)` |
| 2x1    | `(8, 10)` |
| 2x2    | `(12, 10)` |

All at `dpi=300`.

## Domain Axes

| Axis | Label | Scale |
|------|-------|-------|
| Azimuth | `"$\\phi$ (deg)"` | Linear, −90 to 90 |
| SINR | `"SINR (dB)"` | Linear |
| BER | `"BER"` | Log (semilogy) |
| Tracking error | `"Tracking Error (deg)"` | Linear/log |
| Beam pattern | `"Normalized Pattern (dB)"` | Linear, −60 to 0 |
| Eigenvalue | `r"eigenvalue  $\\lambda_k$"` | Log |
| Iterations | `"# of Iterations"` | Linear or log |

## Twin-axis figures

When a left and right axis each carry one dedicated curve (e.g. error vs
γβ̄ on the left, k_99 on the right), color the **spine + tick marks + tick
labels + ylabel** of each axis to match its curve so the reader can pair
data with axis at a glance. Apply `apply_isscc_style` to the left axis as
usual, then style the right axis manually:

```python
# Left axis (navy curve)
ax1.spines["left"].set_color(CLR_NAVY)
ax1.tick_params(axis="y", which="major", labelsize=22, width=2,
                colors=CLR_NAVY)
for label in ax1.get_yticklabels():
    label.set_color(CLR_NAVY)
    label.set_fontweight("bold")
ax1.set_ylabel(..., fontsize=24, color=CLR_NAVY, weight="bold")

# Right axis (purple curve)
ax2 = ax1.twinx()
ax2.spines["top"].set_linewidth(0)
ax2.spines["left"].set_linewidth(0)
ax2.spines["right"].set_linewidth(2.0)
ax2.spines["right"].set_color(CLR_PURPLE)
ax2.tick_params(axis="y", which="major", labelsize=22, width=2,
                colors=CLR_PURPLE)
for label in ax2.get_yticklabels():
    label.set_fontweight("bold")
ax2.set_ylabel(..., fontsize=24, color=CLR_PURPLE, weight="bold")
ax2.patch.set_facecolor("none")
```

## Reference / regime-boundary lines

Stability bounds, asymptotes, and "ideal" levels deserve a thin vertical
or horizontal dashed line plus a rotated label.  Place the label at the
*geometric mean* of the data range (log axis) or arithmetic mean (linear
axis) so it stays inside the plot box:

```python
ax.axvline(GB_STABILITY, color=CLR_RED, linewidth=2.0,
           linestyle="--", alpha=0.85)
y_text = np.sqrt(residuals.min() * residuals.max())   # log axis
ax.text(GB_STABILITY * 0.93, y_text,
        rf"unstable ($\gamma\bar{{\beta}}\geq{GB_STABILITY:.0f}$)",
        color=CLR_RED, fontsize=18, fontweight="bold",
        rotation=90, va="center", ha="right")
```

Use `0.93·x_ref` (log) or `x_ref - small_offset` (linear) to nudge the
label off the line itself.

## Common Fixes

- **Tick overlap**: `ax.xaxis.set_major_locator(plt.MaxNLocator(nbins=6))` or `rotation=45`
- **Legend clipping**: reposition via `loc=...`; switch to `frameon=False` if the frame still clutters
- **Inconsistent spines**: `for ax in fig.axes: apply_isscc_style(ax)`
- **Suptitle overlap**: `fig.tight_layout(rect=[0, 0, 1, 0.95])`

## Anti-patterns

- Do NOT use `plt.show()` without a `--no-show` gate
- Do NOT use default matplotlib colors
- Do NOT save only PNG — always all three formats
- Do NOT set `facecolor="white"` — use transparent
- Do NOT add `ax.grid(...)` by default
- Do NOT add panel titles unless a multi-panel layout really needs them
- Do NOT override `mathtext.fontset` to `stixsans` / `cm` / `stix` — stick with the `dejavusans` default
