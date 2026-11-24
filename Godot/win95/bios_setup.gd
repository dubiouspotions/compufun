class_name BiosSetup
extends Control
## The BIOS's CMOS SETUP UTILITY, Award 4.51PG style, as DEL during the POST opens it: an 80 x 25
## text screen on the VGA font, driven by the keyboard. BootSequence opens it, applies what it
## saves and reboots.

## The player left setup. [param values] are the Win95Setup properties to apply (cmos and
## clock_offset_seconds), or empty when they quit without saving.
signal closed(values: Dictionary[StringName, Variant])

## The BIOS FEATURES SETUP page, top to bottom, left column then right: the id that Win95Setup.cmos
## keeps, the label, and the options; the first option is the default.
const FEATURES: Array[Array] = [
	[&"virus_warning", "Virus Warning", ["Disabled", "Enabled"]],
	[&"cpu_cache", "CPU Internal Cache", ["Enabled", "Disabled"]],
	[&"external_cache", "External Cache", ["Enabled", "Disabled"]],
	[&"quick_post", "Quick Power On Self Test", ["Disabled", "Enabled"]],
	[&"boot_sequence", "Boot Sequence", ["A,C", "C,A"]],
	[&"swap_floppy", "Swap Floppy Drive", ["Disabled", "Enabled"]],
	[&"floppy_seek", "Boot Up Floppy Seek", ["Enabled", "Disabled"]],
	[&"numlock", "Boot Up NumLock Status", ["On", "Off"]],
	[&"system_speed", "Boot Up System Speed", ["High", "Low"]],
	[&"gate_a20", "Gate A20 Option", ["Fast", "Normal"]],
	[&"typematic", "Typematic Rate Setting", ["Disabled", "Enabled"]],
	[&"security", "Security Option", ["Setup", "System"]],
	[&"palette_snoop", "PCI/VGA Palette Snoop", ["Disabled", "Enabled"]],
	[&"os2", "OS Select For DRAM > 64MB", ["Non-OS2", "OS2"]],
	[&"video_shadow", "Video  BIOS Shadow", ["Enabled", "Disabled"]],
	[&"c8000", "C8000-CBFFF  Shadow", ["Disabled", "Enabled"]],
	[&"cc000", "CC000-CFFFF  Shadow", ["Disabled", "Enabled"]],
	[&"d0000", "D0000-D3FFF  Shadow", ["Disabled", "Enabled"]],
	[&"d4000", "D4000-D7FFF  Shadow", ["Disabled", "Enabled"]],
	[&"d8000", "D8000-DBFFF  Shadow", ["Disabled", "Enabled"]],
	[&"dc000", "DC000-DFFFF  Shadow", ["Disabled", "Enabled"]],
]
## How many FEATURES stand in the left column.
const _LEFT_FEATURES: int = 14

## The main menu, left column then right, with the help line under it.
const _MENU: Array[Array] = [
	["STANDARD CMOS SETUP", "Time, Date, Hard Disk Type..."],
	["BIOS FEATURES SETUP", "Virus Protection, Boot Sequence..."],
	["CHIPSET FEATURES SETUP", "Special features"],
	["POWER MANAGEMENT SETUP", "Green PC, Doze, Standby, Suspend..."],
	["PNP/PCI CONFIGURATION", "PnP, IRQ, PCI Slot..."],
	["LOAD BIOS DEFAULTS", "Load BIOS Defaults except Standard CMOS SETUP"],
	["LOAD SETUP DEFAULTS", "Load SETUP Defaults except Standard CMOS SETUP"],
	["INTEGRATED PERIPHERALS", "IDE, FDC, COM, LPT..."],
	["SUPERVISOR PASSWORD", "Change/Set/Disable Password"],
	["USER PASSWORD", "Change/Set/Disable Password"],
	["IDE HDD AUTO DETECTION", "Auto-Configure HDD: Sector, Cylinder, Head..."],
	["SAVE & EXIT SETUP", "Save Data to CMOS & Exit SETUP"],
	["EXIT WITHOUT SAVING", "Abandon all Datas & Exit SETUP"],
]
const _LEFT_MENU: int = 7

enum Page { MAIN, STANDARD, FEATURES }

const _COLS: int = 80
const _ROWS: int = 25
const _BLUE := Color("0000aa")
const _RED := Color("aa0000")
const _WHITE := Color("ffffff")
const _YELLOW := Color("ffff55")
const _DAYS: PackedStringArray = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
const _MONTHS: PackedStringArray = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

## The computer's board: the title, the drives and the memory that the pages show.
var hardware: Hardware = Hardware.new()

