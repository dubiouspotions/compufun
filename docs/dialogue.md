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
story/callouts/everyone.callouts      what every customer calls out while they wait
story/callouts/skater_bro.callouts    what one customer calls out instead, by day, daypart or flags
story/computers/office_girl.setup     a customer's computer at the start of the game (SetupPatch)
story/computers/0301_office_girl.setup  what they did on it before that errand's visit
story/symptoms.keywords               the words that also find each symptom in CompuFunDB's search
story/bible/storyline.md              prose that the game doesn't read: the lore, the end, the cast
story/bible/customers.md
```

- **The file name of an errand starts with its errand code.** `0101` is day 1, the first errand;
  `0503` is day 5, the third. The name after it is the customer. Two errands
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
daypart: midday
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
  a visit that needs no repair. A computer left without one is never called about: from the
  evening its post-it says "Failed to pickup" (as `0603_activist_guy`'s does).
- `computer`: `leaves` (the default: it stays on the counter), `none` (the customer comes without
  one and leaves when the conversation ends), or `shows` (it stands on the counter while they
  visit, and goes with them).
- `comes`: `after opening` (the default) or `before opening`: the customer is already at the
  counter, talking, when the day starts, and the player can open the shop once they are out the
  door. Only the day's first errand (place 01) can come before opening.
- `daypart`: `morning` (the default), `midday` or `afternoon`. When the day's first errand of a
  later daypart comes in, the day turns to it; a second errand of the same daypart doesn't move the
  clock. A day needs at least one errand in each daypart, in order, and alternatives share one: the
  story check lists a day without one, alternatives that differ, and an errand that comes after a
  later daypart's. The week board's bands show it, and a card dropped in a band takes its daypart.
- `when`: a condition (below); without it the errand always comes.
- `brief`: what the visit is for, written before any line.
- **Conversations** start with `==` and the trigger: `drop-off` (the customer arrives),
  `pick-up` (they come back for the computer, on any later day), `phone` (the player calls) and
  `event` (they pop up behind the counter; below). A trigger can have several; the first whose condition matches plays. Without a match, a pick-up
  is a short thanks (`customers/conversations/thanks.tres`) and a phone call a "Hello?"
  (`customers/conversations/hello.tres`). The phone says every line through a telephone
  (`voices/effects/telephone.tres`), over the line's own voice effect. A `phone` without lines rings out: nobody
  answers, nobody comes, and the computer stays on the counter (as `0701_skater_bro`'s does once
  `skater_organs_replaced` is set). The phone calls the customers who answer first, and never calls about a computer again once its call rang out. A drop-off without lines sets its flags and says nothing, so a customer without a
  computer leaves at once.

### Events: `== event`

```
== event [if day 5] [daypart midday] [pop-up (happy) Hey!]
(happy) Yo! Is my computer done yet?
- Not yet. I'll call you when it's ready.
	(neutral) Aw, man. Okay, okay.
(neutral) Later, dude! [leaving]
```

An event is a visit that the customer doesn't walk in for: they pop up from behind the counter,
the view shakes, they call out the `[pop-up ...]` line (a `(mood)` is optional), step to the
counter, and the player turns to face them for the conversation. Then they walk out. While they pop
up, their 3D body shows the portrait of the pop-up line's mood, and the usual one from the step on.

- It can come from the drop-off until the player has finished the errand's computer (fixed and
  tested), on that day or a later one: while that computer is on the counter and not done, nobody
  is in the shop and the phone is on the hook. `[if ...]` and `[daypart ...]` narrow it to a day and
  a daypart.
- It comes only while the player is zoomed in on a computer in the Workview, and the customer
  peeks over the counter there. The next customer doesn't wait for it: when its day or daypart
  passes while the player is not in the Workview, it doesn't come.
- It plays once, and it is not an arrival: it doesn't change the daypart.

## A problem: `story/problems/<id>.problem`

```
post-it: Windows starts and turns off
cause: Clogged CPU fan
symptoms:
	Restarts by itself
	Slow computer
checks:
	yes: Dust in the CPU fan
		shows: in the Workview
	no: CPU fan is clean and spins freely
hardware steps:
	Open case
	Trash the CPU fan
software steps:
	Unmute
notes:
	Free text for people: the story behind it, open questions.
