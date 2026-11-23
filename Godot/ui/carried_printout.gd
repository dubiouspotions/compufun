class_name CarriedPrintout
extends Control
## The printout that the player carries (Game.printout), in every view: its top peeks in at the
## bottom left, clear of the part in the hand on the right. A click on it raises the page: the player
## holds it up on the right side of the view, readable, and keeps playing beside it. A click on a
## line with a check box ticks or unticks it, and a click on the trash can throws the page away. A
## click on a computer on the counter lowers the page and goes on to the computer, which opens the
## Workview on it. A click elsewhere outside the page, or Esc, lowers it, and does nothing else. A page
## just picked up comes up raised. Beside
## an open screen (see [method lay_out_around]) the page is always up, right of the screen and leaving
## it uncovered. Only the trash can takes the page (TrashCan); while the player carries one, a try to
## take another hops the corner.

## How far the corner rises, in pixels, while the mouse is over it.
@export var hover_rise: float = 24.0
## The font sizes that the raised page tries, largest first; it takes the first at which it fits.
@export var font_sizes: Array[int] = [32, 24, 16, 12]
## The share of the view's width, on the right, that the raised page may take away from a screen.
@export_range(0.1, 1.0) var raised_share: float = 0.32
## The space between the raised page and the screen, the buttons and the window's edges, in pixels.
@export var gap: float = 12.0
## The seconds that the page takes to rise.
@export var raise_seconds: float = 0.25
## The seconds of each half of the corner's hop when the player tries to take a second page.
@export var hop_seconds: float = 0.08
## The sound of the page handled as it rises or is lowered.
@export var handle_sound: SoundSet = preload("res://sounds/paper_handle.tres")
## The sounds of a box ticked in pencil, and of a tick rubbed out.
@export var tick_sound: SoundSet = preload("res://sounds/pencil_tick.tres")
@export var untick_sound: SoundSet = preload("res://sounds/eraser_rub.tres")

@onready var _corner: Control = %Corner
@onready var _corner_paper: PrintoutPaper = %CornerPaper
@onready var _paper: PrintoutPaper = %Paper

var _corner_rest: Vector2
## The player raised the page.
var _raised: bool = false
## The open screen that the page is held up beside, in canvas coordinates; empty: none.
var _beside: Rect2 = Rect2()
## The buttons that the raised page must leave uncovered, in canvas coordinates.
var _buttons: Array[Rect2] = []
## How far the raised page has risen into place, 0 to 1.
var _rise: float = 0.0
var _rising: Tween
## The page carried at the last sync: a new one, just picked up, comes up raised.
var _carried: PackedStringArray = []


func _ready() -> void:
	_corner_rest = _corner_paper.position
	_corner.gui_input.connect(_on_corner_input)
	_corner.mouse_entered.connect(func() -> void: _corner_paper.position = _corner_rest - Vector2(0.0, hover_rise))
	_corner.mouse_exited.connect(func() -> void: _corner_paper.position = _corner_rest)
	_paper.gui_input.connect(_on_paper_input)
	Game.printout_refused.connect(_hop_corner)
	get_viewport().size_changed.connect(_layout)
	Game.changed.connect(_sync)
	_paper.hide()
	_carried = Game.printout  # one carried as the scene loads stays in the corner
	_sync()


## True while the carried page is up: raised by the player, or beside an open screen.
func is_raised() -> bool:
	return _paper.visible


## Raises the carried page; does nothing while the player carries none.
func raise() -> void:
	_raised = not Game.printout.is_empty()
	_sync()


## Lowers the page back into the corner, unless it is beside an open screen; the player still
## carries it.
func lower() -> void:
	_raised = false
	_sync()


## Tells the page what to keep clear while it is up, every frame: [param screen] is an open screen in
## canvas coordinates, beside which the page is always up (empty: none), and [param buttons] are the
## view's buttons, which it leaves uncovered.
func lay_out_around(screen: Rect2, buttons: Array[Rect2]) -> void:
	if screen == _beside and buttons == _buttons:
		return
	_beside = screen
	_buttons = buttons
	_sync()


