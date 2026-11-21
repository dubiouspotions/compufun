extends Control
## A 1995 PC booting: the BIOS power-on self test, "Starting Windows 95...", the splash screen,
## then the desktop beneath, with a sound for each stage. Any key or click skips to the desktop.
## Frees itself when the startup sound has played.

## The boot reached the desktop, or the player skipped it.
signal finished
signal _any_key

## A floppy is in drive A:, so after the POST the boot stops on [member disk_error] and every key
## tries again; it goes on to Windows once this is false. win95.gd keeps it in step with the
## computer's Win95Setup.floppy_in_a.
@export var floppy_in_a: bool = false
## What the BIOS says when the floppy in A: can't start the computer.
@export_multiline var disk_error: String = "Non-System disk or disk error\nReplace and press any key when ready"
## Starts as soon as the node is ready; turn off to start it with play().
@export var play_on_start: bool = true
## The power-on self test, one line at a time, in BBCode: [color=#ffffff] marks the bright words.
## %MEMORY% is the memory test, which counts up.
@export_multiline var post_lines: PackedStringArray = [
	"CompuFun Modular BIOS v4.51PG, An Energy Star Ally",
	"Copyright (C) 1984-95, CompuFun Ltd.",
	"",
	"Version 1.03CF",
	"",
	"PENTIUM-S CPU at 100MHz",
	"%MEMORY%",
	"",
	"CompuFun Plug and Play BIOS Extension  v1.0A",
	"Copyright (C) 1995, CompuFun Ltd.",
	"   Detecting HDD Primary Master   ... QUANTUM FIREBALL1080A",
	"   Detecting HDD Primary Slave    ... [Press [color=#ffffff]F4[/color] to skip]",
	"   Detecting HDD Secondary Master ... CD-ROM 4X",
	"   Detecting HDD Secondary Slave  ... None",
]
## The lines at the bottom of the screen during the whole test, in BBCode.
@export_multiline var footer_lines: PackedStringArray = [
	"Press [color=#ffffff]DEL[/color] to enter SETUP",
	"11/09/95-i430FX-CF451PG-00",
]
## Kilobytes of memory that the memory test counts up to.
@export var memory_kb: int = 16384
@export var memory_test_seconds: float = 1.5
## The pause after each POST line, in seconds.
@export var line_seconds: float = 0.15
@export var post_hold_seconds: float = 1.0
@export var starting_seconds: float = 1.5
@export var splash_seconds: float = 3.0
@export_group("Sounds")
## Plays as the POST starts: the switch and the fan spinning up.
@export var power_on_sound: AudioStream
## Plays when the memory test passes.
@export var post_beep_sound: AudioStream
## Plays from drive detection through "Starting Windows 95...".
@export var drive_sound: AudioStream
## Plays as the desktop appears, also after a skip.
@export var startup_sound: AudioStream
@export_group("")

## The colours of the bar that scrolls along the bottom of the splash screen, as Win95 cycled
## its palette there; the gradient repeats every bar_period pixels.
@export var bar_gradient: Gradient
@export var bar_period: float = 640.0
## How many flat colour bands one period has, as Win95 cycled a few palette entries.
@export var bar_steps: int = 12
## How fast the bar scrolls, in pixels per second.
@export var bar_speed: float = 320.0

var _skipped: bool = false
## True while the disk error waits for a key: a key then tries again instead of skipping.
var _awaiting_key: bool = false
var _playing: bool = false
var _bar_offset: float = 0.0
var _players: Array[AudioStreamPlayer] = []

@onready var _post: RichTextLabel = %Post
@onready var _footer: RichTextLabel = %Footer
@onready var _starting: Label = %Starting
@onready var _splash: Control = %Splash
@onready var _bar: Control = %Bar


func _ready() -> void:
	_bar.draw.connect(_draw_bar)
	set_process(false)
	hide()
	if play_on_start:
		play()


func _process(delta: float) -> void:
	_bar_offset += delta * bar_speed
	_bar.queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed():
		accept_event()
		if _awaiting_key:
			_any_key.emit()
		else:
			_skipped = true


## Plays the boot from the start, then emits finished and frees the node.
func play() -> void:
	if _playing:
		return
	_playing = true
	_skipped = false
	show()
	focus_mode = Control.FOCUS_ALL
	grab_focus.call_deferred()
	await _run_post()
	if floppy_in_a:
		await _disk_error()
	if not _skipped:
		await _run_windows()
	for player in _players:
		player.stop()
	hide()
	set_process(false)
	finished.emit()
	if startup_sound:
		_sound(startup_sound)
		# The stream's length, not the player's finished: with no audio device that never fires.
		await get_tree().create_timer(startup_sound.get_length()).timeout
	queue_free()


func _run_post() -> void:
	_show_stage(_post)
	_post.text = ""
	_footer.text = "\n".join(footer_lines)
	_sound(power_on_sound)
	var drive_started := false
	for line in post_lines:
		if not drive_started and line.strip_edges().begins_with("Detecting"):
			drive_started = true
			_sound(drive_sound)
		if line == "%MEMORY%":
			if not await _count_memory():
				return
		else:
			_post.text += line + "\n"
			if not await _wait(line_seconds):
				return
	await _wait(post_hold_seconds)


# The BIOS can't boot from the floppy: it says so, and each key tries again until the floppy is out.
# A skip doesn't get past this; after it, the boot goes on to Windows in full.
func _disk_error() -> void:
	_show_stage(_post)
	_skipped = false
	_awaiting_key = true
	_post.text += "\n" + disk_error + "\n"
	while floppy_in_a:
		await _any_key
		if floppy_in_a:
			_post.text += "\n" + disk_error + "\n"
	_awaiting_key = false


func _run_windows() -> void:
	_show_stage(_starting)
	if not await _wait(starting_seconds):
		return
	_show_stage(_splash)
	set_process(true)
	await _wait(splash_seconds)


## Counts the memory test up on the last line; false when the player skipped.
func _count_memory() -> bool:
	var before := _post.text
	var steps := 30
	for i in steps + 1:
		_post.text = before + "Memory Test :  %dK" % (memory_kb * i / steps)
		if not await _wait(memory_test_seconds / steps):
			return false
	_post.text += " OK\n"
	_sound(post_beep_sound)
	return true


## Waits [param seconds], and longer while the screen is out of the tree; false when the player
## skipped meanwhile.
func _wait(seconds: float) -> bool:
	if _skipped:
		return false
	await get_tree().create_timer(seconds).timeout
	if not is_inside_tree():
		await tree_entered
	return not _skipped


func _show_stage(stage: Control) -> void:
	for other: Control in [_post, _starting, _splash]:
		other.visible = other == stage
	_footer.visible = stage == _post


func _draw_bar() -> void:
	if bar_gradient == null:
		return
	var step := 2.0
	var x := 0.0
	while x < _bar.size.x:
		var at := floorf(fposmod((x + _bar_offset) / bar_period, 1.0) * bar_steps) / bar_steps
		_bar.draw_rect(Rect2(x, 0, step, _bar.size.y), bar_gradient.sample(at))
		x += step


## Plays [param stream] on a new player and returns it; null plays nothing.
func _sound(stream: AudioStream) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	add_child(player)
	_players.append(player)
	if stream:
		player.play()
	return player
