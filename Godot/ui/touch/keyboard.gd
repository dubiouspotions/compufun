class_name TouchKeyboard
extends Control
## A compact 90s PC keyboard for touch screens. Each key sends a real key press and release through
## [method Input.parse_input_event], so the screen views, CompuFunDB and Win95 take it like a
## hardware key. Ctrl, Alt and Shift are sticky: a tap latches one, and the next key sends it along
## and releases it, so Ctrl+Alt+Del is Ctrl, Alt, Del. It shows while the [Trackpad] shows and the
## player toggled it on there.

const _MODIFIERS: Array[String] = ["Ctrl", "Alt", "Shift"]
## What Shift types on a US keyboard, for the keys that aren't letters.
const _SHIFTED: Dictionary[String, String] = {
	"1": "!", "2": "@", "3": "#", "4": "$", "5": "%", "6": "^", "7": "&", "8": "*", "9": "(", "0": ")",
	"-": "_", "=": "+", "[": "{", "]": "}", "\\": "|", ";": ":", "'": "\"", ",": "<", ".": ">", "/": "?", "`": "~",
}

## The keys, one row per string, top to bottom: Godot key names
## ([method OS.find_keycode_from_string]) separated by spaces, each with an optional width in keys
## after a [code]*[/code]. Ctrl, Alt and Shift are the sticky modifiers.
@export var rows: PackedStringArray = [
	"Escape 1 2 3 4 5 6 7 8 9 0 Minus Equal Backspace*1.5",
	"Tab*1.5 Q W E R T Y U I O P BracketLeft BracketRight Delete",
	"Ctrl*1.75 A S D F G H J K L Semicolon Apostrophe Enter*1.75",
	"Shift*2.5 Z X C V B N M Comma Period Slash Up Backslash",
	"Alt*1.5 Space*10 Left Down Right",
]
## The size of a one-wide key, in design pixels.
@export var key_size: Vector2 = Vector2(62, 62)
## The cap of a key whose name isn't what it types; the others show their character.
@export var caps: Dictionary[String, String] = {
	"Escape": "Esc", "Backspace": "Bksp", "Tab": "Tab", "Delete": "Del", "Enter": "Enter",
	"Space": "", "Up": "^", "Down": "v", "Left": "<", "Right": ">",
}

var _modifiers: Dictionary[String, Button] = {}
var _printable: Dictionary[Button, Key] = {}

@onready var _keys: VBoxContainer = %Keys


func _ready() -> void:
	_build()
	_reconcile()


func _process(_delta: float) -> void:
	_reconcile()


## Taps the key [param key_name] (a name from [member rows]), as a finger on its cap would.
func tap(key_name: String) -> void:
	if key_name in _MODIFIERS:
		var modifier: Button = _modifiers.get(key_name)
		if modifier != null:
			modifier.button_pressed = not modifier.button_pressed
		return
	var keycode := OS.find_keycode_from_string(key_name)
	if keycode == KEY_NONE:
		push_error("TouchKeyboard: no key named '%s'" % key_name)
		return
	for pressed: bool in [true, false]:
		var key := InputEventKey.new()
		key.keycode = keycode
		key.physical_keycode = keycode
		key.key_label = keycode
		key.pressed = pressed
		key.ctrl_pressed = _latched("Ctrl")
		key.alt_pressed = _latched("Alt")
		key.shift_pressed = _latched("Shift")
		if pressed:
			key.unicode = _unicode(keycode)
		Input.parse_input_event(key)
	_release_modifiers()


func _reconcile() -> void:
	var pad := get_tree().get_first_node_in_group(Trackpad.GROUP) as Trackpad
	var shown := pad != null and pad.visible and pad.keyboard_open
	if visible and not shown:
		_release_modifiers()
	visible = shown


func _build() -> void:
	for row: String in rows:
		var line := HBoxContainer.new()
		line.add_theme_constant_override(&"separation", 4)
		_keys.add_child(line)
		for token: String in row.split(" ", false):
			var parts := token.split("*")
			var key_name := parts[0]
			var width := parts[1].to_float() if parts.size() > 1 else 1.0
			if not key_name in _MODIFIERS and OS.find_keycode_from_string(key_name) == KEY_NONE:
				push_error("TouchKeyboard: rows name an unknown key '%s' in '%s'" % [key_name, row])
				continue
			line.add_child(_make_key(key_name, width))
	_relabel()


func _make_key(key_name: String, width: float) -> Button:
	var key := Button.new()
	key.name = key_name
	key.focus_mode = Control.FOCUS_NONE  # a focused key would answer Enter and Space as ui_accept
	# Keep the release action mode: in press mode a finger presses twice, by its touch and its mouse twin.
	key.custom_minimum_size = Vector2(key_size.x * width + 4.0 * (width - 1.0), key_size.y)
	key.text = caps.get(key_name, key_name)
	if key_name in _MODIFIERS:
		key.toggle_mode = true
		key.toggled.connect(func(_on: bool) -> void: _relabel())
		_modifiers[key_name] = key
	else:
		key.pressed.connect(tap.bind(key_name))
		var keycode := OS.find_keycode_from_string(key_name)
		if _unicode(keycode) != 0 and not caps.has(key_name):
			_printable[key] = keycode
	return key


func _latched(modifier: String) -> bool:
	var key: Button = _modifiers.get(modifier)
	return key != null and key.button_pressed


func _release_modifiers() -> void:
	for key: Button in _modifiers.values():
		key.button_pressed = false


# The character that [param keycode] types with the latched modifiers, or 0.
func _unicode(keycode: Key) -> int:
	if keycode < 32 or keycode > 126 or _latched("Ctrl") or _latched("Alt"):
		return 0
	var character := char(keycode)
	if _latched("Shift"):
		character = _SHIFTED.get(character, character.to_upper())
	elif keycode >= KEY_A and keycode <= KEY_Z:
		character = character.to_lower()
	return character.unicode_at(0)


func _relabel() -> void:
	for key: Button in _printable:
		key.text = char(_unicode(_printable[key])).to_upper() if not _latched("Ctrl") and not _latched("Alt") else char(_printable[key])
