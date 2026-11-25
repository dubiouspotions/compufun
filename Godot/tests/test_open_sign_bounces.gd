extends "res://tests/test.gd"
## Closing the shop on day 5: the Open sign turns over in its place, then it is the first sheet of
## posters_bounce to leave its place, showing its closed-shop side; its trail shows that side over its back.

const FLAG: StringName = &"sign_posters_bounce"


func run() -> void:
	var shop: Node3D = load("res://rooms/shop/shop.tscn").instantiate()
	root.add_child(shop)
	await process_frame
	var errands: int = game.day_of(5).codes().size()
	check("restore day 5 with everyone in", game.restore({"day": 5, "arrivals": errands, "phase": "OPEN"}), "")
	await process_frame
	var sign: Node3D = shop.get_node("%OpenSign")
	var logo: Node3D = shop.get_node("Room/SignLeft")
	var home := sign.global_transform
	var logo_home := logo.global_position
	var flip: float = sign.get("flip_seconds")
	var board: MeshInstance3D = sign.get_node("%Board")
	game.close_shop()
	check("closing day 5 starts the bounce", game.flag(FLAG), 1)
	var started := now()
	var turned := false
	var moved_while_turning := false
	var sign_left := -1.0
	var logo_left := -1.0
	var side_when_left: Texture2D = null
	while sign_left < 0.0 or logo_left < 0.0:
		await process_frame
		var since := now() - started
		if since < flip and sign.global_position != home.origin:
			moved_while_turning = true
		if since < flip and not is_zero_approx(sign.rotation.y):
			turned = true
		if sign_left < 0.0 and sign.global_position != home.origin:
			sign_left = since
			side_when_left = (board.material_override as ShaderMaterial).get_shader_parameter("albedo_texture")
		if logo_left < 0.0 and logo.global_position != logo_home:
			logo_left = since
		if since > 30.0:
			break
	check("the sign turns over as the shop closes", turned, true)
	check("it stays in its place while it turns", moved_while_turning, false)
	check("then it leaves its place, first", [sign_left > flip, sign_left >= 0.0 and sign_left < logo_left], [true, true])
	check("it shows the closed shop's side", side_when_left == sign.get("open_texture"), true)
	var back: MeshInstance3D = sign.get_node("Back")
	var face_over := -INF
	var back_over := -INF
	for copy: Node in shop.find_child("PostersBounce", true, false).get_node("%Trail").get_children():
		if copy is MeshInstance3D and (copy as MeshInstance3D).mesh == board.mesh:
			face_over = maxf(face_over, (copy as MeshInstance3D).sorting_offset)
		elif copy is MeshInstance3D and (copy as MeshInstance3D).mesh == back.mesh:
			back_over = maxf(back_over, (copy as MeshInstance3D).sorting_offset)
	check("its last copy layers its face over its back", [back_over > -INF, face_over > back_over], [true, true])
	game.set_flag(FLAG, 0)
	await process_frame
	check("stage 0 hangs it back", sign.global_transform.is_equal_approx(home), true)
	shop.queue_free()
