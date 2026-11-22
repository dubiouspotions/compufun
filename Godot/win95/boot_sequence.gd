extends Control
## A 1995 PC booting: a black screen while the monitor warms up, the BIOS power-on self test, the
## system summary, "Starting Windows 95...", the splash screen, then the desktop beneath, over one
## recording of the machine. Any key or click skips to the desktop, unless [member skippable] is off.
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
## False: no key or click skips the boot; they go on to the nodes behind it.
@export var skippable: bool = true
## Starts as soon as the node is ready; turn off to start it with play().
@export var play_on_start: bool = true
## What the BIOS finds: the CPU, the memory, the drives, the PCI devices. null boots the defaults
## of Hardware. win95.gd sets it from the computer.
@export var hardware: Hardware
## What the BIOS says as it hands over to Windows.
@export var starting_text: String = "Starting Windows 95..."
## False stops after the BIOS, for a computer that runs a DOS program instead: no "Starting
## Windows 95...", no splash, no startup sound.
@export var boots_windows: bool = true
@export var memory_test_seconds: float = 1.5
## A broken memory module is in: the memory test stops and the computer halts until it is switched
## off.
@export var memory_fails: bool = false
## How far a failing memory test counts, as a share of the memory. The same for every module, so the
## screen never tells which one is broken.
@export_range(0.0, 1.0) var memory_fail_share: float = 0.4
@export_multiline var memory_fail_text: String = "Memory test fail\n\nSystem halted"
## How long the video card's BIOS banner shows before the POST, while the monitor warms up, in
## seconds.
@export var warm_up_seconds: float = 4.2
## The video card's BIOS banner, the first picture after power-on.
@export_multiline var video_bios_lines: PackedStringArray = [
	"CompuFun Graphics 64 VGA BIOS  Version 2.10.06",
	"Copyright (C) 1995 CompuFun Ltd.  All Rights Reserved.",
	"1024K DRAM",
]
## The pause after each POST line, in seconds.
@export var line_seconds: float = 0.25
## The pause after each "Detecting" line, as the BIOS waits for the drive.
@export var detect_seconds: float = 0.8
@export var post_hold_seconds: float = 0.5
@export var verify_seconds: float = 1.2
@export var starting_seconds: float = 1.5
@export var splash_seconds: float = 3.0
@export_group("Sounds")
## Plays from the power switch until the desktop: the fan, the POST beep, the drive; a looping
## stream keeps humming through a long wait.
@export var power_on_sound: AudioStream
## Plays as the desktop appears, also after a skip, on the Win95 bus: the computer's volume and
## mute apply to it, but not to the power-on sound.
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
var _halted: bool = false
## True while the disk error waits for a key: a key then tries again instead of skipping.
var _awaiting_key: bool = false
var _playing: bool = false
var _bar_offset: float = 0.0
var _players: Array[AudioStreamPlayer] = []

@onready var _post: RichTextLabel = %Post
@onready var _footer: RichTextLabel = %Footer
@onready var _energy_star: Control = %EnergyStar
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
	if not (event is InputEventKey or event is InputEventMouseButton) or not event.is_pressed():
		return
	if _awaiting_key:
		accept_event()
		_any_key.emit()
	elif skippable:
		accept_event()
		_skipped = true


## Plays the boot from the start, then emits finished and frees the node.
func play() -> void:
	if _playing:
		return
	_playing = true
	_skipped = false
	if hardware == null:
		hardware = Hardware.new()
	show()
	focus_mode = Control.FOCUS_ALL
	grab_focus.call_deferred()
	await _run_post()
	if _halted:
		return
	if not _skipped:
		await _run_summary()
	if floppy_in_a:
		await _disk_error()
	if not _skipped and boots_windows:
		await _run_windows()
	for player in _players:
		player.stop()
	hide()
	set_process(false)
	finished.emit()
	if startup_sound and boots_windows:
		Win95Desktop.play_sound(startup_sound, self)
		# The stream's length, not the player's finished: with no audio device that never fires.
		await get_tree().create_timer(startup_sound.get_length()).timeout
	queue_free()


func _run_post() -> void:
	_show_stage(_post)
	_energy_star.hide()
	_footer.hide()
	_post.text = "\n".join(video_bios_lines)
	_sound(power_on_sound)
	if not await _wait(warm_up_seconds):
		return
	_footer.show()
	_energy_star.visible = hardware.energy_star()
	_post.text = ""
	_footer.text = "\n".join(hardware.footer_lines())
	for line in hardware.post_lines():
		if line == "%MEMORY%":
			if not await _count_memory():
				return
		else:
			_post.text += line + "\n"
			if not await _wait(detect_seconds if line.strip_edges().begins_with("Detecting") else line_seconds):
				return
	await _wait(post_hold_seconds)


# The screen clears to the system summary, then the lines before the boot.
func _run_summary() -> void:
	_footer.hide()
	_energy_star.hide()
	_post.text = "\n".join(hardware.summary_lines()) + "\n"
	for line in hardware.boot_lines():
		_print(line)
		if not await _wait(line_seconds):
			return
	await _wait(verify_seconds)


# The BIOS can't boot from the floppy: it says so, and each key tries again until the floppy is out.
# A skip doesn't get past this; after it, the boot goes on to Windows in full.
func _disk_error() -> void:
	_post.show()
	_skipped = false
	_awaiting_key = true
	_print("\n" + disk_error)
	while floppy_in_a:
		await _any_key
		if floppy_in_a:
			_print("\n" + disk_error)
	_awaiting_key = false


func _run_windows() -> void:
	_print(starting_text)
	if not await _wait(starting_seconds):
		return
	_show_stage(_splash)
	set_process(true)
	await _wait(splash_seconds)


## Counts the memory test up on the last line; false when the player skipped, or when the test
## failed and the computer halted. A skip doesn't get past a failing test.
func _count_memory() -> bool:
	var before := _post.text
	var steps := 30
	var last := roundi(steps * memory_fail_share) if memory_fails else steps
	for i in last + 1:
		_post.text = before + "Memory Test :  %dK" % (hardware.memory_kb * i / steps)
		if not await _wait(memory_test_seconds / steps) and not memory_fails:
			return false
	if memory_fails:
		_halted = true
		_print("\n" + memory_fail_text)
		return false
	_post.text += " OK\n"
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


# Adds [param text] as lines at the bottom of the screen, scrolling the top off as the BIOS does.
func _print(text: String) -> void:
	_post.text += text + "\n"
	var line := _post.get_theme_font(&"normal_font").get_height(_post.get_theme_font_size(&"normal_font_size")) + _post.get_theme_constant(&"line_separation")
	var rows := int(_post.size.y / line)
	var lines := _post.text.split("\n")
	if rows > 0 and lines.size() - 1 > rows:
		_post.text = "\n".join(lines.slice(lines.size() - 1 - rows))


func _show_stage(stage: Control) -> void:
	for other: Control in [_post, _splash]:
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
