extends "res://tests/test.gd"
## A monitor's picture lights its own bezel: %ScreenLight sits in front of the screen, reaches the
## bezel's corners, and follows the tube: on with the picture, off while the tube is off or blanked.


func run() -> void:
	var monitor: Node3D = load("res://props/crt_monitor.tscn").instantiate()
	root.add_child(monitor)
	await process_frame
	var light: OmniLight3D = monitor.get_node("%ScreenLight")
	check("a monitor that shows nothing casts no screen light", light.visible, false)

	var image := Image.create(4, 3, false, Image.FORMAT_RGB8)
	image.fill(Color.WHITE)
	var look: ShaderMaterial = monitor.set_screen_texture(ImageTexture.create_from_image(image))
	for uniform: StringName in [&"crt_power", &"crt_warmup", &"crt_sync", &"crt_picture"]:  # a CrtTube's start
		look.set_shader_parameter(uniform, 1.0)
	look.set_shader_parameter(&"crt_blank", 0.0)
	await process_frame
	await process_frame
	check("a warm, locked tube lights the bezel", [light.visible, is_equal_approx(light.light_energy, monitor.screen_light_energy)], [true, true])

	var screen: Node3D = monitor.get_node("%Screen")
	var front: MeshInstance3D = monitor.get_node("Front")
	var half := (front.mesh as BoxMesh).size * 0.5
	var face_z := front.position.z + half.z
	check("the light is in front of the screen and the bezel", light.position.z > maxf(screen.position.z, face_z), true)
	var far := 0.0
	for corner: Vector3 in [Vector3(-half.x, -half.y, half.z), Vector3(half.x, half.y, half.z)]:
		far = maxf(far, light.position.distance_to(front.position + corner))
	check("the light reaches the bezel's corners", far < light.omni_range, true)

	for off: Array in [[&"crt_power", 0.0], [&"crt_blank", 1.0]]:
		look.set_shader_parameter(off[0], off[1])
		await process_frame
		check("%s %s: the screen light is off" % off, light.visible, false)
		look.set_shader_parameter(off[0], 1.0 - off[1])
	await process_frame
	check("back on with the picture", light.visible, true)
	monitor.queue_free()
