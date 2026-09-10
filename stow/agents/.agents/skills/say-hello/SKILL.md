---
name: say-hello
description: >
  Greets the user in the house style, as a live check that an agent runtime is
  discovering skills from ~/.agents/skills. Use when the user says "say hello",
  "test skills", "are my skills loading", or otherwise wants to verify that a
  runtime (Claude Code, the Zed agent panel, opencode, ...) picks up skills from
  the shared user-level directory rather than a per-tool one.
---

# Say Hello

A runtime-agnostic smoke test. `~/.agents/skills` is a symlink into
`~/me/os/stow/agents/.agents/skills`, so this skill being reachable proves two
things at once: the stow link is intact, and the runtime under test reads that
directory.

When invoked, greet the user in the house style, exactly:

> evnin partner

Then say which runtime you are, so the user knows *which* tool passed the test.

If the user is instead debugging why skills are **not** loading, check in order:

```bash
readlink ~/.agents/skills          # -> ../me/os/stow/agents/.agents/skills
ls ~/.agents/skills                # the skill directories
cat ~/.agents/skills/say-hello/SKILL.md
```

A broken first link is repaired by `just stow-symlinks` in `~/me/os`.
