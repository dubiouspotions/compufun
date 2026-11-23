extends "res://tests/test.gd"
## The loading screen plays the CompuFun jingle from its first frame, as the logo starts to draw in,
## and the ink reaches each syllable's letters as the syllable is sung: "Com" from 0.10 s, "pu" (0.42
## of the logo) at 0.77 s, "Fun" (0.64) at 1.35 s, the whole logo at 2.15 s. The byline waits for
## the complete logo.

# Not main.tscn: Godot crashes on a quit while its worker threads still load the game (docs/gotchas.md).
const SMALL_SCENE: String = "res://props/tree_pine.tscn"


func run() -> void:
	var screen: CanvasLayer = (load("res://ui/loading_screen.tscn") as PackedScene).instantiate()
	screen.set(&"game_scene", SMALL_SCENE)
	root.add_child(screen)
	await process_frame
	await process_frame
	var jingle: AudioStreamPlayer = screen.get_node("%Jingle")
	check("the jingle plays from the first frame", [jingle.stream != null, jingle.playing], [true, true])
	var byline: Label = screen.get_node("%Byline")
	check("no byline before the logo is complete", byline.modulate.a, 0.0)
	var ink := func(seconds: float) -> float: return snappedf(screen.call("drawn_at", seconds), 0.01)
	check("no ink before 'Com'", ink.call(0.05), 0.0)
	check("the ink is at 'pu' as it is sung", ink.call(0.77), 0.42)
	check("the ink is at 'Fun' as it is sung", ink.call(1.35), 0.64)
	check("the logo is drawn as 'Fun' ends", ink.call(2.15), 1.0)
	check("within a syllable the ink eases out: past halfway at half the syllable", ink.call((0.77 + 1.35) / 2.0) > (0.42 + 0.64) / 2.0, true)
	# Stopped before the load ends, the screen never starts the game: a slow load must not race the test.
	screen.set_process(false)
	check("the scene loads", ResourceLoader.load_threaded_get(SMALL_SCENE) is PackedScene, true)  # waits for the load
	screen.queue_free()
	await process_frame
