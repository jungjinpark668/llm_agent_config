---
name: project-archaeology
description: Systematically reverse-engineer an existing codebase and produce trustworthy Obsidian vault documentation with evidence-tagged claims
---

# Project Archaeology

Reverse-engineer a codebase that has never had Obsidian interaction. Produce vault notes that let a future agent work on the project immediately. Runs once per project — must be trustworthy.

**Invocation:** `/project-archaeology [optional/path/to/project]`
- If path omitted, use CWD
- Validate target has source files, build files, or git history

## Core Principles

1. **Depth over breadth.** A shallow inventory of components is worthless. The goal is to understand HOW things work, WHY decisions were made, and how information flows between stages. If you can't explain how raw data becomes a trained model or how an experiment config becomes a result table, you haven't gone deep enough.
2. **Trace causal chains.** Every design choice has a cause. Find the chain: requirement → design decision → implementation → test coverage. If you can't trace a configuration value back to its origin, keep digging.
3. **Capture operational knowledge.** "This project uses PyTorch" is useless. "Training uses PyTorch Lightning with a custom `LitModel` in `models/lit_wrapper.py` that wraps the base architecture from `models/transformer.py`. The data pipeline loads HDF5 shards via `data/loader.py` with `num_workers=8` (tuned for the lab's 64-core nodes), applies normalization constants precomputed by `scripts/compute_stats.py` and stored in `data/norm_stats.json`. The learning rate schedule uses cosine annealing with warmup=1000 steps, chosen after sweeps in `configs/sweep_lr.yaml` showed it converged 2x faster than step decay" is useful. Document the HOW.
4. **Ground truth first.** Identify the project's ground truth document (spec, requirements, design doc, README). Everything else traces back to it. The ground truth is the organizing spine of the archaeology.
5. **Evidence-tagged claims.** Every factual statement gets a tag:
   - `[verified]` — ran it, saw the output
   - `[inferred]` — read the source, confident but didn't execute
   - `[unverified]` — mentioned in docs/comments, couldn't confirm
   - `[contradicted]` — execution produced different results than docs claim
6. **Connections are the primary output.** The most valuable thing archaeology produces is NOT descriptions of individual components — it's the explanation of how components interact, how data flows between stages, how one module's output becomes another module's input. If your notes don't have dense, specific cross-references, you've failed.
7. **Scratch files as external memory.** Write intermediate findings to disk after each phase. Read from disk at the start of each phase. Never rely on conversation memory for cross-phase state.
8. **Content integrity.** Only include information verified from source code, execution output, git history, or existing documentation. Do not interpolate from training data.

## Scratch Workspace

Create at `/tmp/archaeology-<project-name>-<timestamp>/`.

**Setup:**
- If the project is a git repo: `git clone --local <project-path> <scratch-path>`
- If not a git repo: `cp -r <project-path> <scratch-path>`
- All builds, tests, and command execution happen in scratch — NEVER in the original
- Scratch also holds intermediate findings (`phase1-*.md`, `phase2-*.md`, `phase3-*.md`)

**Cleanup:**
- On success (all vault notes pass quality gate): delete scratch workspace
- On failure (any phase errors out, agent interrupted, notes fail quality gate): preserve scratch and print its location so the user can inspect or resume

## Phase 1: Surface Scan

**Goal:** Map the project's major themes, identify the ground truth, and understand the high-level flow. NOT to document components — just to know what exists and where to dig.

**Steps:**

1. Create scratch workspace
2. **Find the ground truth.** What drives this project? A paper? A design doc? A requirements spec? A README? Read it thoroughly — this is the organizing spine.
3. File tree inventory — categorize files by type (source, config, tests, docs, notebooks, scripts, data, results/figures)
4. Read all README, CLAUDE.md, and doc files — the project's self-description
5. Parse build/project system — `pyproject.toml`, `setup.py`, `Makefile`, `environment.yml`, `requirements.txt`. For each: what does it do, what does it depend on, what does it produce?
6. Git history summary (if available) — major development phases, most-changed files, recent activity
7. Identify project type and architecture:
   - **ML/DL research:** data loading → preprocessing → model → training → evaluation → analysis
   - **Data pipeline:** ingestion → transformation → validation → storage → visualization
   - **Simulation/numerical:** config → solver → post-processing → plotting
   - **Analysis toolkit:** data readers → processing modules → statistical tests → figures/tables
   - **Library/SDK:** public API → internal modules → utilities
8. Map broad themes — discover the functional areas organically from what you find. Don't force a predefined taxonomy.
9. **Map theme interactions at a high level** — which themes feed into which. What are the inputs and outputs of each? How does data flow between them?
10. Check vault for existing notes: `grep -r "project: <name>" ~/llm_agent_config/vault/ --include="*.md"` to avoid duplication

