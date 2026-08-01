# Code Pipeline Conventions

These conventions apply to all scripts in `scripts/` and its subdirectories.

---

## Path Style

- Use forward slashes in any literal filepath on every platform, including
  Windows (for example `../../results/tab/results.csv`)
- Never write Windows-style backslashes in path literals
- Path helpers such as `here::here()`, `file.path()`, `joinpath()`, and `fullfile()` remain
  preferred for programmatic path construction. The `here` package is prefered, within reason.

---

## R Code Standards

**Standard:** Senior Principal Data Engineer + PhD researcher quality

### 1. Reproducibility

- `set.seed()` called ONCE at top (YYYYMMDD format), when required
- All packages loaded at top via `pacman::p_load()` (not `require()` or `library()`)
- All paths relative to the script working directory (usually `scripts/[task_group]/`)
- Rely on the Makefile to make directories

### 2. Function Design

- `snake_case` naming, verb-noun pattern
- Roxygen-style documentation for functions
- Default parameters, no magic numbers
- Named return values (lists or tibbles)

### 3. Domain Correctness

<!-- Customize for your field's known pitfalls -->
- Verify estimator implementations match paper formulas (`latex/main.tex`)
- Check known package bugs (document below in Common Pitfalls)

### 4. Visual Identity

```r
# --- Your institutional palette ---
plot_blue = "steelblue"
plot_mid = "#d4bf95"
plot_mid2 = "#fbde81"
plot_red = "#c13832"
plot_orange = "#f47321"
plot_muted_orange = "#d28e00"
plot_green = "#005030"
plot_muted_green = "#91b9a4"
plot_gray = "#8996a0" 
plot_lightblue = "#9eceeb"
```

#### Fonts
```
sysfonts::font_add_google("Lato")
sysfonts::font_add_google("Fira Sans")
```

#### Custom Themes
```r
# Regular plots
main_theme <-
  theme_linedraw() +
  theme(
    legend.position = "none",
    title = element_text(size = 24),
    text = element_text(family = font_choice),
    axis.text.x = element_text(size = 30), axis.text.y = element_text(size = 30),
    axis.title.x = element_text(size = 30), axis.title.y = element_text(size = 30),
    panel.grid.minor.x = element_blank(), panel.grid.major.y = element_blank(),
    panel.grid.minor.y = element_blank(), panel.grid.major.x = element_blank(),
    axis.line = element_line(colour = "black"), axis.ticks = element_line(colour = "black"),
    plot.background = element_rect(fill = "#ffffff")
  )

# Maps
map_theme <-
  theme_void() +
  theme(
    legend.position = "bottom",
    legend.key.height = unit(.35, "cm"),
    legend.key.width = unit(.6, "cm"),
    legend.text = element_text(size = 8),
    text = element_text(family = "Lato"),
  )
```

#### Figure Dimensions (for slides template)
```r
# Maps
ggsave(filepath, width = 9, height = 6, bg = "transparent")
# Figures
ggsave(filepath, width = 9, height = 6, bg = "transparent")
```

### 5. Output Paths

We prioritize the use of paths constructed with `here::here()`, which are relative to the origin of the project. Code and Makefiles should be constructed accordingly.

```r
output_root <- here::here("..", "..", "results")

# Figures
ggsave(here::here(output_root, "img", "my_plot.pdf"), width = 8, height = 8, bg = "transparent")

# Tables / RDS
saveRDS(result, here::here(output_root, "tab", "my_results.rds"))

# Inline numbers for manuscript (\newcommand .txt files)
writeLines("\\newcommand{\\myEstimate}{2.31}",
           here::here(output_root, "numbers", "my_estimate.txt"))
```

**Heavy computations saved as RDS; slide rendering loads pre-computed data.**

### 6. Common Pitfalls

<!-- Add your field-specific pitfalls here -->
| Pitfall | Impact | Prevention |
|---------|--------|------------|
| Missing `bg = "transparent"` | White boxes on slides | Always include in ggsave() |
| Hardcoded paths | Breaks on other machines | Use relative paths |

