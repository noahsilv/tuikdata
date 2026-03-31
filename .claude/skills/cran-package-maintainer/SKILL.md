---
name: cran-package-maintainer
description: Use when working in this repository to add or modify functions, documentation, tests, or CI while maintaining CRAN readiness.
---

# CRAN Package Maintainer

## Purpose

This skill defines a conservative, CRAN-oriented workflow for modifying this R package repository.
The primary objective is to keep `R CMD check --as-cran` clean (no ERRORs, no WARNINGs, and no significant NOTEs) while the package evolves.

## Operating rules

1. Never accept an `R CMD check` failure as “CI-only.” Reproduce locally and fix.

2. When you add or change exported objects:

   - Update roxygen2 documentation.

   - Ensure examples run quickly and deterministically.

   - Add or update tests.

3. When you add dependencies:

   - Add the package to `Imports` or `Suggests` in DESCRIPTION, based on whether it is needed at runtime.

   - If you import functions into the namespace, ensure NAMESPACE reflects that.

4. Keep NEWS and versioning consistent:

   - Add a NEWS entry for user-visible changes.

   - Bump the version before a release.

5. CI conventions:

   - Use r-lib/actions v2 patterns for R checks.

   - Avoid legacy “comment-driven” PR automation unless explicitly requested.

## Standard commands

Run these locally before pushing:

- `devtools::document()`

- `devtools::test()`

- `devtools::check()`

Before a CRAN submission, run `R CMD build` and `R CMD check --as-cran` on the resulting tarball.

## What to do when you touch common areas

### R/ code

- Add or modify functions in `R/`.

- If exported, ensure `@export` is present and that documentation exists.

### man/ docs

- If you change roxygen comments, regenerate man pages via `devtools::document()`.

### tests/

- Use testthat edition 3 style.

- Prefer small, fast unit tests.

### DESCRIPTION

- Maintain accurate Title and Description.

- Keep URLs and BugReports consistent.

## Examples

### Add a new exported function

1. Create `R/new-feature.R`.

2. Write the function with roxygen2 comments including `@export` and minimal examples.

3. Add tests under `tests/testthat/test-new-feature.R`.

4. Run `devtools::document()`, `devtools::test()`, `devtools::check()`.

### Add a Suggests dependency for an optional feature

1. Add it to `Suggests`.

2. Guard usage with `requireNamespace()`.

3. Add tests that skip if the dependency is not installed.