**Output:** Write `scratch/phase1-project-map.md` containing:
- Ground truth document identified and summarized
- Project type and architecture pattern
- Broad themes with brief descriptions
- Rough theme interaction map
- Build/run commands and dependency management
- Areas flagged for deep dives (ranked by complexity/importance)
- Existing vault coverage

Everything in Phase 1 is tagged `[inferred]`.

## Phase 2: Deep Dives

**Goal:** Trace every causal chain. Understand not just WHAT exists but HOW it was created, WHY it was designed this way, and how it CONNECTS to everything else.

### What "deep" means

Surface level (BAD): "The model uses a transformer architecture with attention."
Deep level (GOOD): "The model in `models/encoder.py` uses a 6-layer transformer with `d_model=256`, `nhead=8`. These dimensions were chosen after the ablation study in `experiments/ablation_dim/` — `results/ablation_summary.csv` shows d_model=256 hit 94.2% accuracy vs 94.5% for d_model=512 at 3x less compute. The attention uses FlashAttention-2 via `torch.nn.functional.scaled_dot_product_attention` (switched from manual implementation in commit `b4e1c2a` after profiling showed 40% speedup). Positional encoding uses rotary embeddings from `models/rope.py`, chosen over sinusoidal after the comparison in `notebooks/pos_encoding_comparison.ipynb`."

Surface level (BAD): "Tests use pytest with fixtures."
Deep level (GOOD): "The test suite uses pytest with `conftest.py` at two levels: root (shared fixtures for loading sample data from `tests/fixtures/sample_*.npz`, GPU device selection) and `tests/models/` (model fixtures that create small configs for fast testing — `hidden_dim=16` instead of 256). Numerical correctness tests in `tests/test_numerics.py` compare against reference implementations with `torch.allclose(atol=1e-5)`. The regression test `tests/test_regression.py` loads a frozen checkpoint and asserts output matches `tests/fixtures/expected_output.pt` — this caught a silent dtype bug after the mixed-precision migration (see commit `c3d4e5f`)."

### Steps

1. Read `scratch/phase1-project-map.md` to recover state
2. **For each theme, in order of importance, trace these dimensions:**

   **a. Workflow reconstruction:** How do you actually USE this part of the project? What exact commands do you run? What are the inputs? What are the outputs? What tools are required? What environment setup? Document the complete workflow so a future agent can reproduce it.

   **b. Causal chain tracing:** For every significant design parameter, trace it back to its origin. Where did this number come from? What requirement or benchmark drove this choice? Follow the chain: requirement → design decision → implementation → test coverage.

   **c. Cross-theme data flow:** How does this theme's output become another theme's input? Be specific — not "the preprocessor feeds the model" but "`preprocess.py:build_dataset()` reads raw CSVs from `data/raw/`, applies the normalization from `data/norm_stats.json` (precomputed by `scripts/compute_stats.py`), and writes torch tensors to `data/processed/{train,val,test}.pt` which `data/loader.py:get_dataloader()` memory-maps at training time."

   **d. Design decisions and alternatives:** Why this approach and not another? Check git history for deleted alternatives, comments mentioning tradeoffs, TODO/FIXME/HACK markers. If a decision isn't justified anywhere, note it as "decision rationale not found — [unverified]."

   **e. Non-obvious operational details:** Magic constants and where they come from. Implicit ordering dependencies (must run preprocessing before training, must compute stats before normalization). Environment variables. Things that would silently break if changed.

3. Write findings to `scratch/phase2-<theme-name>.md` as EACH theme completes — do not wait until all themes are done.
4. After all themes: write `scratch/phase2-connections.md` — a DENSE cross-theme dependency map.

Everything in Phase 2 is tagged `[inferred]`.

**Compaction safety:** If context compacts mid-phase, read your own scratch files to recover.

### Depth check

Before moving to Phase 3, review your Phase 2 scratch files and ask:
- Can a future agent reproduce every workflow from these notes alone?
- Is every significant design parameter traced back to its origin?
- Are cross-theme connections specific (file names, line numbers, data formats) or vague ("see also")?
- Would a future agent understand WHY, not just WHAT?

If the answer to any of these is no, go back and dig deeper on those themes.

## Phase 3: Verification

**Goal:** Run what can be run. Tag every claim with its evidence level. Verify workflows end-to-end, not just individual commands.

**Steps:**

1. Read `scratch/phase1-project-map.md` for build/run commands
2. Read all `scratch/phase2-*.md` for claims to verify
3. **Verify workflows, not just commands.** Don't just run `pytest` — trace the full pipeline:
   - Does `pip install -e .` or `conda env create` succeed? What dependencies get pulled?
   - Does data preprocessing run end-to-end? Do the output shapes match expectations?
   - Do tests pass? What's the coverage? Are there skipped/xfail tests?
   - Can you run a small training loop (few steps) without errors?
   - Does the linter/type checker pass (`ruff check .`, `mypy .`)?
