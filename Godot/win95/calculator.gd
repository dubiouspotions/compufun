extends "res://win95/window.gd"
## The Win95 Calculator, standard view. Each key is a Button under %Keys, and its text is the key.
## The keyboard works too while the window is visible: digits, . + - * / % Enter = Delete Backspace,
## @ for sqrt and r for 1/x. Not Esc: that leaves the Screen View.

enum EditMenu { COPY, PASTE }

const DIVIDE_BY_ZERO: String = "Cannot divide by zero."
const INVALID_INPUT: String = "Invalid input for function."
## The most digits that the player can type, as in Win95.
const MAX_DIGITS: int = 32
const RED_KEYS: PackedStringArray = ["Backspace", "CE", "C", "MC", "MR", "MS", "M+", "/", "*", "-", "+", "="]
const BINARY_OPS: PackedStringArray = ["+", "-", "*", "/"]
const KEYBOARD: Dictionary = {
	KEY_ENTER: "=", KEY_KP_ENTER: "=", KEY_DELETE: "CE", KEY_BACKSPACE: "Backspace",
	KEY_KP_ADD: "+", KEY_KP_SUBTRACT: "-", KEY_KP_MULTIPLY: "*", KEY_KP_DIVIDE: "/", KEY_KP_PERIOD: ".",
}

## The text colour of the operator, memory and clear keys.
@export var red_key_color: Color = Color(1, 0, 0)
## The text colour of the digit and function keys.
@export var blue_key_color: Color = Color(0, 0, 1)

var _entry: String = "0"
## True when the next digit starts a new number instead of extending the shown one.
var _new_entry: bool = true
var _accumulator: float = 0.0
## The operator waiting for its right operand, or "".
var _pending: String = ""
## What "=" repeats when the player presses it again.
var _last_op: String = ""
var _last_operand: float = 0.0
var _memory: float = 0.0
var _error: String = ""

@onready var _display: Label = %Display
@onready var _memory_flag: Label = %MemoryFlag


func _ready() -> void:
	super()
	for button: Button in %Keys.find_children("*", "Button", true, false):
		button.pressed.connect(press.bind(button.text))
		var color := red_key_color if button.text in RED_KEYS else blue_key_color
		for theme_color: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_hover_pressed_color", &"font_focus_color"]:
			button.add_theme_color_override(theme_color, color)
	%Edit.id_pressed.connect(_on_edit_menu)
	_sync()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or not is_visible_in_tree():
		return
	var text: String = KEYBOARD.get(key.keycode, "")
	if text == "" and key.unicode > 0:
		text = {"@": "sqrt", "r": "1/x", "R": "1/x", ",": "."}.get(char(key.unicode), char(key.unicode))
	if text == "" or not _is_key(text):
		return
	press(text)
	get_viewport().set_input_as_handled()


## Presses the key with the label [param key], as a click on it would.
func press(key: String) -> void:
	if _error != "" and not (key in ["C", "CE"] or key.is_valid_int()):
		return
	if _error != "":
		_function("C")
		_error = ""
	if key.is_valid_int():
		_type_digit(key)
	elif key == ".":
		if _new_entry:
			_entry = "0"
			_new_entry = false
		if not "." in _entry:
			_entry += "."
	elif key in BINARY_OPS:
		_binary(key)
	elif key == "=":
		_equals()
	else:
		_function(key)
	_sync()


func _type_digit(digit: String) -> void:
	if _new_entry:
		_entry = "0"
		_new_entry = false
	if _entry.replace("-", "").replace(".", "").length() >= MAX_DIGITS:
		return
	_entry = digit if _entry == "0" else _entry + digit


func _binary(op: String) -> void:
	if _pending != "" and not _new_entry:
		_accumulator = _apply(_accumulator, _pending, _value())
		_show(_accumulator)
	elif _pending == "":
		_accumulator = _value()
	_pending = op
	_new_entry = true


func _equals() -> void:
	if _pending != "":
		_last_op = _pending
		_last_operand = _value()
		_accumulator = _apply(_accumulator, _pending, _last_operand)
		_pending = ""
	elif _last_op != "":
		_accumulator = _apply(_value(), _last_op, _last_operand)
	else:
		return
	_show(_accumulator)
	_new_entry = true


func _function(key: String) -> void:
	var value := _value()
	match key:
		"Backspace":
			if not _new_entry:
				_entry = _entry.left(-1)
				if _entry == "" or _entry == "-":
					_entry = "0"
		"CE":
			_entry = "0"
			_new_entry = true
		"C":
			_entry = "0"
			_new_entry = true
			_accumulator = 0.0
			_pending = ""
			_last_op = ""
		"+/-":
			_entry = _entry.trim_prefix("-") if _entry.begins_with("-") else ("-" + _entry if _entry != "0" else _entry)
		"sqrt":
			if value < 0.0:
				_error = INVALID_INPUT
			else:
				_show(sqrt(value))
			_new_entry = true
		"%":
			_show(_accumulator * value / 100.0)
			_new_entry = true
		"1/x":
			if value == 0.0:
				_error = DIVIDE_BY_ZERO
			else:
				_show(1.0 / value)
			_new_entry = true
		"MC":
			_memory = 0.0
		"MR":
			_show(_memory)
			_new_entry = true
		"MS":
			_memory = value
			_new_entry = true
		"M+":
			_memory += value
			_new_entry = true
		_:
			assert(false, "Calculator: no key %s" % key)


func _apply(left: float, op: String, right: float) -> float:
	match op:
		"+":
			return left + right
		"-":
			return left - right
		"*":
			return left * right
		"/":
			if right == 0.0:
				_error = DIVIDE_BY_ZERO
				return left
			return left / right
	assert(false, "Calculator: no operator %s" % op)
	return left


func _value() -> float:
	return _entry.to_float()


## Puts [param value] in the entry, in the shortest form that round-trips at 15 digits.
func _show(value: float) -> void:
	if is_inf(value) or is_nan(value):
		_error = INVALID_INPUT
		return
	if value == floorf(value) and absf(value) < 1e15:
		_entry = str(int(value))
	else:
		_entry = String.num(value, maxi(0, 15 - String.num(absf(value), 0).length()))


func _sync() -> void:
	if _error != "":
		_display.text = _error
	else:
		_display.text = _entry if "." in _entry else _entry + "."
	_memory_flag.text = "M" if _memory != 0.0 else ""


func _is_key(text: String) -> bool:
	for button: Button in %Keys.find_children("*", "Button", true, false):
		if button.text == text:
			return true
	return false


func _on_edit_menu(id: int) -> void:
	match id:
		EditMenu.COPY:
			DisplayServer.clipboard_set(_display.text.trim_suffix("."))
		EditMenu.PASTE:
			var pasted := DisplayServer.clipboard_get().strip_edges()
			if not pasted.is_valid_float():
				return
			_entry = pasted
			_new_entry = false
			_error = ""
			_sync()
