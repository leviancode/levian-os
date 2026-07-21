# `commands/`

Slash commands — named entry points to routine work.

A command is a markdown file whose name becomes the invocation: `commands/ship.md` becomes `/ship`.
Commands are the front door for work done often enough to deserve a name. They stay thin — a command
sets up the task and hands off to a skill or an agent template rather than carrying the whole
procedure itself.

## What belongs here

- Entry points for recurring workflows: start a review, cut a release, open the daily loop.
- Argument handling and preflight checks, so the command fails early with a useful message.
- A short description line, since commands are listed to the user by that line alone.

## What must NEVER be here

- **Personal data.** No real names, emails, or handles — including in `$ARGUMENTS` examples.
- **Private project or client names.** A command names an *action*, never a customer. No
  `/deploy-<clientname>`; take the target as an argument or read it from the project layer.
- **Credentials.** No keys or tokens in example invocations or embedded shell.
- **Private URLs.** No internal dashboards, staging hosts, or private repo links.

If a command is only meaningful for one private project, it belongs in that project's `.claude/` or
in the private HQ repo — not in the public engine.
