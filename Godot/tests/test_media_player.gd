extends "res://tests/test.gd"
## Media Player: Javve's computer opens .mid files with MPLAYER.EXE, and the window plays,
## pauses, seeks and goes quiet when it closes.

const COMPUTER_STATE_PATH := "res://win95/computer_state.gd"  # loaded at run time: it names the Game autoload
const MEDIA_PLAYER_PATH := "res://win95/media_player.tscn"


func run() -> void:
	var setup: Win95Setup = (load("res://customers/javve.tres") as Customer).computer.win95_setup
	var demo := setup.file_at("Desktop\\demo final.mid")
	check("the demo has a sound", demo.sound != null, true)

	var state: Node = load(COMPUTER_STATE_PATH).new()
	state.setup = setup
	var openers: Array = state.programs_for("mid").map(func(file: Win95File) -> String: return file.name)
	check("MPLAYER.EXE opens .mid", openers, ["MPLAYER.EXE"])
	check("and is installed", state.installed_programs().any(func(file: Win95File) -> bool: return file.name == "MPLAYER.EXE"), true)
	state.free()

	var window: Node = load(MEDIA_PLAYER_PATH).instantiate()
	root.add_child(window)
	await process_frame
	window.open_file(demo, null)
	check("titled after the file", window.get_node("%TitleBar").title, "demo final.mid - Media Player")
	check("plays at once", window.is_playing(), true)
	window.get_node("%Play").pressed.emit()
	check("Play pauses it", window.is_playing(), false)
	window.seek(30.0)
	check("seeks while paused, and stays paused", [snappedf(window.song_position(), 0.1), window.is_playing()], [30.0, false])
	window.get_node("%Play").pressed.emit()
	check("and plays it again", window.is_playing(), true)
	window.close()
	check("closing stops and rewinds", [window.is_playing(), window.song_position()], [false, 0.0])
	window.seek(20.0)
	check("seeks while stopped", window.song_position(), 20.0)
	window.queue_free()
	await process_frame
