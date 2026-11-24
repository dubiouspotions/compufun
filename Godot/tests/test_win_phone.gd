extends "res://tests/test.gd"
## The Late corruption sign win_phone turns every desk phone, the one on the counter and the one in
## the call box, into the Windows 95 Modems icon in 3D while sign_win_phone is set and the sign is
## switched on; stage 0, or switching it off, gives the push-button phone back. Day 7 starts it.


func run() -> void:
	var shop: Node = load("res://rooms/shop/shop.tscn").instantiate()
	root.add_child(shop)
	var call_box: Node = load("res://ui/phone_call.tscn").instantiate()
	root.add_child(call_box)
	await process_frame
	var sign: Node = shop.get_node("CorruptionSigns/WinPhone")
	var counter: MeshInstance3D = shop.get_node("Room/PhoneProp/Body")
	var in_call: MeshInstance3D = call_box.find_child("DeskPhone", true, false).get_node("Body")
	var plain := counter.mesh
	var plain_details := counter.get_surface_override_material(1)
	var icon: Mesh = sign.get("mesh")
	check("the Signs list has it, under Late", [sign in shop.get_node("CorruptionSigns").call("every"), sign.get("timing")], [true, 2])
	check("its model is the icon's", icon.resource_path, "res://corruption/win_phone/modem_phone.tres")
	check("both phones plain without the flag", [counter.mesh, in_call.mesh], [plain, plain])

	check("restore day 7 with the flag", game.restore({"day": 7, "phase": "CLOSED", "flags": {"sign_win_phone": 1}}), "")
	check("on: both phones are the icon", [counter.mesh, in_call.mesh], [icon, icon])
	check("in the icon's material", [counter.get_surface_override_material(0), in_call.get_surface_override_material(0)], [sign.get("material"), sign.get("material")])
	check("the counter phone still takes the shop's outline", counter == shop.get("_phone_body"), true)
	sign.set("enabled", false)
	check("switched off: the push-button phone and its materials", [counter.mesh, counter.get_surface_override_material(1), in_call.mesh], [plain, plain_details, plain])
	sign.set("enabled", true)
	check("switched on again: the icon", counter.mesh, icon)
	game.set_flag(&"sign_win_phone", 0)
	check("stage 0: plain", [counter.mesh, in_call.mesh], [plain, plain])

	game.start_day(game.day_of(7))
	check("day 7 starts it", [game.flag(&"sign_win_phone"), counter.mesh], [1, icon])
	call_box.queue_free()
	shop.queue_free()
	await process_frame
