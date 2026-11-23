extends "res://tests/test.gd"
## Game plays a day of errands from story files: alternatives by condition, errands that bring no
## computer or only show it (or say nothing), an errand without a problem, the pick-up and phone of a job's errand on
## a later day, a phone call that rings out, and the dayparts with day 1's tutorial first.

const GAME := preload("res://game.gd")


func run() -> void:
	_alternatives()
	_dayparts()
	_brings_nothing()
	_shows()
	_no_problem()
	_later_pickup_and_phone()
	_rings_out()


func errand(file_name: String, text: String) -> Errand:
	var path := "res://story/errands/%s.errand" % file_name
	var parsed := StoryFormat.parse_errand(text, path)
	check("%s parses" % file_name, parsed.errors, PackedStringArray())
	return parsed.value


func day_of(number: int, errands: Array[Errand]) -> Day:
	var d := Day.new()
	d.number = number
	d.errands = errands
	d.first_wait_seconds = Vector2.ZERO
	d.gap_seconds = Vector2(60.0, 60.0)
	return d


# Lets the next visitor in, up to the counter.
func next_visitor() -> void:
	tick(61.0)
	check("a visitor walks in", game.visitor_state, GAME.VisitorState.WALKING_IN)
	game.customer_arrived()


func see_out() -> void:
	game.dialogue_finished()
	game.customer_left()


func _alternatives() -> void:
	var day_7 := day_of(7, [
		errand("0703_office_girl", "customer: office_girl\ncomputer: none\nwhen: gone_young_entrepreneur\n\n== drop-off\n(neutral) He's gone.\n"),
		errand("0703_young_entrepreneur", "customer: young_entrepreneur\ncomputer: none\nwhen: not gone_young_entrepreneur\n\n== drop-off\n(neutral) I'm back.\n"),
		errand("0704_skater_bro", "customer: skater_bro\ncomputer: none\nwhen: never_set\n\n== drop-off\n(neutral) Never.\n"),
	])
	check("two codes, alternatives share one", day_7.codes(), PackedStringArray(["0703", "0704"]))
	game.start_day(day_7)
	game.open_shop()
	game.customer_arrived()
	check("without the flag, the second alternative comes", [game.visitor.resource_path, game.errand.file_name()], ["res://customers/young_entrepreneur.tres", "0703_young_entrepreneur"])
	see_out()
	check("a code whose alternatives all fail is skipped: the day can close", [game.can_close(), game.arrivals], [true, 1])

	game.set_flag(&"gone_young_entrepreneur")
	game.start_day(day_7)
	game.open_shop()
	game.customer_arrived()
	check("with the flag, the first by file name comes", game.errand.file_name(), "0703_office_girl")
	check("its drop-off plays and is remembered by id", [game.conversation.lines[0].text, game.seen.has("0703/drop-off/1")], ["He's gone.", true])
	see_out()
	game.set_flag(&"gone_young_entrepreneur", 0)


func _dayparts() -> void:
	var dust := "problem: dust_overheat\n\n== drop-off\n(neutral) Hi.\n"
	var day_1 := day_of(1, [
		errand("0101_retired_accountant", "customer: retired_accountant\ncomputer: none\n\n== drop-off\n(neutral) Welcome.\n"),
		errand("0102_skater_bro", "customer: skater_bro\n" + dust),
		errand("0103_office_girl", "customer: office_girl\n" + dust),
		errand("0104_hat_guy", "customer: hat_guy\n" + dust),
	])
	game.restore({"day": 1, "phase": "CLOSED"})
	game.start_day(day_1)
	game.open_shop()
	var dayparts: Array = []
	for i: int in 4:
		if i > 0:
			tick(61.0)
		game.customer_arrived()
		dayparts.append(game.daypart)
		see_out()
	var M := GAME.Daypart.MORNING
	check("the tutorial and the first customer in the morning, then midday and afternoon", dayparts, [M, M, GAME.Daypart.MIDDAY, GAME.Daypart.AFTERNOON])
	check("four errands fit a day", GAME.check_day(day_1), "")


