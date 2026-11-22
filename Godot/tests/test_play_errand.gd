extends "res://tests/test.gd"
## Game.play_errand jumps to an errand of the week for the Story Lab's Play here: its day, the errands
## before it gone, and the conversation of the trigger playing, with the customer at the counter, or
## their computer done on the counter, or the call on.

const GAME := preload("res://game.gd")
const PATH: String = "res://story/errands/0599_hat_guy.errand"
const TEXT: String = """customer: hat_guy
problem: dust_overheat

== drop-off [once]
(neutral) Hello again.

== pick-up
(happy) Thanks for fixing it.

== phone
(neutral) Hat guy here.
"""


func run() -> void:
	var drafts: Dictionary[String, String] = {"res://story/errands/0503_nice_guy.errand": "", PATH: TEXT, "res://story/errands/0598_office_girl.errand": "customer: office_girl\ncomputer: none\n\n== drop-off\n(neutral) Hi.\n"}
	check("the drafts load", game.load_story(drafts), PackedStringArray())
	var own := StoryFormat.parse_errand(TEXT, PATH).value as Errand
	var visit := game.day_of(5).alternatives("0599")[0] as Errand
	game.set_flag(&"gone_hat_guy")
	game.seen["0599/drop-off/1"] = true
	game.set_flag(&"kept_flag")

	check("the drop-off, from the Lab's own parse", game.play_errand(own), "")
	check("day 5, the errands before it came", [game.day_number, game.phase, game.arrivals], [5, GAME.Phase.OPEN, game.day_of(5).codes().find("0599") + 1])
	check("he talks at the counter, in for that errand", [game.visitor.resource_path, game.visit, game.visitor_state, game.errand], ["res://customers/hat_guy.tres", GAME.Visit.DROP_OFF, GAME.VisitorState.TALKING, visit])
	check("its once drop-off plays again", game.conversation.lines[0].text, "Hello again.")
	check("he isn't gone; the other flags stay", [game.is_gone(load("res://customers/hat_guy.tres")), game.flag(&"kept_flag")], [false, 1])
	check("the counter is empty", game.jobs.size(), 0)

	check("the pick-up", game.play_errand(visit, Conversation.Trigger.PICKUP), "")
	check("his computer is done on the counter, and he picks it up", [game.jobs.size(), game.jobs[0].done, game.jobs[0].errand, game.visit, game.visitor_state], [1, true, visit, GAME.Visit.PICKUP, GAME.VisitorState.TALKING])
	check("its pick-up plays", game.conversation.lines[0].text, "Thanks for fixing it.")

	check("the phone", game.play_errand(visit, Conversation.Trigger.PHONE), "")
	check("the call is on about his done computer", [game.phase, game.calling == game.jobs[0], game.calling.done, game.visitor], [GAME.Phase.CALLING, true, true, null])
	check("its phone plays", game.conversation.lines[0].text, "Hat guy here.")

	var none := game.day_of(5).alternatives("0598")[0] as Errand
	var before: Dictionary = game.snapshot()
	check("no pick-up for an errand without a computer", game.play_errand(none, Conversation.Trigger.PICKUP) != "", true)
	var stray := StoryFormat.parse_errand(TEXT, "res://story/errands/0597_hat_guy.errand").value as Errand
	check("an errand that isn't in the week is refused", game.play_errand(stray) != "", true)
	check("a refusal keeps the state", game.snapshot(), before)
