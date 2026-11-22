extends "res://win95/window.gd"
## A simple calculator: digits, the four operators, = and C. Each key is a Button whose text is
## the key: the ones in %Keys, and %Equals.

const DIVIDE_BY_ZERO: String = "Cannot divide by zero."

## Metadata on the scene tree's root: while set, every result in a computer that runs Cambion
## (Game.runs_cambion) is this number (the corruption sign corruption/calc_666.tscn sets it). Not a
## static var: a GDScript static leaks the script's dependencies at exit.
const CAMBION_RESULT_META: StringName = &"win95_cambion_result"

var _entry: String = "0"
## True when the next digit starts a new number.
var _new_entry: bool = true
var _accumulator: float = 0.0
## The operator waiting for its right operand, or "".
var _pending: String = ""
var _error: bool = false
var _job: Job

@onready var _display: Label = %Display


func _ready() -> void:
	super()
	var desktop := get_parent() as Win95Desktop
	_job = desktop.computer.job if desktop != null and desktop.computer != null else null
	var keys: Array = %Keys.get_children()
	keys.append(%Equals)
	for button: Button in keys:
		button.pressed.connect(press.bind(button.text))


## Presses the key with the label [param key], as a click on it would.
func press(key: String) -> void:
	if _error and key != "C" and not key.is_valid_int():
		return
	if _error or key == "C":
		_clear()
	if key.is_valid_int() or key == ".":
		if _new_entry:
			_entry = "0"
			_new_entry = false
		if key == "." and "." in _entry:
			return
		_entry = key if _entry == "0" and key != "." else _entry + key
	elif key in ["+", "-", "*", "/", "="]:
		var computed := _pending != "" and not _new_entry
		if computed:
			_accumulator = _apply(_accumulator, _pending, _entry.to_float())
		elif _pending == "":
			_accumulator = _entry.to_float()
		var cambion_result: String = get_tree().root.get_meta(CAMBION_RESULT_META, "")
		if (computed or key == "=") and _job != null and Game.runs_cambion(_job.customer) and cambion_result != "":
			_accumulator = cambion_result.to_float()
		_pending = "" if key == "=" else key
		_new_entry = true
		_entry = _format(_accumulator)
	_display.text = DIVIDE_BY_ZERO if _error else _entry


func _clear() -> void:
	_entry = "0"
	_new_entry = true
	_accumulator = 0.0
	_pending = ""
	_error = false


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
				_error = true
				return 0.0
			return left / right
	assert(false, "Calculator: no operator %s" % op)
	return left


func _format(value: float) -> String:
	if value == floorf(value) and absf(value) < 1e15:
		return str(int(value))
	return String.num(value, 10)
