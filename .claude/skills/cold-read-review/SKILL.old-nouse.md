---
name: "cold-read-review"
description: "General cold-read reviewer for Visvesh's drafts across genres: SSCS papers (ISSCC, CICC, VLSI, ESSCIRC, A-SSCC, JSSC, SSC-L), research proposals, tutorials, industry talks, and conference presentations. A fresh reviewer agent, given the persona of that genre's real audience, reads only what's written so far in the file(s) he names (paper text, proposal text, or a slide deck / slide-studio plan), with no knowledge of outlines or later sections. It catches undefined terms, unsupported claims, logic gaps, pacing problems and unmet audience expectations. The skill then advises fixes with proposed phrasing in his style (he does the writing). If he doesn't name the file(s), ask. Use when he says \"cold read\", \"read what I have so far\", \"check my draft\", \"review the intro\", \"review my deck/slides/talk\", \"what gaps do I have\". If a draft-specific review skill or a folder instructions.md exists, it layers on top of this."
---

# Cold-Read Review (General, Multi-Genre)

 Your job is to **read, advise, and propose phrasing he can adopt or adapt**. Never edit the draft yourself. The goal is to see the draft the way its real audience does: one sentence or one slide at a time, with no idea what comes later.

What changes from genre to genre:
- **who** the reader is
- **what** they see
- **what** they are judging

The workflow is shared.

## 0. Identify the genre (before anything else)

| Genre | Typical cues | Reader | Judged on |
|---|---|---|---|
| **paper** | `.docx`/`.tex` under `paper_drafts/`; venue names ISSCC, CICC, VLSI, ESSCIRC, A-SSCC, JSSC, SSC-L | expert TPC member or journal reviewer | novelty chain, evidence, rigour, concision |
| **proposal** | `proposals/`; NSF, DARPA, SRC, DOE, industry gift; "aims", "solicitation" | review panelist or program manager | significance, approach, feasibility, fit to the call |
| **tutorial** | `tutorials/`; "tutorial", "short course", "lecture" | non-expert learner attending live | can they *learn* it: prerequisites, build-up, pacing |
| **conference-talk** | the slides presenting a paper (ISSCC/CICC/VLSI paper talk), `presentations/` + paper id | expert attendee who hasn't read the paper | one idea landed in ~15–20 min, claims match the paper |
| **industry-talk** | company names; "seminar at", "visit", "tech talk", sponsor reviews | practising engineers and managers | relevance, clear takeaways, credibility, no academic padding |

- If the cues conflict or are missing, **ask with AskUserQuestion**. Do not guess the genre.
- An invited seminar at a university is closest to **conference-talk** for depth, and to **tutorial** if it's labelled introductory.

**Draft-level context overrides the generic profile.** Look for, in this order:
1. A draft-specific skill (e.g. `cicc27-buck-ldo-review`).
2. An `instructions.md` or `CLAUDE.md` in the draft's folder.

Either one may define:
- the audience persona
- the organiser's hard rules (slide or page limits, timing, formatting)
- deadlines
- how the review should be run

Use its rules as the rubric, and its audience definition as the persona. These files are context for *you*. Pass the reader only the persona, the format constraints and the rubric items, never the author's plans for content.

## Hard rules (all genres)
- **Read only the file(s) he names.** If he names none, **ask with AskUserQuestion** which file(s) to read. You may list candidate drafts in the folder as options. Do not guess, and do not default to the newest file. If the conversation already makes the target unambiguous (e.g. "again" right after reviewing a named file), use that file.
- Never open skeletons, outlines, notes or other planning files unless he names them. Do not carry outline or plan knowledge into the review. A folder `instructions.md`/`CLAUDE.md` is allowed: it describes audience and rules, not content. A style folder of old papers may be read only to learn his style.
- **The cold read is done by a fresh subagent** that gets only the extracted audience-visible content and the figures. Do not describe the work, its contributions or the author's intent in that subagent's prompt.
- Never edit the draft. Proposed phrasing goes in your reply only.
- **Check the file's modification time first.** If it hasn't changed since the last review, the editor (Word, PowerPoint) probably still has unsaved edits. Ask him to save before reviewing again.

