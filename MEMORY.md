# Project Memory

<!-- Claude Code stores [LEARN] entries here. Prefer structured entries:
[LEARN:category]
- Date: YYYY-MM-DD
- Trigger:
- Wrong:
- Right:
- Scope:
- Evidence:
- Action:
Do not edit manually unless you are intentionally maintaining the template. -->

[LEARN:pipe-migration]
- Date: 2026-04-28
- Trigger: Converting `%>%` to `|>` caused runtime errors (`object '.' not found`)
- Wrong: Blindly replacing `%>%` with `|>` everywhere. The native pipe `|>` does not support the magrittr dot (`.`) placeholder. Expressions like `mutate(area = st_area(.))`, `filter(!st_is_empty(.))`, and `bind_cols(st_coordinates(.))` all rely on `.` referring to the piped object, which only works with `%>%`.
- Right: When converting `%>%` to `|>`, inspect every `.` on the RHS. Each one needs a different fix:
  (a) `bind_cols(st_coordinates(.))` → break the pipe: assign to a variable, then `bind_cols(st_coordinates(var))`
  (b) `mutate(x = fn(.))` where `.` means "this sf object" → break the pipe or reference the variable by name
  (c) `filter(!st_is_empty(.))` on an sf object → use subsetting: `df <- df[!st_is_empty(df), ]`
  Never assume a `%>%` → `|>` swap is safe without checking for dot usage.
- Scope: All R scripts in this project; any future pipe-style migration
- Evidence: `01_identify_fishing_grounds.R` line 151 (`st_area(.)`), `02_get_grounds_exposure.R` line 55 (`st_is_empty(.)`), `03_build_panel.R` line 42 (`st_is_empty(.)`)
- Action: Before replacing `%>%` with `|>`, grep for `\.` patterns on the RHS. If dot usage is found, either refactor to intermediate variables/direct references, or **keep `%>%` for that specific pipe**. Using `%>%` is acceptable when the dot placeholder makes the code materially clearer or more concise than the `|>` alternative — do not contort code just to avoid magrittr.

[LEARN:quarto-revealjs]
- Date: 2026-05-04
- Trigger: Quarto revealjs slides with `. . .` (pause separators) inside `:::: {.columns}` / `::: {.column}` blocks
- Wrong: Using `. . .` for incremental reveals inside column environments, same as outside columns
- Right: `. . .` is not permitted inside column divs in Quarto revealjs. Use `::: {.fragment}` wrapper divs instead to achieve incremental reveals within columns.
- Scope: All Quarto revealjs slide decks (`qmd/**/*.qmd`)
- Evidence: User correction when translating `GulfCon26/GulfCon.tex` to `GulfCon26/GulfCon.qmd`
- Action: When generating revealjs slides, always use `{.fragment}` divs (not `. . .`) for incremental content inside column layouts. `. . .` remains fine outside columns.

[LEARN:unit-mismatch]
- Date: 2026-08-13
- Trigger: Filtering `stormwindmodel` output with `vmax_sust >= 34` intending tropical storm force
- Wrong: Using 34 as the threshold, assuming the package returns knots. `stormwindmodel` returns wind speeds in **meters per second**, so 34 m/s ≈ 66 kt (hurricane force), not tropical storm force.
- Right: Convert named meteorological thresholds to the package's native units before applying. Tropical storm force = 34 kt = ~17.5 m/s.
- Scope: Any R script using `stormwindmodel` or similar modelling packages with non-obvious output units
- Evidence: `scripts/02_analysis/05_exposure_to_hurricanes.R` line 197 filter was cutting at hurricane intensity instead of tropical storm intensity
- Action: Always check the documentation for output units of modelling packages before applying numeric thresholds. Never assume meteorological convention (knots) — verify.
