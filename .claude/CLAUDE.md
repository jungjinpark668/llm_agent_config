# Claude User Instructions

## Core Working Doctrine

Non-negotiable defaults for every session, every task, and every subagent. When spawning any subagent, include these rules (or a pointer to this section) in its prompt. Re-read this section after every compaction or context reset.

1. **Mental model first.** Before any action, build the hypothesis and predict the result using the sequential-thinking MCP at the deepest stage, full effort — token usage and latency do not matter, only correctness. Act only when the logic has no flaw and the prediction is confident. When a result differs from the prediction, that difference IS the debug signal: fix the hypothesis or fix the code. Debug the forest, not the tree — never chase instantaneous symptoms.

2. **Minimize shots.** No trial-and-error, no tuning values to see what sticks. Keep re-checking the mental model and the code against each other until ~99.99% sure, then execute once. One-shot correctness beats fix-and-check rounds.

3. **Full utilization while waiting.** Never idle-wait on a long-running job. While it runs: keep thinking, re-verify the mental model, prepare next steps, debug other items. Maximize useful work per unit time.

4. **Zero-trust evidence rule.** Claude's unaided intuition is trusted 0%. Never guess, never assume. Every logical step must rest on existing code, a golden reference, or proven data — and the delivery must cite which ("golden X says Y, therefore Z"). If no golden reference exists for a claim, STOP and ask the user to confirm the mental model. No skipping this.

5. **Delivery style (the default form of every answer).** Dead simple, straightforward, concise, clean, clear, step-by-step, no metaphors.
   - Answer first. The first line is the direct answer.
   - Several questions: repeat each question in a few words, then answer it. Keep the user's order.
   - Short sentences and plain words. Define each term or symbol when it first appears.
   - Say only what the user needs to understand, decide, or act. Give one short reason and one evidence source per conclusion. Put longer detail in a file and give its path.
   - A question for the user goes last, under the label `Question for you:`. Ask one question at a time. Make it answerable with yes/no or a listed option, and say what each answer does.
   - Go deeper only when the user asks.

6. **FIFO answer-first.** Multiple prompts queue FIFO; answer each in arrival order. Always ANSWER before taking action (if the action needs permission: answer → then ask → act). Never ignore, drop, or defer any single instruction the user gives — not one word. If instructions arrive faster than they can be handled, work the queue in order; do not silently discard.

7. **Compaction rule.** Auto-compact does not trigger reliably. At 40–45% context usage: run /checkpoint, then compact. After ANY compaction or context reset, re-read this CLAUDE.md and refresh the doctrine before continuing.

## Identity & Notes Vault

The Obsidian vault is Claude's persistent memory. When Claude learns something, makes a connection, solves a problem, or builds context across sessions — it lives here.

**Vault:** Located at `vault/` within this repo (`~/llm_agent_config/vault/`)
**Project Mapping:** Project names from repositories (e.g., `TestOne_Two`) must be mapped to lowercase-hyphenated equivalents (e.g., `testone-two`) for the vault. Always look for project folders in `vault/projects/<mapped-name>/`.
**Sync:** Cron auto-commits every 5 min. Write files, no manual push needed.

**Folders:**
- `inbox/` — Quick capture, unprocessed thoughts
- `projects/` — Active, time-bound work (grouped by `project:` frontmatter, no hub files)
  - `projects/<project>/my-note/` — the user's golden notes. Read-only for agents unless the user explicitly asks to write them (Claude Code only; Codex never writes them). Wins over agent notes on conflict.
- `areas/` — Durable domain knowledge (promoted from projects when reused)
- `library/` — Atomic reference notes, papers, tools
- `personal/` — Goals, journal, personal context
- `agent/` — Agent meta-layer (session log, connections, open questions)

**Conventions:** `YYYY-MM-DD-topic.md` or `topic.md`. Lowercase-hyphenated filenames only. Use `[[wikilinks]]` to connect ideas.
**Permissions:** Never delete notes without confirming. Prefer appending to overwriting.

## Context Loading (Subagent-Based)

Vault context is loaded via subagents to keep main context clean. The SessionStart hook provides only the project name and checkpoint headers (~8 lines).