## Shared-doc / paste workflow
When he is editing in a shared doc and pastes pieces into chat instead of saving a file:
- Keep a running mirror, `paste_mirror.md`, in the draft folder. Seed it from the last saved draft.
- Insert or replace each pasted piece where he says. If he doesn't say, treat it as the next piece.
- Cold-read the mirror up to and including the new piece, and tell the reader to focus on that piece and how it fits with what came before.
- Use the figures from the last saved file unless he says a figure has changed.

## Workflow

### 1. Confirm the file(s)
- Resolve a bare filename against the draft's folder: `~/Desktop/v/paper_drafts/<VENUE>/` for papers; the talk folder for decks; the proposal folder for proposals.
- If he names several files, extract each one and pass them to the reader **in the order given**, each under its own filename header.
- A lock file (`~$...docx`, `~$...pptx`) is fine. Just read the named file.

### 2. Extract only audience-visible content, up to the frontier

#### 2a. Prose (papers, proposals)
- **Strict OOXML.** A `.docx` may be saved in Strict OOXML, which python-docx can't open. Use regex over `word/document.xml` instead:
  1. Pull out every `<…:txbxContent>…</…:txbxContent>` block. These are figure and caption text, and they can be anchored mid-sentence. Extract them separately as captions.
  2. Stream through the remaining body in document order with `re.finditer(r'</w:p>|<[wm]:t(?: [^>]*)?>([^<]*)</[wm]:t>')`. Append `w:t`/`m:t` text to a buffer, and flush it as one paragraph at each `</w:p>`. Then unescape HTML entities.
  3. **Never match whole `<w:p>…</w:p>` blocks.** Nested paragraphs make that silently drop content.
- **Figures.** A real reader sees the figures, and key content often lives only there. For `.docx`, unzip `word/media/*` into a folder under the outputs directory. Map each image to its figure number using `r:embed` order and the rels file. Have the reader confirm the mapping from the image content, because file order can differ from figure numbering. Exclude any figure not yet cited before the frontier.
- **Other formats.** For `.tex`, `.md` or `.txt`, read the source. Strip the preamble and comments, keep the captions, and pass figure files when they are available.
- **Keep** the title, abstract, keywords (if real), headings, body, figure captions and table contents.
- **Drop** template boilerplate and placeholders:
  - IEEE template guidance text ("This template, modified in MS Word…", "Ease of Use", "Maintaining the Integrity of the Specifications", "Prepare Your Paper Before Styling", "Abbreviations and Acronyms", "Units", "Equations", "Some Common Mistakes", "Using the Template", "Authors and Affiliations", "Identify the Headings", "Figures and Tables", "Table Type Styles", and the text-box guidance)
  - placeholders ("<Author placeholder…>", "<Funding placeholder…>", "(Heading 1)" tags, "Keywords—component, formatting…")
  - the sample references (Eason, Maxwell, Jacobs & Bean, Elissa, Nicole, Yorozu, Young, Kingma, Eves, Liu, TEDS-D)
  - ISSCC digest submission-form front matter
  - agency proposal-template instructions

#### 2b. Decks (tutorial, conference-talk, industry-talk)
The reader is an **attendee**. They see the slides and hear the speaker, in order, at the speaker's pace. They cannot flip back.

**slide-studio plan (`deck.md`)**
- Per `## ` section, give the reader the following, labelled `Slide N`:
  - the **title**
  - the on-slide text fields: `body`, `left`/`right`/columns, `subtitle`, and `message` when the layout draws it
  - `source` (attribution)
  - figures: the image (Read tool), or, if missing, `[figure not yet drawn: <filename>]`
  - `notes`, labelled **"Speaker says:"**
- **Hide plan-only fields**: `num`, `layout`, file paths, front matter.
- When `message` has no on-slide slot, it is the takeaway the speaker intends. Pass it as **"Speaker's intended takeaway"** so the reader can judge whether the slide earns it.
- Render `~~greyed~~` text as "(shown greyed, covered later)".

**`.pptx`**
- Extract per slide: title, text frames in reading order (top-to-bottom, left-to-right), tables, and speaker notes as "Speaker says:".
- Export pictures with their slide number. If PowerPoint/LibreOffice export is allowed, give the reader slide PNGs instead, since layout and legibility matter.

