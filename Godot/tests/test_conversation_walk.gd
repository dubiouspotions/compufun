extends "res://tests/test.gd"
## ConversationWalk plays a conversation from a story file as docs/dialogue.md says: - branches meet
## below their list, a + list comes back with its picks greyed and its leave button goes on below it,
## a deeper list's back button returns to the list above, [end] stops, if/else answers by flag,
## lines below a list play after it, and leaving lines at the end wait for the box to close while
## those that something follows play in it. A walk on a sandbox day and flags leaves Game alone,
## and a walk can start at any line.

const ERRAND := """customer: skater_bro

== drop-off
(neutral) Yo!
- Welcome!
	(happy) Sweet!
- Hi.
	(angry) Whatever.

- What's the issue?
	(problem) It turns off.

+ When did it start?
	set new_windows
	(thinking) After the new Windows.
+ Did you install anything?
	if new_windows
		(happy) Floppies.
	else
		(neutral) Nah.
set told
(neutral) Anyway, fix it.

== drop-off
(neutral) Hm.
+ Tell me about it.
	(neutral) Which part?
	+ The screen?
		(neutral) Blank.
	+ The fans?
		(neutral) Loud.
+ Bye. [end]
	(happy) Bye!
(neutral) Never said.

== pick-up
(neutral) Done?
- Yes.
	(happy) Dope!
	(neutral) Later! [leaving]
	(neutral) Peace! [leaving]

== phone
(neutral) Hi. [leaving]
(neutral) Still here.
+ Q?
	(neutral) Bye. [leaving]
- Go.
"""


func run() -> void:
	var parsed := StoryFormat.parse_errand(ERRAND, "res://story/errands/0101_skater_bro.errand")
	check("the errand parses", parsed.errors, PackedStringArray())
	var talks := (parsed.value as Errand).conversations

	var walk_script: GDScript = load("res://customers/conversation_walk.gd")  # by path: ConversationWalk names Game, which doesn't compile under -s
	game.start_day(make_day(1, []))
	game.conversation = talks[0]
	var walk: RefCounted = walk_script.new(talks[0])
	check("starts at the first lines", texts(walk.lines()), ["Yo!"])
	walk.said()
	check("then the first list; a - list has no leave button", [texts(walk.choices()), walk.leave_text()], [["Welcome!", "Hi."], ""])
	walk.pick(walk.choices()[1])
	check("the pick's reply", texts(walk.lines()), ["Whatever."])
	walk.said()
	check("both branches meet at the next list", texts(walk.choices()), ["What's the issue?"])
	walk.pick(walk.choices()[0])
	walk.said()
	check("a + list, with the leave button at the top", [texts(walk.choices()), walk.leave_text()], [["When did it start?", "Did you install anything?"], "That's all, thanks."])
	walk.pick(walk.choices()[1])
	check("else plays without the flag", texts(walk.lines()), ["Nah."])
	walk.said()
	check("a + comes back to its list, the pick greyed", [texts(walk.choices()), walk.was_picked(walk.choices()[1]), walk.was_picked(walk.choices()[0])], [["When did it start?", "Did you install anything?"], true, false])
	walk.pick(walk.choices()[0])
	check("the reply sets its flag", game.flag(&"new_windows"), 1)
	walk.said()
	walk.pick(walk.choices()[1])
	check("if plays with the flag", texts(walk.lines()), ["Floppies."])
	walk.said()
	check("not told before the lines below the list", game.flag(&"told"), 0)
	walk.leave()
	check("leaving goes on below the list, and sets its flags", [texts(walk.lines()), game.flag(&"told"), walk.is_over()], [["Anyway, fix it."], 1, false])
	walk.said()
	check("off the top: over", [walk.is_over(), walk.lines(), walk.choices()], [true, [], []])

	game.conversation = talks[1]
	walk = walk_script.new(talks[1])
	walk.said()
	check("a list with [end] has no leave button", [texts(walk.choices()), walk.leave_text()], [["Tell me about it.", "Bye."], ""])
	walk.pick(walk.choices()[0])
	walk.said()
	check("a deeper + list says back", [texts(walk.choices()), walk.leave_text()], [["The screen?", "The fans?"], "Something else..."])
	walk.pick(walk.choices()[0])
	walk.said()
	check("the deeper list comes back", texts(walk.choices()), ["The screen?", "The fans?"])
	walk.leave()
	check("back returns to the outer list", [texts(walk.choices()), walk.was_picked(walk.choices()[0])], [["Tell me about it.", "Bye."], true])
	check("a choice that isn't offered doesn't pick", walk.pick(Choice.new()), false)
	walk.pick(walk.choices()[1])
	check("[end]: its reply plays", texts(walk.lines()), ["Bye!"])
	walk.said()
	check("then the conversation is over, the lines below unsaid", walk.is_over(), true)

	game.conversation = talks[2]
	walk = walk_script.new(talks[2])
	walk.said()
	walk.pick(walk.choices()[0])
	check("the leaving lines that end the conversation are not in the box", [texts(walk.lines()), walk.leaving_lines()], [["Dope!"], []])
	walk.said()
	check("the walk is over before them, and holds them", [walk.is_over(), texts(walk.leaving_lines())], [true, ["Later!", "Peace!"]])

	game.conversation = talks[3]
	walk = walk_script.new(talks[3])
	check("a leaving line that a line follows plays in the box", texts(walk.lines()), ["Hi.", "Still here."])
	walk.said()
	walk.pick(walk.choices()[0])
	check("a leaving line that its list follows plays in the box first", [texts(walk.lines()), walk.choices()], [["Bye."], []])
	walk.said()
	check("then the list", texts(walk.choices()), ["Q?", "Go."])
	walk.pick(walk.choices()[1])
	check("over, with nothing to call out", [walk.is_over(), walk.leaving_lines()], [true, []])

	_on_a_sandbox(walk_script, talks)


