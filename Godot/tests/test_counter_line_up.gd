extends "res://tests/test.gd"
## When a computer leaves the counter, the computers right of it shift left: the counter holds them
## oldest first from slot 0, and the focus, the cable, the open case and its mat go with them.

const SKATER: String = "res://customers/skater_bro.tres"
const ACCOUNTANT: String = "res://customers/retired_accountant.tres"
const ACTIVIST: String = "res://customers/activist_guy.tres"
const HAT_GUY: String = "res://customers/hat_guy.tres"
const OFFICE_GIRL: String = "res://customers/office_girl.tres"
const ENTREPRENEUR: String = "res://customers/young_entrepreneur.tres"


func run() -> void:
	var shop: Node3D = load("res://rooms/shop/shop.tscn").instantiate()
	root.add_child(shop)
	await process_frame
	await _left_one_leaves(shop)
	_middle_one_leaves()
	shop.queue_free()


# The skater's computer in slot 0 leaves; the accountant's (in focus, lying open, a fan on its mat)
# and the activist's (on the cable) slide one slot left.
func _left_one_leaves(shop: Node3D) -> void:
	var open_parts := {"cpu": "cpu", "gpu": "gpu", "hard_drive": "hard_drive", "motherboard": "motherboard", "ram_1": "ram", "ram_2": "ram"}
	check("restore three computers, the skater picks up", game.restore({"day": 1, "arrivals": 3, "jobs": [
		{"customer": SKATER, "problem": "dust_overheat", "slot": 0, "order": 0, "hardware_fixed": true, "software_fixed": true},
		{"customer": ACCOUNTANT, "problem": "no_sound", "slot": 1, "order": 1, "case_open": true, "panel_screws": [false, false], "parts": open_parts, "mat": ["fan"]},
		{"customer": ACTIVIST, "problem": "bad_ram", "slot": 2, "order": 2, "powered": true},
	], "focus_slot": 1, "connected_slot": 2, "visitor": SKATER, "visit": "PICKUP", "visitor_state": "TALKING", "view": "Main"}), "")
	await create_timer(0.5).timeout
	var accountant: Job = game.jobs[1]
	var activist: Job = game.jobs[2]
	game.dialogue_finished()
	check("slot, order", [slots(), accountant.order, activist.order], [["Retired accountant@0", "Activist guy@1"], 1, 2])
	check("focus, cable, open case and mat stay with their computers",
			[game.focus == accountant, game.connected == activist, accountant.lying, accountant.case_open, Job.pieces_data(accountant.mat), activist.powered],
			[true, true, true, true, ["fan"], true])
	check("the snapshot names the new slots", [game.snapshot()["focus_slot"], game.snapshot()["connected_slot"]], [0, 1])
	await process_frame
	var accountant_pc := computer_of(shop, accountant)
	check("the accountant's computer is under Slot0 and on its way there", [accountant_pc.get_parent().name, accountant_pc.position.is_zero_approx()], [&"Slot0", false])

	await create_timer(1.0).timeout
	var activist_pc := computer_of(shop, activist)
	check("both stand on their new slots", [accountant_pc.position.is_zero_approx(), activist_pc.get_parent().name, activist_pc.position.is_zero_approx()], [true, &"Slot1", true])
	var plug: Node3D = shop.find_child("Bench", true, false).get_node("%Plug")
	var socket: Node3D = activist_pc.cable_socket()
	check("the cable's plug is in the activist's socket", plug.global_position.distance_to(socket.global_position) < 0.001, true)
	var mat: Node3D = accountant_pc.get_node("OpenCase/Mat")
	var slot0: Node3D = shop.find_child("Slot0", true, false)
	check("the mat moved with the accountant's computer", absf(mat.global_position.x - slot0.global_position.x) < 0.5, true)


# The office girl's computer in the middle leaves: the hat guy's stays in slot 0, the entrepreneur's
# moves to slot 1, and the next drop-off goes right of them, in slot 2.
func _middle_one_leaves() -> void:
	check("restore three computers, the office girl picks up", game.restore({"day": 1, "arrivals": 3, "jobs": [
		{"customer": HAT_GUY, "problem": "dust_overheat", "slot": 0, "order": 4},
		{"customer": OFFICE_GIRL, "problem": "dust_overheat", "slot": 1, "order": 5, "hardware_fixed": true, "software_fixed": true},
		{"customer": ENTREPRENEUR, "problem": "no_sound", "slot": 2, "order": 6},
	], "focus_slot": 2, "connected_slot": 0, "visitor": OFFICE_GIRL, "visit": "PICKUP", "visitor_state": "TALKING"}), "")
	var hat_guy: Job = game.jobs[0]
	var entrepreneur: Job = game.jobs[2]
	game.dialogue_finished()
	check("the left one stays, the right one shifts left", slots(), ["Hat guy@0", "Young entrepreneur@1"])
	check("focus and cable stay on their computers", [game.focus == entrepreneur, game.connected == hat_guy], [true, true])
	game.customer_left()
	tick(1000.0)
	check("the activist comes in", game.visitor != null and game.visitor.resource_path == ACTIVIST, true)
	game.customer_arrived()
	game.dialogue_finished()
	check("the newest drop-off stands rightmost", [slots(), game.jobs[2].order > entrepreneur.order], [["Hat guy@0", "Young entrepreneur@1", "Activist guy@2"], true])


## The jobs on the counter as "<customer>@<slot>", in the order of [member Game.jobs].
func slots() -> Array:
	return game.jobs.map(func(j: Job) -> String: return "%s@%d" % [j.customer.display_name, j.slot])


func computer_of(shop: Node3D, job: Job) -> Node3D:
	for node: Node in shop.find_children("*", "JobComputer", true, false):
		if node.get("job") == job:
			return node
	push_error("no JobComputer shows the job of %s" % job.customer.display_name)
	return null
