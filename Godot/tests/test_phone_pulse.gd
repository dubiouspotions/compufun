extends "res://tests/test.gd"
## While a click on the phone would place a call (Game.can_call), its outline pulses in the Open
## sign's colour and rhythm, light blue under the mouse; otherwise it is dark: with no computer done,
## off the hook, and while a visitor, also one who pops up for an event, is in the shop.

const GAME := preload("res://game.gd")
const MIDDAY := {"day": 1, "arrivals": 3, "focus_slot": 0, "view": "Main",
	"seen": ["0101/drop-off/1", "0102/drop-off/1", "0103/drop-off/1"],
	"jobs": [{"errand": "0102_skater_bro", "slot": 0}, {"errand": "0103_retired_accountant", "slot": 1, "order": 1}]}


func run() -> void:
	var shop: Node = load("res://rooms/shop/shop.tscn").instantiate()
	root.add_child(shop)
	await process_frame
	var phone: Area3D = shop.get_node("%Phone")
	var body: MeshInstance3D = shop.get_node("Room/PhoneProp/Body")
	var look: ClickableOutline = shop.get_node("%OpenSign").get("outline")  # OpenSign names Game, which doesn't compile under -s
	var pulse: StandardMaterial3D = shop.get("_phone_pulse_outline")
	check("restore day 1 with no computer done", game.restore(MIDDAY), "")
	check("nothing to call about: dark", [game.can_call(), body.material_overlay == null], [false, true])

	var done := MIDDAY.duplicate(true)
	done["jobs"][1].merge({"hardware_fixed": true, "software_fixed": true, "tested": true})
	check("restore with the old dude's computer done", game.restore(done), "")
	check("a click calls: it pulses", [game.can_call(), body.material_overlay], [true, pulse])
	check("the phone's outline looks like the Open sign's", shop.get("phone_outline"), look)
	check("in its colour", [pulse.albedo_color.r, pulse.albedo_color.g, pulse.albedo_color.b], [look.pulse_color.r, look.pulse_color.g, look.pulse_color.b])
	var alphas := {}
	for i: int in int(look.pulse_seconds * FPS):
		alphas[snappedf(pulse.albedo_color.a, 0.1)] = true
		await process_frame
	check("from full down to the sign's low and back", [alphas.has(1.0), alphas.has(snappedf(look.pulse_low, 0.1))], [true, true])
	phone.mouse_entered.emit()
	check("under the mouse, the light blue outline", body.material_overlay, shop.get("_phone_outline"))
	phone.mouse_exited.emit()

	check("pick up the receiver", game.pick_up_phone(), true)
	check("off the hook: dark", body.material_overlay == null, true)
	game.put_down_phone()
	check("back on the hook: it pulses", body.material_overlay, pulse)

	var event := done.duplicate(true)
	event.merge({"visitor": "res://customers/skater_bro.tres", "visit": "EVENT", "visitor_state": "POPPING_UP"})
	check("restore the skater popping up for his event", game.restore(event), "")
	check("while he's in the shop: dark", [game.can_call(), body.material_overlay == null], [false, true])
	shop.queue_free()
	await process_frame
