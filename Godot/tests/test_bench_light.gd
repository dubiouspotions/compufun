extends "res://tests/test.gd"
## The bench monitor's front faces away from every ceiling light. Once the ceiling lights are on,
## their bounce still lights it: it goes dark with them in a flicker, and comes back in full after.


func run() -> void:
	var shop: Node3D = load("res://rooms/shop/shop.tscn").instantiate()
	root.add_child(shop)
	await process_frame
	var ceiling_lights := get_nodes_in_group(&"ceiling_lights")  # CeilingLight names Game, which a test can't
	for node: Node in ceiling_lights:
		node.set(&"flickers_per_minute", PackedFloat32Array())  # no random flicker mid-check
	var monitor: Node3D = shop.get_node("%Bench").find_child("Monitor", true, false)
	check("the bench has a monitor", monitor != null, true)
	if monitor == null:
		return

	check("restore the morning", game.restore({"daypart": "MORNING"}), "")
	await create_timer(2.0).timeout
	check("by day the ceiling lights are off, and nothing of theirs reaches the front", _light_on_front(shop, monitor), 0.0)

	check("restore the afternoon", game.restore({"arrivals": 3, "daypart": "AFTERNOON"}), "")
	await create_timer(2.0).timeout
	var lit := _light_on_front(shop, monitor)
	check("in the afternoon a ceiling light's bounce reaches the front", lit > 0.0, true)

	var in_the_dark: Array[float] = []
	ceiling_lights[0].get_script().call(&"cover", self, func() -> void: in_the_dark.append(_light_on_front(shop, monitor)))
	await create_timer(3.0).timeout
	check("it goes dark with the ceiling lights", in_the_dark, [0.0])
	check("after the flicker it is back in full", is_equal_approx(_light_on_front(shop, monitor), lit), true)
	shop.queue_free()


# The summed energy of [param shop]'s lit omni and spot lights, besides the monitor's own, that sit
# in front of [param monitor]'s front and reach it.
func _light_on_front(shop: Node3D, monitor: Node3D) -> float:
	var front: Vector3 = (monitor.get_node("Front") as Node3D).global_position
	var normal := monitor.global_transform.basis.z.normalized()
	var energy := 0.0
	for node: Node in shop.find_children("*", "Light3D", true, false):
		var light := node as Light3D
		if monitor.is_ancestor_of(light) or not light.is_visible_in_tree() or light.light_energy <= 0.0:
			continue
		var to_light := light.global_position - front
		if to_light.dot(normal) <= 0.0:
			continue
		if light is OmniLight3D and to_light.length() < (light as OmniLight3D).omni_range:
			energy += light.light_energy
		elif light is SpotLight3D:
			var spot := light as SpotLight3D
			var aim := -spot.global_transform.basis.z
			if to_light.length() < spot.spot_range and rad_to_deg(aim.angle_to(-to_light)) < spot.spot_angle:
				energy += light.light_energy
	return energy
