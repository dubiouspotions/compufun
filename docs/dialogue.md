# Dialogue and the week, for agents

How to read and change what customers say, and who comes on which day. The design is on the
wiki page [Architecture](../wiki/Architecture.md) ("Content data"); the guide for people is
[Writing Dialogue and Planning the Week](../wiki/Writing-Dialogue-and-Planning-the-Week.md).

## Where it lives

- **Who comes when:** `Godot/days/day_<n>.tres`. A `Day` holds `errands` (an `Errand` is a customer
  and the problem their computer has this time; at most `Game.MAX_CUSTOMERS`), `warp`, `set_flags`
  (set as the day starts), `close_flags` (set at closing, and they stay) and `close_signs` (start at
  closing, stop the next day).
- **What they say:** `Godot/customers/<name>.tres`. A `Customer` holds `conversations`. A
  `Conversation` is a `Reply` with an id, a trigger (`ARRIVE`, `PICKUP`, `PHONE`), `once`, a voice
  effect, `leave_text` and `back_text`. A `Reply` holds `when` (a `Condition`), `set_flags`,
  `lines` (`DialogueLine`: text and pose) and `choices`. A `Choice` holds the player's `text`,
  `when`, `replies` and `ends`. Lines shared by every customer are in `customers/conversations/`.
- **Flags** are names with a number; 0 or missing is off. `sign_<id>` starts the corruption sign
  `corruption/<id>.tscn`.

## Read it as text

Don't read the `.tres`: its sub-resources are out of order and hard to follow. Print the outline,
and the week's missing links, from `Godot/`:

```sh
"$GODOT" --headless -s res://dev/story.gd -- outline skater_bro   # one customer's trees
"$GODOT" --headless -s res://dev/story.gd -- outline              # all of them
"$GODOT" --headless -s res://dev/story.gd                         # the missing links
```

In the outline, `##` is a conversation with its tags, `>` a player choice, `-` a reply; tags read
`day 2-2`, `needs x`, `not y`, `sets z`, `once`, `ends`. The missing links are what a change should
fix, never add to: a flag that nothing sets or checks, a choice without a reply, an errand whose
customer has no `ARRIVE` conversation for that day.

## How it plays

- The game plays the **first** conversation of the customer, from the top, whose trigger and
  condition match (and that hasn't played, if `once`). Put specific ones above the general one.
- A choice shows only while its condition matches and one of its replies can. Picking it plays
  the **first** matching reply, which sets its flags as it starts. Give a choice a last reply
  without a condition as the fallback.
- After a reply: its own choices; with none, back to the list it came from. A list without an
  `ends` choice gets `leave_text` (the first list) or `back_text` (deeper). `ends` on a choice
  ends the conversation after its reply, so its reply's choices never show.
- The phone shows no choices yet; `PHONE` conversations stay plain lines.
- The arrival pattern: a greeting, chitchat choices, "So, what's your problem?" whose reply is the
  problem, questions that bring out the rest, and "OK, leave it with me." with `ends` on the
  farewell. A problem's "if asked" symptom becomes a question.
- A customer never says their own name (#148). Poses are `Person.POSES`; a pose the person has no
  photo for shows the neutral photo, with an error. Write the player's lines short: they are buttons.

## Change it

Don't hand-edit sub-resources in a `.tres`. Write a throwaway script in your scratch folder that
loads the resource, changes it with the classes, and saves it; run it from `Godot/` with
`"$GODOT" --headless -s /path/to/script.gd`. If it fails with "Could not parse global class" after
a pull, the class cache is stale: run `"$GODOT" --headless --editor --quit` once. For example, a question with two answers:

```gdscript
extends SceneTree

func _initialize() -> void:
	var path := "res://customers/hat_guy.tres"
	var c: Customer = load(path)
	var talk: Conversation = c.conversation(&"arrive")
	var problem: Reply = talk.choices.back().replies[0]  # the reply to "So, what's your problem?"
	var asked := Choice.new()
	asked.text = "Did a friend help you?"
	var told := Reply.new()
	told.when = Condition.new()
	told.when.need_flags = [&"hat_guy_cambion"]
	told.lines = [line("My grandson did. He brought that Cambion thing.", &"thinking")]
	var not_yet := Reply.new()
	not_yet.lines = [line("No, I did it all myself.", &"happy")]
	asked.replies = [told, not_yet]
	problem.choices.insert(problem.choices.size() - 1, asked)  # above "OK, leave it with me."
	var err := ResourceSaver.save(c, path)
	print("%s: %s" % [path, error_string(err)])
	quit(1 if err != OK else 0)

func line(text: String, pose: StringName) -> DialogueLine:
	var each := DialogueLine.new()
	each.text = text
	each.pose = pose
	return each
```

`ResourceSaver` writes the whole file again, so the diff is large. Read it back through the
outline, not the diff, and check that the customer's other fields (person, computer, voice) are
unchanged. The Dialogue and Week tabs edit the same resources by hand; an open editor holds its
own copy, so reload it before saving there after a script changed a file.

## Check it

1. The outline shows the change, and `dev/story.gd` lists no missing links you added.
2. `"$GODOT" --headless -s res://tests/run.gd` passes.
3. Render the voices of new or changed lines, then import (see "Voices" in
   [building-and-testing.md](building-and-testing.md)):
   `CHIMERA=/path/to/chimera "$GODOT" --headless --script res://voices/render_voices.gd`.
   `git rm` the files it lists as unused. Commit the `.wav` and `.wav.import` files with the text.
4. A new rule of how dialogue plays is a design change: it goes on the wiki page first.