```

The file name is the problem's id, the name of its `problems/<id>.tres`, which holds the mechanics
(where it is, the broken part, the check that fixes it). Every key but `post-it` is optional.

- `post-it`: what the customer says is wrong; the post-it shows it.
- `cause`: what CompuFunDB calls the cause, as a service manual would, such as `Clogged CPU fan`:
  its POSSIBLE CAUSES column and the fix it prints. Without one, CompuFunDB names it by the file name.
- `symptoms`: one per line: every complaint this cause can bring, as a customer would put it, worded
  as other problems word the same complaint ("Slow computer"), so a search offers every likely
  cause. The player searches CompuFunDB for their words and their keywords
  (`story/symptoms.keywords`). Nothing goes under a symptom.
- `checks`: one per line, `yes:` (true when this is the cause) or `no:` (false). The player ticks
  what is true. A ticked check rules out every cause that says `no:` to it, so a cause says `no:`
  only to a check that it makes false. `shows:` is how it fails in the game.
- `hardware steps`, `software steps`: one per line, as CompuFunDB prints them on the cause's fix
  page, which already names the cause.
- `notes`: for people; the game doesn't read them.

A problem file without a `.tres` is a problem that a writer named before a developer built it: an
errand can name it, and the story check lists it as a problem without mechanics.

A problem that is corruption, as `organ_failure` and `no_parts` are, sets `in_compufun_db = false`
in its `.tres`: CompuFunDB finds nothing for its symptoms. With
`empty_case = true`, as `no_parts` has, the computer comes with every place empty and runs anyway;
taking the side panel off and putting it back on with its screws in is the repair, and the case
stays empty.

## Symptom keywords: `story/symptoms.keywords`

CompuFunDB's search finds a symptom when its name and its keywords together hold every word that
the player typed. One line per symptom, the symptom exactly as the problem files spell it:

```
Computer runs hot: heat, warm, overheating, temperature, fan
No sound: audio, speaker, silent, mute, volume, quiet
```

A symptom without a line is found by its name alone. A line for a symptom that no problem lists is
in the story check. In the Story Lab, a problem's symptoms have their keywords beside them; an edit
there changes this file, so every problem with that symptom gets it.

## Call-outs: `story/callouts/<customer>.callouts`

What a customer calls out while they wait at the counter and the player looks elsewhere, in the
call-out box. `everyone.callouts` is what every customer says; a file named for a customer
(`customers/<customer>.tres`) gives them their own. The Story Lab edits them in Call-outs.

```
== waiting [if day 7] [effect cambion_glitch]
(irritated03) I am still here. I am always here.

== waiting [daypart afternoon]
(neutral) Getting late, man.

== waiting
brief: The skater gets bored fast.
(neutral) Yo?
(thinking) Dude?
(irritated01) Hellooo?
```

- A file holds sets: each starts with `== waiting`, then `(mood) text` lines, without choices,
  `set`, `if`, `[leaving]` or `[look]`. A line can have `[effect name]` and `[voice mood]`.
- Tags after `== waiting`: `[if ...]` (a condition, below), `[daypart morning]`, `midday` or
  `afternoon` (the daypart as the customer waits, as the week board's bands show it), and
  `[effect name]` for all its lines.
- **Which set plays:** the first set whose `if` and `daypart` both match; else the set without
  either, the customer's fallback. A file has at most one such set. When none of the customer's
  sets plays, or they have no file, everyone's file decides the same way; it must have a set
  without `if` and `daypart`.
- The customer says two random lines of a mood, then the next mood's, in the order in which
  each mood first appears in the set: put the calmest first. After the last mood they go round
  the moods from the fourth on, or stay in the last in a set with fewer than five.

## Setup patches: `story/computers/<customer>.setup`, `<code>_<customer>.setup`

What a customer did on their computer (wiki: "Lived-in computers"). `<customer>.setup` goes on the
setup of `customers/<customer>.tres` as the game makes its running copy; `<code>_<customer>.setup`,
named like its errand, goes on as that visit's job starts, before the problem's break. Moving the
errand on the week board renames its patch; removing or discarding the errand removes it. The Story
Lab's Computers tab writes them from the real Win95 (Save patch); this is the text it writes.

```
reset
set volume: 40.0
set wallpaper: res://win95/wallpapers/bubbles.png
delete Desktop\passwords.txt

folder C:\Letters

file C:\Letters\letter.txt
	modified: Tuesday, May 28, 1996 9:14:02 PM
	contents:
		Dear Kent,

		the printer jams again.

mail
	from: Kent <kent@modemlandia.se>
	subject: Lunch?
	sent: 1996-05-30 11:02
	body:
		Friday at noon.
		Kent

unmail
	sent: 1996-05-28 21:14
	subject: Re: invoices
