# CLAUDE.md -- Academic Project Development with Claude Code

<!-- HOW TO USE: Replace [BRACKETED PLACEHOLDERS] with your project info.
     Keep this root file under ~150 lines — Claude loads it every session.
     See README.md for full documentation. -->

**Project:** fishing_grounds
**Institution:** University of Miami
**Branch:** main

---

## Core Principles

- **Plan first** -- enter plan mode before non-trivial tasks; save plans to `quality_reports/plans/`
- **Verify after** -- compile/render and confirm output at the end of every task
- **Single source of truth** -- `latex/main.tex` is authoritative for the paper
- **Quality gates** -- nothing ships below 80/100
- **Structured [LEARN] tags** -- when corrected or when you discover a durable lesson, save a structured `[LEARN:category]` entry to `MEMORY.md`

---

## Folder Structure

```
fishing_grounds/
├── CLAUDE.md                    # Root Claude Code instructions
├── AGENTS.md                    # Codex CLI instructions
├── MEMORY.md                    # Persistent [LEARN] entries across sessions
├── Makefile                     # Root — single flat Makefile
├── fishing_grounds.Rproj        # RStudio project file
├── protocols/                   # Canonical shared skill bodies
│   └── skills/
│       └── *.md
├── .claude/                     # Claude Code: settings, wrappers, agents, hooks
├── .agents/                     # Codex CLI: thin skill wrappers
├── scripts/                     # Analysis pipeline
│   ├── CLAUDE.md                # Claude loads this when working in scripts/
│   ├── AGENTS.md                # R code conventions
│   ├── 01_processing/           # VMS track retrieval and preparation
│   │   └── *.R
│   ├── 02_analysis/             # EPS calibration, fishing grounds, space utilization, revisitation
│   │   └── *.R
│   └── 03_content/              # Figures and Quarto report
│       ├── *.R
│       └── *.qmd
├── R/                           # Reusable utility functions
│   └── *.R
├── data/                        # Data pipeline
│   ├── raw/                     # Raw data from external sources
│   ├── output/                  # Intermediate outputs (e.g., fishing_grounds.rds)
│   └── processed/               # Derived datasets for content generation
├── latex/                       # Paper manuscript and slides
│   ├── CLAUDE.md                # Claude loads this when working in latex/
│   ├── AGENTS.md                # LaTeX conventions
│   ├── main.tex                 # Main paper
│   ├── slides.tex               # Presentation slides
│   ├── references.bib           # Bibliography
│   └── latex_extras/            # Preamble files (packages, commands, tables)
├── results/                     # Pipeline outputs
│   ├── img/                     # Generated figures
│   ├── tab/                     # Generated tables
│   └── numbers/                 # Inline numbers for manuscript (\newcommand .txt files)
├── quality_reports/             # Plans, handoffs, session logs, merge reports
├── templates/                   # Session, handoff, learning, and quality templates
└── tools/                       # Utility scripts (e.g., template consistency checker)
```

---

## Commands

```bash
# Make (preferred — builds everything)
make                               # Build all targets
make -n                            # Dry-run: show what would be built
make check-template                # Validate shared-skill and permission sync

# LaTeX (manual fallback — 3-pass, pdflatex)
cd latex
export TEXINPUTS=.:./latex_extras/:../results/numbers/:../results/tab/:../results/img/:
pdflatex -interaction=nonstopmode main.tex
bibtex main
pdflatex -interaction=nonstopmode main.tex
pdflatex -interaction=nonstopmode main.tex
```

---

## Quality Thresholds

| Score | Gate | Meaning |
|-------|------|---------|
| 80 | Commit | Good enough to save |
| 90 | PR | Ready for deployment |
| 95 | Excellence | Aspirational |

---

## Skills Quick Reference

| Command | What It Does |
|---------|-------------|
| `/commit [msg]` | Stage, commit, PR, merge on the current non-`main` branch; create a branch only when needed |
| `/data-analysis [dataset]` | End-to-end R analysis |
| `/refactor [file-or-dir]` | Verify-refactor-verify loop |
| `/verify-outputs [script]` | Checksum outputs, compare to reference |
| `/compare-branches [b1] [b2]` | Cross-branch output comparison |
| `/resume` | Recover context after compression/new session |
| `/trace [question]` | Trace an ambiguous result or failure back to its most likely cause |
| `/learn [insight]` | Save a durable, project-specific lesson to `MEMORY.md` |
| `/setup-makefile [dir]` | Generate Makefile from directory contents |
| `/review-r [file]` | R code quality review |
| `/review-tex [file]` | LaTeX hardcoded-number review for manuscripts and slides |
| `/review-makefile [file]` | Makefile conventions review |
| `/review-comments [path]` | Clean up comments, docstrings, dead code |
| `/review-domain [file]` | Substantive domain review (identification, citations, code-theory) — opt-in |
| `/proofread [file]` | Grammar, typos, overflow, consistency check — opt-in |
| `/review-pr [PR#]` | Address PR review comments, commit fixes, resolve threads |

---

## Shared Skill Protocols

- Canonical shared skill bodies live in `protocols/skills/`
- `.claude/skills/` and `.agents/skills/` are thin wrappers around those files
- Review-oriented agents in `.claude/agents/` execute the same canonical protocols

## Claude Loading Model

- Root `CLAUDE.md` sets project-wide workflow rules
- `scripts/CLAUDE.md` loads when Claude works in `scripts/`
- `latex/CLAUDE.md` loads when Claude works in `latex/`
- Shared local conventions live in `AGENTS.md`, `scripts/AGENTS.md`, and
  `latex/AGENTS.md`
- `.claude/agents/` and `.claude/hooks/` remain Claude-only execution surfaces
  and mechanics

## Claude-Specific Notes

- Enter plan mode before non-trivial tasks and exit only after the user
  approves the plan
- Prefer auto-compression over `/clear`; use `/clear` only when context is
  genuinely polluted
- After compression or a new session, read `CLAUDE.md`, read the most recent
  plan in `quality_reports/plans/`, read the most recent relevant handoff in
  `quality_reports/handoffs/` if one exists, then inspect
  `git log --oneline -10` and `git diff`

---

## Current Project State

| Component | File | Status | Description |
|-----------|------|--------|-------------|
| Manuscript | `latex/main.tex` | Template | Paper skeleton with standard sections |
| Slides | `latex/slides.tex` | Template | Presentation template |
| Processing | `scripts/01_processing/` | Complete | VMS track retrieval and preparation |
| Analysis | `scripts/02_analysis/` | Complete | EPS calibration, fishing grounds, space utilization, revisitation |
| Content | `scripts/03_content/` | Complete | Figures and Quarto report |
| Utilities | `R/` | Complete | Reusable functions (find_elbow, get_extensive, minpts_rule, project_to_metric) |

---

## Plan-First Notes

For manuscript or slide tasks, ask during planning whether to include these optional review passes:
- `domain-reviewer` for substantive domain review (identification, derivations, citations, code-theory alignment)
- `proofreader` for grammar, typos, overflow, and consistency

For multi-file tasks, write short handoff notes under
`quality_reports/handoffs/` at major stage boundaries.

When a durable, project-specific lesson emerges, save it to `MEMORY.md` with a
structured `[LEARN:category]` block or use `/learn`.