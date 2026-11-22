class_name CarriedPrintout
extends Control
## The printout that the player carries (Game.printout), in every view: its top peeks in at the
## bottom left. A click on it opens the close-up, where a click on a line with a check box ticks or
## unticks it, and "Throw in the trash" puts the printout in the trash can. Esc, Back or a click
## beside the paper closes the close-up. While it is open it takes every click and key.

## How far the corner rises, in pixels, while the mouse is over it.
@export var hover_rise: float = 24.0
## The space kept free around the paper in the close-up, in pixels; the button goes below the paper.
@export var close_up_margin: Vector2 = Vector2(80.0, 60.0)
## The font sizes that the close-up tries, largest first; it takes the first at which the paper fits.
@export var close_up_font_sizes: Array[int] = [32, 24, 16]

@onready var _corner: Control = %Corner
@onready var _corner_paper: PrintoutPaper = %CornerPaper
@onready var _close_up: Control = %CloseUp
@onready var _paper: PrintoutPaper = %Paper
@onready var _throw_away: Button = %ThrowAway

var _corner_rest: Vector2


func _ready() -> void:
	_corner_rest = _corner_paper.position
	_corner.gui_input.connect(_on_corner_input)
	_corner.mouse_entered.connect(func() -> void: _corner_paper.position = _corner_rest - Vector2(0.0, hover_rise))
	_corner.mouse_exited.connect(func() -> void: _corner_paper.position = _corner_rest)
	_close_up.gui_input.connect(_on_close_up_input)
	_paper.gui_input.connect(_on_paper_input)
	_throw_away.pressed.connect(func() -> void: Game.trash_printout())
	get_viewport().size_changed.connect(_layout)
	Game.changed.connect(_sync)
	_close_up.hide()
	_sync()


## True while the close-up of the printout is open.
func is_open() -> bool:
	return _close_up.visible


## Opens the close-up of the carried printout; does nothing while the player carries none.
func open() -> void:
	if Game.printout.is_empty():
		return
	_close_up.show()
	_sync()


## Closes the close-up; the player still carries the printout.
func close() -> void:
	_close_up.hide()
	_sync()


func _unhandled_input(event: InputEvent) -> void:
	if not is_open() or event is InputEventMouse:
		return
	if event.is_action_pressed(&"go_back"):
		close()
	get_viewport().set_input_as_handled()


func _on_corner_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		open()


func _on_close_up_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed:
		accept_event()
		close()


func _on_paper_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed:
		return
	_paper.accept_event()
	var line := _paper.line_at(click.position)
	if click.button_index == MOUSE_BUTTON_LEFT and line >= 0:
		Game.tick_printout(line, line not in Game.printout_ticks)


func _sync() -> void:
	var carrying := not Game.printout.is_empty()
	if not carrying:
		_close_up.hide()
	_corner.visible = carrying and not is_open()
	for paper: PrintoutPaper in [_corner_paper, _paper]:
		paper.lines = Game.printout
		paper.ticks = Game.printout_ticks.duplicate()
	_layout()


# Centres the paper at the largest font size at which it and the button fit the view.
func _layout() -> void:
	if not is_open():
		return
	var view := get_viewport_rect().size
	var room := view - close_up_margin * 2.0 - Vector2(0.0, _throw_away.size.y)
	for font_size: int in close_up_font_sizes:
		_paper.font_size = font_size
		if _paper.size.x <= room.x and _paper.size.y <= room.y:
			break
	var top_left := ((view - Vector2(0.0, _throw_away.size.y) - _paper.size) * 0.5).round()
	_paper.position = top_left
	_throw_away.position = top_left + _paper.size + Vector2(-_throw_away.size.x, 8.0)