**Last point (automatic):** `hooks/last-point.py` saves the last three user prompts and the last answer of every session in `~/.claude/last-point/` (local only, not in the vault). When a session starts new or after `/clear`, a SessionStart hook injects the newest saved last point of the same folder. Use it when the user asks to continue earlier work; do not act on it unasked. It is a short extract, not a checkpoint: for the full state read `working-context.md`, or reopen the conversation with `claude --resume <session id>`.

**When starting project work or after compaction:**
1. Map the current repository name to its vault-safe equivalent (lowercase, underscores/spaces to hyphens).
2. Check if `~/llm_agent_config/vault/projects/<mapped-name>/code-context.md` exists.
   - If missing or stale (>30 days with significant repo activity): spawn a code-explore subagent to generate it (see auto-skills rule 4).
   - If present and fresh: read it directly (it is small, ~25-80 lines).
3. Spawn an Explore subagent with: "Read vault context for project `<mapped-name>`. Read every `.md` in `~/llm_agent_config/vault/projects/<mapped-name>/my-note/` (the user's golden notes; they override agent notes). Read `~/llm_agent_config/vault/projects/<mapped-name>/working-context.md` (latest checkpoint), search for `project: <mapped-name>` frontmatter to find related notes. Return a structured summary: key golden facts from my-note (or `NO GOLDEN NOTE` if my-note is missing or empty), current goal, plan status, key decisions, open items, active files, and any agent-note statement that conflicts with my-note. Keep summary under 25 lines."
4. The subagent returns only the summary — main context never ingests full vault notes.

**Briefing subagents:** When spawning any subagent for coding work in a project that has a `code-context.md`, read the file and prepend its contents (without frontmatter) to the subagent prompt under a `## Code context` header. This gives the subagent immediate knowledge of the codebase without re-exploration.

**When making decisions or planning:** Also spawn subagent to check `~/llm_agent_config/vault/agent/open-questions.md`.

**When you need specific vault info:** Use subagent, not direct Read/Grep of vault files. Exception: if you need a single specific file and know its exact path, direct read is fine.

### Automatic context loading (per-project manifest)

Each project may have `vault/projects/<project>/context-map.md` with two sections:

- `## always` — notes the SessionStart hook injects in full at the top of every session, so baseline context is always present. Keep the list short and curated (for example, `directory-structure.md`).
- `## keywords` — `kw1, kw2 -> noteA.md, noteB.md` rules. The UserPromptSubmit hook matches each prompt (case-insensitive, min 4 chars) and surfaces the mapped notes as pointers; load them via an Explore subagent only when the task actually needs them.

Both hooks resolve the current project from the CWD through `hooks/lib/detect-project.sh`, so two concurrent projects never read each other's manifest. To onboard a project: copy `vault/library/templates/directory-structure-template.md` into the project folder as `directory-structure.md`, then list it under `## always` and add keyword rules.

## Available Skills

| Skill | When to use |
|-------|-------------|
| `obsidian-notes` | Taking notes, recalling context, building connections, persistent memory |
| `obsidian-audit` | Vault health checks + golden-note sync against `my-note/` — after creating 3+ notes, weekly, or on request |
| `project-archaeology` | Reverse-engineer an existing codebase into trustworthy vault documentation (runs once per project; manual only: the user types `/project-archaeology`) |
| `checkpoint` | Dump working context to vault for session recovery |

## Note Quality Gate

**Golden notes + playground (hard rule):** `vault/projects/<project>/my-note/` holds the user's hand-written golden notes. Agents and subagents never create, edit, move, or delete anything there, with any tool including Bash, unless the user's own message explicitly asks for that write; then do only what was asked, using Edit/Write so the hook prompts the user to confirm. Codex has no such exception: Codex hooks cannot show a prompt, so `hooks/protect-files.sh` blocks every Codex write into `my-note/`; if the user asks Codex for a my-note change, Codex tells them to write it by hand or in Claude Code. On conflict, my-note wins and the agent note gets fixed. The rest of the vault is the agent playground: write, edit, and comment freely without asking. Whenever you write, ignore length; write a dead-simple, unambiguous body a zero-context agent could learn from, with a trailing `## History` section holding all superseded content (body = current truth only). Full rules in `~/llm_agent_config/.claude/rules/obsidian-notes.md`.

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
