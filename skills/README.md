# `skills/`

Skills — procedural know-how, loaded on demand.

A skill is a folder with a `SKILL.md`: frontmatter carrying a `name` and a sharp one-line
`description`, and a body holding the actual procedure. The description is the only part that sits in
context all the time, so it earns its place by making the load/skip decision obvious. Everything
expensive — long checklists, reference tables, scripts — goes in the body or in sibling files the
skill points to.

## What belongs here

- Repeatable procedures worth doing the same way twice: release steps, review passes, research
  harnesses, document production.
- Reference material a procedure needs, split into files the skill loads only when it gets that far.
- Helper scripts a skill shells out to.

## What must NEVER be here

- **Personal data.** No real names, emails, or handles — not in examples, not in sample output.
- **Private project or client names.** Write `the target repository`, `the client`, `the deploy
  target`. If a skill only makes sense for one specific private project, it belongs in the private HQ
  repo, not here.
- **Credentials.** No keys or tokens, including in example commands and sample transcripts.
- **Internal URLs and paths.** No private dashboards, staging hosts, or `/Users/<someone>/...`
  absolute paths.

A skill here describes *how* to do something. *What* it gets pointed at is supplied by the HQ or
project layer at runtime.
