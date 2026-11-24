extends "res://tests/test.gd"
## An errand's event (== event in its story file): while its computer is on the counter and not yet
## done, on the day and in the daypart that its tags allow, the customer pops up behind the counter
## as the player is zoomed in on a computer in the Workview. The skater's day-4 event comes only at
## midday on day 5, while his defrag still runs. Its daypart lasts until it has played: the
## afternoon's customer waits. It doesn't count as an arrival, plays once, and survives a restore.

const GAME := preload("res://game.gd")
## The skater's day-4 defrag errand, which runs until the afternoon of day 5.
const SKATER := "0403_skater_bro"
const SEEN := ["0401/drop-off/1", "0402/drop-off/1", "0403/drop-off/1"]
## Day 5 before the first customer: the skater's computer from day 4 is on the counter, not done.
const MORNING := {"day": 5, "arrivals": 0, "focus_slot": 0, "view": "Main", "seen": SEEN,
	"jobs": [{"errand": SKATER, "slot": 0}]}
## Day 5 at midday, the office girl's drop-off over: the skater's computer defrags, on, since day 4.
const MIDDAY := {"day": 5, "arrivals": 2, "focus_slot": 0, "view": "Main",
	"seen": SEEN + ["0501/drop-off/1", "0502/drop-off/1"],
	"jobs": [{"errand": SKATER, "slot": 0, "powered": true, "defrag_started": [4, "AFTERNOON"]}]}


func run() -> void:
	_the_format()
	_not_on_day_4()
	_not_in_the_morning()
	_at_midday_zoomed_in()
	_not_outside_the_workview()
	_midday_holds_until_it_played()
	_no_event_without_the_computer()
	_not_once_done()
	_restore_and_play()
	await _he_rises_where_the_player_looks()


func _the_format() -> void:
	var text := "customer: skater_bro\n\n== event [if day 5] [daypart midday] [pop-up (happy) Hey!]\n(neutral) Done yet?\n"
	var parsed := StoryFormat.parse_errand(text, "res://story/errands/0403_skater_bro.errand")
	var event: Conversation = (parsed.value as Errand).conversations[0]
	check("an event parses, with its day, daypart and pop-up line", [parsed.errors, event.trigger, event.id, event.when.from_day, event.when.to_day, event.daypart, event.pop_up.text, event.pop_up.mood],
			[PackedStringArray(), Conversation.Trigger.EVENT, &"0403/event/1", 5, 5, &"midday", "Hey!", &"happy"])
	check("and writes back the same", StoryFormat.write_errand(parsed.value as Errand), text)
	check("its pop-up line is among its lines, for the voices", event.all_lines()[0], event.pop_up)
	var wrong := StoryFormat.parse_errand("customer: skater_bro\n\n== drop-off [pop-up Hey!]\n(neutral) Hi.\n", "res://story/errands/0102_skater_bro.errand")
	check("only an event pops up", wrong.errors.size() == 1 and wrong.errors[0].contains("only an event pops up"), true)
	var teatime := StoryFormat.parse_errand("customer: skater_bro\n\n== event [daypart teatime]\n(neutral) Hi.\n", "res://story/errands/0403_skater_bro.errand")
	check("a daypart that isn't one", teatime.errors.size() == 1 and teatime.errors[0].contains("the daypart must be morning, midday, afternoon"), true)


# Zooms in on the computer in slot 0 and lets a frame pass.
func _zoom_in() -> void:
	game.focus_job(game.jobs[0])
	game.go_to_view(&"Workview")
	tick(0.1)


func _not_on_day_4() -> void:
	var dropped := MORNING.duplicate()
	dropped.merge({"day": 4, "arrivals": 3}, true)
	check("restore day 4 right after his drop-off", game.restore(dropped), "")
	_zoom_in()
	check("no event on day 4, zoomed in", [game.waiting_event(), game.visitor], [null, null])


func _not_in_the_morning() -> void:
	check("restore day 5 before the first customer", game.restore(MORNING), "")
	_zoom_in()
	check("no event in the morning of day 5, zoomed in", [game.waiting_event(), game.visitor], [null, null])
	game.go_to_view(&"Main")
	game.skip_wait()
	tick(0.1)
	check("the first customer comes in", [game.arrivals, game.visitor.resource_path], [1, "res://customers/hat_guy.tres"])


