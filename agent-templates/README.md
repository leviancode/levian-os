# `agent-templates/`

Subagent role definitions — the narrow background roles the orchestrator delegates to.

Each template defines one role: its system prompt, its tool allowlist, its model and effort defaults,
and the shape of the result it returns. Roles are deliberately narrow. A role with a tight brief and
a small tool surface outperforms a generalist given the same context, and it fails in ways that are
easier to see.

## What belongs here

- Role definitions: reviewer, researcher, implementer, verifier, and similar.
- The tool allowlist each role is trusted with, kept as small as the job allows.
- Output contracts — the schema or format a role must return, so callers can rely on it.
- Delegation notes: what to put in the brief, and what the role should hand back.

## What must NEVER be here

- **Personal data.** No real names or emails in prompts, examples, or persona descriptions.
- **Private project or client names.** A role is defined by its function, never by the account it
  happens to serve. No client-specific reviewers here.
- **Credentials.** No keys or tokens in prompts or environment blocks.
- **Business context.** Company policy, standards, priorities, and house style belong in the private
  HQ repo; templates here read that context at runtime rather than baking it in.

A template defines a *capability*. The private HQ layer decides what that capability is aimed at.
