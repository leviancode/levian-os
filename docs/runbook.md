# Levian OS Runbook

How the system is put together and how to operate it.

> Pre-release. Sections land as the corresponding machinery does; §1 describes the layout everything
> else assumes.

---

## 1. Topology

Levian OS is not one repository. It is an engine plus three layers of content, kept apart on purpose.
The separation is the load-bearing design decision: it is what lets the engine be public, what keeps
authored policy from being buried under accumulated notes, and what stops a mistake in one layer from
exposing the others.

### 1.1 The four layers

```
┌───────────────────────────────────────────────────────────┐
│  ENGINE  ·  public                                        │
│  mcp/ · skills/ · agent-templates/ · hooks/ · commands/   │
│  Capabilities. Knows how, never what about.               │
└───────────────────────────────────────────────────────────┘
                          ▲  installed as a distribution
┌───────────────────────────────────────────────────────────┐
│  HQ  ·  private  ·  installed at user level (~/.claude)   │
│  Identity · standards · policy · roles · priorities       │
│  Authored, deliberate, low churn. Applies everywhere.     │
└───────────────────────────────────────────────────────────┘
                          ▲  read at session start
┌───────────────────────────────────────────────────────────┐
│  MEMORY  ·  private  ·  separate repository               │
│  Decisions · compiled wiki · durable notes                │
│  Accrued, high churn. Informs; does not govern.           │
└───────────────────────────────────────────────────────────┘
                          ▲  loaded on relevance
┌───────────────────────────────────────────────────────────┐
│  PROJECT  ·  per-repository .claude/                      │
│  Build · test · architecture · local convention           │
│  Travels with the codebase. Shared with its team.         │
└───────────────────────────────────────────────────────────┘
```

### 1.2 Engine — public

This repository. It carries capabilities and nothing else: MCP server definitions, skills, agent
templates, hooks, and slash commands. Every artifact is written to be useful to someone who has never
met the author — a skill describes a procedure, an agent template describes a role, a hook enforces a
shape. What any of them gets *pointed at* is always supplied from outside.

The engine is versioned and released. It is the only layer with an audience of strangers, and the
only layer where a change needs to consider backward compatibility.

### 1.3 HQ — private, user level

The operator's own context, installed at the user level so it applies to every session on the machine
regardless of which directory the session starts in. This is where identity, company standards,
working agreements, escalation rules, the register of active engagements, and current priorities
live. It is what turns a generic engine into a specific operation.

HQ is **authored**. Entries are written deliberately, edited when policy actually changes, and stay
small enough to read in one sitting. It is a constitution, not a logbook — churn here should be low,
and a growing HQ usually means something belongs in memory or the project layer instead.

### 1.4 Memory — private, separate repository

Durable state that accumulates across sessions: decisions and their reasoning, the compiled knowledge
wiki, per-topic notes that later sessions load instead of rediscovering the same ground.

Memory is **accrued**, and that is precisely why it is a separate repository from HQ. The two have
opposite write patterns — HQ is edited rarely and reviewed carefully, memory is appended constantly
and pruned in passes. Mixing them buries the twenty lines that govern behaviour under a thousand
lines that merely record it. Memory also carries a different obligation: it must be compacted. Raw
session transcripts are not knowledge until something distills them into linked notes worth loading.

Memory **informs**; it does not govern. When a note and a policy disagree, the policy wins and the
note is stale.

### 1.5 Project layer

A `.claude/` directory inside each individual codebase, committed to that codebase's own repository.
It holds what is true about that project and nowhere else: how to build it, how to run its tests,
what its architecture assumes, which conventions its reviewers enforce.

This layer is the only one shared with a project's collaborators, so it is written for a teammate
rather than for the operator — and it must never assume the private layers are present. A project's
`.claude/` should still make sense to a contributor running a stock toolchain.

### 1.6 How the layers compose

At session start the engine supplies mechanism, HQ overlays operator context, memory is consulted for
relevance, and the project layer contributes codebase specifics. On conflict, the more specific layer
wins:

```
project  >  HQ  >  engine
```

Memory sits outside that precedence chain by design — it is evidence, not authority. A project's
build command overrides a general convention; a company standard overrides an engine default; a
remembered observation overrides nothing.

Progressive disclosure applies across all four. Each layer advertises itself cheaply and loads its
substance only when a task reaches for it, so the resting cost of having four layers stays close to
the cost of having one.

### 1.7 Where does this belong?

A single question resolves most placement decisions:

| Ask                                                         | It belongs in |
| ----------------------------------------------------------- | ------------- |
| Would this still be true and useful for someone else's company? | **Engine**    |
| Is it true about *my* operation, across all projects?           | **HQ**        |
| Was it *learned* rather than *decided*?                         | **Memory**    |
| Is it true only inside this one codebase?                       | **Project**   |

Two failure modes are worth naming because both are easy and both are quiet. Content drifting *up*
into the engine is a disclosure bug: a client name in an example, a private hostname in a sample
command, a real address in test data. The pre-commit guard exists to catch exactly this, and it is a
backstop, not a substitute for the question above. Content drifting *down* — a genuinely reusable
procedure trapped in one project's `.claude/`, or a general standard restated in six places — is a
leverage bug, cheaper to fix but the reason most of this system exists.

### 1.8 Operational consequences

- **Cloning the engine alone gets you a working, empty system.** That is the intended behaviour and
  the test that the split is honest. If the engine stops functioning without the private layers,
  something has leaked in the form of a dependency.
- **Each layer is backed up and rotated independently.** A compromised layer exposes only itself.
- **Only the engine takes external contributions.** The other three have an audience of one, or of
  one team.
- **Publishing is a one-way door.** The guard in `.githooks/` refuses commits that carry personal
  data, private project names, or credentials into this repository — but git history is public and
  permanent, so the guard is calibrated to fail loudly and early rather than to be convenient.
