extends "res://tests/test.gd"
## In the Workview, the screwdriver beside the standing computer takes the hover outline under the
## mouse; once the computer lies, its dashed outline shows a ghost of it under the mouse while a click
## stands the computer up.


func run() -> void:
	var pierre: Customer = load("res://customers/skater_bro.tres")
	game.start_day(make_day(1, [[pierre, load("res://problems/dust_overheat.tres")]]))
	game.open_shop()
	game.customer_arrived()
	game.dialogue_finished()
	game.customer_left()
	var job: Job = game.jobs[0]
	var computer: Node3D = (load("res://rooms/shop/job_computer.tscn") as PackedScene).instantiate()  # untyped: JobComputer needs the Game autoload to compile
	computer.set(&"job", job)
	root.add_child(computer)
	await process_frame
	var driver := computer.get_node("%Screwdriver") as Node3D
	var outline := computer.get_node("%ScrewdriverOutline") as Node3D
	var hotspot := computer.get_node("%ScrewdriverHotspot") as Hotspot
	var meshes: Array[Node] = driver.find_children("*", "MeshInstance3D")
	var outlined := func() -> Array: return meshes.map(func(m: MeshInstance3D) -> bool: return m.material_overlay != null)
	var ghosted := func() -> Array: return meshes.map(func(m: MeshInstance3D) -> bool:
		return (m.material_override as StandardMaterial3D).albedo_color.a < 1.0)
	check("the screwdriver has meshes", meshes.size() > 0, true)

	game.focus_job(job)
	game.go_to_view(&"Workview")
	check("standing: the screwdriver shows, no outline", [driver.visible, outline.visible, outlined.call()], [true, false, [false, false]])
	hotspot.mouse_entered.emit()
	check("under the mouse: outlined", outlined.call(), [true, true])
	hotspot.mouse_exited.emit()
	check("off the mouse: no outline", outlined.call(), [false, false])

	game.lay_down(job)
	check("lying: the dashed outline, no screwdriver", [driver.visible, outline.visible], [false, true])
	hotspot.mouse_entered.emit()
	check("the dashed outline under the mouse: a ghost, no outline", [driver.visible, ghosted.call(), outlined.call()], [true, [true, true], [false, false]])
	game.turn_screw(job, 0)
	check("no stand-up with a screw out: no ghost", [driver.visible, hotspot.input_ray_pickable], [false, false])
	hotspot.mouse_exited.emit()
	game.turn_screw(job, 0)
	game.stand_up(job)
	check("standing again: the solid screwdriver", [driver.visible, ghosted.call(), outlined.call()], [true, [false, false], [false, false]])
