# `mcp/`

MCP server definitions — the engine's connections to the outside world.

## What belongs here

- Server manifests: command, args, transport, and the environment variable *names* a server expects.
- Thin wrapper scripts that launch a server with sane defaults.
- Per-server notes: which tools it exposes, what it costs, when an agent should reach for it.
- Sensible tool-permission defaults, so a server arrives pre-scoped rather than wide open.

## What must NEVER be here

- **Credentials.** No API keys, tokens, OAuth secrets, connection strings, or `.env` files. Reference
  secrets by variable name only (`GITHUB_TOKEN`), never by value.
- **Personal data.** No real names, emails, phone numbers, or account handles.
- **Private project or client identifiers.** No org names, workspace IDs, project IDs, internal
  hostnames, private repo URLs, or ticket-key prefixes.
- **Tenant-specific endpoints.** Point at the public service; the private HQ repo supplies the
  account-specific host, region, or workspace.

A server definition here should be usable by a stranger who fills in their own environment.
