extends "res://tests/test.gd"
## Call-outs come from story/callouts/: everyone's set plays for a customer without their own, with
## the voices rendered for it; a customer's set for a day, flags or a daypart wins over their plain
## set, which wins over everyone's. A call-outs file that doesn't fit the format names its line.

const GAME := preload("res://game.gd")
const SKATER: String = "res://story/callouts/skater_bro.callouts"
const SKATER_TEXT: String = """== waiting [if day 7] [effect cambion_glitch]
(irritated03) I am still here. I am always here.

== waiting
(neutral) Yo?
(thinking) Dude?

== waiting [daypart afternoon]
(neutral) Getting late, man.
"""


func run() -> void:
	var skater := load("res://customers/skater_bro.tres") as Customer
	var lady := load("res://customers/nice_lady.tres") as Customer
	check("the week loads without call-out drafts", game.story_errors, PackedStringArray())
	var everyone: CallOuts.Set = game.week.call_outs[CallOuts.EVERYONE].sets[0]
	game.restore({"day": 7, "phase": "OPEN"})
	check("a customer without their own calls out everyone's set", game.call_outs_of(skater), everyone)
	var silent := PackedStringArray()
	for line: DialogueLine in everyone.lines:
		if not ResourceLoader.exists(Voices.path_of(line, skater.voice.body)):
			silent.append(line.text)
	check("everyone's call-outs keep the voices rendered for them", silent, PackedStringArray())

	check("a customer's call-outs load", game.load_story(drafts({SKATER: SKATER_TEXT})), PackedStringArray())
	var sets: Array[CallOuts.Set] = game.week.call_outs[&"skater_bro"].sets
	check("restore day 7", game.restore({"day": 7, "phase": "OPEN"}), "")
	check("on day 7 the day's set plays, with its effect", [game.call_outs_of(skater), game.call_outs_of(skater).effect.resource_path], [sets[0], "res://voices/effects/cambion_glitch.tres"])
	check("others still call out everyone's", said(game.call_outs_of(lady)), said(everyone))
	check("restore day 3", game.restore({"day": 3, "phase": "OPEN"}), "")
	check("on day 3 in the morning, their plain set", [game.daypart, game.call_outs_of(skater)], [GAME.Daypart.MORNING, sets[1]])
	game.daypart = GAME.Daypart.AFTERNOON
	check("in the afternoon, the afternoon's set", game.call_outs_of(skater), sets[2])

	var only_day := "== waiting [if day 2]\n(neutral) Tuesday?\n"
	check("a customer with only a day's set loads", game.load_story(drafts({SKATER: only_day})), PackedStringArray())
	check("restore day 3", game.restore({"day": 3, "phase": "OPEN"}), "")
	check("on another day they fall back to everyone's", said(game.call_outs_of(skater)), said(everyone))

	var bad := {
		"== waiting\n(neutral) A.\n== waiting\n(neutral) B.\n": "a second '== waiting' without [if] or [daypart]",
		"== waiting [daypart evening]\n(neutral) A.\n": "the daypart must be morning, midday, afternoon",
		"== drop-off\n(neutral) A.\n": "a call-out set starts with '== waiting'",
		"== waiting\n(neutral) A.\n- Hi.\n": "a call-out set holds only lines",
		"== waiting\n(neutral) Bye. [leaving]\n": "can't have [leaving] or [look]",
		"== waiting [once]\n(neutral) A.\n": "is not a tag of a call-out set",
		"(neutral) A.\n== waiting\n(neutral) B.\n": "a line before the first '== waiting'",
	}
	for text: String in bad:
		var parsed := StoryFormat.parse_call_outs(text, SKATER)
		check("refused: %s" % bad[text], parsed.errors.size() == 1 and parsed.errors[0].begins_with(SKATER + ":") and parsed.errors[0].contains(bad[text]), true)
	var stranger := StoryFormat.parse_call_outs("== waiting\n(neutral) A.\n", "res://story/callouts/nobody_at_all.callouts")
	check("a file named for no customer is refused", stranger.errors.size(), 1)
	var errors: PackedStringArray = game.load_story(drafts({"res://story/callouts/everyone.callouts": "== waiting [if day 1]\n(neutral) A.\n"}))
	check("everyone's call-outs need a plain set", errors.size() == 1 and errors[0].contains("every customer falls back to it"), true)


# "(mood) text" of each line of [param lines].
func said(lines: Conversation) -> PackedStringArray:
	var found := PackedStringArray()
	for line: DialogueLine in lines.lines:
		found.append("(%s) %s" % [line.mood, line.text])
	return found


func drafts(texts: Dictionary) -> Dictionary[String, String]:
	var typed: Dictionary[String, String] = {}
	typed.assign(texts)
	return typed
