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
appear in this repository. The file is gitignored — it never leaves your machine.

**Set your commit identity repo-locally before your first commit.** The author line is written into
permanent public history exactly like file content is, and correcting it afterwards means rewriting
history for everyone who has cloned. A global identity carrying a personal address is inherited
silently by every new clone, so make it explicit here:

```sh
git config user.email <id>+<handle>@users.noreply.github.com
git config user.name  "<public attribution name>"
```

### What the guard checks

| Check                | Scope                                                                       |
| -------------------- | --------------------------------------------------------------------------- |
| **Commit identity**  | `user.email` and `user.name` against your marker list. Runs even for an empty commit. |
| **File paths**       | A path alone can carry a client or project name.                            |
| **File content**     | The *staged* blob, so `git add -p` cannot sneak content past it.             |
| **Credential shapes**| PEM private-key headers, AWS access key ids, GitHub tokens and PATs, Anthropic keys, Slack tokens, Google API keys. |
| **The marker list**  | `.personal-markers` itself can never be staged, even with `-f`.             |

If your public attribution name is itself a marker, list it verbatim under `[identity-allow]` in
`.personal-markers`. That exemption is scoped to the author line only — the string stays blocked in
file content and in paths.

### Known limits

- Markers are literal, case-insensitive **substrings**. No regex, no fuzzy matching: `Acme Corp`
  does not catch `AcmeCorp` or `acme-corp`. Prefer the shortest distinctive form.
- Only the credential shapes listed above are recognised. A secret in any other format — a database
  URL, a bare password, a bearer token — passes untouched.
- Binary files are skipped, so a marker inside an image, a PDF, or an archive is invisible.
- Only staged additions and modifications are read. Content already in history is never
  re-examined: the hook prevents a leak, it cannot undo one.
- The commit *message* is not scanned — it is not final when a pre-commit hook runs.
- `--no-verify` bypasses everything.

### Testing the guard

```sh
.githooks/test/run-tests.sh
```

The suite is built around **positive controls**: each protection is proven to fire by staging a real
violation and asserting a non-zero exit with zero commits created, plus that the failure came from
the check under test. This matters more than it sounds — the credential scan was once a silent
no-op, because its pattern begins with `-----BEGIN` and grep parsed that as a bundle of short flags,
scanning nothing and exiting clean. Only a test that stages an actual key catches that. Run the
suite after any change to the hook.

## License

[Apache-2.0](LICENSE) © Levian OS contributors.
