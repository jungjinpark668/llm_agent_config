# Auto-Applied Skills

Four behaviors that apply automatically based on context. Each section lists
the trigger, condensed rules, and a pointer to the full reference.

---

## 1. Plans: invoke create-plan skill

**When:** Plan mode is active, or user asks to "make a plan" / "plan this".

**Action:** Call the `create-plan` skill via the Skill tool at the start of
planning. This loads the full template and workflow. Do this BEFORE exploring
the codebase or writing any plan content.

```
Skill({ skill: "create-plan" })
```

The skill defines the output template (Scope, Action Items, Open Questions)
and the minimal workflow (scan context → ask if blocking → output plan only).
Follow it as the primary planning workflow.

---

## 2. Prose: apply humanizer patterns

**When:** Writing prose longer than ~2 sentences — comments, documentation,
PR descriptions, commit messages, explanations, vault notes, any natural
language output.

**Content — remove:**
- Inflated significance ("pivotal moment", "testament to", "crucial role")
- Vague attributions ("experts believe", "industry reports suggest")
- Promotional language ("vibrant", "groundbreaking", "nestled", "stunning")
- Formulaic "challenges and future prospects" sections
- Superficial -ing analyses ("highlighting", "showcasing", "ensuring")

**Language — avoid:**
- AI vocabulary: Additionally, delve, enhance, foster, garner, landscape
  (abstract), tapestry (abstract), underscore, showcase, pivotal, interplay
- Copula avoidance: use "is/are/has" instead of "serves as/stands as/boasts"
- "Not only X but also Y" constructions
- Forced groups of three; synonym cycling

**Style — enforce:**
- Limit em dashes — use commas or periods instead
- No mechanical boldface on every term
- No inline-header bullet lists (bold key: explanation)
- Sentence case in headings, not Title Case
- Straight quotes, not curly quotes

**Communication — never:**
- "I hope this helps", "Certainly!", "Great question!"
- Knowledge-cutoff disclaimers
- Sycophantic opener/closer

**Voice — do:**
- Vary sentence length and structure
- Be specific ("adds batch processing" not "enhances the experience")
- Have opinions when appropriate; acknowledge uncertainty honestly

**Full reference:** `.claude/skills/humanizer/SKILL.md`

---

## 3. Matplotlib figures: apply ISSCC/IEEE style

**When:** Writing or editing Python code that uses matplotlib for plotting.

**Mandatory checklist:**
- Spines: top/right width 0, left/bottom width 2.0
- Ticks: labelsize=22, fontweight="bold", width=2
- Background: transparent (ax.patch + fig.patch facecolor="none")
- Font: Arial Narrow with sans-serif bold fallback
- mathtext.default = "regular"; do NOT override mathtext.fontset
- Colors: CLR_NAVY="#1a1f7a", CLR_RED="#C0392B", CLR_GREEN="#27AE60",
  CLR_PURPLE="#8E44AD"
- Axis labels: fontsize=24, weight="bold"
- Legend: size=18, weight="bold", framealpha=0.7
- Lines: linewidth=3 data, 2-2.5 reference/dashed
- Markers: markersize=10, markerfacecolor="white", markeredgewidth=2.5
- Save: PNG + SVG + EPS, all transparent=True, bbox_inches="tight"
- Call apply_isscc_style(ax) on every axes object

**Anti-patterns:**
- No plt.show() without --no-show gate
- No default matplotlib colors
- No facecolor="white" — use transparent
- No ax.grid() by default
- No panel titles unless multi-panel genuinely needs them

**Full reference:** `.claude/skills/isscc-figure/SKILL.md`

---

## 4. Long commands: auto-background

**When:** A Bash command is estimated to take longer than 1 minute.

**Rule:** Automatically use `run_in_background: true` for commands likely to
exceed 1 minute. Common examples:
- Full test suites (`pytest`, `npm test`, `cargo test` on large projects)
- Package installs (`pip install`, `npm install`, `cargo build`)
- Build processes (`make`, `cmake --build`, `gradle build`)
- Long data processing scripts
- Server/service startups
- Docker builds
- Large git operations (`git clone` of big repos)

Do not background short commands even if they touch these tools (e.g.,
`pip install single-package` is usually fast — use judgment).
