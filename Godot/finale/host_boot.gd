class_name HostBoot
extends Control
## The player's own computer, faked: it seems to restart and hangs with a corrupted drive. It draws
## the boot screen of [member host], the computer that the game runs on: the Windows logo with its
## spinning dots, the Apple logo with a progress bar that stops, or a Linux boot log. The Windows logo
## is four squares; the Apple logo is Simple Icons' (CC0). [method show_stage] moves it on; the finale
## times the stages.

enum Host { WINDOWS, MACOS, LINUX }
## OFF: black. STARTING: the logo, or the boot log. REPAIRING: Windows only, a line under the dots.
## FAILED: the error.
enum Stage { OFF, STARTING, REPAIRING, FAILED }

const WINDOWS_LOGO := Color(0.0, 0.47, 0.84)
const WINDOWS_ERROR := Color(0.02, 0.24, 0.55)
const TRACK := Color(0.27, 0.27, 0.27)
const MONO: Font = preload("res://compufun_db/fonts/Px437_IBM_VGA_8x16.ttf")
const APPLE: Texture2D = preload("res://finale/apple_logo.svg")

## The computer whose boot screen shows.
@export var host: Host = Host.WINDOWS
## The text of the errors.
@export var text: FinaleText
## The share of the progress bar that fills before the Mac hangs, 0 to 1.
@export_range(0.0, 1.0) var mac_progress: float = 0.62
## The seconds that the Mac's progress bar takes to get there.
@export var mac_progress_seconds: float = 4.0
## The lines of the Linux boot log per second.
@export var linux_lines_per_second: float = 7.0

var _stage: Stage = Stage.OFF
var _time: float = 0.0


## The computer that the game runs on: on the web, the browser's user agent says which.
static func detect() -> Host:
	if OS.has_feature("web"):
		return from_user_agent(str(JavaScriptBridge.eval("navigator.userAgent", true)))
	match OS.get_name():
		"Windows":
			return Host.WINDOWS
		"macOS", "iOS":
			return Host.MACOS
	return Host.LINUX


## The computer that a browser's user agent names; Linux for one that names neither Windows nor Apple.
static func from_user_agent(agent: String) -> Host:
	if agent.contains("Windows"):
		return Host.WINDOWS
	for apple: String in ["Macintosh", "Mac OS", "iPhone", "iPad"]:
		if agent.contains(apple):
			return Host.MACOS
	return Host.LINUX


## Shows [param stage] from its start.
func show_stage(stage: Stage) -> void:
	_stage = stage
	_time = 0.0
	queue_redraw()


## The stage that shows now.
func stage() -> Stage:
	return _stage


func _process(delta: float) -> void:
	_time += delta
	if visible and _stage in [Stage.STARTING, Stage.REPAIRING]:
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
	if _stage == Stage.OFF or text == null:
		return
	match host:
		Host.WINDOWS:
			_draw_windows()
		Host.MACOS:
			_draw_mac()
		Host.LINUX:
			_draw_linux()


# The design size is 1080 pixels high; everything scales with the window.
func _unit() -> float:
	return size.y / 1080.0


func _draw_windows() -> void:
	var font := get_theme_default_font()
	var u := _unit()
	if _stage == Stage.FAILED:
		draw_rect(Rect2(Vector2.ZERO, size), WINDOWS_ERROR)
		var left := size.x * 0.1
		draw_string(font, Vector2(left, size.y * 0.16), text.windows_title, HORIZONTAL_ALIGNMENT_LEFT, -1, int(60 * u))
		draw_multiline_string(font, Vector2(left, size.y * 0.26), text.windows_error, HORIZONTAL_ALIGNMENT_LEFT, size.x * 0.75, int(28 * u))
		return
	var centre := Vector2(size.x / 2.0, size.y * 0.42)
	var half := 60.0 * u
	var gap := 5.0 * u
	var side := half - gap / 2.0
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var at := centre + Vector2(minf(corner.x, 0.0) * half + maxf(corner.x, 0.0) * gap / 2.0, minf(corner.y, 0.0) * half + maxf(corner.y, 0.0) * gap / 2.0)
		draw_rect(Rect2(at, Vector2(side, side)), WINDOWS_LOGO)
	_draw_dots(Vector2(size.x / 2.0, size.y * 0.72), 22.0 * u, 3.5 * u)
	if _stage == Stage.REPAIRING:
		draw_string(font, Vector2(0.0, size.y * 0.8), text.windows_repair, HORIZONTAL_ALIGNMENT_CENTER, size.x, int(28 * u))


# Windows' spinner: dots chase each other around a ring, slow at the bottom and fast at the top.
func _draw_dots(centre: Vector2, radius: float, dot: float) -> void:
	for i: int in 6:
		var local := fmod(_time - i * 0.09, 2.6)
		if local < 0.0 or local > 2.2:
			continue
		var turn := smoothstep(0.0, 1.0, local / 2.2) * 1.6
		var angle := PI / 2.0 + TAU * turn
		draw_circle(centre + Vector2(cos(angle), sin(angle)) * radius, dot, Color.WHITE)


func _draw_mac() -> void:
	var u := _unit()
	var centre := Vector2(size.x / 2.0, size.y * 0.42)
	if _stage == Stage.FAILED:
		var ring := 70.0 * u
		draw_arc(centre, ring, 0.0, TAU, 64, Color.WHITE, 14.0 * u, true)
		var slash := Vector2.ONE.normalized() * ring
		draw_line(centre - slash, centre + slash, Color.WHITE, 14.0 * u, true)
		draw_multiline_string(get_theme_default_font(), Vector2(size.x * 0.25, size.y * 0.62), text.macos_error,
				HORIZONTAL_ALIGNMENT_CENTER, size.x * 0.5, int(26 * u))
		return
	var logo := Vector2.ONE * 190.0 * u
	draw_texture_rect(APPLE, Rect2(centre - logo / 2.0, logo), false)
	var bar := Rect2(size.x / 2.0 - 110.0 * u, size.y * 0.64, 220.0 * u, 6.0 * u)
	draw_rect(bar, TRACK)
	var filled := mac_progress * (1.0 - pow(1.0 - clampf(_time / mac_progress_seconds, 0.0, 1.0), 3.0))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * filled, bar.size.y)), Color.WHITE)


func _draw_linux() -> void:
	var u := _unit()
	var lines := text.linux_boot.split("\n")
	var shown := lines.size() if _stage == Stage.FAILED else mini(lines.size(), int(_time * linux_lines_per_second))
	if _stage == Stage.FAILED:
		lines.append_array(text.linux_error.split("\n"))
		shown = lines.size()
	var font_size := int(16 * maxf(1.0, roundf(u * 1.5)))
	var height := font_size * 1.25
	for i: int in shown:
		draw_string(MONO, Vector2(size.x * 0.02, size.y * 0.04 + height * (i + 1)), lines[i], HORIZONTAL_ALIGNMENT_LEFT, size.x * 0.96, font_size)
