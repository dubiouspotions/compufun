class_name CarriedPrintout
extends Control
## The printout that the player carries (Game.printout), in every view: its top peeks in at the
## bottom left, clear of the part in the hand on the right. A click on it raises the page: the player
## holds it up on the right side of the view, readable, and keeps playing beside it. A click on a
## line with a check box ticks or unticks it, a click on its folded corner lowers it, and a
## click on the trash can throws the page away; other clicks go on to what is under them. A page
## just picked up comes up raised. While a customer talks, at the counter or on the phone, a raised
## page is down, and comes back up after. Beside an open screen (see [method lay_out_around]) a raised
## page stands right of the screen, leaving it uncovered. Only the trash can takes the page
## (TrashCan); while the player carries one, a try to take another hops the corner.

## How far the corner rises, in pixels, while the mouse is over it.
@export var hover_rise: float = 24.0
## The font sizes that the raised page tries, largest first; it takes the first at which it fits.
@export var font_sizes: Array[int] = [32, 24, 16, 12]
## The share of the view's width, on the right, that the raised page may take away from a screen.
@export_range(0.1, 1.0) var raised_share: float = 0.32
## The space between the raised page and the screen, the buttons and the window's edges, in pixels.
@export var gap: float = 12.0
## The seconds that the page takes to rise, and to drop back down.
@export var raise_seconds: float = 0.25
@export var lower_seconds: float = 0.2
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
## The page is up, or rising; false while it drops and once it is down.
var _up: bool = false
var _rising: Tween
## The page carried at the last sync: a new one, just picked up, comes up raised.
var _carried: PackedStringArray = []


func _ready() -> void:
	_corner_rest = _corner_paper.position
	_corner.gui_input.connect(_on_corner_input)
	_corner.mouse_entered.connect(func() -> void: _corner_paper.position = _corner_rest - Vector2(0.0, hover_rise))
	_corner.mouse_exited.connect(func() -> void: _corner_paper.position = _corner_rest)
	_paper.gui_input.connect(_on_paper_input)
	_paper.mouse_exited.connect(func() -> void: _paper.fold_hovered = false)
	Game.printout_refused.connect(_hop_corner)
	get_viewport().size_changed.connect(_layout)
	Game.changed.connect(_sync)
	_paper.hide()
	_carried = Game.printout  # one carried as the scene loads stays in the corner
	_sync()


## True while the carried page is up, or rising; false as it drops.
func is_raised() -> bool:
	return _up


## Raises the carried page; does nothing while the player carries none or a customer talks.
func raise() -> void:
	_raised = not Game.printout.is_empty() and not _talking()
	_sync()


## Lowers the page back into the corner; the player still carries it.
func lower() -> void:
	_raised = false
	_sync()


## Tells the page what to keep clear while it is up, every frame: [param screen] is an open screen in
## canvas coordinates, beside which the raised page stands (empty: none), and [param buttons] are the
## view's buttons, which it leaves uncovered.
func lay_out_around(screen: Rect2, buttons: Array[Rect2]) -> void:
	if screen == _beside and buttons == _buttons:
		return
	_beside = screen
	_buttons = buttons
	_sync()


# _input, before the hotspots: a left click on the trash can throws the raised page in, even with a part
# in the hand, which the can would take first.
func _input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT or not is_raised():
		return
	var can := get_tree().get_first_node_in_group(TrashCan.GROUP) as TrashCan
	if can != null and can.is_hovered() and can.throw_printout():
		get_viewport().set_input_as_handled()


func _on_corner_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		raise()


func _on_paper_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null:
		_paper.fold_hovered = _paper.fold_rect().grow(4.0).has_point(motion.position)
		return
	var click := event as InputEventMouseButton
	if click == null or not click.pressed:
		return
	_paper.accept_event()
	if click.button_index != MOUSE_BUTTON_LEFT:
		return
	if _paper.fold_rect().grow(4.0).has_point(click.position):
		lower()
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
		@warning_ignore("static_called_on_instance")
		if Game.printout_box(lines[i]) >= 0:
			return i
	return -1


func _sync() -> void:
	var carrying := not Game.printout.is_empty()
	if carrying and Game.printout != _carried:
		_raised = true
	_carried = Game.printout
	_raised = _raised and carrying
	var up := carrying and _raised and not _talking()
	if up != _up and carrying:
		handle_sound.play_at(self)
	if up != _up:
		_up = up
		_move_page()
	_corner.visible = carrying and not up and not _paper.visible
	for paper: PrintoutPaper in [_corner_paper, _paper]:
		paper.lines = Game.printout
		paper.ticks = Game.printout_ticks.duplicate()
	_fit_corner()
	_layout()


# A customer talks, at the counter or on the phone: the page is out of the way.
func _talking() -> bool:
	return Game.visitor_state == Game.VisitorState.TALKING or Game.phase == Game.Phase.CALLING


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


# Slides the page up into place, or down out of the view and then back into the corner, from wherever
# it is now. A dropping page takes no clicks.
func _move_page() -> void:
	if _rising != null:
		_rising.kill()
	_paper.mouse_filter = Control.MOUSE_FILTER_STOP if _up else Control.MOUSE_FILTER_IGNORE
	_paper.fold_hovered = false
	if _up:
		_paper.show()
	_rising = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT if _up else Tween.EASE_IN)
	_rising.tween_method(func(rise: float) -> void:
		_rise = rise
		_layout(), _rise, 1.0 if _up else 0.0, (1.0 - _rise if _up else _rise) * (raise_seconds if _up else lower_seconds))
	if not _up:
		_rising.tween_callback(func() -> void:
			_paper.hide()
			_corner.visible = not Game.printout.is_empty())


# Lays the raised page on the right: right of the screen, or in the right [member raised_share] of
# the view, left of the buttons there, at the largest font size at which its text fits. Its tractor
# margin may run off the window's edge. It rises from below while [member _rise] grows.
func _layout() -> void:
	if not _paper.visible:
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