**Organiser chrome and frontier**
- Drop organiser chrome: footers, "N of M", template example slides, and a closing QR slide unless it's the subject of a rule.
- **Frontier** = the last slide with authored content. Title-only slides with no notes are typed-ahead headings: count them for pacing, but don't show them as content.

#### 2c. Common to all genres
- **Co-author or self notes** embedded in the text, captions or notes are not shown to the reader. Examples: "Jiwon Notes: …", "[Jiwon, grow the font…]", "@jiwon …", "TODO", "Notes for Visvesh". List them separately for him.
- **Frontier** (prose) = the last authored sentence.
  - Headings he has typed ahead with no text under them are not shown.
  - A sentence that stops midway is *unfinished*, not an error.
  - Rough bullet notes after the last prose are his notes. Exclude them, and say you did.
- **Citations.** Placeholder citations (e.g. [a-b], [xu,liu]) are expected. The reader flags only claims that have no citation at all.
- **Long drafts.** If earlier sections were already reviewed, you may summarise them in one bracketed line and tell the reader to focus on the new section and its consistency with the earlier text.

### 3. Spawn the cold reader (fresh `general-purpose` agent; Read tool only, for figure images)
The prompt contains **only**:
- the persona (genre profile below, overridden by the draft-level context)
- the format and constraints: e.g. "4-page CICC paper", "ISSCC 2-page digest + figures", "15-page NSF project description", "75-minute ISSCC tutorial, ≤75 slides, live audience", "20-minute ISSCC paper talk"
- the extracted content between `--- BEGIN DRAFT ---` and `--- END OF WHAT HAS BEEN WRITTEN ---`, with captions (prose) or per-slide blocks (decks)
- the figure image paths, with an instruction to view each figure (Read tool only) when it is first cited or first appears, and to check that the text, narration and figures agree on symbols, equations, waveforms vs. claims, and panel labels
- the rubric items from the draft-level context (organiser rules), if any
- an optional **deferred list**: topics he has said come later; the reader should not flag them unless the content actively misleads
- the return format below, with the genre's checks and the scope reminder (section 4)
- the style baseline for that genre (section 6)

The reader returns:
0. **Verdict**: 2–3 sentences.
1. **What I understood** (or *learned*, for talks): 3–6 sentences, plus anything it is unsure of.
2. **Gaps** by severity (Critical / Major / Minor). Each gap quotes the phrase, or names the slide or figure element, says what is wrong, and says why it matters. Use the genre's checks below.
3. **Questions I'm carrying** at the frontier. For talks, also: *where I got lost*, by slide.
4. **What I expect next.**
5. **Style notes**: deviations from the baseline, plus **Style upgrades**.

### Genre profiles

#### paper
- **Persona**: "You are an expert IEEE <venue> reviewer in <subfield>. You are reading a paper draft for the first time. You know the field's literature but nothing about this specific work. Read strictly in order, using only what has been stated so far. When the text ends, stop: do not guess what the author intends to write. Be strict but proportionate: flag what a real reviewer would notice."
- **Checks**:
  - undefined terms or symbols
  - claims with no number, citation or mechanism
  - logical jumps
  - whether problem → prior-work failure → numbered challenges → contributions forms a closed chain
  - inconsistencies across title, abstract, captions, figures and body
  - physically questionable specs, ranges or equations
  - garbles and typos

#### proposal
- **Persona**: "You are a <agency> review panelist (or program manager) with expertise near, but not in, <subfield>. You are reading this proposal for the first time with 10 others to score this week. Read in order; stop where the text stops."
  - Name the actual program if known: NSF CCF/ECCS panel, DARPA PM, SRC liaison, DOE.
- **Checks**:
  - Is the significance clear within the first page? Why now, and why this team?
  - Specific, testable aims.
  - Each aim has an approach, a risk and a fallback.
  - Preliminary results support feasibility.
  - Evaluation metrics and milestones.
  - Fit to the solicitation's review criteria (e.g. NSF Intellectual Merit / Broader Impacts, quoted if the solicitation is in the folder).
  - Undefined jargon for an adjacent-field panelist.
  - Overclaiming.
  - Page-budget balance.
- **Tone**: panels skim. Flag anything that forces a re-read.

