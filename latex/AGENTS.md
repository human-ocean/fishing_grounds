# LaTeX Conventions

These conventions apply to all files in `latex/` and its subdirectories.

---

## Verification

After any LaTeX change:

1. Compile with `make` from the project root (preferred)
2. For manual runs, first export environment variables from the `latex/` directory:
   ```bash
   export TEXINPUTS=.:./latex_extras/:../results/numbers/:../results/tab/:../results/img/:
   pdflatex -interaction=nonstopmode main.tex
   bibtex main
   pdflatex -interaction=nonstopmode main.tex
   pdflatex -interaction=nonstopmode main.tex
   ```
3. Verify PDF was generated with non-zero size
4. Check for overfull hbox warnings
5. Check for undefined citations
6. Run the `/review-tex` skill to check for hardcoded numbers in prose
7. Verify all dynamic number `\input{...}` files exist in `results/numbers/` and are listed in the root `Makefile` dependencies

---

## Makefile Pattern

The project uses a single flat Makefile at the repo root. If a dedicated `latex/Makefile` is ever added, use this pattern:

```make
TEX      = pdflatex
BIBTEX   = bibtex
TEXFLAGS = -interaction=nonstopmode

# Resolve \input and \includegraphics from results/ subdirs
export TEXINPUTS := .:./latex_extras/:../results/numbers/:../results/tab/:../results/img/:

MAIN     = main
SLIDES   = slides

MAIN_SOURCES = $(MAIN).tex \
               latex_extras/packages.tex \
               latex_extras/custom_commands.tex \
               latex_extras/dynamic_tables.tex \
               references.bib

SLIDES_SOURCES = $(SLIDES).tex \
                 latex_extras/slides_setup.tex \
                 latex_extras/dynamic_tables.tex \
                 references.bib

.PHONY: all clean

all: $(MAIN).pdf $(SLIDES).pdf

$(MAIN).pdf: $(MAIN_SOURCES)
	$(TEX) $(TEXFLAGS) $(MAIN)
	@if grep -q '\\citation' $(MAIN).aux 2>/dev/null; then $(BIBTEX) $(MAIN); fi
	$(TEX) $(TEXFLAGS) $(MAIN)
	$(TEX) $(TEXFLAGS) $(MAIN)

$(SLIDES).pdf: $(SLIDES_SOURCES)
	$(TEX) $(TEXFLAGS) $(SLIDES)
	@if grep -q '\\citation' $(SLIDES).aux 2>/dev/null; then $(BIBTEX) $(SLIDES); fi
	$(TEX) $(TEXFLAGS) $(SLIDES)
	$(TEX) $(TEXFLAGS) $(SLIDES)

clean:
	rm -f $(MAIN).pdf $(SLIDES).pdf *.aux *.bbl *.blg *.log *.out *.toc \
	      *.fdb_latexmk *.fls *.nav *.snm *.vrb *.synctex.gz *.run.xml *-blx.bib
```

List all `.tex` and `.bib` dependencies in SOURCES variables so Make can detect staleness. The conditional bibtex pattern avoids errors when there are no citations yet.

---

## Dynamic Numbers

The pipeline keeps computed results out of `.tex` source by writing `\newcommand` definitions to `results/numbers/` and resolving them at compile time via `TEXINPUTS`.

### How It Works

1. **Code generates a `.txt` file** with a `\newcommand` (R, Julia, Stata, or MATLAB)
2. **The manuscript inputs the file**: `\input{revenue_estimate.txt}`
3. **`TEXINPUTS` resolves the path** -- pdflatex finds the file in `../results/numbers/`

### Adding a New Dynamic Number

1. Add the write call to your R script in `scripts/`
2. Add the `.txt` file as a prerequisite in the root `Makefile`
3. Add `\input{filename.txt}` in the manuscript preamble
4. Use the macro in prose
5. Run `make` -- the code pipeline writes the file, then pdflatex picks it up

The same `TEXINPUTS` mechanism resolves figures (`results/img/`) and tables (`results/tab/`).

---

## TeX Prose Conventions

- Reference labels as "equation \eqref{...}" or "equations \eqref{...}--\eqref{...}" when grammatically appropriate
- Avoid bare "\eqref{...}" in running text
