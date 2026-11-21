extends "res://tests/test.gd"
## Plays two days through the Game API: drop-offs, a full counter that holds back the next
## customer, focus, fixes, post-its, calling a chosen customer, the pickup, closing the shop, and the
## next day from the day files.

const GAME := preload("res://game.gd")
const OPEN := GAME.Phase.OPEN
const WALKING_IN := GAME.VisitorState.WALKING_IN
const TALKING := GAME.VisitorState.TALKING


func run() -> void:
	var hardware: Problem = load("res://problems/dust_overheat.tres")
	var software: Problem = load("res://problems/no_sound.tres")
	var both := Problem.new()
	both.short_name = &"both_test"
	both.location = Problem.Location.BOTH
	var o1 := customer("O1", hardware, false)
	var o2 := customer("O2", hardware, false)
	var a := customer("A", hardware, true)
	var b := customer("B", software, false)
	var c := customer("C", both, true)

	# A day with more than MAX_CUSTOMERS is refused with an error.
	game.start_day(make_day(9, [o1, o2, a, b]))
	check("too many customers: still IDLE", [game.phase, game.day], [GAME.Phase.IDLE, null])

	# Day 1: two drop-offs stay overnight.
	game.start_day(make_day(1, [o1, o2]))
	check("open, morning, first customer at once", [game.phase, game.daypart, game.arrivals], [OPEN, GAME.Daypart.MORNING, 1])
	tick(1000.0)
	check("no arrival while a visitor is in", game.arrivals, 1)
	check("can't close with a visitor in", game.can_close(), false)
	drop_off("O1")
	check("O1 in slot 0, focused", [slots(), game.focus == job_of("O1")], [["O1@0"], true])
	tick(59.0)
	check("59 s: nobody yet", game.arrivals, 1)
	tick(2.0)
	check("61 s: O2 comes, midday", [game.arrivals, game.daypart], [2, GAME.Daypart.MIDDAY])
	drop_off("O2")
	check("O2 in slot 1, focus stays", [slots(), game.focus == job_of("O1")], [["O1@0", "O2@1"], true])
	check("can close after every customer", game.can_close(), true)
	game.close_shop()
	check("DAY_OVER, evening, jobs stay", [game.phase, game.daypart, game.jobs.size()], [GAME.Phase.DAY_OVER, GAME.Daypart.EVENING, 2])
	tick(1000.0)
	check("nothing happens at night", [game.phase, game.visitor], [GAME.Phase.DAY_OVER, null])

	# Day 2: three drop-offs, the counter fills.
	game.start_day(make_day(2, [a, b, c]))
	check("morning, A walks in", [game.phase, game.daypart, game.visitor == a], [OPEN, GAME.Daypart.MORNING, true])
	drop_off("A")
	tick(61.0)
	drop_off("B")
	check("counter full", slots(), ["O1@0", "O2@1", "A@2", "B@3"])
	tick(1000.0)
	check("a full counter holds back the arrival", [game.arrivals, game.visitor, game.daypart], [2, null, GAME.Daypart.MIDDAY])
	check("can't close before C came in", game.can_close(), false)

	# Fixes per location. Two of these steps log an error on purpose.
	var job_a := job_of("A")
	var job_b := job_of("B")
	game.focus_job(job_a)
	check("focus A", game.focus == job_a, true)
	game.fix(Problem.Location.HARDWARE)
	check("A hardware fixed, A fixed", [job_a.hardware_fixed, job_a.fixed], [true, true])
	game.fix(Problem.Location.SOFTWARE)
	check("software fix with no cable changes nothing", [job_a.software_fixed, job_b.software_fixed], [false, false])
	game.connect_cable(job_b)
	game.fix(Problem.Location.SOFTWARE)
	check("B software fixed via the cable, focus stays A", [job_b.fixed, game.focus == job_a], [true, true])
	check("A and B are ready for pickup, O1 isn't", [job_a.fixed, job_b.fixed, job_of("O1").fixed], [true, true, false])

	game.set_software_fixed(job_b, false)
	check("B's software breaks again: B isn't ready", [job_b.fixed, game.can_call()], [false, true])
	game.set_software_fixed(job_b, true)
	game.set_powered(job_a, true)
	check("power is per job", [job_a.powered, job_b.powered, job_b.fixed], [true, false, true])

	# The player calls A, whose computer is fixed.
	check("can call", game.can_call(), true)
	var changes: Array[int] = [0]
	game.changed.connect(func() -> void: changes[0] += 1)
	game.call_customer(job_of("O1"))
	check("O1 isn't fixed: no call", game.phase, OPEN)
	game.call_customer(job_a)
	check("CALLING A, changed fired", [game.phase, game.calling == job_a, changes[0] > 0], [GAME.Phase.CALLING, true, true])
	check("can't call twice", game.can_call(), false)
	tick(1000.0)
	check("the call lasts until hang up", [game.phase, game.visitor], [GAME.Phase.CALLING, null])
	game.hang_up()
	check("hung up: A walks in for PICKUP", [game.phase, game.visitor == a, game.visit, game.visitor_state], [OPEN, true, GAME.Visit.PICKUP, WALKING_IN])
	game.customer_arrived()
	check("A has a pickup conversation: TALKING", game.visitor_state, TALKING)
	game.dialogue_finished()
	game.customer_left()
	check("A's job left, focus cleared, cable stays on B", [slots(), game.focus, game.connected == job_b], [["O1@0", "O2@1", "B@3"], null, true])

	# The freed place lets C in after the gap.
	tick(59.0)
	check("59 s: nobody yet", game.arrivals, 2)
	tick(2.0)
	check("C comes, afternoon", [game.arrivals, game.daypart], [3, GAME.Daypart.AFTERNOON])
	drop_off("C")
	check("C in the free slot 2, focused", [slots(), game.focus == job_of("C")], [["O1@0", "O2@1", "B@3", "C@2"], true])

	# B has no pickup conversation and takes the computer at once.
	game.call_customer(job_of("B"))
	game.hang_up()
	check("B walks in for PICKUP", [game.visitor == b, game.visit], [true, GAME.Visit.PICKUP])
	game.customer_arrived()
	check("can't close while B walks out with the computer", [game.visitor_state, game.can_close()], [GAME.VisitorState.WALKING_OUT, false])
	game.customer_left()
	check("B left with the job, cable cleared", [game.visitor, slots(), game.connected], [null, ["O1@0", "O2@1", "C@2"], null])

	check("can close", game.can_close(), true)
	game.close_shop()
	check("DAY_OVER, evening, 3 jobs overnight", [game.phase, game.daypart, game.jobs.size()], [GAME.Phase.DAY_OVER, GAME.Daypart.EVENING, 3])

	# The next day comes from its file; the jobs stay overnight; day 7 is the last.
	var overnight := [{"customer": "res://customers/skater_bro.tres", "slot": 2}]
	check("restore day 1, closed", game.restore({"day": 1, "phase": "DAY_OVER", "arrivals": 2, "jobs": overnight}), "")
	check("day 1 has a next day", game.has_next_day(), true)
	game.start_next_day()
	check("day 2: open, morning, nobody in yet, the job stayed", [game.day_number, game.phase, game.daypart, game.arrivals, slots()], [2, OPEN, GAME.Daypart.MORNING, 0, ["Skater bro@2"]])
	check("restore day 7", game.restore({"day": 7, "phase": "DAY_OVER", "arrivals": 2}), "")
	check("day 7 is the last", game.has_next_day(), false)