func _at_midday_zoomed_in() -> void:
	check("restore day 5 at midday", game.restore(MIDDAY), "")
	var skater: Errand = game.jobs[0].errand
	var setup: Win95Setup = game.setups.get(game.jobs[0].customer.computer)
	check("his computer still defrags, at 75%", [setup.defragmenting, game.defrag_progress(setup), game.jobs[0].done], [true, 0.75, false])
	check("his event waits", [game.daypart, game.waiting_event()], [GAME.Daypart.MIDDAY, skater])
	tick(0.1)
	check("in the Main view nobody pops up", game.visitor, null)
	_zoom_in()
	check("zoomed in on a closed computer, he pops up, calling out", [game.visitor_state, game.visit, game.errand, game.leaving_lines.map(func(l: DialogueLine) -> String: return l.text)], [GAME.VisitorState.POPPING_UP, GAME.Visit.EVENT, skater, ["Hey!"]])
	check("which isn't an arrival", [game.arrivals, game.daypart], [2, GAME.Daypart.MIDDAY])
	check("nobody calls while he's in", game.can_pick_up_phone(), false)
	game.customer_arrived()
	check("he talks, and the player faces him", [game.visitor_state, game.view, String(game.conversation.id), game.leaving_lines], [GAME.VisitorState.TALKING, &"Main", "0403/event/1", [] as Array[DialogueLine]])
	game.dialogue_finished()
	check("then he walks out, his computer stays", [game.visitor_state, game.jobs.size()], [GAME.VisitorState.WALKING_OUT, 1])
	game.customer_out_the_door()
	game.customer_left()
	check("the event played once", game.waiting_event(), null)
	_zoom_in()
	check("zoomed in again, nobody pops up", game.visitor, null)


func _not_outside_the_workview() -> void:
	for view: StringName in [&"Screen", &"Left", &"Right", &"CompuFunDB"]:
		var looking := MIDDAY.duplicate()
		looking["view"] = String(view)
		check("restore day 5 at midday in the %s view" % view, game.restore(looking), "")
		tick(0.1)
		check("in the %s view nobody pops up" % view, [game.visitor, game.waiting_event() != null], [null, true])


func _midday_holds_until_it_played() -> void:
	check("restore day 5 at midday", game.restore(MIDDAY), "")
	game.skip_wait()
	tick(0.1)
	check("the event holds the afternoon's customer back: midday goes on", [game.arrivals, game.daypart, game.visitor], [2, GAME.Daypart.MIDDAY, null])
	_zoom_in()
	check("zoomed in, he pops up", game.visit, GAME.Visit.EVENT)
	game.customer_arrived()
	game.dialogue_finished()
	game.customer_out_the_door()
	game.customer_left()
	game.go_to_view(&"Main")
	game.skip_wait()
	tick(0.1)
	check("once it played, the afternoon's customer comes in", [game.arrivals, game.daypart, game.visit, game.errand.file_name()], [3, GAME.Daypart.AFTERNOON, GAME.Visit.DROP_OFF, "0503_nice_guy"])


func _no_event_without_the_computer() -> void:
	var empty := MIDDAY.duplicate()
	empty.merge({"jobs": [], "focus_slot": -1}, true)
	check("restore day 5 at midday with an empty counter", game.restore(empty), "")
	check("no event", game.waiting_event(), null)


func _not_once_done() -> void:
	var done := MIDDAY.duplicate()
	done.merge({"jobs": [{"errand": SKATER, "slot": 0, "software_fixed": true, "tested": true}]}, true)
	check("restore day 5 at midday with his computer done", game.restore(done), "")
	check("no event once it is done", [game.jobs[0].done, game.waiting_event()], [true, null])
	var on_day_1 := {"day": 1, "arrivals": 3, "view": "Main", "seen": ["0101/drop-off/1", "0102/drop-off/1", "0103/drop-off/1"],
		"jobs": [{"errand": "0102_skater_bro", "slot": 0}]}
	check("restore day 1 at midday with his day-1 computer", game.restore(on_day_1), "")
	check("his day-1 errand has no event", game.waiting_event(), null)