4. For each runnable command:
   - Run it in the scratch workspace (set a timeout — if it hangs, log and move on)
   - Capture stdout, stderr, return code
   - Compare against Phase 2 claims
   - Save output to `scratch/phase3-run-<target>.log`
5. For claims that can't be verified by running:
   - Check if tests exist that cover the claim — run them if so
   - If no way to execute, leave as `[inferred]`
6. **Verify causal chains where possible.** If Phase 2 says "d_model=256 was chosen after ablation", check: does the config file show d_model=256? Is there an ablation results file? Does a commit message or notebook reference the comparison?
7. Write `scratch/phase3-verification.md`:
   - Each verifiable claim with its final evidence tag
   - Any `[contradicted]` findings
   - Commands that failed and why
   - Workflow verification results

**Safety:** All execution in scratch. Timeout long-running commands (5 minutes default). Document failures — they're valuable.

**Environment note:** Check for `environment.yml`, `requirements.txt`, or conda/venv setup. If the project needs external resources (GPU, specific datasets, HPC cluster, licensed software), note what's required and which claims couldn't be verified due to missing resources: tag as `[unverified — requires <resource>]`.

## Phase 4: Vault Note Production

**Goal:** Synthesize scratch files into vault-compliant Obsidian notes that are DENSELY INTERCONNECTED and capture deep operational knowledge.

**Steps:**

1. Read all scratch files
2. Determine note structure based on project complexity:
   - Small project (1-2 themes): 2-3 notes
   - Medium project (3-5 themes): 4-6 notes
   - Large project (6+ themes): 7-10 notes, never more than 10
3. Create `projects/<project-name>/` subfolder in vault
4. For each note:
   - Full YAML frontmatter: `date`, `tags`, `type: concept`, `status: active`, `project: <name>`
   - Lowercase-hyphenated filename
   - Evidence tags inline next to claims: `[verified]`, `[inferred]`, `[unverified]`
   - **Dense, specific wikilinks** — not "see [[other-note]]" but "the feature extraction pipeline described here produces the spectrograms consumed by the model in [[model-architecture#Input Pipeline]], and the windowing parameters were validated against the analytical baselines in [[dsp-validation#FFT Comparisons]]"
   - **Operational sections** — every note that describes a workflow must include a "How to run" or "Workflow" section with actual commands
   - 200-400 lines target per note
5. Note structure (agent decides which are warranted — don't force notes that aren't needed):
   - **Project overview** — ground truth summary, themes, architecture, how pieces connect. This is the entry point.
   - **Theme notes** — one per major theme with enough substance. Each must cover: what it does, how to use it, why it's designed this way, what it connects to.
   - **Cross-cutting reference** — if reusable patterns, workflows, or operational knowledge spans themes
6. Append to `agent/session-log.md` with archaeology summary
7. Cleanup:
   - Verify all notes pass quality gate (frontmatter, wikilinks, filenames, correct folder)
   - If PASS: delete scratch workspace
   - If FAIL: preserve scratch, print location

### Note quality check

Before finalizing, verify each note against:
- **Reproducibility:** Could a future agent reproduce the workflows described?
- **Causal depth:** Are design parameters traced to their origins?
- **Connection density:** Do wikilinks explain the relationship, not just point?
- **Operational value:** Does the note tell you HOW, not just THAT?

**Notes must NOT contain:**
- Raw benchmark output (those live in the source repo)
- Restated READMEs without added reasoning
- File-by-file inventories (notes are about themes and connections)
- Vague connections ("see also", "related to") without explaining the relationship
- Component descriptions without operational context

## Anti-Patterns

- **Do NOT** produce a component inventory. "The project has X, Y, Z" is not archaeology. Trace how X produces output consumed by Y, designed to satisfy requirement Z.
- **Do NOT** stop at surface level. If you find a config value, trace it to its source. If you find a script, understand what it produces and who consumes it.
- **Do NOT** write vague connections. "See [[other-note]]" is worthless. "The filter coefficients computed in [[dsp-filters]] are the same ones loaded by the feature extraction pipeline in [[data-preprocessing#Bandpass Filtering]]" is useful.
- **Do NOT** skip operational knowledge. Every workflow must be documented with enough detail to reproduce.
- **Do NOT** read every file before understanding the project structure. Surface scan first, then targeted deep dives.
- **Do NOT** run commands in the original project directory. Everything executes in scratch.
- **Do NOT** hold all findings in conversation memory. Write to scratch files after each phase/theme.
- **Do NOT** create a note per source file. Notes are about themes, not files.
- **Do NOT** include unverified training-data knowledge as if it were project-specific fact.
- **Do NOT** force exactly N notes. Let project complexity determine the count.
- **Do NOT** skip Phase 3 verification even if it seems obvious. Trust but verify.
