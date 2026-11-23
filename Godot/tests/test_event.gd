extends "res://tests/test.gd"
## An errand's event (== event in its story file): in the midday of its day, while its computer is on
## the counter, the customer pops up behind the counter as the player works in the open case, or as
## they turn back to the Main view once the next customer is due. The event holds the afternoon
## customer back, doesn't count as an arrival, plays once, and survives a restore.

const GAME := preload("res://game.gd")
const SKATER := "0102_skater_bro"
## Day 1 at midday: the old dude came and went, and the skater's computer is on the counter.
const MIDDAY := {"day": 1, "arrivals": 3, "focus_slot": 0, "view": "Main",
	"seen": ["0101/drop-off/1", "0102/drop-off/1", "0103/drop-off/1"],
	"jobs": [{"errand": SKATER, "slot": 0}]}


func run() -> void:
	_the_format()
	_the_open_case_lets_it_in()
	_a_turn_back_lets_it_in_once_due()
	_no_event_without_the_computer()
	_restore_and_play()


func _the_format() -> void:
	var text := "customer: skater_bro\n\n== event [pop-up (happy) Hey!]\n(neutral) Done yet?\n"
	var parsed := StoryFormat.parse_errand(text, "res://story/errands/0102_skater_bro.errand")
	var event: Conversation = (parsed.value as Errand).conversations[0]
	check("an event parses, with its pop-up line", [parsed.errors, event.trigger, event.id, event.pop_up.text, event.pop_up.mood], [PackedStringArray(), Conversation.Trigger.EVENT, &"0102/event/1", "Hey!", &"happy"])
	check("and writes back the same", StoryFormat.write_errand(parsed.value as Errand), text)
	check("its pop-up line is among its lines, for the voices", event.all_lines()[0], event.pop_up)
	var wrong := StoryFormat.parse_errand("customer: skater_bro\n\n== drop-off [pop-up Hey!]\n(neutral) Hi.\n", "res://story/errands/0102_skater_bro.errand")
	check("only an event pops up", wrong.errors.size() == 1 and wrong.errors[0].contains("only an event pops up"), true)


func _the_open_case_lets_it_in() -> void:
	check("restore day 1 at midday", game.restore(MIDDAY), "")
	var skater: Errand = game.jobs[0].errand
	check("the skater's event waits", [game.daypart, game.waiting_event()], [GAME.Daypart.MIDDAY, skater])
	game.skip_wait()
	tick(0.1)
	check("it holds the afternoon customer back", [game.visitor, game.arrivals], [null, 3])
	game.go_to_view(&"Workview")
	check("lay the computer down", game.lay_down(game.focus), true)
	for i: int in game.focus.panel_screws.size():
		game.turn_screw(game.focus, i)
	check("open its case", game.open_case(game.focus, true), true)
	tick(0.1)
	check("he pops up, calling out", [game.visitor_state, game.visit, game.errand, game.leaving_lines.map(func(l: DialogueLine) -> String: return l.text)], [GAME.VisitorState.POPPING_UP, GAME.Visit.EVENT, skater, ["Hey!"]])
	check("which isn't an arrival", [game.arrivals, game.daypart], [3, GAME.Daypart.MIDDAY])
	check("nobody calls while he's in", game.can_pick_up_phone(), false)
	game.customer_arrived()
	check("he talks, and the player faces him", [game.visitor_state, game.view, String(game.conversation.id), game.leaving_lines], [GAME.VisitorState.TALKING, &"Main", "0102/event/1", [] as Array[DialogueLine]])
	game.dialogue_finished()
	check("then he walks out, his computer stays", [game.visitor_state, game.jobs.size()], [GAME.VisitorState.WALKING_OUT, 1])
	game.customer_out_the_door()
	game.customer_left()
	check("the event played once", game.waiting_event(), null)
	game.skip_wait()
	tick(0.1)
	check("the afternoon customer comes in", [game.arrivals, game.daypart, game.visitor.resource_path], [4, GAME.Daypart.AFTERNOON, "res://customers/activist_guy.tres"])


func _a_turn_back_lets_it_in_once_due() -> void:
	var left := MIDDAY.duplicate()
	left["view"] = "Left"
	check("restore day 1 at midday, looking left", game.restore(left), "")
	game.go_to_view(&"Main")
	check("a turn back before the next customer is due lets nobody in", game.visitor, null)
	game.go_to_view(&"Right")
	game.skip_wait()
	game.go_to_view(&"Main")
	check("once due, a turn back from a side view lets him pop up", [game.visitor_state, game.visit], [GAME.VisitorState.POPPING_UP, GAME.Visit.EVENT])


func _no_event_without_the_computer() -> void:
	var empty := MIDDAY.duplicate()
	empty.merge({"jobs": [], "focus_slot": -1}, true)
	check("restore day 1 at midday with an empty counter", game.restore(empty), "")
	game.skip_wait()
	tick(0.1)
	check("no event: the afternoon customer comes", [game.waiting_event(), game.arrivals], [null, 4])


func _restore_and_play() -> void:
	var popping := MIDDAY.duplicate()
	popping.merge({"visitor": "res://customers/skater_bro.tres", "visit": "EVENT", "visitor_state": "POPPING_UP"})
	check("restore him popping up", game.restore(popping), "")
	var before: Dictionary = game.snapshot()
	check("a restore of the snapshot keeps it", [game.restore(before), game.snapshot() == before], ["", true])
	game.customer_arrived()
	check("he talks", String(game.conversation.id), "0102/event/1")
	var talking: Dictionary = game.snapshot()
	check("a restore while he talks keeps the event", [game.restore(talking), String(game.conversation.id)], ["", "0102/event/1"])
	var stranger := popping.duplicate()
	stranger["visitor"] = "res://customers/retired_accountant.tres"
	check("someone without an event of theirs on the counter can't pop up", game.restore(stranger).contains("no computer of theirs"), true)
	var walking := popping.duplicate()
	walking["visit"] = "DROP_OFF"
	check("only an event visitor pops up", game.restore(walking) != "", true)
	var skater: Errand = game.week.days[0].errands.filter(func(e: Errand) -> bool: return e.file_name() == SKATER)[0]
	check("the Story Lab plays the event", game.play_errand(skater, Conversation.Trigger.EVENT), "")
	check("he pops up behind his computer", [game.visitor_state, game.jobs.size(), game.jobs[0].done], [GAME.VisitorState.POPPING_UP, 1, false])
