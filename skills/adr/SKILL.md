---
name: adr
description: "Use when one architecture decision needs recording as it is taken — writes the numbered record under docs/decisions/. For a period summary or a release entry, use chronicle instead."
---

# Recording an architecture decision

An ADR captures a decision that constrains future work, together with the reasoning that was
available when it was taken. Its value is that it stays fixed: a reader six months later can see
*why*, not just *what*, and can tell whether the reasoning still holds.

**Record** a choice between real alternatives that would be expensive to reverse, that a newcomer
would otherwise re-litigate, or that trades a known cost for a known benefit.

**Do not record** things with no rejected alternative — style preferences, a library's documented
usage, a bug fix, or anything a reader would find faster by looking at the code.

## Procedure

### 1. Settle the decision first

Establish, from the conversation, all five: the **title**, the **context** that forced the choice,
the **options** considered, the **decision**, and its **consequences**.

If the decision is not actually settled, or if no alternative was ever rejected, stop and say so
rather than writing a record that invents deliberation.

Phrase the title as the choice itself, not the topic — `X via Y, not Z` reads well and makes the
rejected option visible in the index. Prefer `Session state in signed cookies, not server storage`
over `Session state`.

### 2. Allocate the record

Run the helper in this skill's directory, from anywhere inside the target repository:

```bash
scripts/new-adr.sh "<decision title>"
```

It picks the number, derives the slug, writes the record from `template.md`, appends the index line,
and prints the path it created. It also creates `docs/decisions/` and `INDEX.md` if this is the
repository's first record. Pass `--dir` if the records do not live at `docs/decisions/`.

### 3. Write the record

Open the printed path and replace the italic guidance in each of the five sections — **Context**,
**Options considered**, **Decision**, **Consequences**, **Links** — with the real content. Delete the
guidance text; do not write around it.

Keep it short. A record that takes ten minutes to read does not get read. Context and Consequences
carry the value; Decision is usually two sentences.

### 4. Verify before reporting

Re-read the created file and the last line of `INDEX.md`. Confirm no italic guidance survives, the
number and date are consistent between the two, and the index link resolves to the filename on disk.

## Conventions

- **Number** — highest existing number plus one, zero-padded to three digits. Never reuse a number,
  and never renumber; gaps are fine and are cheaper than broken references.
- **Filename** — `NNN-slug.md`, slug derived from the title, lowercase and hyphenated.
- **Date** — ISO `YYYY-MM-DD`, the date the decision was taken.
- **Index order** — newest last, so the file grows by appending and diffs stay clean.
- **Immutable once written** — a record is a historical statement. When a decision is reversed,
  write a new record and link the two: `Superseded by NNN` in the old one, `Supersedes NNN` in the
  new one. Correct typos, never reasoning.

If the helper cannot run in the current environment, do the same steps by hand following the
conventions above — read the directory to find the highest existing number, copy `template.md`, and
append the index line in the same format as the entries already there.
