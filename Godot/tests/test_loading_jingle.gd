extends "res://tests/test.gd"
## The loading screen draws the logo's outline as the game loads, as a loading bar, and plays the
## CompuFun jingle only once the load is complete. Then the ink reaches each syllable's letters as
## the syllable is sung: "Com" from 0.10 s, "pu" (0.42 of the logo) at 0.77 s, "Fun" (0.64) at
## 1.35 s, the whole logo at 2.15 s. The byline waits for the complete logo.

# Not main.tscn: Godot crashes on a quit while its worker threads still load the game (docs/gotchas.md).
# This one has no scripts, and its textures take long enough to load that the test sees the loading bar.
const SMALL_SCENE: String = "res://props/wall_shelf.tscn"


func run() -> void:
	var screen: CanvasLayer = (load("res://ui/loading_screen.tscn") as PackedScene).instantiate()
	screen.set(&"game_scene", SMALL_SCENE)
	root.add_child(screen)
	var jingle: AudioStreamPlayer = screen.get_node("%Jingle")
	var logo: ShaderMaterial = (screen.get_node("%Logo") as CanvasItem).material
	var loading_frames := 0
	for i in 1000000:  # headless frames are fast; the loop ends when the jingle plays
		await process_frame
		var progress: Array = []
		if ResourceLoader.load_threaded_get_status(SMALL_SCENE, progress) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			loading_frames += 1
			if jingle.playing or logo.get_shader_parameter("ink_progress") > 0.0:
				check("no jingle and no ink while the game loads", [jingle.playing, logo.get_shader_parameter("ink_progress")], [false, 0.0])
				break
		elif jingle.playing:
			break
	print("the load took %d frames that the test saw" % loading_frames)
	check("the jingle plays once the load is complete", [jingle.stream != null, jingle.playing], [true, true])
	check("with the whole outline: the loading bar is full", logo.get_shader_parameter("outline_progress"), 1.0)
	var byline: Label = screen.get_node("%Byline")
	check("no byline before the logo is complete", byline.modulate.a, 0.0)
	var ink := func(seconds: float) -> float: return snappedf(screen.call("drawn_at", seconds), 0.01)
	check("no ink before 'Com'", ink.call(0.05), 0.0)
	check("the ink is at 'pu' as it is sung", ink.call(0.77), 0.42)
	check("the ink is at 'Fun' as it is sung", ink.call(1.35), 0.64)
	check("the logo is drawn as 'Fun' ends", ink.call(2.15), 1.0)
	check("within a syllable the ink eases out: past halfway at half the syllable", ink.call((0.77 + 1.35) / 2.0) > (0.42 + 0.64) / 2.0, true)
	# Stopped before the byline, the screen never starts the game under the test.
	screen.set_process(false)
	check("the scene loads", ResourceLoader.load_threaded_get(SMALL_SCENE) is PackedScene, true)
	screen.queue_free()
	await process_frame