func _brings_nothing() -> void:
	game.restore({"day": 2, "phase": "CLOSED"})
	game.start_day(day_of(2, [errand("0201_office_girl", "customer: office_girl\ncomputer: none\n\n== drop-off\n(neutral) Just saying hi.\n")]))
	game.open_shop()
	check("walks in with empty hands", [game.visitor_state, game.visitor_carries()], [GAME.VisitorState.WALKING_IN, false])
	game.customer_arrived()
	game.dialogue_finished()
	check("walks out after the drop-off, with no computer left", [game.visitor_state, game.visitor_carries(), game.jobs.size()], [GAME.VisitorState.WALKING_OUT, false, 0])
	game.customer_left()

	game.restore({"day": 2, "phase": "CLOSED"})
	game.start_day(day_of(2, [errand("0201_office_girl", "customer: office_girl\ncomputer: none\n\n== drop-off\nset sign_pipedream\n")]))
	game.open_shop()
	game.customer_arrived()
	check("a drop-off without lines sets its flags, and she goes at once", [game.flag(&"sign_pipedream"), game.visitor_state, game.conversation], [1, GAME.VisitorState.WALKING_OUT, null])
	game.customer_left()

	var leaves := errand("0201_office_girl", "customer: office_girl\nproblem: dust_overheat\n\n== drop-off\n(neutral) Fix it.\n")
	var visits := errand("0202_office_girl", "customer: office_girl\ncomputer: none\n\n== drop-off\n(neutral) Is it done?\n")
	game.restore({"day": 2, "phase": "CLOSED"})
	game.start_day(day_of(2, [leaves, visits]))
	game.open_shop()
	game.customer_arrived()
	see_out()
	next_visitor()
	check("she comes without a computer while hers is in the shop", [game.errand, game.jobs.size()], [visits, 1])
	see_out()


func _shows() -> void:
	var shows := errand("0201_hat_guy", "customer: hat_guy\nproblem: dust_overheat\ncomputer: shows\n\n== drop-off\n(neutral) Look at this.\n\n== pick-up\n(happy) I'll take it back.\n")
	game.restore({"day": 2, "phase": "CLOSED"})
	game.start_day(day_of(2, [shows]))
	game.open_shop()
	check("carries it in", game.visitor_carries(), true)
	game.customer_arrived()
	game.dialogue_finished()
	check("it stands on the counter while he waits beside it", [game.visitor_state, game.jobs.size(), game.focus == game.jobs[0], game.visitor_carries()], [GAME.VisitorState.WAITING, 1, true, false])
	check("the phone can't be picked up while he waits", game.pick_up_phone(), false)
	game.connect_cable(game.jobs[0])
	check("the player can connect it", game.connected, game.jobs[0])
	check("a click on him plays his pick-up", [game.talk_to_visitor(), game.visit, game.visitor_state, game.conversation.lines[0].text], [true, GAME.Visit.PICKUP, GAME.VisitorState.TALKING, "I'll take it back."])
	check("only a waiting visitor can be talked to", game.talk_to_visitor(), false)
	game.dialogue_finished()
	check("he leaves with it, unfixed", [game.jobs.size(), game.visitor_state, game.visitor_carries(), game.connected], [0, GAME.VisitorState.WALKING_OUT, true, null])
	game.customer_left()


func _no_problem() -> void:
	game.restore({"day": 6, "phase": "CLOSED"})
	game.start_day(day_of(6, [errand("0603_activist_guy", "customer: activist_guy\n\n== drop-off\n(neutral) Keep it for me.\n")]))
	check("a day with an errand without a problem plays", game.day_number, 6)
	game.open_shop()
	game.customer_arrived()
	see_out()
	var job: Job = game.jobs[0]
	check("its job has no problem and a blank post-it", [job.problem, job.perceived_issue(), job.software_check()], [null, "", null])
	job.hardware_fixed = true
	game.set_software_fixed(job, true)
	check("it can't be fixed, tested or called about", [job.fixed, job.done, game.can_call(), game.next_to_call()], [false, false, false, null])
	game.set_tested(job)
	check("set_tested refuses it", job.tested, false)
	game.restore({"day": 6, "phase": "CLOSED"})


