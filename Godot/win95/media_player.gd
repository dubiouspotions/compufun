extends "res://win95/window.gd"
## Media Player: plays a .mid file's sound on the Win95 bus, so the computer's volume and mute
## apply. Play turns into Pause while it plays; the slider shows and sets where the song is.

enum FileMenu { CLOSE }

## The file extensions that this app opens, lower case, without the dot.
@export var opens: Array[String] = ["mid", "rmi"]
## Seconds that Rewind and Fast Forward skip.
@export var skip_seconds := 5.0

const _MESSAGE := preload("res://win95/message_box.tscn")
# Pixel art for the buttons and the slider thumb: # black, w white, g gray, s silver, . clear.
const _PLAY := ["#....", "##...", "###..", "####.", "#####", "####.", "###..", "##...", "#...."]
const _PAUSE := ["##.##", "##.##", "##.##", "##.##", "##.##", "##.##", "##.##"]
const _STOP := ["#######", "#######", "#######", "#######", "#######", "#######", "#######"]
const _EJECT := ["...#...", "..###..", ".#####.", "#######", ".......", "#######", "#######"]
const _START := ["#...#...#", "#..##..##", "#.###.###", "#########", "#.###.###", "#..##..##", "#...#...#"]
const _BACK := ["...#...#", "..##..##", ".###.###", "########", ".###.###", "..##..##", "...#...#"]
const _FORWARD := ["#...#...", "##..##..", "###.###.", "########", "###.###.", "##..##..", "#...#..."]
const _END := ["#...#...#", "##..##..#", "###.###.#", "#########", "###.###.#", "##..##..#", "#...#...#"]
const _THUMB := [
		"wwwwwwwwww#", "wssssssssg#", "wssssssssg#", "wssssssssg#", "wssssssssg#", "wssssssssg#", "wssssssssg#",
		"wssssssssg#", "wssssssssg#", "wssssssssg#", "wssssssssg#", "wssssssssg#", "wssssssssg#", "wssssssssg#",
		"wssssssssg#", "wssssssssg#", "wssssssssg#", "wssssssssg#", "wssssssssg#", "wggggggggg#", "###########"]

var _play_icon: Texture2D
var _pause_icon: Texture2D
## Where a stopped or not yet started song is, in seconds.
var _stopped_at := 0.0

@onready var _player: AudioStreamPlayer = %Player
@onready var _slider: HSlider = %Position
@onready var _status: Label = %Status
@onready var _length_label: Label = %Length
@onready var _play: Button = %Play


func _ready() -> void:
	super()
	_play_icon = _art(_PLAY)
	_pause_icon = _art(_PAUSE)
	%Stop.icon = _art(_STOP)
	%Eject.icon = _art(_EJECT)
	%Start.icon = _art(_START)
	%Back.icon = _art(_BACK)
	%Forward.icon = _art(_FORWARD)
	%End.icon = _art(_END)
	var thumb := _art(_THUMB)
	for state: StringName in [&"grabber", &"grabber_highlight", &"grabber_disabled"]:
		_slider.add_theme_icon_override(state, thumb)
	_play.pressed.connect(func() -> void: (pause if is_playing() else play).call())
	%Stop.pressed.connect(stop)
	%Start.pressed.connect(func() -> void: seek(0.0))
	%Back.pressed.connect(func() -> void: seek(song_position() - skip_seconds))
	%Forward.pressed.connect(func() -> void: seek(song_position() + skip_seconds))
	%End.pressed.connect(func() -> void: seek(_length()))
	_slider.drag_ended.connect(func(_changed: bool) -> void: seek(_slider.value))
	_player.finished.connect(stop)
	%File.id_pressed.connect(func(id: int) -> void:
		if id == FileMenu.CLOSE:
			request_close())
	closed.connect(stop)
	_show_state()


## Opens [param opened], a .mid file, and plays its sound. The state is unused: Media Player
## doesn't save.
func open_file(opened: Win95File, _state: ComputerState) -> void:
	stop()
	_player.stream = opened.sound
	%TitleBar.title = "%s - Media Player" % opened.name
	if opened.sound == null:
		push_error("Media Player: %s has no sound, so it has nothing to play" % opened.name)
		var box: Node = (get_parent() as Win95Desktop).open(_MESSAGE, false)
		box.closed.connect(box.queue_free)
		box.show_message("Media Player", "Cannot play %s. The file is not a valid MIDI file, or it is damaged." % opened.name)
		box.belong_to(self)
	else:
		play()
	_show_state()


## True while the song plays; false when it is paused, stopped or there is none.
func is_playing() -> bool:
	return _player.playing and not _player.stream_paused


## Where the song is, in seconds.
func song_position() -> float:
	return _player.get_playback_position() if _is_started() else _stopped_at


## Plays on from where the song is.
func play() -> void:
	if _player.stream == null:
		return
	if _player.stream_paused:
		_player.stream_paused = false
	elif not _player.playing:
		_player.play(_stopped_at)


## Holds the song where it is; play() goes on from there.
func pause() -> void:
	_player.stream_paused = true


## Stops and goes back to the start.
func stop() -> void:
	_player.stop()
	_player.stream_paused = false
	_stopped_at = 0.0


## Moves to [param seconds], playing or not.
func seek(seconds: float) -> void:
	seconds = clampf(seconds, 0.0, _length())
	if _player.stream_paused:
		_player.play(seconds)  # a paused player ignores seek()
		_player.stream_paused = true
	elif _player.playing:
		_player.seek(seconds)
	else:
		_stopped_at = seconds
	_show_state()


func _process(_delta: float) -> void:
	_show_state()


# A paused player reads as not playing.
func _is_started() -> bool:
	return _player.playing or _player.stream_paused


func _length() -> float:
	return _player.stream.get_length() if _player.stream != null else 0.0


func _show_state() -> void:
	var loaded := _player.stream != null
	for button: Button in [_play, %Stop, %Start, %Back, %Forward, %End]:
		button.disabled = not loaded
	_slider.editable = loaded
	_slider.max_value = maxf(_length(), 0.01)
	_play.icon = _pause_icon if is_playing() else _play_icon
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_slider.set_value_no_signal(song_position())
	_length_label.text = _clock(_length()) if loaded else ""
	if not loaded:
		_status.text = "Not ready"
	else:
		var mode := "Playing" if is_playing() else ("Paused" if _player.stream_paused else "Stopped")
		_status.text = "%s   %s" % [mode, _clock(song_position())]


static func _clock(seconds: float) -> String:
	return "%d:%04.1f" % [int(seconds) / 60, fmod(seconds, 60.0)]


static func _art(rows: Array) -> ImageTexture:
	var colors := {"#": Color.BLACK, "w": Color.WHITE, "g": Color("#808080"), "s": Color("#c0c0c0")}
	var width := 0
	for row: String in rows:
		width = maxi(width, row.length())
	var image := Image.create_empty(width, rows.size(), false, Image.FORMAT_RGBA8)
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			if colors.has(row[x]):
				image.set_pixel(x, y, colors[row[x]])
	return ImageTexture.create_from_image(image)