# _input, before the buttons, the screens and the hotspots: a click outside the raised page only lowers it,
# or throws it in the trash can under the mouse, or lowers it and goes on to the computer under the mouse.
func _input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index not in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		return
	if not _raised or _beside.has_area():
		return
	if Rect2(Vector2.ZERO, _paper.size).has_point((_paper.make_input_local(click) as InputEventMouseButton).position):
		return
	var can := get_tree().get_first_node_in_group(TrashCan.GROUP) as TrashCan
	if click.button_index == MOUSE_BUTTON_LEFT and can != null and can.is_hovered():
		can.throw_printout()
	elif click.button_index == MOUSE_BUTTON_LEFT and get_tree().get_nodes_in_group(JobComputer.GROUP).any(func(computer: JobComputer) -> bool: return computer.is_hovered()):
		lower()
		return  # unhandled, so the click goes on to the computer
	else:
		lower()
	get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if _raised and is_raised() and not _beside.has_area() and event.is_action_pressed(&"go_back"):
		lower()
		get_viewport().set_input_as_handled()


func _on_corner_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		raise()


func _on_paper_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed:
		return
	_paper.accept_event()
	if click.button_index != MOUSE_BUTTON_LEFT:
		return
	var line := _boxed_line(_paper.line_at(click.position))
	if line >= 0:
		var tick := line not in Game.printout_ticks
		if Game.tick_printout(line, tick):
			(tick_sound if tick else untick_sound).play_at(self)


# The line with the check box of the entry that [param line] is part of; -1 for none. An entry wraps
# onto lines that start with spaces: a step has its box on its last line, a check on its first.
func _boxed_line(line: int) -> int:
	if line < 0:
		return -1
	var lines := Game.printout
	var first := line
	while first > 0 and lines[first].begins_with(" "):
		first -= 1
	var last := first
	while last + 1 < lines.size() and lines[last + 1].begins_with(" "):
		last += 1
	for i: int in range(first, last + 1):
		if Game.printout_box(lines[i]) >= 0:
			return i
	return -1


func _sync() -> void:
	var carrying := not Game.printout.is_empty()
	if carrying and Game.printout != _carried:
		_raised = true
	_carried = Game.printout
	_raised = _raised and carrying
	var up := carrying and (_raised or _beside.has_area())
	_corner.visible = carrying and not up
	if up != _paper.visible and carrying:
		handle_sound.play_at(self)
	if up and not _paper.visible:
		_rise_page()
	_paper.visible = up
	for paper: PrintoutPaper in [_corner_paper, _paper]:
		paper.lines = Game.printout
		paper.ticks = Game.printout_ticks.duplicate()
	_fit_corner()
	_layout()


# Widens the corner to the tilted page's right edge, so that it clips only the page's bottom.
func _fit_corner() -> void:
	var paper := Transform2D(_corner_paper.rotation, _corner_rest)
	var right := maxf((paper * Vector2(_corner_paper.size.x, 0.0)).x, (paper * Vector2(_corner_paper.size.x, _corner.size.y)).x)
	_corner.size.x = ceilf(right)


# Hops the corner's page up and down twice: the player carries a page already.
func _hop_corner() -> void:
	var hop := create_tween()
	for i: int in 2:
		hop.tween_property(_corner_paper, "position:y", _corner_rest.y - hover_rise, hop_seconds)
		hop.tween_property(_corner_paper, "position:y", _corner_rest.y, hop_seconds)


func _rise_page() -> void:
	if _rising != null:
		_rising.kill()
	_rise = 0.0
	_rising = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_rising.tween_method(func(rise: float) -> void:
		_rise = rise
		_layout(), 0.0, 1.0, raise_seconds)


# Lays the raised page on the right: right of the screen, or in the right [member raised_share] of
# the view, left of the buttons there, at the largest font size at which its text fits. Its tractor
# margin may run off the window's edge. It rises from below while [member _rise] grows.
func _layout() -> void:
	if not is_raised():
		return
	var view := get_viewport_rect().size
	var left := _beside.end.x + gap if _beside.has_area() else view.x * (1.0 - raised_share)
	var right := view.x
	for button: Rect2 in _buttons:
		if button.get_center().x > left:
			right = minf(right, button.position.x - gap)
	var room := Rect2(left, gap, right - left, view.y - gap * 2.0)
	for font_size: int in font_sizes:
		_paper.font_size = font_size
		var off_edge := _paper.cell().x * _paper.margin_chars if right >= view.x else 0.0
		if _paper.size.x - off_edge <= room.size.x and _paper.size.y <= room.size.y:
			break
	var top := clampf(room.get_center().y - _paper.size.y * 0.5, room.position.y, room.end.y - _paper.size.y)
	var risen := Vector2(maxf(left, right - _paper.size.x), top).round()
	_paper.position = risen.lerp(Vector2(risen.x, view.y), 1.0 - _rise)