func _later_pickup_and_phone() -> void:
	var first := errand("0101_skater_bro", "customer: skater_bro\nproblem: dust_overheat\n\n== drop-off\n(neutral) Fix it.\n\n== pick-up\n(happy) The day-1 pick-up.\n\n== phone\n(neutral) The day-1 phone.\n")
	var later := errand("0201_skater_bro", "customer: skater_bro\nproblem: no_sound\ncomputer: none\n\n== drop-off\n(neutral) Just me.\n\n== pick-up\n(neutral) The day-2 pick-up.\n")
	game.restore({"day": 1, "phase": "CLOSED"})
	game.start_day(day_of(1, [first]))
	game.open_shop()
	game.customer_arrived()
	see_out()
	game.close_shop()
	game.start_day(day_of(2, [later]))
	game.open_shop()
	game.customer_arrived()
	check("on day 2 he visits without his computer", [game.errand, game.conversation.lines[0].text], [later, "Just me."])
	see_out()
	var job: Job = game.jobs[0]
	check("the job keeps its errand overnight", job.errand, first)
	job.hardware_fixed = true
	game.set_tested(job)
	game.call_customer(job)
	check("the phone plays the job's errand", [game.phase, game.conversation.lines[0].text, game.rings_out()], [GAME.Phase.CALLING, "The day-1 phone.", false])
	game.hang_up()
	game.customer_arrived()
	check("the pick-up on day 2 plays from the day-1 errand", [game.visit, game.errand, game.conversation.lines[0].text], [GAME.Visit.PICKUP, first, "The day-1 pick-up."])
	see_out()


func _rings_out() -> void:
	var silent := errand("0101_hat_guy", "customer: hat_guy\nproblem: dust_overheat\n\n== drop-off\n(neutral) Here.\n\n== phone\n")
	game.restore({"day": 1, "phase": "CLOSED"})
	game.start_day(day_of(1, [silent]))
	game.open_shop()
	game.customer_arrived()
	see_out()
	var job: Job = game.jobs[0]
	job.hardware_fixed = true
	game.set_tested(job)
	game.call_customer(job)
	check("a phone conversation without lines rings out", [game.phase, game.rings_out()], [GAME.Phase.CALLING, true])
	game.hang_up()
	check("the call ends, and nobody comes", [game.phase, game.phone_off_hook, game.visitor, game.jobs.size()], [GAME.Phase.OPEN, false, null, 1])
	tick(1000.0)
	check("still nobody", game.visitor, null)
	check("the phone calls him again", [game.next_to_call() == job, game.answers(job)], [true, false])

	var talker := errand("0102_skater_bro", "customer: skater_bro\nproblem: dust_overheat\n\n== drop-off\n(neutral) Mine too.\n\n== phone\n(neutral) On my way.\n")
	game.restore({"day": 1, "phase": "CLOSED"})
	game.start_day(day_of(1, [silent, talker]))
	game.open_shop()
	for i: int in 2:
		tick(1000.0)
		game.customer_arrived()
		see_out()
	for each: Job in game.jobs:
		each.hardware_fixed = true
		game.set_tested(each)
	var first: Job = game.jobs.filter(func(j: Job) -> bool: return j.errand == silent)[0]
	var second: Job = game.jobs.filter(func(j: Job) -> bool: return j.errand == talker)[0]
	check("the phone calls the one who answers first, though he came later", [first.order < second.order, game.next_to_call() == second], [true, true])
	game.call_customer(second)
	game.hang_up()
	check("he comes", game.visitor, second.customer)