var _page: Page = Page.MAIN
var _menu: int = 0
var _feature: int = 0
## The date and time field picked on STANDARD CMOS SETUP: month, day, year, hour, minute, second.
var _field: int = 0
## Unsaved choices, as Win95Setup.cmos.
var _cmos: Dictionary[StringName, int] = {}
var _clock_offset: int = 0
## The open Y/N question, such as "SAVE to CMOS and EXIT (Y/N)? ", with its answer and what Y does;
## empty while none is open.
var _question: String = ""
var _answer: bool = false
var _on_yes: Callable
var _second: int = -1
var _font: Font = preload("res://win95/theme/dos_font.tres")
## The text drawn this frame: column, row, text, colour, background (transparent: blue).
var _runs: Array[Array] = []


## The option index of feature [param id] in [param setup]: its saved one, or the default 0.
static func value(setup: Win95Setup, id: StringName) -> int:
	return setup.cmos.get(id, 0) if setup != null else 0


## Shows the main menu over the POST, with [param setup]'s choices to change.
func open(setup: Win95Setup) -> void:
	_cmos = setup.cmos.duplicate()
	_clock_offset = setup.clock_offset_seconds
	focus_mode = Control.FOCUS_ALL
	grab_focus.call_deferred()
	queue_redraw()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000
	if now != _second and _page == Page.STANDARD:
		_second = now
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed:
		return
	accept_event()
	if _question != "":
		_answer_key(key)
	elif key.keycode == KEY_F10:
		_ask("SAVE to CMOS and EXIT (Y/N)? ", true, _save)
	elif _page == Page.MAIN:
		_menu_key(key)
	elif key.keycode == KEY_ESCAPE:
		_page = Page.MAIN
	elif _page == Page.STANDARD:
		_standard_key(key)
	else:
		_features_key(key)
	queue_redraw()


func _menu_key(key: InputEventKey) -> void:
	var left := _menu < _LEFT_MENU
	match key.keycode:
		KEY_UP:
			if _menu != 0 and _menu != _LEFT_MENU:
				_menu -= 1
		KEY_DOWN:
			if _menu != _LEFT_MENU - 1 and _menu != _MENU.size() - 1:
				_menu += 1
		KEY_LEFT, KEY_RIGHT:
			_menu = mini(_menu + _LEFT_MENU, _MENU.size() - 1) if left else _menu - _LEFT_MENU
		KEY_ESCAPE:
			_ask("Quit Without Saving (Y/N)? ", false, func() -> void: closed.emit({} as Dictionary[StringName, Variant]))
		KEY_ENTER, KEY_KP_ENTER:
			match _MENU[_menu][0]:
				"STANDARD CMOS SETUP":
					_page = Page.STANDARD
				"BIOS FEATURES SETUP":
					_page = Page.FEATURES
				"LOAD BIOS DEFAULTS", "LOAD SETUP DEFAULTS":
					_ask("%s (Y/N)? " % _MENU[_menu][0].capitalize(), false, func() -> void: _cmos.clear())
				"SAVE & EXIT SETUP":
					_ask("SAVE to CMOS and EXIT (Y/N)? ", true, _save)
				"EXIT WITHOUT SAVING":
					_ask("Quit Without Saving (Y/N)? ", false, func() -> void: closed.emit({} as Dictionary[StringName, Variant]))


func _features_key(key: InputEventKey) -> void:
	var left := _feature < _LEFT_FEATURES
	match key.keycode:
		KEY_UP:
			if _feature != 0 and _feature != _LEFT_FEATURES:
				_feature -= 1
		KEY_DOWN:
			if _feature != _LEFT_FEATURES - 1 and _feature != FEATURES.size() - 1:
				_feature += 1
		KEY_LEFT, KEY_RIGHT:
			_feature = mini(_feature + _LEFT_FEATURES, FEATURES.size() - 1) if left else _feature - _LEFT_FEATURES
		KEY_F7, KEY_F6:
			_cmos.clear()
		_:
			var step := _step(key)
			if step != 0:
				var id: StringName = FEATURES[_feature][0]
				_cmos[id] = posmod(_cmos.get(id, 0) + step, FEATURES[_feature][2].size())


func _standard_key(key: InputEventKey) -> void:
	match key.keycode:
		KEY_LEFT, KEY_UP:
			_field = posmod(_field - 1, 6)
		KEY_RIGHT, KEY_DOWN:
			_field = posmod(_field + 1, 6)
		_:
			var step := _step(key)
			if step == 0:
				return
			var t := _now()
			var key_name: String = ["month", "day", "year", "hour", "minute", "second"][_field]
			var low: int = [1, 1, 1994, 0, 0, 0][_field]
			var high: int = [12, _days_in(t.month, t.year), 2079, 23, 59, 59][_field]
			t[key_name] = low + posmod(t[key_name] - low + step, high - low + 1)
			t.day = mini(t.day, _days_in(t.month, t.year))
			_clock_offset = Time.get_unix_time_from_datetime_dict(t) - ComputerState.game_unix()


