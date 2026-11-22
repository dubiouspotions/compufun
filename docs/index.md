# Documentation index

Read the doc whose situation matches yours. Agents read this index at the start of every
session (Claude Code includes it through AGENTS.md); the docs themselves are not included, so
the "read it when…" column is what makes them reachable. Write each row as a *trigger* — a
situation the reader might be in — never as a summary.

| Doc | Read it when… |
| --- | --- |
| [code-standard.md](code-standard.md) | **Binding.** You write or review GDScript, or create a scene or resource type. |
| [wiki/Architecture.md](../wiki/Architecture.md) | You add a resource type or change how the parts work together, or you need to know where state lives. It is the wiki page; `tools/sync-wiki.sh` fetches it. |
| [architecture.md](architecture.md) | You add, move or remove a folder, a scene in the main tree or an autoload, or you touch a load-bearing setting. |
| [building-and-testing.md](building-and-testing.md) | You need the import, test, export or CI commands, want to add a test or film a change, want to know whether the whole week still plays to the end, add a public Game method, an enum value or a `SoftwareCheck` type (teach the week bot), CI failed, something passed that should have failed, a customer line is silent, or you want the story's missing links or an errand's file. |
| [dialogue.md](dialogue.md) | You read or change a story file: what a customer says, who comes on which day, a day's weather or signs, or a story flag; you apply a writer's `story` issue, or fill a missing link of the week. |
| [glossary.md](glossary.md) | You name a concept in code, docs or an issue, or meet a word you're not sure is the project's. |
| [working-together.md](working-together.md) | You set up a machine, add or rename a file, add a new kind of binary file, or meet a merge conflict. |
| [crt.md](crt.md) | You tune or change the CRT look of the Screen View, or a click on the desktop lands in the wrong place. |
| [win95-icons.md](win95-icons.md) | You need a Windows 95 icon for the desktop, a window or a dialog, or want to re-extract them from a Win95 install. |
| [gotchas.md](gotchas.md) | Godot or the web build behaves weirdly. Also where a new non-obvious fact goes when it doesn't fit anywhere else. |

When you learn something deep that isn't easily rediscovered from the code, fold it into the
matching doc — or start a new one — and add its row here. **The docs are the project's memory;**
an unindexed doc is a doc nobody reads.

Mark a doc **binding** in its row when it encodes rules that must be read *before* touching an
area, and add the matching line to the "Required reading by area" table in AGENTS.md. Those
earn their weight from real incidents — don't promote a doc to binding just because it's good.
