extends "res://tests/test.gd"
## The Late corruption sign win95_boxes turns every box on the wall shelving into a Windows 95 box
## while sign_win95_boxes is set and the sign is switched on; stage 0, or switching it off, gives the
## plain goods back.


func run() -> void:
	var shop: Node = load("res://rooms/shop/shop.tscn").instantiate()
	root.add_child(shop)
	await process_frame
	var sign: Node = shop.get_node("CorruptionSigns/Win95Boxes")
	var shelf: MeshInstance3D = shop.get_node("Room/WallShelf")
	var goods := func() -> Material: return shelf.get_surface_override_material(2)
	var plain: Material = goods.call()
	var boxes: ShaderMaterial = sign.get("boxes")
	check("the Signs list has it, under Late", [sign in shop.get_node("CorruptionSigns").call("every"), sign.get("timing")], [true, 2])
	check("plain without its flag", plain.resource_path, "res://materials/shop_goods.tres")
	check("its boxes use the Windows 95 goods", (boxes.get_shader_parameter("albedo_texture") as Texture2D).resource_path, "res://corruption/win95_boxes/goods.png")

	check("restore day 6 with the flag", game.restore({"day": 6, "phase": "CLOSED", "flags": {"sign_win95_boxes": 1}}), "")
	check("on: every box is a Windows 95 box", goods.call(), boxes)
	sign.set("enabled", false)
	check("switched off: plain", goods.call(), plain)
	sign.set("enabled", true)
	check("switched on again: Windows 95", goods.call(), boxes)
	game.set_flag(&"sign_win95_boxes", 0)
	check("stage 0: plain", goods.call(), plain)
	shop.queue_free()
	await process_frame
