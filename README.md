# Levian OS

**A Claude Code distribution that runs your software company.**

---

## Overview

Levian OS is the engine, and only the engine. This repository holds capabilities — MCP server
definitions, skills, agent templates, hooks, and slash commands — kept deliberately free of the
content they operate on. Nothing here knows who you are, what you sell, or which repositories you
ship. Personal and business content lives in a separate **private HQ repository**, installed at the
user level, which composes with this engine at load time. Durable memory — decisions, compiled
knowledge, working notes — lives in a third **private memory repository**. The split is what makes
the engine publishable: it can be open precisely because everything that would make it sensitive
lives somewhere else.

Four ideas hold the design together. **Progressive disclosure** — a context window is a budget, so
capabilities announce themselves in a line or two and load their full instructions only when a task
actually reaches for them. **Hooks as law** — conventions that matter are not written down and hoped
for, they are enforced by hooks that run whether or not the model remembered the rule. **One
orchestrator, narrow background roles** — a single agent holds the thread of the work and delegates
to specialists with tight briefs and small tool surfaces, instead of a committee of generalists all
trying to hold the same context. **A compiled knowledge wiki** — raw session output is not
knowledge; it gets compacted into durable, linked notes that later sessions load cheaply instead of
rediscovering the same ground.

**Status: pre-release, built in the open.** The structure is real, but the contents are still
landing. Directories may be stubs, interfaces will change without deprecation notices, and there is
no versioning or stability guarantee yet. Read it, take ideas from it, open an issue if something is
interesting — but don't build anything load-bearing on it at this stage.

## Install

Coming with the plugin packaging (Phase 5).

## Layout

| Directory          | Contents                                                          |
| ------------------ | ----------------------------------------------------------------- |
| `mcp/`             | MCP server definitions and connection configs                     |
| `skills/`          | Progressive-disclosure skills — procedural know-how, on demand     |
| `agent-templates/` | Reusable subagent role definitions                                |
| `hooks/`           | Lifecycle hooks — the enforcement layer                           |
| `commands/`        | Slash commands — named entry points to routine work               |
| `docs/`            | Architecture, runbook, and design notes                           |

Every directory carries a `README.md` explaining what belongs in it and what must never be committed
to it.

## Contributing setup

This repository is public and stays free of personal data, private project names, and credentials. A
tracked pre-commit hook enforces that. Enable it once per clone:

```sh
git config core.hooksPath .githooks
```

Then create your local marker list:

```sh
cp .personal-markers.example .personal-markers
```

Edit `.personal-markers` with the names, emails, domains, and project codenames that must never
appear in this repository. The file is gitignored — it never leaves your machine. The hook scans
staged content *and* file paths against it and refuses the commit on a match. It also blocks a small
set of well-known credential formats regardless of your marker list.

## License

[Apache-2.0](LICENSE) © Levian OS contributors.
