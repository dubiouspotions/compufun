extends "res://tests/test.gd"
## The street lamps outside are off by day, rain or shine, and on once the sun is down: from the
## afternoon's hour to the night's.


func run() -> void:
	var outside: Node = load("res://rooms/shop/outside.tscn").instantiate()
	root.add_child(outside)
	await process_frame
	var lights: Array[Node] = []
	var glows: Array[Node] = []
	for node: Node in get_nodes_in_group(&"lamp"):
		if outside.is_ancestor_of(node):
			lights.append(node)
	for node: Node in get_nodes_in_group(&"lamp_glow"):
		if outside.is_ancestor_of(node):
			glows.append(node)
	check("the outside has lamps and glowing glass", [lights.size() > 0, glows.size() > 0], [true, true])
	for raining: bool in [false, true]:
		outside.raining = raining
		var weather := "rain" if raining else "clear"
		for hour: String in ["morning_hour", "midday_hour"]:
			outside.hour = outside.get(hour)
			check("%s, %s: the lamps are off" % [hour, weather], _lit(lights, glows), [false, false])
		for hour: String in ["afternoon_hour", "evening_hour", "night_hour"]:
			outside.hour = outside.get(hour)
			check("%s, %s: the lamps are on" % [hour, weather], _lit(lights, glows), [true, true])
	outside.queue_free()


# Whether any lamp gives light, and whether any lamp's glass glows.
func _lit(lights: Array[Node], glows: Array[Node]) -> Array[bool]:
	return [lights.any(func(n: Node) -> bool: return (n as Light3D).visible and (n as Light3D).light_energy > 0.0),
			glows.any(func(n: Node) -> bool: return (n as Node3D).visible)]