# PgDn, - : the previous option; PgUp, + : the next. 0 for any other key.
func _step(key: InputEventKey) -> int:
	if key.keycode in [KEY_PAGEUP, KEY_KP_ADD, KEY_PLUS, KEY_EQUAL]:
		return 1
	if key.keycode in [KEY_PAGEDOWN, KEY_KP_SUBTRACT, KEY_MINUS]:
		return -1
	return 0


func _ask(question: String, answer: bool, on_yes: Callable) -> void:
	_question = question
	_answer = answer
	_on_yes = on_yes


func _answer_key(key: InputEventKey) -> void:
	match key.keycode:
		KEY_Y:
			_answer = true
		KEY_N:
			_answer = false
		KEY_ESCAPE:
			_question = ""
		KEY_ENTER, KEY_KP_ENTER:
			_question = ""
			if _answer:
				_on_yes.call()


func _save() -> void:
	closed.emit({&"cmos": _cmos.duplicate(), &"clock_offset_seconds": _clock_offset} as Dictionary[StringName, Variant])


func _now() -> Dictionary:
	return Time.get_datetime_dict_from_unix_time(ComputerState.game_unix() + _clock_offset)


static func _days_in(month: int, year: int) -> int:
	if month == 2:
		return 29 if year % 4 == 0 and (year % 100 != 0 or year % 400 == 0) else 28
	return 30 if month in [4, 6, 9, 11] else 31


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), _BLUE)
	_runs.clear()
	var id := hardware.bios_id.get_slice("-", 2).left(8)
	_centre(0, "ROM PCI/ISA BIOS (%s)" % id, _WHITE)
	_centre(1, ["CMOS SETUP UTILITY", "STANDARD CMOS SETUP", "BIOS FEATURES SETUP"][_page], _WHITE)
	_centre(2, "%s SOFTWARE, INC." % hardware.bios_maker.to_upper(), _WHITE)
	match _page:
		Page.MAIN:
			_draw_menu()
		Page.STANDARD:
			_draw_standard()
		Page.FEATURES:
			_draw_features()
	if _question != "":
		var text := _question + ("Y" if _answer else "N")
		@warning_ignore("integer_division")
		var col := (_COLS - text.length() - 4) / 2
		_put(col, 11, "┌" + "─".repeat(text.length() + 2) + "┐", _WHITE, _RED)
		_put(col, 12, "│ " + text + " │", _WHITE, _RED)
		_put(col, 13, "└" + "─".repeat(text.length() + 2) + "┘", _WHITE, _RED)
	var cell := Vector2(size.x / _COLS, size.y / _ROWS)
	draw_set_transform(Vector2.ZERO, 0.0, cell / Vector2(8, 16))
	var ascent := _font.get_ascent(16)
	for run in _runs:
		var at := Vector2(run[0] * 8, run[1] * 16)
		var text: String = run[2]
		if run[4] != Color.TRANSPARENT:
			draw_rect(Rect2(at, Vector2(text.length() * 8, 16)), run[4])
		draw_string(_font, at + Vector2(0, ascent), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, run[3])
	draw_set_transform(Vector2.ZERO)


func _draw_menu() -> void:
	_frame(3, 24, [17, 21], 40, 3, 17)
	for i in _MENU.size():
		var col := 5 if i < _LEFT_MENU else 45
		var row := 4 + 2 * (i if i < _LEFT_MENU else i - _LEFT_MENU)
		_put(col, row, _MENU[i][0], _WHITE if i == _menu else _YELLOW, _RED if i == _menu else Color.TRANSPARENT)
	_put(2, 18, "Esc : Quit", _WHITE)
	_put(2, 19, "F10 : Save & Exit Setup", _WHITE)
	_put(42, 18, "↑ ↓ → ←   : Select Item", _WHITE)
	_put(42, 19, "(Shift)F2 : Change Color", _WHITE)
	_centre(22, _MENU[_menu][1], _YELLOW)


