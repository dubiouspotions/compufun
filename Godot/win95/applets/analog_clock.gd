extends Control
## The clock face of Date/Time: twelve square hour marks and a sunken dot for every other minute,
## around the centre of the control, with hour, minute and second hands.

const _PALETTE := preload("res://win95/theme/palette.tres")

## From the centre to the middle of each mark, in pixels.
@export var radius: float = 61.0
## Hand lengths from the centre, in pixels.
@export var hour_length: float = 40.0
@export var minute_length: float = 52.0
@export var second_length: float = 50.0
## Half the width of the hour and minute hands at their widest, in pixels.
@export var hand_half_width: float = 4.0
## The face of the hands and of the hour marks, and the lit edge of the marks.
@export var hand_color := Color8(0, 128, 128)
@export var mark_light := Color8(0, 255, 255)

var _hour: int = 0
var _minute: int = 0
var _second: int = 0


func _ready() -> void:
	_PALETTE.changed.connect(queue_redraw)


## Points the hands at [param hour] (0 to 23), [param minute] and [param second].
func show_time(hour: int, minute: int, second: int) -> void:
	if [hour, minute, second] == [_hour, _minute, _second]:
		return
	_hour = hour
	_minute = minute
	_second = second
	queue_redraw()


func _draw() -> void:
	var center := (size / 2.0).floor()
	for minute in 60:
		var at := (center + _direction(minute / 60.0) * radius).round()
		if minute % 5 == 0:
			draw_rect(Rect2(at - Vector2(2, 2), Vector2(5, 5)), Color.BLACK)
			draw_rect(Rect2(at - Vector2(2, 2), Vector2(4, 4)), mark_light)
			draw_rect(Rect2(at - Vector2(1, 1), Vector2(3, 3)), hand_color)
		else:
			draw_rect(Rect2(at - Vector2(1, 1), Vector2(2, 1)), _PALETTE.shadow_color)
			draw_rect(Rect2(at - Vector2(1, 0), Vector2(1, 1)), _PALETTE.shadow_color)
			draw_rect(Rect2(at + Vector2(1, 0), Vector2(1, 1)), _PALETTE.highlight_color)
			draw_rect(Rect2(at + Vector2(0, 1), Vector2(2, 1)), _PALETTE.highlight_color)
	_draw_hand(center, (_hour % 12 + _minute / 60.0) / 12.0, hour_length)
	_draw_hand(center, (_minute + _second / 60.0) / 60.0, minute_length)
	draw_line(center, center + _direction(_second / 60.0) * second_length, _PALETTE.shadow_color, 1.0)


# A long kite from a short tail behind the centre to its tip, lit from the top left.
func _draw_hand(center: Vector2, turn: float, length: float) -> void:
	var along := _direction(turn)
	var across := Vector2(-along.y, along.x)
	var widest := center + along * length * 0.2
	var points := PackedVector2Array([center + along * length, widest + across * hand_half_width,
		center - along * length * 0.2, widest - across * hand_half_width])
	var shadow := PackedVector2Array()
	for point in points:
		shadow.append(point + Vector2(2, 2))
	draw_colored_polygon(shadow, _PALETTE.shadow_color)
	draw_colored_polygon(points, hand_color)
	for i in points.size():
		var from := points[i]
		var to := points[(i + 1) % points.size()]
		var outward := Vector2(to.y - from.y, from.x - to.x)
		if outward.x + outward.y < 0.0:
			draw_line(from, to, _PALETTE.highlight_color, 1.0)


# Clockwise from twelve o'clock: 0.25 points at three.
func _direction(turn: float) -> Vector2:
	return Vector2(sin(turn * TAU), -cos(turn * TAU))
