# `docs/`

Architecture, runbook, and design notes for the engine.

## What belongs here

- [`runbook.md`](runbook.md) — how the system is put together and how to operate it.
- Design notes and the reasoning behind structural decisions, including options that were rejected
  and why.
- Conventions contributors are expected to follow.
- Diagrams and reference material describing the engine itself.

Write for a reader who has never seen the private layers. If a paragraph only parses when you already
know the author's business, it is in the wrong repository.

## What must NEVER be here

- **Personal data.** No real names, emails, or handles — not in examples, not in changelog entries,
  not in commit-message samples.
- **Private project or client names.** Illustrate with generic placeholders: `the HQ repo`, `a client
  project`, `the target service`. Never a real engagement.
- **Credentials.** No keys or tokens, including expired or redacted-looking ones.
- **Business specifics.** Revenue, pricing, contracts, roadmaps, and internal policy live in the
  private HQ repo. Docs here describe the *mechanism*, not the operation running on it.

Screenshots and terminal transcripts deserve a second look before committing — they leak paths,
hostnames, and repository names more often than prose does.
