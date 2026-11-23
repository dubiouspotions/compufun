extends "res://tests/test.gd"
## A click on the phone while the shop is closed and a computer is done shakes the Open sign instead
## of calling, with a rattle; with the shop open, the sign stays still. With nothing done, the phone
## takes no clicks and shows no outline.

const SKATER: String = "res://customers/skater_bro.tres"


func run() -> void:
	var shop: Node = load("res://rooms/shop/shop.tscn").instantiate()
	root.add_child(shop)
	await process_frame
	var phone: Area3D = shop.get_node("%Phone")
	var sign: Node3D = shop.get_node("%OpenSign")
	var requested := [0]
	shop.connect("phone_requested", func() -> void: requested[0] += 1)
	var done_job := {"customer": SKATER, "problem": "dust_overheat", "slot": 0, "hardware_fixed": true, "software_fixed": true}

	check("restore closed, nothing done", game.restore({"day": 2, "phase": "CLOSED", "jobs": [{"customer": SKATER, "problem": "dust_overheat", "slot": 0}]}), "")
	phone.emit_signal("clicked", phone)
	check("closed, nothing done: no clicks, no shake, no call", [phone.input_ray_pickable, sign.call("is_shaking"), requested[0]], [false, false, 0])

	var body: MeshInstance3D = shop.get_node("Room/PhoneProp/Body")
	check("restore open, nothing done", game.restore({"day": 2, "phase": "OPEN", "jobs": [{"customer": SKATER, "problem": "dust_overheat", "slot": 0}]}), "")
	phone.mouse_entered.emit()
	phone.emit_signal("clicked", phone)
	check("open, nothing done: no clicks, no outline, no call", [phone.input_ray_pickable, body.material_overlay == null, requested[0], game.phone_off_hook], [false, true, 0, false])
	phone.mouse_exited.emit()

	check("restore closed, one done", game.restore({"day": 2, "phase": "CLOSED", "jobs": [done_job]}), "")
	phone.emit_signal("clicked", phone)
	check("closed with a done computer: the sign shakes, no call", [phone.input_ray_pickable, sign.call("is_shaking"), requested[0], game.phase], [true, true, 0, game.Phase.CLOSED])
	var rattle: SoundSet = sign.get("rattle_sound")
	check("it rattles", sign.get_children().filter(func(n: Node) -> bool: return n is AudioStreamPlayer3D and n.stream in rattle.sounds).size(), 1)
	await create_timer(float(sign.get("shake_seconds")) / 2.0).timeout
	check("it swings mid-shake", absf(sign.rotation.z) > 0.0, true)
	phone.emit_signal("clicked", phone)
	await create_timer(float(sign.get("shake_seconds")) * 0.75).timeout
	check("a second click starts the shake over", sign.call("is_shaking"), true)
	await create_timer(float(sign.get("shake_seconds"))).timeout
	check("the shake ends with the sign at rest", [sign.call("is_shaking"), is_zero_approx(sign.rotation.z)], [false, true])

	check("restore open, one done", game.restore({"day": 2, "phase": "OPEN", "jobs": [done_job]}), "")
	phone.emit_signal("clicked", phone)
	check("open: the phone calls, no shake", [phone.input_ray_pickable, sign.call("is_shaking"), requested[0]], [true, false, 1])
	shop.queue_free()
	await process_frame
