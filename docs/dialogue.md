# The story files: days, errands, problems and what customers say

How the week is stored in story files, and how conversations are written in them. The design is on the
wiki page [Architecture](../wiki/Architecture.md) ("Content data"). Writers edit these files in the
Story Lab in the running game; agents and developers edit them as text.

## Where it lives

Everything that writers edit is plain text under `Godot/story/`. One thing is one file.

```
story/days/day_1.day ... day_7.day    each day's settings: weather, warp, flags, signs, notes
story/errands/0101_skater_bro.errand  one visit: who, which problem, the brief, the conversations
story/problems/dust_overheat.problem  one computer problem's text: the post-it, symptoms, steps, notes
story/bible/storyline.md              prose that the game doesn't read: the lore, the end, the cast
story/bible/customers.md
```

- **The file name of an errand starts with its errand code.** `0101` is day 1, the first errand
  (morning); `0503` is day 5, the third (evening). The name after it is the customer. Two errands
  with the same code are alternatives: the first, by name, whose `when` matches comes (day 7
  evening). Moving an errand to another day or place renames its file.
- **Customers, persons and computers stay resources** (`customers/*.tres`,
  `people/<name>/person.tres`). Their mechanics are code; the Story Lab shows their text. A
  problem's mechanics stay in `problems/<id>.tres`, and its text is in its problem file.
- **Moods:** a line picks a mood, which picks the portrait (`Person.portraits`) and the voice
  (`voices/moods/<mood>.tres`), unless the line has its own voice mood (`[voice mood]`). A person
  has the moods that it has portraits for. A voice mood without a file speaks as neutral, and the
  story check lists it.

## A day: `story/days/day_<n>.day`

```
weather: rain
warp: 0.15
on start: sign_pipedream
on close: sign_logo_blue
close signs: posters_bounce
first customer: 5-8
between customers: 20-40
empty counter wait: 4
notes:
	Early corruption signs start: small and flashy, never obvious.
```

Every key is optional. `weather` is `clear` (the default) or `rain`. `on start` sets flags as the
day starts; `on close` sets flags at closing that stay; `close signs` start at closing and stop the
next morning. Flags are `name` (1), `name=2`, or `name=0` (clears it). The waits are seconds, a
random time from the first to the second number; `empty counter wait` caps the wait for the next
customer while the counter is empty. `notes` is for people only.

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

- `customer`, `problem`: file names without `.tres` or `.problem`. An errand without a problem is
  a visit that needs no repair.
- `computer`: `leaves` (the default: it stays on the counter), `none` (the customer comes without
  one and leaves when the conversation ends), or `shows` (it stands on the counter while they
  visit, and goes with them).
- `comes`: `after opening` (the default) or `before opening`: the customer is already at the
  counter, talking, when the day starts, and the player can open the shop once they are out the
  door. Only the day's first errand (place 01) can come before opening.
- `when`: a condition (below); without it the errand always comes.
- `brief`: what the visit is for, written before any line.
- **Conversations** start with `==` and the trigger: `drop-off` (the customer arrives),
  `pick-up` (they come back for the computer, on any later day) and `phone` (the player calls).
  A trigger can have several; the first whose condition matches plays. Without a match, a pick-up
  is a short thanks and a phone call a "Hello?". A `phone` without lines rings out: nobody
  answers.

## A problem: `story/problems/<id>.problem`

```
post-it: Windows starts and turns off
symptoms:
	Hangs and reboots at startup
		shows: a second into the Windows startup sound, the computer stops answering...
		category: At startup
	Customer mentions increased heat
		shows: at drop-off, the customer says that the computer was a little hot when he unplugged it
		category: From the customer
hardware steps:
	Remove the computer shell
	Remove the fan, throw it in the trash
software steps:
	Unmute
notes:
	Free text for people: the story behind it, open questions.
```

The file name is the problem's id, the name of its `problems/<id>.tres`, which holds the mechanics
(where it is, the broken part, the check that fixes it). Every key but `post-it` is optional.

- `post-it`: what the customer says is wrong; the post-it shows it.
- `symptoms`: one per line, as CompuFunDB finds and lists them. The player searches them by their words, so
  a symptom says what the player sees. Changing one changes what the player marks. `shows:` under a symptom says how it shows in the game, for people.
- `hardware steps`, `software steps`: one per line, as CompuFunDB prints them.
- `notes`: for people; the game doesn't read them.

A problem file without a `.tres` is a problem that a writer named before a developer built it: an
errand can name it, and the story check lists it as a problem without mechanics.

A problem that is corruption, as `organ_failure` and `no_parts` are, sets `in_compufun_db = false`
in its `.tres`: CompuFunDB finds nothing for its symptoms, which still need their categories. With
`empty_case = true`, as `no_parts` has, the computer comes with every place empty and runs anyway;
taking the side panel off and putting it back on with its screws in is the repair, and the case
stays empty.

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
  gives it its own voice effect (`voices/effects/<name>.tres`). `[voice mood]` speaks it in another
  voice mood than its portrait's (`voices/moods/<mood>.tres`), for a portrait used outside its own
  mood. `[leaving]` makes it a call-out:
  the customer says it while walking out, outside the dialogue box, as at the end of a visit.
  Leaving lines come last: the box closes before them. A leaving line that the conversation can go
  on after plays in the box, and the story check lists it.
- `[look left]`, `[look right]` and `[look ahead]` turn the player's view before the line is said:
  to the Left View (the storage side), the Right View (the work computer) or the Main View (the
  counter, facing the customer). A look names the view, not a turn, so a look that brings the
  player back to the customer is always `[look ahead]`. While a look has turned the player away
  from the customer, the conversation goes on in the call-out box, which points at the customer:
  each line goes on once its voice ended and the player had time to read it, or on a click. The
  choices turn the player back to answer; so does facing the customer on their own, and the line
  goes on in the dialogue box. Turning away on their own hushes the line until they face the
  customer again. A look works only before a line in the dialogue box: the story check lists one
  on a `[leaving]` line or on the phone, and a look that is not left, right or ahead.
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

The wiki page "The Week" shows the whole week for people who don't run the game: each day, its
errands with their briefs, problems, missing links and conversations. CI rebuilds it from these
files on every push; nobody edits it.

The files are the outline. The story check lists the missing links: a flag that nothing sets or
checks, a `+` choice without a line, an errand without a `drop-off`, an errand code whose alternatives can
all fail, a mood that the person has no portrait for, a voice mood that a line speaks in and that has no voice, a `[leaving]` line that the
conversation can go on after, a look that is unknown or never turns the view, a problem without repair mechanics, a problem file that no errand
names:

```sh
"$GODOT" --headless -s res://dev/story.gd
```

The game refuses a file that doesn't parse, and names the file, the line and what it expected.

## Change it

Edit the text, then run the story check and the tests that cover the change
(`run.gd -- story`). Render the voices of new or changed lines, then import (see "Voices" in
[building-and-testing.md](building-and-testing.md)); `git rm` the files it lists as unused, and
commit the `.wav` and `.wav.import` files with the text.

A writer's change arrives as a GitHub issue with the labels `story` and `feedback`: the Story Lab's **Send**. The issue builder builds every `feedback` issue; a note that starts with `[test]` adds `test`, and the builder leaves those. Its
body holds each changed file whole and its diff against the commit that the writer started from.
Apply it: where `main` changed the same lines since, merge by hand and say so on the issue. A new
rule of how the story plays is a design change: it goes on the wiki page first.