#### tutorial
- **Persona**: the learner defined in the draft-level context. Default: "You are a first-year graduate student in circuits, or an experienced IC designer new to this topic, attending this tutorial live. You know undergraduate circuits and basic digital timing. You see each slide and hear the speaker once, in order; you cannot flip back or look things up. Stop where the deck stops."
- **Checks**:
  - **Prerequisites**: any concept, symbol or acronym used before it is defined or motivated. Acronyms must be spelled out on the slide.
  - **Build-up**: motivation before mechanism; simple case before general case; one concept per slide; no jump in complexity without a bridge.
  - **Takeaways**: can the reader state each slide's point in one sentence? Does it match the speaker's intended takeaway?
  - **Figures**: is there a figure where one is needed? Is it readable as drawn? Is it a pasted publication diagram too dense for a learner?
  - **Signposting**: outline or recap slides at section boundaries; where the interim Q&A falls.
  - **Pacing**: slides vs. minutes; sections that are too dense or too thin.
  - **Ending**: future directions, a conclusion, and references (on-slide and at the end).
  - The **organiser rubric** from the draft-level context, item by item.
- **Do not demand** novelty, a contribution chain, or measured-vs-baseline claims. That is paper criticism, not tutorial criticism.

#### conference-talk
- **Persona**: "You are an expert attendee at <venue> in <subfield>. You haven't read this paper. You have ~<N> minutes and will hear this talk once. Stop where the deck stops."
- **Checks**:
  - The problem and the one key idea are clear within the first 3–4 slides.
  - Each slide supports that idea.
  - Measured results are stated against a clear baseline, with conditions.
  - Claims match the paper. If the paper is named, read it as context only.
  - Figures are legible at the back of the room.
  - Slide count vs. time.
  - A comparison table, and a conclusion that restates the idea and the numbers.

#### industry-talk
- **Persona**: "You are a senior engineer or engineering manager at <company/sector>. You are technically strong but have no time for academic framing. You are attending live. Stop where the deck stops."
- **Checks**:
  - The relevance to their products or problems is stated early.
  - Concrete takeaways or asks.
  - Costs, area, power, integration effort and risk are addressed.
  - Maturity is stated (silicon-proven vs. simulated).
  - Jargon that is academic rather than industrial.
  - Overclaiming.
  - Respect for confidentiality: no third-party proprietary data without a source.

### 4. Filter, trim to scope, then relay
- Sanity-check the reader's technical critiques. Verify math yourself where you can.
- Drop critiques he has already refuted, and any that contradict his house style (e.g. a space before units).
- **Hold the reader to its genre.** Drop paper-style demands (novelty, contribution chain) raised against tutorials. Drop "needs more depth" raised against a slide whose stated role is an overview.

**Match the depth to the element.** Readers over-ask, so trim before relaying.
- **Abstracts** (papers, proposal summaries) must be very concise. That is a hard constraint, not a weakness. Only raise what an abstract must carry:
  - a clear novelty or mechanism hook, in a few words
  - internal consistency (motivation vs. result, title vs. abstract)
  - headline numbers that aren't ambiguous; a word or two of reference is enough
  - garbles and wrong words
- Do **not** ask the abstract for measurement conditions (mV, edge rates, operating points), baseline definitions, implementation specs (fsw, L) or measured-vs-modeled detail. If such an item matters, note once that the *intro or results* must carry it.
- Prefer fixes that keep the abstract the same length or make it shorter. Flag any fix that adds words, and suggest what to cut to pay for it.
- Keep abstract reviews to about 3–5 items.
- **Titles**: check accuracy against the abstract or content, hype, and length. Nothing else.
- **Captions, single sentences and single slides**: apply the same proportionality.
- **Slides**: every fix must respect the slide's real estate. A fix that adds bullets should say what to cut, or move it to the notes.

### 5. Proposed phrasing (always include for Critical/Major items, and for abstracts and titles)
For each Critical or Major item, and for any abstract or title issue, give **one proposed phrasing** in his style. He decides whether to use it.
- Use the voice for the genre (section 6).
- Keep his structure and wording wherever possible. Change the minimum needed to fix the issue; this is not a rewrite.
- Show it as a short quoted replacement for the specific phrase, sentence, bullet or slide title, labelled with what it fixes.
- For **decks**, the proposal may be one of:
  - a reworded bullet or title
  - a one-sentence `message`
  - a missing bridge slide, given as title + message only
  - a figure description ("plot Tclk and Tcrit vs. time through a droop")

  Never write full slide content unless he asks.
