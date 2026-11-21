extends Control
## A 1995 PC booting: a black screen while the monitor warms up, the BIOS power-on self test, the
## system summary, "Starting Windows 95...", the splash screen, then the desktop beneath, over one
## recording of the machine. Any key or click skips to the desktop.
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
## The screen after the POST: the system summary, all at once. %EXTENDED% is the memory above 640K.
@export_multiline var summary_lines: PackedStringArray = [
	"┌──────────────────────────────────────────────────────────────────────────┐",
	"│                          System Configurations                           │",
	"├──────────────────────────────────────────────────────────────────────────┤",
	"│ CPU Type         : PENTIUM-S         Base Memory      :        640K      │",
	"│ Co-Processor     : Installed         Extended Memory  : %EXTENDED%K      │",
	"│ CPU Clock        : 100MHz            Cache Memory     :        256K      │",
	"├──────────────────────────────────────────────────────────────────────────┤",
	"│ Diskette Drive A : 1.44M, 3.5 in.    Display Type     : EGA/VGA          │",
	"│ Diskette Drive B : None              Serial Port(s)   : 3F8 2F8          │",
	"│ Pri. Master Disk : LBA,Mode 4,1080MB Parallel Port(s) : 378              │",
	"│ Pri. Slave  Disk : None              EDO DRAM Row(s)  : 0 1              │",
	"│ Sec. Master Disk : CDROM,Mode 4      L2 Cache Type    : Pipeline         │",
	"│ Sec. Slave  Disk : None                                                  │",
	"└──────────────────────────────────────────────────────────────────────────┘",
]
## The lines under the summary, one at a time, as the BIOS lists them before it boots.
@export_multiline var boot_lines: PackedStringArray = [
	"",
	"PCI device listing.....",
	"Bus No. Device No. Func No. Vendor ID  Device ID  Device Class          IRQ",
	"-----------------------------------------------------------------------------",
	"   0        7         1       8086       7010     IDE Controller         14",
	"   0       17         0       1274       5000     Multimedia Device      11",
	"-----------------------------------------------------------------------------",
	"",
	"Verifying DMI Pool Data ........",
]
## What the BIOS says as it hands over to Windows.
@export var starting_text: String = "Starting Windows 95..."
## The lines at the bottom of the screen during the whole test, in BBCode.
@export_multiline var footer_lines: PackedStringArray = [
	"Press [color=#ffffff]DEL[/color] to enter SETUP",
	"11/09/95-i430FX-CF451PG-00",
]
## Kilobytes of memory that the memory test counts up to.
@export var memory_kb: int = 16384
@export var memory_test_seconds: float = 1.5
## The black screen before the POST, while the monitor warms up, in seconds.
@export var warm_up_seconds: float = 4.2
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
	if not _skipped:
		await _run_summary()
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
		_sound(startup_sound).bus = Win95Desktop.SOUND_BUS
		# The stream's length, not the player's finished: with no audio device that never fires.
		await get_tree().create_timer(startup_sound.get_length()).timeout
	queue_free()


func _run_post() -> void:
	_show_stage(null)
	_sound(power_on_sound)
	if not await _wait(warm_up_seconds):
		return
	_show_stage(_post)
	_energy_star.show()
	_post.text = ""
	_footer.text = "\n".join(footer_lines)
	for line in post_lines:
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
	_post.text = "\n".join(summary_lines).replace("%EXTENDED%", str(memory_kb - 640).lpad(10)) + "\n"
	for line in boot_lines:
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