# A walk on a sandbox day and flags, from the start or from a line, leaves Game as it was.
func _on_a_sandbox(walk_script: GDScript, talks: Array[Conversation]) -> void:
	game.conversation = null
	var game_flags: Dictionary = game.flags.duplicate()
	var flags: Dictionary[StringName, int] = {}
	var walk: RefCounted = walk_script.new(talks[0], null, walk_script.Sandbox.new(1, flags))
	walk.said()
	walk.pick(walk.choices()[0])
	walk.said()
	walk.pick(walk.choices()[0])
	walk.said()
	walk.pick(walk.choices()[0])
	check("a reply sets its flag in the sandbox", flags, {&"new_windows": 1})
	walk.said()
	walk.pick(walk.choices()[1])
	check("and the sandbox's flags decide what plays", texts(walk.lines()), ["Floppies."])

	var floppies: DialogueLine = talks[0].then.then.choices[1].replies[0].lines[0]
	flags = {}
	walk = walk_script.new(talks[0], floppies, walk_script.Sandbox.new(1, flags))
	check("from a line, it starts there, whatever its condition says", texts(walk.lines()), ["Floppies."])
	walk.said()
	check("then its + list shows again, the pick on the way greyed", [texts(walk.choices()), walk.was_picked(walk.choices()[1]), walk.leave_text()], [["When did it start?", "Did you install anything?"], true, "That's all, thanks."])
	walk.leave()
	check("and on below it, setting the sandbox's flags", [texts(walk.lines()), flags], [["Anyway, fix it."], {&"told": 1}])

	var sweet: DialogueLine = talks[0].choices[0].replies[0].lines[0]
	walk = walk_script.new(talks[0], sweet, walk_script.Sandbox.new(1, no_flags()))
	walk.said()
	check("from a reply of a - choice, on below its list", texts(walk.choices()), ["What's the issue?"])

	var later: DialogueLine = talks[2].choices[0].replies[0].lines[1]
	walk = walk_script.new(talks[2], later, walk_script.Sandbox.new(1, no_flags()))
	check("from a leaving line at the end: over, and it holds the leaving lines", [walk.is_over(), texts(walk.leaving_lines())], [true, ["Later!", "Peace!"]])
	check("Game stays as it was", [game.flags, game.conversation], [game_flags, null])


func no_flags() -> Dictionary[StringName, int]:
	return {}


func texts(of: Array) -> Array:
	return of.map(func(each: Resource) -> String: return each.get(&"text"))