### 7. Line Length & Mathematical Exceptions

**Standard:** Keep lines <= 120 characters.

**Exception:** Mathematical formulas may exceed 120 chars if breaking the line would harm readability, an inline comment explains the operation, and the line is in a numerically intensive section.

### 8. Code Quality Checklist

```
[ ] Packages at top via pacman::p_load()
[ ] set.seed() once at top, when required
[ ] All paths relative to the root working directory
[ ] Functions documented (Roxygen)
[ ] Figures: transparent bg, explicit dimensions
[ ] RDS: every computed object saved
[ ] Comments explain WHY not WHAT
```
---

## Makefile Conventions

### Structure

- Every Makefile has `all` and `clean` as `.PHONY` targets
- `all` is the default (first) target and builds everything in that directory
- `clean` removes all generated outputs
- Root Makefile is a single flat Makefile (no sub-Makefile delegation)

### Directory Creation

Use order-only prerequisites for output subdirectories. Route generated files
to the repo-root `results/` directory:

```make
RESULTS_ROOT = results

$(RESULTS_ROOT)/tab/results.csv: scripts/02_analysis/analysis.R | $(RESULTS_ROOT)/tab
	cd $(<D); Rscript $(<F)
$(RESULTS_ROOT)/img/plot.pdf: scripts/03_content/figures.R | $(RESULTS_ROOT)/img
	cd $(<D); Rscript $(<F)
$(RESULTS_ROOT)/numbers/estimate.txt: scripts/02_analysis/analysis.R | $(RESULTS_ROOT)/numbers
	cd $(<D); Rscript $(<F)

$(RESULTS_ROOT)/tab $(RESULTS_ROOT)/img $(RESULTS_ROOT)/numbers:
	mkdir -p $@
```

Scripts must NOT create directories themselves. The Makefile owns all directory creation.

### Cross-Makefile Dependencies

```make
RESULTS_ROOT = results

$(RESULTS_ROOT)/tab/sibling_output.csv: scripts/sibling_dir/sibling_script.R
	cd $(<D); Rscript $(<F)
```

### Expensive Intermediates

Mark expensive-to-produce files as `.PRECIOUS` so Make does not delete them on interruption.

### Pattern Rules

```make
RESULTS_ROOT = results
STATA ?= stata-mp

$(RESULTS_ROOT)/tab/%.rds: %.R | $(RESULTS_ROOT)/tab
	Rscript $<

$(RESULTS_ROOT)/tab/%.csv: %.jl | $(RESULTS_ROOT)/tab
	julia $<

$(RESULTS_ROOT)/tab/%.dta: %.do | $(RESULTS_ROOT)/tab
	$(STATA) -b do $<
```

### Joint Production

When a single script produces multiple outputs, declare one primary target with the recipe and secondary targets with an empty recipe (`;`).

```make
RESULTS_ROOT = results

$(RESULTS_ROOT)/tab/results.csv $(RESULTS_ROOT)/img/diagnostics.pdf: analysis.R | $(RESULTS_ROOT)/tab $(RESULTS_ROOT)/img
	Rscript $<
$(RESULTS_ROOT)/img/diagnostics.pdf: $(RESULTS_ROOT)/tab/results.csv ;
```

### Recipe Conventions

- R scripts: `Rscript $<`
- Always use `$<` (first prerequisite) and `$@` (target) automatic variables
- Never use absolute paths
- In task-group Makefiles, keep script prerequisites local (`analysis.R`) and
  route outputs through `$(RESULTS_ROOT)`

### Root Makefile Pattern

This project uses a single flat Makefile at the repo root. All targets for
scripts, data processing, and content generation are defined there directly.

### Validation

- `make -n` (dry-run) must produce a valid plan
- Every `.R`, `.jl`, `.do`, `.ado`, and `.m` file under `scripts/` should appear as a prerequisite in some Makefile target -- orphaned scripts are a warning sign
