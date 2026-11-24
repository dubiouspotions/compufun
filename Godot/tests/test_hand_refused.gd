extends "res://tests/test.gd"
## A take that only the piece in the hand stops (Game.hand_refused) shakes the part in the hand
## sideways: a storage box, a piece in the open case, a misplaced one and the mat. A take
## that an empty hand wouldn't make either (a piece under another) refuses nothing. With a full hand,
## the case's pieces take the click but show no outline.

const SKATER: String = "res://customers/skater_bro.tres"


func run() -> void:
	var shop: Node3D = load("res://rooms/shop/shop.tscn").instantiate()
	root.add_child(shop)
	await process_frame
	var hand: Node3D = shop.get_node("%Hand")
	var refused := [0]
	game.hand_refused.connect(func() -> void: refused[0] += 1)
	var fan: Part = load("res://parts/fan.tres")
	var cpu: Part = load("res://parts/cpu.tres")
	var gpu: Part = load("res://parts/gpu.tres")
	var drive: Part = load("res://parts/hard_drive.tres")
	check("restore an open case", game.restore({"day": 1, "phase": "OPEN", "focus_slot": 0, "view": "Workview", "jobs": [{"customer": SKATER, "problem": "dust_overheat", "slot": 0, "case_open": true, "panel_screws": [false, false]}]}), "")
	var job: Job = game.jobs[0]

	check("an empty hand takes a new fan", [game.take_new_part(fan), refused[0], hand.call("is_shaking")], [true, 0, false])
	check("a full hand takes no CPU from storage, and the fan shakes", [game.take_new_part(cpu), game.hand.part, refused[0], hand.call("is_shaking")], [false, fan, 1, true])
	await create_timer(float(hand.get("shake_seconds")) / 4.0).timeout
	check("it swings sideways mid-shake", absf(float(hand.get("_shake_progress")) - 0.25) < 0.05, true)
	await create_timer(float(hand.get("shake_seconds"))).timeout
	check("the shake ends", hand.call("is_shaking"), false)

	check("the graphics card would come out: refused", [game.take_part(job, gpu), job.piece(gpu) != null, refused[0]], [false, true, 2])
	check("the CPU is under the fan: not refused", [game.take_part(job, cpu), refused[0]], [false, 2])
	var case: Node = shop.find_children("*", "OpenCase", true, false)[0]
	var place: Hotspot = case.call("_place", gpu).get_node("Hotspot")
	var shown: Node3D = case.get("_shown")[gpu.id()]
	var outlined := shown.find_children("*", "MeshInstance3D", true, false).any(func(m: MeshInstance3D) -> bool: return m.material_overlay != null)
	check("the graphics card takes the click, unoutlined", [place.input_ray_pickable, outlined], [true, false])
	place.clicked.emit(place)
	check("a click on it shakes the fan", [game.hand.part, refused[0], hand.call("is_shaking")], [fan, 3, true])

	game.put_on_mat(job)
	game.take_new_part(cpu)
	check("the mat's fan: refused", [game.take_from_mat(job, 0), refused[0]], [false, 4])
	game.trash_part()
	game.take_new_part(gpu)

	var storage := shop.find_children("*", "Area3D", true, false).filter(func(h: Node) -> bool: return h is Hotspot and h.action == Hotspot.Action.TAKE_PART)
	var cpu_box: Hotspot = storage.filter(func(h: Hotspot) -> bool: return h.part == cpu)[0]
	var gpu_box: Hotspot = storage.filter(func(h: Hotspot) -> bool: return h.part == gpu)[0]
	cpu_box.clicked.emit(cpu_box)
	check("a click on the CPU box shakes the new graphics card", [game.hand.part, refused[0]], [gpu, 5])
	gpu_box.clicked.emit(gpu_box)
	check("its own box takes it back", [game.hand, refused[0]], [null, 5])

	check("restore a misplaced drive", game.restore({"day": 1, "phase": "OPEN", "jobs": [{"customer": SKATER, "problem": "dust_overheat", "slot": 0, "case_open": true, "panel_screws": [false, false], "misplaced": {"cpu": "hard_drive"}, "parts": {"fan": "fan!", "gpu": "gpu", "motherboard": "motherboard", "ram_1": "ram", "ram_2": "ram"}}]}), "")
	job = game.jobs[0]
	game.take_new_part(fan)
	check("the misplaced drive: refused", [game.take_misplaced(job, cpu), job.misplaced[cpu].part, refused[0]], [false, drive, 6])
	shop.queue_free()
	await process_frame
