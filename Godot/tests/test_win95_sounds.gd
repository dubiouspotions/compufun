extends "res://tests/test.gd"
## Win95 sounds play on the Win95 bus, and the bus follows the volume and mute of the computer on
## the cable: a muted computer is silent (the no_sound problem), the hardware boot sounds are not.

# Loaded at run time: their scripts name the Game autoload.
const WIN95 := "res://win95/win95.tscn"
const BOOT := "res://win95/boot_sequence.tscn"
const MESSAGE := "res://win95/message_box.tscn"
const SHUT_DOWN := "res://win95/shut_down.tscn"
const MEDIA_PLAYER := "res://win95/media_player.tscn"


func run() -> void:
	var bus := AudioServer.get_bus_index(&"Win95")
	check("the Win95 bus exists", bus >= 0, true)

	var loud := desktop(80.0, false)
	var muted := desktop(80.0, true)
	game.jobs = [loud.get_node("ComputerState").job, muted.get_node("ComputerState").job] as Array[Job]
	game.connected = game.jobs[1]
	root.add_child(muted)
	await process_frame
	check("a muted desktop mutes the bus", AudioServer.is_bus_mute(bus), true)
	root.remove_child(muted)
	game.connected = game.jobs[0]
	root.add_child(loud)
	await process_frame
	check("the desktop on screen sets the bus", [AudioServer.is_bus_mute(bus), snappedf(AudioServer.get_bus_volume_linear(bus), 0.01)], [false, 0.8])
	muted.get_node("ComputerState").set_sound(10.0, true)
	check("a desktop out of the tree leaves the bus alone", AudioServer.is_bus_mute(bus), false)

	var mute_box: CheckBox = loud.get_node("%Systray").get_node("%Mute")
	mute_box.button_pressed = true
	check("Mute in the systray mutes the bus", AudioServer.is_bus_mute(bus), true)
	mute_box.button_pressed = false
	(loud.get_node("%Systray").get_node("%VolumeSlider") as VSlider).value = 25.0
	check("the volume slider sets the bus", [AudioServer.is_bus_mute(bus), snappedf(AudioServer.get_bus_volume_linear(bus), 0.01)], [false, 0.25])

	var boot: Node = (load(BOOT) as PackedScene).instantiate()
	boot.play_on_start = false
	for seconds: StringName in [&"memory_test_seconds", &"line_seconds", &"post_hold_seconds", &"starting_seconds", &"splash_seconds"]:
		boot.set(seconds, 0.0)
	root.add_child(boot)
	boot.play()
	await boot.finished
	await process_frame  # finished fires just before the startup sound starts
	var startup: Array = players(boot).filter(func(p: AudioStreamPlayer) -> bool: return p.stream == boot.startup_sound)
	check("the startup sound plays on the Win95 bus", startup.map(func(p: AudioStreamPlayer) -> StringName: return p.bus), [&"Win95"])
	var hardware: Array = players(boot).filter(func(p: AudioStreamPlayer) -> bool: return p.stream != boot.startup_sound and p.stream != null)
	check("the hardware sounds don't", hardware.all(func(p: AudioStreamPlayer) -> bool: return p.bus == &"Master"), true)
	boot.queue_free()

	var media: Node = (load(MEDIA_PLAYER) as PackedScene).instantiate()
	check("Media Player plays on the Win95 bus", (media.get_node("%Player") as AudioStreamPlayer).bus, &"Win95")
	media.free()

	var win95_desktop: Node = loud.get_node("Desktop")
	var box: Node = win95_desktop.open(load(MESSAGE), false)
	var before := players(win95_desktop).size()
	box.show_message("Error", "Cannot find the file.")
	box.ask("Notepad", "Save changes?")
	check("a message box plays the chord on the desktop, on the Win95 bus", played(win95_desktop, before), [["chord.ogg", &"Win95"], ["chord.ogg", &"Win95"]])
	box.queue_free()

	var shut_down: Node = win95_desktop.open(load(SHUT_DOWN), false)
	before = players(win95_desktop).size()
	shut_down.get_node("%Yes").pressed.emit()
	check("Shut Down plays the tada on the Win95 bus", played(win95_desktop, before), [["tada.ogg", &"Win95"]])
	check("Empty Recycle Bin plays the ding", loud.empty_bin_sound.resource_path.get_file(), "ding.ogg")

	root.remove_child(loud)
	loud.free()
	muted.free()


func desktop(volume: float, muted: bool) -> Control:
	var computer := Computer.new()
	computer.win95_setup = Win95Setup.new()
	computer.win95_setup.volume = volume
	computer.win95_setup.muted = muted
	var customer := Customer.new()
	customer.computer = computer
	var job := Job.new(customer, Problem.new(), 0, 0)
	job.powered = true
	var win95: Control = (load(WIN95) as PackedScene).instantiate()
	win95.get_node("ComputerState").job = job
	return win95


func players(node: Node) -> Array:
	return node.get_children().filter(func(child: Node) -> bool: return child is AudioStreamPlayer)


# [file name, bus] of each player that [param node] got after its first [param from] players.
func played(node: Node, from: int) -> Array:
	return players(node).slice(from).map(func(p: AudioStreamPlayer) -> Array: return [p.stream.resource_path.get_file(), p.bus])