```

- `reset`, first if at all, throws away what the player did: the computer starts again from its
  `.tres` and its start patch, then this patch.
- `set <field>: <value>` sets a field of `Win95Setup`. `delete <path>` deletes a file or folder
  with what is in it. A path starts with `Desktop`, `C:` or `Recycled` (the Recycle Bin). A second
  file of one name in a folder, as two deleted `readme.txt` in the Recycle Bin, is `readme.txt*2`.
- `#` starts a comment line.
- `file <path>` and `folder <path>` set the fields under it, tab-indented. A file that is there
  keeps the fields left out, so a moved icon is its path and `desktop_position`; a new one has its
  defaults in them. Save patch writes a new file's fields that aren't their defaults. A folder keeps
  its children. A text with line breaks is a block: `contents:`, then its lines two tabs deep. A text with a space or line break at an end, or a leading `"`, is one quoted line instead, escaped as in JSON: `body: "the "`.
- `mail` puts a mail. Its `sent` and `subject` say which: for a mail the computer has with those, it
  sets only the fields under it and the mail keeps the rest, so a change is short (`read: true`); a
  mail it hasn't got is new, with the fields left out at their defaults. `unmail` deletes the mail
  with that `sent` and `subject`.
- A resource field (an icon, a picture, a program) names a `res://` file, or `none`. Enums are
  their names in lower case (`folder: trash`); other values are Godot's on one line (`true`,
  `Vector2(300, 200)`, `{&"title": "Q2"}`), texts quoted as above.
- A patch converges: deleting what is gone does nothing, and a file in a missing folder makes the
  folder. A computer gets the patches of all its customer's errands up to the visit, by code, each
  once, also those of visits where it never booted, and those of an alternative errand of the same
  customer that didn't come. A patch with an error applies nothing; the Lab marks the line.
- The mail table shows the patch's `mail` and `unmail` lines, nothing else: new mails, changes to
  hers (with her own values dim) and deletes. Editing a row edits its line.
- Save patch writes what differs from the computer before the visit, and keeps the
  stored patch's `reset`, its comments (moved to the top) and its lines that still hold, such as a
  `delete` of a file the player might make. What a patch can't hold, such as a picture drawn in
  Paint, is left out, and the Lab says so. While the patch text has unsaved edits or errors, a table
  edit is refused and undone. Play here makes the customer's computer again, so it shows the patches
  as they are; a computer already running in the game keeps what it had.

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
  mood.
- **A line's mood can change partway.** Inside a customer line, `(mood)` with a mood of
  `Person.MOODS` starts a new line part in that mood; any other word in parentheses stays text.
  It is still one line: one box, one click. The voice says the parts one after another, each in
  its own mood, without a pause; each part has its own voice file. The dialogue box shows each
  part's face as its audio starts, and types its text over the time that its audio takes; a click
  shows the whole line, and the face goes on following the voice. Where the voice's timing is
  unknown (in a browser, or a part without its voice file), the text types at its own speed and
  each face shows as the typing reaches its part. The tags at the end (`[voice]`, `[effect]`, `[look]`, `[leaving]`) hold for the
  whole line: with `[voice mood]` every part speaks in that voice mood, and only the faces change.

  ```
  (neutral) I always help when I can. About the computer... (angry) You can keep it.
  ```
 `[leaving]` makes it a call-out:
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
time it matches), `[daypart morning]`, `midday` or `afternoon` (plays only in that daypart),
`[effect name]` (for all its lines), `[leave Text]` and `[back Text]` (the
leave buttons), and for an event `[pop-up Text]`. After a choice: `[if ...]` and `[end]`.

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
all fail, a mood that the person has no portrait for (a leading one or one inside a line), a voice mood that a line speaks in and that has no voice, a `[leaving]` line that the
conversation can go on after, a look that is unknown or never turns the view, a problem without repair mechanics, a problem file that no errand
names, a call-out whose voice mood has no voice:

```sh
"$GODOT" --headless -s res://dev/story.gd
```

The game refuses a file that doesn't parse, and names the file, the line and what it expected.

## Change it

Edit the text, then run the story check and the tests that cover the change
(`run.gd -- story`). A change to the format changes the Story Lab's short reference too,
`dev/story_lab/how_to_write.txt`, which the text view's sidebar shows. Render the voices of new or changed lines, then import (see "Voices" in
[building-and-testing.md](building-and-testing.md)); `git rm` the files it lists as unused, and
commit the `.wav` and `.wav.import` files with the text.

A writer's change arrives as a GitHub issue with the labels `story` and `feedback`: the Story Lab's **Send**. The issue builder builds every `feedback` issue; a note that starts with `[test]` adds `test`, and the builder leaves those. Its
body holds each changed file whole and its diff against the commit that the writer started from.
Apply it: where `main` changed the same lines since, merge by hand and say so on the issue. A new
rule of how the story plays is a design change: it goes on the wiki page first.
