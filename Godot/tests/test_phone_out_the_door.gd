extends "res://tests/test.gd"
## The phone works as soon as the visitor who walks out passes the door (OUTSIDE), before they are out
## of sight; a call goes on when they leave the scene, and the outline (hovered or pulsing) shows only
## while the phone works.

const GAME := preload("res://game.gd")
const WALK_SECONDS: float = 2.0


func run() -> void:
	var shop: Node = load("res://rooms/shop/shop.tscn").instantiate()
	shop.walk_seconds = WALK_SECONDS
	root.add_child(shop)
	await process_frame
	var phone: Area3D = shop.get_node("%Phone")
	var body: MeshInstance3D = shop.get_node("Room/PhoneProp/Body")
	var day: Day = computer_day(1)
	day.first_wait_seconds = Vector2.ZERO
	game.start_day(day)
	game.open_shop()
	await create_timer(WALK_SECONDS * 1.5).timeout
	check("the visitor reaches the counter", game.visitor_state, GAME.VisitorState.TALKING)
	game.dialogue_finished()
	var job: Job = game.jobs[0]
	job.hardware_fixed = true
	job.software_fixed = true
	game.set_tested(job)
	phone.mouse_entered.emit()
	check("walking out, the phone doesn't work", [game.visitor_state, game.can_call(), phone.input_ray_pickable, body.material_overlay == null], [GAME.VisitorState.WALKING_OUT, false, false, true])

	while game.visitor_state == GAME.VisitorState.WALKING_OUT and now() < WALK_SECONDS * 4.0:
		await process_frame
	check("out the door, the phone works and the hovered phone is outlined", [game.visitor_state, game.visitor != null, game.can_call(), phone.input_ray_pickable, body.material_overlay != null], [GAME.VisitorState.OUTSIDE, true, true, true, true])
	check("in light blue", body.material_overlay, shop.get("_phone_outline"))
	phone.mouse_exited.emit()
	check("without the mouse, it pulses like the Open sign", body.material_overlay, shop.get("_phone_pulse_outline"))
	phone.mouse_entered.emit()

	game.call_customer(job)
	check("the call starts while the visitor walks away", [game.phase, game.visitor_state], [GAME.Phase.CALLING, GAME.VisitorState.OUTSIDE])
	check("off the hook, the phone isn't outlined", body.material_overlay == null, true)
	var snapshot: Dictionary = game.snapshot()
	snapshot["arrivals"] = game.day_of(1).codes().find(game.errand.code) + 1  # its place in the whole day, which restore reads
	check("a snapshot of the call restores", game.restore(snapshot), "")
	var conversation: Variant = game.conversation
	while game.visitor != null and game.visitor_state == GAME.VisitorState.OUTSIDE and now() < WALK_SECONDS * 8.0:
		await process_frame
	check("the visitor leaves the scene and the call goes on", [game.visitor, game.phase, game.conversation == conversation], [null, GAME.Phase.CALLING, true])
	game.hang_up()
	check("the called customer comes back", [game.visitor_state, game.visit], [GAME.VisitorState.WALKING_IN, GAME.Visit.PICKUP])
	shop.queue_free()
