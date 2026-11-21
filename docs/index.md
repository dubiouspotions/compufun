# Documentation index

Read the doc whose situation matches yours. Agents read this index at the start of every
session (Claude Code includes it through AGENTS.md); the docs themselves are not included, so
the "read it when…" column is what makes them reachable. Write each row as a *trigger* — a
situation the reader might be in — never as a summary.

| Doc | Read it when… |
| --- | --- |
| [code-standard.md](code-standard.md) | **Binding.** You write or review GDScript, or create a scene or resource type. |
| [architecture.md](architecture.md) | You add structure: a new scene tree, autoload or folder, or you need to know where state lives. |
| [building-and-testing.md](building-and-testing.md) | You need the import, export or CI commands, CI failed, or something passed that should have failed. |
| [glossary.md](glossary.md) | You name a concept in code, docs or an issue, or meet a word you're not sure is the project's. |
| [gotchas.md](gotchas.md) | Godot or the web build behaves weirdly. Also where a new non-obvious fact goes when it doesn't fit anywhere else. |

When you learn something deep that isn't easily rediscovered from the code, fold it into the
matching doc — or start a new one — and add its row here. **The docs are the project's memory;**
an unindexed doc is a doc nobody reads.

Mark a doc **binding** in its row when it encodes rules that must be read *before* touching an
area, and add the matching line to the "Required reading by area" table in AGENTS.md. Those
earn their weight from real incidents — don't promote a doc to binding just because it's good.
