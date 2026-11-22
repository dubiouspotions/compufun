extends "res://tests/test.gd"
## Only the computer on the VGA cable plays its Win95 sounds aloud. One off the cable boots and shows
## message boxes in silence, but its power-on sound plays, and it leaves the Win95 bus alone.
## Plugging the cable in makes its sounds aloud from then on.

const MESSAGE := "res://win95/message_box.tscn"  # loaded at run time: its script names the Game autoload
const MEDIA_PLAYER := "res://win95/media_player.tscn"


func run() -> void:
	var bench: Control = load("res://ui/bench_screen.tscn").instantiate()
	root.add_child(bench)
	await process_frame
	var on := Job.new(load("res://customers/skater_bro.tres"), load("res://problems/dust_overheat.tres"), 0, 0)
	var off := Job.new(load("res://customers/retired_accountant.tres"), load("res://problems/dust_overheat.tres"), 1, 1)
	game.jobs = [on, off] as Array[Job]
	game.connect_cable(on)
	game.set_powered(on, true)
	game.set_powered(off, true)
	await process_frame
	var on_desktop: Control = bench._desktops[on]
	var off_desktop: Control = bench._desktops[off]
	check("one desktop on the screen, one parked", [on_desktop.get_parent() == bench, off_desktop.get_parent() == bench], [true, false])

	var off_boot: Node = off_desktop.get("_boot")
	var power_on: Array = players(off_boot).filter(func(p: AudioStreamPlayer) -> bool: return p.stream == off_boot.power_on_sound)
	check("off the cable, the power-on sound plays aloud", power_on.map(func(p: AudioStreamPlayer) -> float: return p.volume_db), [0.0])

	var bus := AudioServer.get_bus_index(&"Win95")
	var bus_before := [AudioServer.is_bus_mute(bus), AudioServer.get_bus_volume_db(bus)]
	off_desktop.get_node("%ComputerState").set_sound(10.0, true)
	check("off the cable, a sound change leaves the bus alone", [AudioServer.is_bus_mute(bus), AudioServer.get_bus_volume_db(bus)], bus_before)

	var on_boot: Node = on_desktop.get("_boot")
	for boot: Node in [off_boot, on_boot]:
		boot.set(&"_skipped", true)
	for boot: Node in [off_boot, on_boot]:
		if boot.visible:  # it hides as it finishes
			await boot.finished
	await process_frame
	check("off the cable, the startup sound plays silently", win95_volumes(off_boot), [-80.0])
	check("on the cable, the startup sound plays aloud", win95_volumes(on_boot), [0.0])

	var off_box: Node = off_desktop.get_node("Desktop").open(load(MESSAGE), false)
	var on_box: Node = on_desktop.get_node("Desktop").open(load(MESSAGE), false)
	off_box.show_message("Error", "Cannot find the file.")
	on_box.show_message("Error", "Cannot find the file.")
	check("off the cable, a message box chord is silent", win95_volumes(off_desktop.get_node("Desktop")), [-80.0])
	check("on the cable, it is aloud", win95_volumes(on_desktop.get_node("Desktop")), [0.0])
	var media: Node = off_desktop.get_node("Desktop").open(load(MEDIA_PLAYER))
	check("off the cable, Media Player is silent", (media.get_node("%Player") as AudioStreamPlayer).volume_db, -80.0)

	game.connect_cable(off)
	await process_frame
	check("plugged in, its sounds play aloud from then on", [win95_volumes(off_desktop.get_node("Desktop")), (media.get_node("%Player") as AudioStreamPlayer).volume_db], [[0.0], 0.0])
	check("and the computer that lost the cable goes silent", win95_volumes(on_desktop.get_node("Desktop")), [-80.0])
	check("the bus follows the computer on the cable now", [AudioServer.is_bus_mute(bus), snappedf(AudioServer.get_bus_volume_linear(bus), 0.01)], [true, 0.1])

	game.jobs = [] as Array[Job]
	bench.free()


func players(node: Node) -> Array:
	return node.get_children().filter(func(child: Node) -> bool: return child is AudioStreamPlayer) if is_instance_valid(node) else []


# The volume_db of each Win95-bus player directly under [param node].
func win95_volumes(node: Node) -> Array:
	return players(node).filter(func(p: AudioStreamPlayer) -> bool: return p.bus == &"Win95").map(func(p: AudioStreamPlayer) -> float: return p.volume_db)
