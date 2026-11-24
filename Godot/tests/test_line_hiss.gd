extends "res://tests/test.gd"
## The line hisses under a phone call from the customer's answer to the hang-up, and stays quiet while
## the phone rings and once it is down.


func run() -> void:
	var errand: Errand = StoryFormat.parse_errand("customer: activist_guy\nproblem: dust_overheat\n\n== drop-off\n(neutral) Here.\n\n== phone\n(neutral) Oh, it's ready? Great.\n", "res://story/errands/9901_line_hiss.errand").value
	var phone: Node = load("res://ui/phone_call.tscn").instantiate()
	root.add_child(phone)
	await process_frame
	var hiss: AudioStreamPlayer = phone.get_node("%LineHiss")
	check("the hiss loops", (hiss.stream as AudioStreamOggVorbis).loop, true)
	game.restore({"day": 1, "phase": "CLOSED"})
	game.start_day(make_day(1, [[errand.customer, errand.problem, errand.conversations]]))
	game.open_shop()
	game.customer_arrived()
	game.dialogue_finished()
	game.customer_left()
	var job: Job = game.jobs[0]
	job.hardware_fixed = true
	game.set_tested(job)
	game.call_customer(job)
	phone.call(&"_process", 0.1)
	check("quiet while it rings", hiss.playing, false)
	phone.call(&"_process", phone.get(&"ring_seconds"))
	phone.call(&"_process", 0.0)
	check("the line hisses once the customer answers", hiss.playing, true)
	game.hang_up()
	phone.call(&"_process", 0.0)
	check("quiet once the phone is down", hiss.playing, false)
	phone.queue_free()
	await process_frame