func customer(display_name: String, problem: Problem, has_pickup: bool) -> Customer:
	var c := Customer.new()
	c.display_name = display_name
	c.problem = problem
	var triggers: Array[Conversation.Trigger] = [Conversation.Trigger.ARRIVE]
	if has_pickup:
		triggers.append(Conversation.Trigger.PICKUP)
	for trigger: Conversation.Trigger in triggers:
		var conversation := Conversation.new()
		conversation.trigger = trigger
		var line := DialogueLine.new()
		line.text = "%s says %s" % [display_name, Conversation.Trigger.find_key(trigger)]
		conversation.lines = [line]
		c.conversations.append(conversation)
	return c


func make_day(number: int, customers: Array[Customer]) -> Day:
	var d := Day.new()
	d.number = number
	d.customers = customers
	d.first_wait_seconds = Vector2.ZERO
	d.gap_seconds = Vector2(60.0, 60.0)
	return d


func drop_off(who: String) -> void:
	check("%s walking in" % who, [game.visitor.display_name, game.visit, game.visitor_state], [who, GAME.Visit.DROP_OFF, WALKING_IN])
	game.customer_arrived()
	check("%s talking" % who, game.visitor_state, TALKING)
	game.dialogue_finished()
	game.customer_left()
	check("%s left" % who, [game.visitor, game.visit, game.visitor_state], [null, GAME.Visit.NONE, GAME.VisitorState.NONE])


func job_of(who: String) -> Job:
	for j: Job in game.jobs:
		if j.customer.display_name == who:
			return j
	return null


## The jobs on the counter as "<customer>@<slot>", oldest first.
func slots() -> Array:
	return game.jobs.map(func(j: Job) -> String: return "%s@%d" % [j.customer.display_name, j.slot])