func _restore_and_play() -> void:
	var popping := MIDDAY.duplicate()
	popping.merge({"visitor": "res://customers/skater_bro.tres", "visit": "EVENT", "visitor_state": "POPPING_UP"})
	check("restore him popping up", game.restore(popping), "")
	var before: Dictionary = game.snapshot()
	check("a restore of the snapshot keeps it", [game.restore(before), game.snapshot() == before], ["", true])
	game.customer_arrived()
	check("he talks", String(game.conversation.id), "0403/event/1")
	var talking: Dictionary = game.snapshot()
	check("a restore while he talks keeps the event", [game.restore(talking), String(game.conversation.id)], ["", "0403/event/1"])
	var stranger := popping.duplicate()
	stranger["visitor"] = "res://customers/retired_accountant.tres"
	check("someone without an event of theirs on the counter can't pop up", game.restore(stranger).contains("no computer of theirs"), true)
	var walking := popping.duplicate()
	walking["visit"] = "DROP_OFF"
	check("only an event visitor pops up", game.restore(walking) != "", true)
	var skater: Errand = game.week.days[3].errands.filter(func(e: Errand) -> bool: return e.file_name() == SKATER)[0]
	check("the Story Lab plays the event", game.play_errand(skater, Conversation.Trigger.EVENT), "")
	check("on its day and daypart, he pops up behind his computer", [game.day_number, game.daypart, game.visitor_state, game.jobs.size(), game.jobs[0].done],
			[5, GAME.Daypart.MIDDAY, GAME.VisitorState.POPPING_UP, 1, false])
	game.customer_arrived()
	check("and talks", String(game.conversation.id) if game.conversation != null else "", "0403/event/1")


# The shop: zooming in lets him jump up only once the view has zoomed in, into a gap beside the
# computer in focus; half a second later he stands at the counter and talks. In the Workview of every
# counter slot, the gap on each side holds his face, halfway to the next slot.
func _he_rises_where_the_player_looks() -> void:
	var shop: Node = load("res://rooms/shop/shop.tscn").instantiate()
	root.add_child(shop)
	await process_frame
	var camera: Camera3D = shop.get_node("%Camera")
	var body: Node3D = shop.get_node("%CustomerBody")
	var head_height: float = shop.get("head_height")
	check("restore day 5 at midday", game.restore(MIDDAY), "")
	await create_timer(0.5).timeout
	game.focus_job(game.jobs[0])
	game.go_to_view(&"Workview")
	tick(0.1)
	await process_frame
	await process_frame
	check("zooming in lets him pop up", game.visitor_state, GAME.VisitorState.POPPING_UP)
	var gaps: Array[Vector3] = [shop.call("_peek_spot", -1), shop.call("_peek_spot", 1)]
	check("while the view zooms in, he stays down behind the counter", body.global_position.y < gaps[0].y - 0.5, true)
	await create_timer(float(shop.get("turn_seconds")) + float(shop.get("pop_up_seconds")) + 0.1).timeout
	var head := body.global_position + Vector3.UP * head_height
	check("once zoomed in, he is up in a gap and his face in view", [gaps.any(func(gap: Vector3) -> bool: return body.global_position.is_equal_approx(gap)), camera.is_position_in_frustum(head)], [true, true])
	var relief: MeshInstance3D = body.get_node("Relief")
	var front := func() -> Texture2D: return (relief.get_surface_override_material(PhotoRelief.Surface.FRONT) as ShaderMaterial).get_shader_parameter("albedo_texture")
	var portraits: Dictionary = (load("res://people/skater_bro/person.tres") as Person).portraits
	check("as he pops up, his relief is the portrait of the pop-up line's mood", [body.get("pose"), front.call()], [&"irritated03", portraits[&"irritated03"]])
	await create_timer(float(shop.get("pop_up_scare_seconds")) + 0.1).timeout
	check("half a second later he stands at the counter and talks, his usual relief", [game.visitor_state, body.position.is_zero_approx(), body.get("pose"), front.call()], [GAME.VisitorState.TALKING, true, &"", portraits[&"neutral"]])

	for slot: int in GAME.MAX_JOBS:
		var zoomed := MIDDAY.duplicate(true)
		zoomed.merge({"focus_slot": slot, "view": "Workview", "jobs": [{"errand": SKATER, "slot": slot}]}, true)
		game.set_process(false)  # the Workview would let him in at once
		check("restore his computer in slot %d, in the Workview" % slot, game.restore(zoomed), "")
		await create_timer(1.0).timeout
		var slots: Node = shop.get_node("%JobSlots")
		var here: Vector3 = slots.call("slot_marker", slot).global_position
		var spacing: Vector3 = slots.call("slot_marker", 1).global_position - slots.call("slot_marker", 0).global_position
		for side: int in [-1, 1]:
			var face: Vector3 = shop.call("_peek_spot", side) + Vector3.UP * head_height
			var y := camera.unproject_position(face).y / shop.get_viewport().get_visible_rect().size.y
			check("slot %d, gap %s: his face is in the Workview's frame, in its top half, halfway to the next slot" % [slot, "left" if side < 0 else "right"],
					[camera.is_position_in_frustum(face), y < 0.5, is_equal_approx(face.x, here.x + spacing.x * 0.5 * side)], [true, true, true])
	game.set_process(true)
	shop.queue_free()
	await process_frame
