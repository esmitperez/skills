# AGENTS.md

Guidance for AI coding agents working in this repository.

## What this repo is

A personal collection of agent **skills**, organized by category at the repo root (following the [`mattpocock/skills`](https://github.com/mattpocock/skills) layout). Skills are harness-agnostic — they work with any agent runtime that loads `SKILL.md` files (Claude Code, `pi`, etc.). Skills are *not* under any harness-specific path (`.claude/skills/`, `.pi/skills/`, ...) here — that's intentional. This repo is a source library; users copy individual skills into whichever skills location their harness expects.

See [`README.md`](README.md) for the user-facing description.

## Layout

```
<category>/              e.g. costarica/
  <skill-name>/          e.g. cr-snit-dta/
    SKILL.md             frontmatter (name, description) + agent instructions
    <driver files>       scripts/tools the skill invokes
```

Each skill directory is **self-contained**. Drivers must resolve their own paths (e.g. via `BASH_SOURCE`) so the skill works whether it's run in place, copied into a global skills directory, or dropped into a project-local skills directory.

## Conventions

- **One skill per directory.** Don't bundle multiple skills together.
- **`SKILL.md` is the entry point.** Keep it concise and action-oriented — it's loaded into the agent's context.
- **Frontmatter `name:`** must match the directory name; it becomes the slash command.
- **Frontmatter `description:`** should clearly state *when* to use the skill (harnesses use this to decide whether to load it).
- **Drivers stay local.** Don't reach outside the skill's own directory for code. External deps (CLIs, packages) should be documented in `SKILL.md`.
- **No secrets, no credentials, no scraped personal data** committed to the repo.
- **Keep skills small and composable.** If a skill grows large, consider splitting it.
- **Stay harness-agnostic.** Don't reference Claude Code, `pi`, or any specific runtime inside `SKILL.md` or driver scripts. Skills should describe *what* they do and *when* to use them, not which agent is invoking them.

## Adding a new skill

1. Pick or create a category folder at the repo root.
2. Create `<category>/<skill-name>/SKILL.md` with frontmatter:
   ```yaml
   ---
   name: <skill-name>
   description: <when to use this skill>
   ---
   ```
3. Add driver scripts alongside `SKILL.md`. Make them executable and path-independent.
4. Add a row for the skill to the category's table in `README.md`.
5. Test by copying the skill into your harness's skills directory (or a test project) and invoking it.

## Editing existing skills

- Preserve the `name:` in frontmatter unless you also rename the directory (and update `README.md`).
- When changing driver behavior, update `SKILL.md` so the agent-facing instructions stay accurate.
- Prefer small, focused commits per skill.

## Things not to do

- Don't add a top-level harness-specific skills directory (`.claude/skills/`, `.pi/skills/`, ...) — that's not how this repo is organized.
- Don't mention specific agent harnesses (Claude, `pi`, etc.) inside skill content. The only exception is `CLAUDE.md` at the repo root, which exists solely to redirect Claude to `AGENTS.md`.
- Don't add build tooling, package managers, or CI unless a specific skill needs it (and then scope it to that skill's directory).
- Don't hardcode absolute paths in drivers.
