---
name: cran-release-preflight
description: Use when preparing an R package submission or resubmission to CRAN, including running CRAN-style checks and drafting cran-comments.
---

# CRAN Release Preflight

## Goal

Ensure the package passes a CRAN-style check and that the submission metadata (DESCRIPTION, NEWS, cran-comments) is complete.

## Preflight protocol

1. Confirm package metadata is accurate:

   - Title is in title case and does not include the word "package".

   - Description is informative and does not repeat the package name.

   - URLs and BugReports point to the correct repository.

2. Ensure versioning is correct:

   - For updates, the Version in DESCRIPTION is strictly greater than the current CRAN version.

3. Build a source tarball:

   - Run `R CMD build .` from the package root.

4. Run CRAN-style checks on the tarball:

   - Run `R CMD check --as-cran <tarball>`.

   - Prefer running this with an R-devel toolchain when feasible.

5. Eliminate all ERRORs and WARNINGs.

   - For NOTEs, eliminate them unless they are expected (for example, the "new submission" NOTE).

6. Update NEWS and cran-comments:

   - Add bullet entries in NEWS describing user-visible changes.

   - Fill in cran-comments with test environments and the check summary.

## Common failure modes

- Vignettes time out or require system dependencies.

- Examples are non-deterministic (randomness without a fixed seed).

- Missing documentation for exported objects.

- Incorrect license declaration or missing LICENSE file.

## Output expectations

When asked to "prepare a CRAN submission", produce:

- A precise list of commands to run.

- A table summarizing check results by platform (local, CI, external checks if any).

- A draft cran-comments.md that includes any unavoidable notes and their justification.
