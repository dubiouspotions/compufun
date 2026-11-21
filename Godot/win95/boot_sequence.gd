extends Control
## A 1995 PC booting: the BIOS power-on self test, "Starting Windows 95...", the splash screen,
## then the desktop beneath. Any key or click skips it. Frees itself when done.

## The boot reached the desktop, or the player skipped it.
signal finished

## Starts as soon as the node is ready; turn off to start it with play().
@export var play_on_start: bool = true
## The power-on self test, one line at a time. %MEMORY% is the memory test, which counts up.
@export_multiline var post_lines: PackedStringArray = [
	"CompuFun Modular BIOS v4.51PG, An Energy Star Ally",
	"Copyright (C) 1984-95, CompuFun Ltd.",
	"",
	"PENTIUM-S CPU at 100MHz",
	"%MEMORY%",
	"",
	"CompuFun Plug and Play BIOS Extension v1.0A",
	"Copyright (C) 1995, CompuFun Ltd.",
	"  Detecting IDE Primary Master  ... QUANTUM FIREBALL1080A",
	"  Detecting IDE Primary Slave   ... None",
	"  Detecting IDE Secondary Master... CD-ROM 4X",
	"  Detecting IDE Secondary Slave ... None",
	"",
	"",
	"Press DEL to enter SETUP",
]
## Kilobytes of memory that the memory test counts up to.
@export var memory_kb: int = 16384
@export var memory_test_seconds: float = 1.5
## The pause after each POST line, in seconds.
@export var line_seconds: float = 0.15
@export var post_hold_seconds: float = 1.0
@export var starting_seconds: float = 1.5
@export var splash_seconds: float = 3.0
## The colours that scroll along the bottom of the splash screen.
@export var bar_colors: PackedColorArray = [Color8(0, 0, 128), Color8(0, 128, 255), Color8(255, 255, 255), Color8(0, 128, 255)]

var _skipped: bool = false
var _playing: bool = false
var _bar_offset: float = 0.0

@onready var _post: Label = %Post
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
	_bar_offset += delta * 200.0
	_bar.queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed():
		accept_event()
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
	await _run()
	finished.emit()
	queue_free()


func _run() -> void:
	_show_stage(_post)
	_post.text = ""
	for line in post_lines:
		if line == "%MEMORY%":
			if not await _count_memory():
				return
		else:
			_post.text += line + "\n"
			if not await _wait(line_seconds):
				return
	if not await _wait(post_hold_seconds):
		return
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
	return true


## Waits [param seconds]; false when the player skipped meanwhile.
func _wait(seconds: float) -> bool:
	if _skipped:
		return false
	await get_tree().create_timer(seconds).timeout
	return not _skipped


func _show_stage(stage: Control) -> void:
	for other: Control in [_post, _starting, _splash]:
		other.visible = other == stage


func _draw_bar() -> void:
	var width := 64.0
	var count := bar_colors.size()
	var x := -fmod(_bar_offset, width * count)
	var i := 0
	while x < _bar.size.x:
		_bar.draw_rect(Rect2(x, 0, width, _bar.size.y), bar_colors[i % count])
		x += width
		i += 1
