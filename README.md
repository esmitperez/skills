# skills

My agent skills — small, composable, easy to adapt. Harness-agnostic: works with any agent runtime that supports the [skill format](https://github.com/mattpocock/skills) (Claude Code, `pi`, and other agent harnesses that load `SKILL.md` files).

This repo follows the layout philosophy of [`mattpocock/skills`](https://github.com/mattpocock/skills): skills live at the repo root grouped into **category folders**, not under any harness-specific path (`.claude/skills/`, `.pi/skills/`, etc.). Each skill is a self-contained directory you can copy into whichever project (or global skills location) needs it.

> *"These skills are designed to be small, easy to adapt, and composable. They work with any model. Hack around with them. Make them your own."* — Matt Pocock

## Layout

```
<category>/
  <skill-name>/
    SKILL.md         — frontmatter + agent-facing instructions
    <driver files>   — scripts the skill calls
```

## Categories

### [`costarica/`](costarica/)

Skills for navigating Costa Rica's bureaucracy, government websites, and other local quirks (e.g. SNIT, the official Gaceta, IMAS forms, registro civil).

| Skill | What it does |
|---|---|
| [`cr-snit-dta`](costarica/cr-snit-dta/) | Fetch the latest *División Territorial Administrativa* PDF from SNIT, convert to text, and parse cantones + distritos into CSVs. |

## Using my skills

[![skills.sh](https://skills.sh/b/esmitperez/skills)](https://skills.sh/esmitperez/skills)

Quickstart:

**Use the [skills.sh](https://skills.sh) installer** (30-second setup):
```shell
npx skills@latest add esmitperez/skills
```


Other methods:
- **Install globally** — copy the skill folder into your agent's global skills directory (e.g. `~/.claude/skills/<skill-name>/`, `~/.config/pi/skills/<skill-name>/`, etc.) and your agent will auto-load it across all projects.
- **Install per-project** — copy into the project-local equivalent (e.g. `<project>/.claude/skills/<skill-name>/`).
- **Run in place** — `cd` into the skill directory and follow its `SKILL.md`. The drivers self-resolve their paths via `BASH_SOURCE`, so they work from wherever you put them.

The category folders (`costarica/`, etc.) are organizational — most harnesses don't auto-discover skills from this repo's layout. Copy what you want to your harness's skills location and the `name:` in each skill's frontmatter becomes the invocation handle (e.g. `/cr-snit-dta`).
