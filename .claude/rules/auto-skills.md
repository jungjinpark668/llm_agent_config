# Auto-Applied Skills

Three behaviors that apply automatically based on context. Each section lists
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

## 3. Long commands: auto-background

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

---

## 4. Code-explore agent: generate and brief subagents

**When:** Starting project work in a repository that has a vault project folder
but no `code-context.md`, OR when `code-context.md` has a `date:` frontmatter
older than 30 days and the repo has >50 commits since then.

**Agent:** Defined in `.claude/agents/code-explore.md`. Read-only — uses
filesystem MCP tools for exploration, returns markdown content as output.
Handles adaptive mode selection (conventions-only vs full) internally.

**Invocation:** The agent returns content; the caller writes the file.

```
result = Agent({
  subagent_type: "code-explore",
  prompt: "REPO_PATH: <CWD>, PROJECT: <mapped-project-name>"
})
# Write result to vault/projects/<project>/code-context.md
```

**Briefing protocol:**
- When spawning any subagent for coding work (implementation, review,
  planning, exploration), read `code-context.md` and prepend its content
  (without frontmatter) to the subagent prompt under a `## Code context`
  header
- This is mandatory for coding subagents, optional for vault-only or
  non-coding subagents

**Freshness:**
- Check `date:` frontmatter on first load each session
- If >30 days old: check `git log --oneline --since="30 days ago" | wc -l`
- If >50 commits: regenerate via code-explore subagent
- If archaeology runs on a project with full-mode code-context, regenerate
  in conventions-only mode
