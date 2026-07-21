# `hooks/`

Lifecycle hooks — the enforcement layer.

Hooks are where conventions stop being advice. A rule written in a prompt is followed when the model
remembers it; a rule in a hook runs every time, on every session, whether or not anyone remembered.
Anything that must always hold — formatting, guardrails, required checks, audit trails — belongs
here rather than in an instruction file.

## What belongs here

- Hook scripts keyed to lifecycle events (tool pre/post, session start, prompt submit, stop).
- Matcher configuration deciding which tools or paths a hook applies to.
- Guards that block unsafe or off-convention actions, with a clear message about what to do instead.
- Formatters, linters, and validators wired to run automatically.

Keep hooks fast and quiet. They run constantly; a slow hook is felt on every call, and a chatty one
trains people to ignore its output.

## What must NEVER be here

- **Credentials.** No keys or tokens — hooks run in an environment that already has what it needs.
- **Personal data.** No real names or emails, including in log lines and blocked-action messages.
- **Private project or client names.** No hardcoded paths to private repos, no client-specific
  branches. Match on shape (file extension, directory role), not on identity.
- **Machine-specific absolute paths.** No `/Users/<someone>/...` — resolve from the repo root or the
  environment.

The pre-commit guard protecting this repository lives in [`../.githooks/`](../.githooks/) — it is a
git hook rather than a Claude Code hook, so it sits outside this directory.
