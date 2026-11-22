class_name CarriedPrintout
extends Control
## The printout that the player carries (Game.printout), in every view: its top peeks in at the
## bottom left. A click on it opens the close-up, where a click on a line with a check box ticks or
## unticks it. Esc, Back or a click beside the paper closes the close-up. While it is open it takes
## every click and key. Only the trash can takes the page (TrashCan); while the player carries one,
## a try to take another hops the corner.
## Beside an open screen (see [method hold_beside]) the player holds the page up instead: it rises
## into the space left of the screen, readable and tickable there, and leaves the screen uncovered.

## How far the corner rises, in pixels, while the mouse is over it.
@export var hover_rise: float = 24.0
## The space kept free around the paper in the close-up, in pixels.
@export var close_up_margin: Vector2 = Vector2(80.0, 60.0)
## The font sizes that the close-up and the held page try, largest first; each takes the first at
## which the paper fits.
@export var font_sizes: Array[int] = [32, 24, 16, 12]
## The space between the held page and the screen, and above and below the page, in pixels.
@export var hold_gap: float = 12.0
## The seconds that the page takes to rise beside the screen.
@export var hold_seconds: float = 0.25
## The seconds of each half of the corner's hop when the player tries to take a second page.
@export var hop_seconds: float = 0.08

@onready var _corner: Control = %Corner
@onready var _corner_paper: PrintoutPaper = %CornerPaper
@onready var _close_up: Control = %CloseUp
@onready var _paper: PrintoutPaper = %Paper
@onready var _held: PrintoutPaper = %Held

var _corner_rest: Vector2
## The screen that the page is held up beside, in canvas coordinates; empty: none.
var _beside: Rect2 = Rect2()
## How far the held page has risen into place, 0 to 1.
var _rise: float = 0.0
var _rising: Tween


func _ready() -> void:
	_corner_rest = _corner_paper.position
	_corner.gui_input.connect(_on_corner_input)
	_corner.mouse_entered.connect(func() -> void: _corner_paper.position = _corner_rest - Vector2(0.0, hover_rise))
	_corner.mouse_exited.connect(func() -> void: _corner_paper.position = _corner_rest)
	_close_up.gui_input.connect(_on_close_up_input)
	_paper.gui_input.connect(_on_paper_input.bind(_paper))
	_held.gui_input.connect(_on_paper_input.bind(_held))
	Game.printout_refused.connect(_hop_corner)
	get_viewport().size_changed.connect(_layout)
	Game.changed.connect(_sync)
	_close_up.hide()
	_held.hide()
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


## Holds the carried page up beside [param screen], an open screen in canvas coordinates, instead of
## in the corner; an empty rect puts it back in the corner. The caller passes the screen's current
## rect every frame; the page shows only while the player carries one.
func hold_beside(screen: Rect2) -> void:
	if screen == _beside:
		return
	_beside = screen
	_sync()


## True while the carried page is held up beside a screen.
func is_held() -> bool:
	return _held.visible


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


func _on_paper_input(event: InputEvent, paper: PrintoutPaper) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed:
		return
	paper.accept_event()
	var line := paper.line_at(click.position)
	if click.button_index == MOUSE_BUTTON_LEFT and line >= 0:
		Game.tick_printout(line, line not in Game.printout_ticks)


func _sync() -> void:
	var carrying := not Game.printout.is_empty()
	var held := carrying and _beside.has_area()
	if not carrying or held:
		_close_up.hide()
	_corner.visible = carrying and not is_open() and not held
	if held and not _held.visible:
		_rise_held()
	_held.visible = held
	for paper: PrintoutPaper in [_corner_paper, _paper, _held]:
		paper.lines = Game.printout
		paper.ticks = Game.printout_ticks.duplicate()
	_layout()


# Hops the corner's page up and down twice: the player carries a page already.
func _hop_corner() -> void:
	var hop := create_tween()
	for i: int in 2:
		hop.tween_property(_corner_paper, "position:y", _corner_rest.y - hover_rise, hop_seconds)
		hop.tween_property(_corner_paper, "position:y", _corner_rest.y, hop_seconds)


func _rise_held() -> void:
	if _rising != null:
		_rising.kill()
	_rise = 0.0
	_rising = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_rising.tween_method(func(rise: float) -> void:
		_rise = rise
		_layout(), 0.0, 1.0, hold_seconds)


func _layout() -> void:
	if is_open():
		_layout_close_up()
	if is_held():
		_layout_held()


# Centres the paper at the largest font size at which it fits the view.
func _layout_close_up() -> void:
	var view := get_viewport_rect().size
	var room := view - close_up_margin * 2.0
	for font_size: int in font_sizes:
		_paper.font_size = font_size
		if _paper.size.x <= room.x and _paper.size.y <= room.y:
			break
	_paper.position = ((view - _paper.size) * 0.5).round()


# Lays the held page left of the screen, at the largest font size at which its text fits there; the
# tractor margin may run off the window's edge. It rises from below while [member _rise] grows.
func _layout_held() -> void:
	var view := get_viewport_rect().size
	var room := Vector2(_beside.position.x - hold_gap, view.y - hold_gap * 2.0)
	for font_size: int in font_sizes:
		_held.font_size = font_size
		var margin := _held.cell().x * _held.margin_chars
		if _held.size.x - margin <= room.x and _held.size.y <= room.y:
			break
	var top := clampf(_beside.get_center().y - _held.size.y * 0.5, hold_gap, view.y - hold_gap - _held.size.y)
	var risen := Vector2(_beside.position.x - hold_gap - _held.size.x, top).round()
	_held.position = risen.lerp(Vector2(risen.x, view.y), 1.0 - _rise)
