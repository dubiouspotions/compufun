# The story files: days, errands and what customers say

How the week is stored in story files, and how conversations are written in them. The design is on the
wiki page [Architecture](../wiki/Architecture.md) ("Content data"). Writers edit these files in the
Story Lab in the running game; agents and developers edit them as text.

## Where it lives

Everything that writers edit is plain text under `Godot/story/`. One thing is one file.

```
story/days/day_1.day ... day_7.day    each day's settings: weather, warp, flags, signs, notes
story/errands/0101_skater_bro.errand  one visit: who, which problem, the brief, the conversations
story/bible/storyline.md              prose that the game doesn't read: the lore, the end, the cast
story/bible/customers.md
```

- **The file name of an errand starts with its errand code.** `0101` is day 1, the first errand
  (morning); `0503` is day 5, the third (evening). The name after it is the customer. Two errands
  with the same code are alternatives: the first, by name, whose `when` matches comes (day 7
  evening). Moving an errand to another day or place renames its file.
- **Problems, customers, persons and computers stay resources** (`problems/*.tres`,
  `customers/*.tres`, `people/<name>/person.tres`). Their mechanics are code; the Story Lab shows
  their text.
- **Moods:** a line picks a mood, which picks the portrait (`Person.portraits`) and the voice
  (`voices/moods/<mood>.tres`). A person has the moods that it has portraits for. A mood without
  a voice mood file speaks as neutral, and the story check lists it.

## A day: `story/days/day_<n>.day`

```
weather: rain
warp: 0.15
on start: sign_pipedream
on close: sign_logo_blue
close signs: posters_bounce
first customer: 5-8
between customers: 20-40
notes:
	Early corruption signs start: small and flashy, never obvious.
```

Every key is optional. `weather` is `clear` (the default) or `rain`. `on start` sets flags as the
day starts; `on close` sets flags at closing that stay; `close signs` start at closing and stop the
next morning. Flags are `name` (1), `name=2`, or `name=0` (clears it). The waits are seconds, a
random time from the first to the second number. `notes` is for people only.

## An errand: `story/errands/<code>_<customer>.errand`

```
customer: skater_bro
problem: dust_overheat
computer: leaves
when: young_entrepreneur_deleted
brief:
	Meet the skater. His computer runs Cambion: the calculator answers 666 to every sum.
	Nothing points the player there; they find it by chance.

== drop-off
...
== pick-up
...
== phone
...
```

- `customer`, `problem`: file names without `.tres`. An errand without a problem is a visit
  that needs no repair.
- `computer`: `leaves` (the default: it stays on the counter), `none` (the customer comes without
  one and leaves when the conversation ends), or `shows` (it stands on the counter while they
  visit, and goes with them).
- `when`: a condition (below); without it the errand always comes.
- `brief`: what the visit is for, written before any line.
- **Conversations** start with `==` and the trigger: `drop-off` (the customer arrives),
  `pick-up` (they come back for the computer, on any later day) and `phone` (the player calls).
  A trigger can have several; the first whose condition matches plays. Without a match, a pick-up
  is a short thanks and a phone call a "Hello?". A `phone` without lines rings out: nobody
  answers.

## Conversations

One line per thing; a tab indents. Depth matters, not width.

```
== drop-off [once]
brief: He arrives cheerful; the problem comes out only when asked.
(neutral) Yo! What's up! Is this the computer repair shop?
- Welcome to CompuFun! You're in the right place! How can I help you?
	(happy) Sweet! Maybe you can help a buddy out!
	(neutral) My computer isn't working!
- Did your mom give it away?
	(angry) Whatever dude.. You don't have to be a douche about it.

- What seems to be the issue?
	(problem) When I start it, everything seems primo. Then Windows turns it off again!

+ When did it start?
	set skater_new_windows
	(thinking) Right after I got the new Windows.
+ Did you install anything?
	if skater_new_windows
		set skater_cambion
		(happy) Oh yeah. My buddy gave me this Windows 95 on floppies.
	else
		(neutral) Nah, nothing, man.
+ Cambion? [if skater_cambion]
	(happy) It's the rad one, dude.
- OK, leave it with me.
	(happy) Cool. Call me, dude.
```

- `(mood) text` is a customer line. Without a mood it is neutral. `[effect name]` at the end
  gives it its own voice effect (`voices/effects/<name>.tres`).
- `- text` and `+ text` are the player's choices. Choices in a row make one list; an empty
  line between two choices starts a new list.
  - After a `-` choice's lines, the conversation goes on **below the list**: two branches meet
    again there. Nothing below ends the conversation.
  - After a `+` choice's lines, **the same list** shows again; the choices already picked are grey.
  - A list without a `-` choice gets one more button that leaves it: `That's all, thanks.` at the
    top, `Something else...` deeper.
  - `[end]` ends the conversation after the choice's lines.
- Under a choice, indented: its lines, and deeper lists of choices.
- `if` and `else` at the start of a choice's lines give it alternative answers: the first that
  matches plays. A choice shows only while one of its answers can play.
- `set a, b=2, c=0` sets flags as its lines start.
- `brief:` right under `==` says what the conversation must get across.

**Conditions**, in `when:`, `if` and `[if ...]`: a comma list of `flag` (must be set),
`not flag` (must not be), `day 3` and `days 2-4`. A flag that is 0 or missing is not set.

**Tags** in `[...]` after a conversation's `==` line: `[if ...]`, `[once]` (plays only the first
time it matches), `[effect name]` (for all its lines), `[leave Text]` and `[back Text]` (the
leave buttons). After a choice: `[if ...]` and `[end]`.

## Flags and signs

Flags are the facts of the story: a name and a number. `sign_<id>` starts the corruption sign
`corruption/<id>.tscn`. `<customer>_runs_cambion` (the customer file name) makes that customer's computer run Win95 Cambion;
a day or a conversation sets it, and clearing it uninstalls Cambion.

## Read and check it

The files are the outline. The story check lists the missing links: a flag that nothing sets or
checks, a choice without a line, an errand without a `drop-off`, an errand code whose alternatives can
all fail, a mood that the person has no portrait for or no voice for:

```sh
"$GODOT" --headless -s res://dev/story.gd
```

The game refuses a file that doesn't parse, and names the file, the line and what it expected.

## Change it

Edit the text, then run the story check and the tests that cover the change
(`run.gd -- story`). Render the voices of new or changed lines, then import (see "Voices" in
[building-and-testing.md](building-and-testing.md)); `git rm` the files it lists as unused, and
commit the `.wav` and `.wav.import` files with the text.

A writer's change arrives as a GitHub issue with the label `story`: the Story Lab's **Send**. Its
body holds each changed file whole and its diff against the commit that the writer started from.
Apply it: where `main` changed the same lines since, merge by hand and say so on the issue. A new
rule of how the story plays is a design change: it goes on the wiki page first.
