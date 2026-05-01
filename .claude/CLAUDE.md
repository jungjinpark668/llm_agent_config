# Claude User Instructions

## Identity & Notes Vault

The Obsidian vault is Claude's persistent memory. When Claude learns something, makes a connection, solves a problem, or builds context across sessions — it lives here.

**Vault:** Located at `vault/` within this repo (`~/llm_agent_config/vault/`)
**Project Mapping:** Project names from repositories (e.g., `TestOne_Two`) must be mapped to lowercase-hyphenated equivalents (e.g., `testone-two`) for the vault. Always look for project folders in `vault/projects/<mapped-name>/`.
**Sync:** Cron auto-commits every 5 min. Write files, no manual push needed.

**Folders:**
- `inbox/` — Quick capture, unprocessed thoughts
- `projects/` — Active, time-bound work (grouped by `project:` frontmatter, no hub files)
- `areas/` — Durable domain knowledge (promoted from projects when reused)
- `library/` — Atomic reference notes, papers, tools
- `personal/` — Goals, journal, personal context
- `agent/` — Agent meta-layer (session log, connections, open questions)

**Conventions:** `YYYY-MM-DD-topic.md` or `topic.md`. Lowercase-hyphenated filenames only. Use `[[wikilinks]]` to connect ideas.
**Permissions:** Never delete notes without confirming. Prefer appending to overwriting.

## Context Loading (Subagent-Based)

Vault context is loaded via subagents to keep main context clean. The SessionStart hook provides only the project name and checkpoint headers (~8 lines).

**When starting project work or after compaction:**
1. Map the current repository name to its vault-safe equivalent (lowercase, underscores/spaces to hyphens).
2. Check if `~/llm_agent_config/vault/projects/<mapped-name>/code-context.md` exists.
   - If missing or stale (>30 days with significant repo activity): spawn a code-explore subagent to generate it (see auto-skills rule 5).
   - If present and fresh: read it directly (it is small, ~25-80 lines).
3. Spawn an Explore subagent with: "Read vault context for project `<mapped-name>`. Read `~/llm_agent_config/vault/projects/<mapped-name>/working-context.md` (latest checkpoint), search for `project: <mapped-name>` frontmatter to find related notes. Return a structured summary: current goal, plan status, key decisions, open items, active files. Keep summary under 25 lines."
4. The subagent returns only the summary — main context never ingests full vault notes.

**Briefing subagents:** When spawning any subagent for coding work in a project that has a `code-context.md`, read the file and prepend its contents (without frontmatter) to the subagent prompt under a `## Code context` header. This gives the subagent immediate knowledge of the codebase without re-exploration.

**When making decisions or planning:** Also spawn subagent to check `~/llm_agent_config/vault/agent/open-questions.md`.

**When you need specific vault info:** Use subagent, not direct Read/Grep of vault files. Exception: if you need a single specific file and know its exact path, direct read is fine.

## Available Skills

| Skill | When to use |
|-------|-------------|
| `obsidian-notes` | Taking notes, recalling context, building connections, persistent memory |
| `obsidian-audit` | Vault health checks — after creating 3+ notes, weekly, or on request |
| `project-archaeology` | Reverse-engineer an existing codebase into trustworthy vault documentation (runs once per project) |
| `checkpoint` | Dump working context to vault for session recovery |

## Note Quality Gate

Before writing ANY note to the vault, verify:
1. **Future value** — Would a future Claude instance genuinely benefit? (not just "nice to have")
2. **No duplication** — Is this already in the codebase, git history, or existing notes?
3. **Frontmatter present** — Every note MUST have `date`, `tags`, `type`, and `status` in YAML frontmatter
4. **Wikilinks included** — Link to concepts, not parents. No hub/index files.
5. **Correct folder** — `projects/` for time-bound work, `areas/` for durable knowledge, `library/` for reference
6. **Lowercase-hyphenated filename** — No spaces, CamelCase, or uppercase

## Standard Patterns

**New project (2+ notes):** Create `projects/<project>/` subfolder. Each note gets `project: <name>` in frontmatter. No `_index.md` — use frontmatter queries to find project notes.
**Area promotion:** When a second project needs knowledge from the first, extract it to `areas/`.
**Quick capture:** Drop in `inbox/`, process later.
**Decision record:** Use `type: decision`. Include the decision, alternatives considered, rationale, and who decided.
**Session summary:** Use structured template (see obsidian-notes skill).

## Santa Method Verification

For high-stakes output (production deployments, critical infrastructure, security-sensitive code): invoke two independent reviewer agents that must both PASS before shipping. Max 3 fix iterations, then escalate.

## Instincts

Learned behavioral patterns live in `~/llm_agent_config/vault/agent/instincts.yaml`. Each instinct has a `project:` field (`global` or project name). When a project-scoped instinct is validated at confidence >= 0.8 in 2+ projects, promote it to `project: global`.
