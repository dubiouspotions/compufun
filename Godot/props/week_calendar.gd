class_name WeekCalendar
extends Node3D
## The week calendar on the wall: one column per day of the game, with its weekday and date, and a
## red cross on each day that has passed. The paper faces +Z; its origin is the centre.

## The game's days, one per Day file (days/day_1.tres to day_7.tres).
const DAYS: int = 7
const WEEKDAYS: PackedStringArray = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
const MONTHS: PackedStringArray = ["JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE", "JULY",
	"AUGUST", "SEPTEMBER", "OCTOBER", "NOVEMBER", "DECEMBER"]

## The colour of the printing, and of the crosses over the days that have passed.
@export var ink_color: Color = Color(0.12, 0.1, 0.16)
@export var cross_color: Color = Color(0.8, 0.1, 0.08)

var _crosses: Array[Label3D] = []

@onready var _paper: MeshInstance3D = $Paper
@onready var _header: Label3D = $Header


func _ready() -> void:
	var size := (_paper.mesh as QuadMesh).size
	var column := size.x / DAYS
	var first: Dictionary = Game.date_of(1)
	var last: Dictionary = Game.date_of(DAYS)
	_header.modulate = ink_color
	_header.text = "%s %d" % [MONTHS[first.month - 1], first.year] if first.month == last.month else (
			"%s / %s %d" % [MONTHS[first.month - 1], MONTHS[last.month - 1], last.year])
	var ink := _paper.material_override.duplicate() as ShaderMaterial
	ink.set_shader_parameter(&"albedo_color", ink_color)
	_line(ink, Vector2(size.x, 0.012), Vector2(0.0, size.y * 0.3))
	for number in range(1, DAYS + 1):
		var date: Dictionary = Game.date_of(number)
		var x := -size.x * 0.5 + column * (number - 0.5)
		if number > 1:
			_line(ink, Vector2(0.01, size.y * 0.8), Vector2(x - column * 0.5, -size.y * 0.1))
		_label(WEEKDAYS[date.weekday], 28, ink_color, Vector3(x, size.y * 0.18, 0.003))
		_label(str(date.day), 56, ink_color, Vector3(x, -size.y * 0.1, 0.003))
		_crosses.append(_label("X", 170, cross_color, Vector3(x, -size.y * 0.04, 0.004)))
	Game.changed.connect(_sync)
	_sync()


# A day has passed once the next one starts, or once the shop closes for its night.
func _sync() -> void:
	var today := Game.day_number
	for i in _crosses.size():
		var number := i + 1
		_crosses[i].visible = number < today or (number == today and Game.phase == Game.Phase.DAY_OVER)


func _label(text: String, font_size: int, color: Color, at: Vector3) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = font_size
	label.pixel_size = _header.pixel_size
	label.texture_filter = _header.texture_filter
	label.shaded = _header.shaded
	label.outline_size = 0
	label.modulate = color
	label.position = at
	add_child(label)
	return label


func _line(material: Material, size: Vector2, at: Vector2) -> void:
	var quad := QuadMesh.new()
	quad.size = size
	var line := MeshInstance3D.new()
	line.mesh = quad
	line.material_override = material
	line.position = Vector3(at.x, at.y, 0.0015)
	add_child(line)
