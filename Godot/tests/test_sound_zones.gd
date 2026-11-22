extends "res://tests/test.gd"
## The sound zones (rooms/shop/sound_zones.tscn): a reverb zone keeps the direct sound and sends in
## proportion to it, a part taken in the storage room sounds there, and the shop sounds from the
## right while the player is in the storage room.


func run() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _frames(5)
	var zones: Node3D = main.find_child("SoundZones", true, false)
	for zone: Area3D in zones.find_children("*", "Area3D", false, false):
		if zone.reverb_bus_enabled:
			# Godot drops the direct sound of a reverb zone that doesn't override the bus (docs/gotchas.md).
			check("%s keeps the direct sound" % zone.name, zone.audio_bus_override, true)
			check("%s sends in proportion to the sound" % zone.name, zone.reverb_bus_uniformity, 0.0)

	var shop_bus := AudioServer.get_bus_index(&"Shop")
	var panner := AudioServer.get_bus_effect(shop_bus, 0) as AudioEffectPanner
	check("in the Main view the shop sounds from the middle", panner.pan, 0.0)
	game.go_to_view(&"Left")
	game.go_to_view(&"Storage")
	await create_timer(0.6).timeout
	check("in the storage room it sounds from the right", is_equal_approx(panner.pan, zones.get(&"storage_pan")), true)

	var cpu: Part = load("res://parts/cpu.tres")
	check("take a CPU in the storage room", game.take_new_part(cpu), true)
	await _frames(2)
	var hand: Node3D = main.find_child("Hand", true, false)
	var takes := hand.get_children().filter(func(n: Node) -> bool: return n is AudioStreamPlayer3D)
	check("the take sounds at the hand", takes.size(), 1)
	if takes.size() == 1:
		check("in the storage room's zone", _zone_at(takes[0]), &"Storage")

	game.go_to_view(&"Left")
	await create_timer(0.6).timeout
	check("back in the shop: the middle again", panner.pan, 0.0)
	main.queue_free()
	await process_frame


func _zone_at(at: Node3D) -> StringName:
	var query := PhysicsPointQueryParameters3D.new()
	query.position = at.global_position
	query.collision_mask = SoundSet.SOUND_ZONES
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hits := at.get_world_3d().direct_space_state.intersect_point(query)
	return (hits[0].collider as Node).name if not hits.is_empty() else &""


func _frames(count: int) -> void:
	for i: int in count:
		await process_frame