func _draw_standard() -> void:
	_frame(3, 24, [20], -1, 0, 0)
	var t := _now()
	var fields: Array[String] = [_MONTHS[t.month - 1], "%2d" % t.day, "%d" % t.year, "%2d" % t.hour, "%02d" % t.minute, "%02d" % t.second]
	var at: Array[Vector2i] = [Vector2i(25, 4), Vector2i(29, 4), Vector2i(32, 4), Vector2i(21, 5), Vector2i(26, 5), Vector2i(31, 5)]
	_put(2, 4, "Date (mm:dd:yy) :", _YELLOW)
	_put(20, 4, _DAYS[t.weekday] + ",", _WHITE)
	_put(2, 5, "Time (hh:mm:ss) :", _YELLOW)
	_put(24, 5, ":", _WHITE)
	_put(29, 5, ":", _WHITE)
	for i in fields.size():
		_put(at[i].x, at[i].y, fields[i], _WHITE, _RED if i == _field else Color.TRANSPARENT)
	_put(2, 7, "HARD DISKS          TYPE   SIZE   CYLS  HEAD  PRECOMP  LANDZ  SECTOR  MODE", _YELLOW)
	var drives := [["Primary Master  ", hardware.hard_drive], ["Primary Slave   ", ""], ["Secondary Master", hardware.cd_rom], ["Secondary Slave ", ""]]
	for i in drives.size():
		var on: bool = drives[i][1] != ""
		_put(2, 8 + i, "%s  : %s" % [drives[i][0], ("Auto      0      0     0        0      0       0  AUTO" if on else "None      0      0     0        0      0       0  ------")], _YELLOW)
	_put(2, 13, "Drive A : 1.44M, 3.5 in.", _YELLOW)
	_put(2, 14, "Drive B : None", _YELLOW)
	_put(2, 16, "Video   : EGA/VGA", _YELLOW)
	_put(2, 17, "Halt On : All Errors", _YELLOW)
	_put(50, 13, "   Base Memory: %6dK" % 640, _YELLOW)
	_put(50, 14, "Extended Memory: %6dK" % maxi(hardware.memory_kb - 1024, 0), _YELLOW)
	_put(50, 15, "   Other Memory: %6dK" % 384, _YELLOW)
	_put(50, 17, "   Total Memory: %6dK" % hardware.memory_kb, _YELLOW)
	_put(2, 21, "ESC : Quit             ↑ ↓ → ←   : Select Item     PU/PD/+/- : Modify", _WHITE)
	_put(2, 22, "F10 : Save & Exit      (Shift)F2 : Change Color", _WHITE)


func _draw_features() -> void:
	_frame(3, 24, [], -1, 0, 0)
	for i in FEATURES.size():
		var left := i < _LEFT_FEATURES
		var col := 2 if left else 42
		var row := 4 + (i if left else i - _LEFT_FEATURES)
		var label: String = FEATURES[i][1]
		var options: Array = FEATURES[i][2]
		_put(col, row, label.rpad(26 if left else 20) + ": ", _YELLOW)
		var value_col := col + (28 if left else 22)
		_put(value_col, row, options[_cmos.get(FEATURES[i][0], 0)], _WHITE, _RED if i == _feature else Color.TRANSPARENT)
	_put(42, 18, "ESC : Quit       ↑↓→←  : Select Item", _WHITE)
	_put(42, 19, "F1  : Help       PU/PD/+/- : Modify", _WHITE)
	_put(42, 20, "F5  : Old Values (Shift)F2 : Color", _WHITE)
	_put(42, 21, "F6  : Load BIOS  Defaults", _WHITE)
	_put(42, 22, "F7  : Load Setup Defaults", _WHITE)


# The single-line box from [param top] to [param bottom], with a rule across each row of
# [param rules] and, if [param split] is a column, a line down it from [param split_top] to
# [param split_bottom].
func _frame(top: int, bottom: int, rules: Array, split: int, split_top: int, split_bottom: int) -> void:
	var line := "─".repeat(_COLS - 2)
	_put(0, top, "┌" + line + "┐", _WHITE)
	_put(0, bottom, "└" + line + "┘", _WHITE)
	for row in range(top + 1, bottom):
		_put(0, row, "│", _WHITE)
		_put(_COLS - 1, row, "│", _WHITE)
	for row: int in rules:
		_put(0, row, "├" + line + "┤", _WHITE)
	if split >= 0:
		_put(split, split_top, "┬", _WHITE)
		for row in range(split_top + 1, split_bottom):
			_put(split, row, "│", _WHITE)
		_put(split, split_bottom, "┴", _WHITE)


func _centre(row: int, text: String, colour: Color) -> void:
	@warning_ignore("integer_division")
	_put((_COLS - text.length()) / 2, row, text, colour)


func _put(col: int, row: int, text: String, colour: Color, back: Color = Color.TRANSPARENT) -> void:
	_runs.append([col, row, text, colour, back])
