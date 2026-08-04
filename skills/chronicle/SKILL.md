---
name: chronicle
description: "Use when a workflow needs to append a release milestone or a narrative entry to a project's docs/HISTORY.md: creates the file from its fixed header when absent and appends a dated entry at the end."
---

# Appending to a project chronicle

A chronicle records what a project actually did — what shipped and when, what was decided, what was
tried and abandoned. Its value is that it is *compiled*, never composed: entries are appended by
workflows as work completes, so the file cannot quietly drift away from what happened.

**Append** when a release ships, or when a period of work closes and its shape is worth keeping.

**Do not append** plans, progress notes, or anything not yet true. A chronicle is past tense only:
work that is intended belongs in the tracker, and work in flight belongs nowhere yet.

## Procedure

### 1. Choose the shape

**milestone** — a release. The version, what shipped, and the tickets and pull requests that carried
it.

**narrative** — a period. The decisions taken, the turns the work took, and what did not work.

If the material is neither — a single decision with its reasoning, for instance — it is not a
chronicle entry. A decision belongs in a decision record; say so and stop rather than filing it here,
where nothing links to it.

### 2. Allocate the entry

Run the helper in this skill's directory, from anywhere inside the target repository:

```bash
scripts/append-entry.sh milestone "v1.4.0"
scripts/append-entry.sh narrative "2026-W31"
```

It creates the chronicle with its fixed header if this is the repository's first entry, instantiates
the template for the shape, appends it at the end, and prints `<path>:<line>` — the line the new
entry starts on. Pass `--file` if the chronicle does not live at `docs/HISTORY.md`.

### 3. Write the entry

Open the printed path at the printed line and replace the italic guidance in each section with the
real content. Delete the guidance text; do not write around it.

Keep it short, and compile rather than transcribe. An entry assembled by pasting commit subjects is
a log, and a log is already in git. What earns a place here is the part git cannot reconstruct: why
a release mattered, and what was abandoned.

### 4. Verify before reporting

Re-read the tail of the file. Confirm the new entry is the last thing in it, no italic guidance
survives, and the date is the one the Conventions call for — not merely today's.

If it sits below an entry bearing a later date, that is expected, not a mistake to correct.

Then read `git diff` on the chronicle. **It must show additions only** — a diff that touches any
earlier line means something was rewritten, and the fix is to restore it, not to explain it.

## Conventions

- **Position** — appended at the end, always. Never inserted in date order, never sorted, never
  regrouped, so diffs stay clean and links into the file by line stay valid. What this guarantees is
  **record order, not date order**: the file reads in the order entries were written down, which is
  not always the order things happened. A backfilled entry lands below newer ones, and a chronicle's
  first entries are usually backfills. That is correct rather than a defect — sorting would mean
  rewriting entries above the insertion point, which is exactly what the header forbids.
- **Date** — ISO `YYYY-MM-DD`, in the heading beside the label, and which date depends on the shape.
  A **milestone** takes the date the thing shipped; that is normally today, which is why the helper
  defaults to it, but pass `--date` when recording a release after the fact. A **narrative** takes
  the date it was compiled, because the period it covers is already in the label.
- **Label** — the version for a milestone (`v1.4.0`), the period for a narrative (`2026-W31`,
  `2026-Q3`). One label per entry; do not merge two releases into one heading.
- **Immutable once written** — an entry is a historical statement. When something recorded here turns
  out to have been wrong, the correction is a later entry that says so, not an edit to the earlier
  one. Correct typos, never facts.
- **Compiled, not hand-written** — the header states that the file is never edited by hand, and that
  claim has to stay true. Every entry arrives through this skill; nothing is typed straight in.

If the helper cannot run in the current environment, do the same by hand following the conventions
above — copy the matching `template-*.md`, substitute the label and the date, and append it to the
end of the file with one blank line before it. Create the file from the header in
`scripts/append-entry.sh` if it does not exist.
