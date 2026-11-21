extends Control
## The felt of Solitaire: draws a Klondike game and plays it with the mouse. Click the stock to
## draw, drag face-up cards between piles, double-click a card to send it to a foundation.

## Emitted when the last card reaches a foundation.
signal won

## The 52 faces, 13 ranks across (Ace first) and 4 suits down, in Klondike.Suit order.
@export var faces: Texture2D
@export var back: Texture2D
## Shown on the empty stock: a click turns the waste over.
@export var recycle: Texture2D
@export var felt := Color(0.0, 0.5, 0.0)
@export var outline := Color(0.0, 0.3, 0.0)
@export var card_size := Vector2(71, 96)
## Space between piles and around the table, in pixels.
@export var gap := 6.0
## How far a tableau card shows below the one under it: face down, and face up at most.
@export var down_step := 3.0
@export var up_step := 14.0

var _game := Klondike.new()
## The pile and index of the bottom card being dragged; -1 when nothing is.
var _drag_pile := -1
var _drag_index := -1
## Where the dragged bottom card's corner is, in local coordinates.
var _drag_at := Vector2.ZERO
var _grab := Vector2.ZERO


func _ready() -> void:
	deal()


## Shuffles and deals a new game.
func deal() -> void:
	_game.deal(randi())
	_drag_pile = -1
	queue_redraw()


func _get_minimum_size() -> Vector2:
	return Vector2(gap + 7 * (card_size.x + gap), 2 * card_size.y + 3 * gap + 13 * up_step)


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			_press(button.position, button.double_click)
		elif _drag_pile != -1:
			_drop()
		accept_event()
	elif event is InputEventMouseMotion and _drag_pile != -1:
		_drag_at = (event as InputEventMouseMotion).position - _grab
		queue_redraw()
		accept_event()


func _press(point: Vector2, double: bool) -> void:
	if Rect2(_pile_origin(Klondike.STOCK), card_size).has_point(point):
		_game.draw()
		queue_redraw()
		return
	var hit := _card_at(point)
	if hit.x == -1 or not _game.is_face_up(hit.x, hit.y):
		return
	if double:
		if hit.y == _game.cards(hit.x).size() - 1 and _game.to_foundation(hit.x):
			_after_move()
		return
	_drag_pile = hit.x
	_drag_index = hit.y
	_drag_at = _card_rect(hit.x, hit.y).position
	_grab = point - _drag_at
	queue_redraw()


func _drop() -> void:
	var center := _drag_at + card_size / 2
	for pile in range(Klondike.FOUNDATION, Klondike.PILES):
		if _drop_rect(pile).has_point(center) and _game.move(_drag_pile, _drag_index, pile):
			break
	_drag_pile = -1
	_after_move()


func _after_move() -> void:
	queue_redraw()
	if _game.is_won():
		won.emit()


## The topmost card under [param point] as (pile, index), or (-1, -1).
func _card_at(point: Vector2) -> Vector2i:
	for pile in range(Klondike.WASTE, Klondike.PILES):
		for index in range(_game.cards(pile).size() - 1, -1, -1):
			if _card_rect(pile, index).has_point(point):
				return Vector2i(pile, index)
			if pile < Klondike.TABLEAU:
				break
	return Vector2i(-1, -1)


func _pile_origin(pile: int) -> Vector2:
	var column: int
	var row := 0
	if pile == Klondike.STOCK:
		column = 0
	elif pile == Klondike.WASTE:
		column = 1
	elif pile < Klondike.TABLEAU:
		column = 3 + pile - Klondike.FOUNDATION
	else:
		column = pile - Klondike.TABLEAU
		row = 1
	return Vector2(gap + column * (card_size.x + gap), gap + row * (card_size.y + 2 * gap))


func _card_rect(pile: int, index: int) -> Rect2:
	var at := _pile_origin(pile)
	if pile >= Klondike.TABLEAU:
		var step := _up_step(pile)
		for i in index:
			at.y += step if _game.is_face_up(pile, i) else down_step
	return Rect2(at, card_size)


## The face-up step of a tableau column, shrunk so a long run still fits on the table.
func _up_step(pile: int) -> float:
	var count := _game.cards(pile).size()
	var up := 0
	for i in count - 1:
		if _game.is_face_up(pile, i):
			up += 1
	if up == 0:
		return up_step
	var room := size.y - _pile_origin(pile).y - card_size.y - gap - (count - 1 - up) * down_step
	return clampf(room / up, down_step, up_step)


func _drop_rect(pile: int) -> Rect2:
	var rect := Rect2(_pile_origin(pile), card_size)
	if pile >= Klondike.TABLEAU:
		rect.size.y = size.y - rect.position.y
	return rect.grow(gap / 2)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), felt)
	for pile in Klondike.PILES:
		var cards := _game.cards(pile)
		var empty := Rect2(_pile_origin(pile), card_size)
		if cards.is_empty() or (pile == _drag_pile and _drag_index == 0):
			if pile == Klondike.STOCK:
				draw_texture_rect(recycle, empty, false)
			else:
				draw_rect(empty, outline, false)
		var first := 0 if pile >= Klondike.TABLEAU else maxi(cards.size() - 2, 0)
		var last := _drag_index if pile == _drag_pile else cards.size()
		for index in range(first, last):
			_draw_card(cards[index], _game.is_face_up(pile, index), _card_rect(pile, index).position)
	if _drag_pile != -1:
		var cards := _game.cards(_drag_pile)
		var step := _up_step(_drag_pile) if _drag_pile >= Klondike.TABLEAU else 0.0
		for index in range(_drag_index, cards.size()):
			_draw_card(cards[index], true, _drag_at + Vector2(0, (index - _drag_index) * step))


func _draw_card(card: int, face_up: bool, at: Vector2) -> void:
	if not face_up:
		draw_texture_rect(back, Rect2(at, card_size), false)
		return
	var cell := Vector2(Klondike.rank(card) - 1, Klondike.suit(card)) * card_size
	draw_texture_rect_region(faces, Rect2(at, card_size), Rect2(cell, card_size))