- For abstracts and titles, the proposal must be no longer than the original, or only marginally longer with the cut that pays for it noted. Give the word count when it matters.
- Use `[X]` placeholders for numbers or facts you don't know. Never invent results.
- Don't propose phrasing for Minor items unless the fix is non-obvious. A short hint is enough there.

### 6. Style baselines
These are his *current* conventions. They are a baseline, not gospel, and he is open to improvements. Flag deviations, and mark a place where a convention hurts clarity as a **Style upgrade**.

#### Papers (from his ISSCC 2027 submissions)

**Intro arc**
1. Open with the system-level problem and what it costs. Introduce symbols at first use ("supply-voltage (Vdd) droop").
2. End the motivation with a "requirement" sentence ("…are required for…").
3. Group prior work by citation, each group with its own limitation, often framed as a tradeoff.
4. List numbered, named challenges ("(1) Prediction Horizon: …").
5. "This paper presents…", with contributions mapped to the challenges ("resolving (4) and (3)"), plus "In contrast to prior work…".
6. Close with the test chip (process), the operating range and headline **measured** numbers against a stated baseline.

**Body**
- Anchor each paragraph to a figure ("Fig. 2 outlines…").
- Explain causally ("Because…", "thereby", "therefore").
- Define the baseline early and justify it.
- Label simulated numbers as simulated, and state measurement conditions.
- Keep the conclusion short.

**Abstract (his ISSCC pattern, ~60–80 words)**
1. The problem, and why prior approaches fall short, in one sentence.
2. The key idea / mechanism, in one sentence.
3. Process node and headline measured results in one or two sentences, with ratios such as "cuts droop 90% and raises effective frequency 13.5%".

**Mechanics**
- No space before units (65nm). Use × for ratios.
- Ascending ranges, in one style.
- Consistent notation and capitalization.
- Present tense, active voice, dense. No hype adjective without a number behind it.

#### Proposals
- Same voice as papers: dense, active, causal, numbers over adjectives.
- Aims stated as imperatives with measurable outcomes.
- Each aim has an explicit risk and mitigation.
- Mirror the solicitation's language for review criteria.

#### Decks (all talk genres)
- **Titles**: tutorials use a short topic title (Title Case). Paper and industry talks prefer assertion titles that state the takeaway. Flag a topic title that hides a takeaway the audience needs.
- **Bullets**: fragments, not sentences. One line each. Parallel grammar. No more than ~5 per slide. Few sub-bullets.
- **Visual first**: the figure carries the point; bullets annotate it.
- Symbols and acronyms defined on the slide where they first appear.
- Same mechanics as papers (units, ×, notation consistency).
- Paper prose conventions ("This paper presents…", the numbered-challenge intro) do **not** apply to decks.

### 7. Track progress
Keep `cold_read_log.md` in the draft folder. For each run, append:
- the date
- the genre
- the file(s) or pasted pieces reviewed
- the frontier (sentence or slide number)
- the notes you excluded
- a gap table with a status for each gap

Compare against the previous entry and tell him what got fixed. Never pass the log to the cold reader.

Standing lists at the top of the log:
- **Final-pass checklist**: mention open items briefly in every review. Check every item on "final pass". For decks, seed it from the organiser's hard rules.
- **Deferred to later section**: pass these to the reader as the deferred list, and remind him when his writing reaches that section.

"Add this to the final pass" or "remind me later" means add the item to the right list.

## Output to User
Keep it concise:
1. **Genre and persona used** (one line), then the **verdict**, and what was fixed since last time.
2. **Gaps**: Critical and Major items, each with *what*, *why*, and a **proposed phrasing**. Minor items in brief. For decks, cite slide numbers and titles.
3. **Questions the reader is carrying** (and, for talks, where it got lost), and what the draft owes next, plus any relevant open final-pass or deferred items.
4. **Style**: deviations and upgrades, briefly.

When he pastes a revised passage or slide for a quick check, a direct review without a subagent is fine. Say so if your own context could be filling gaps that a cold reader would catch.
