class_name Printer
extends MeshInstance3D
## The dot-matrix printer under the work desk. It keeps one page: the last one printed sticks out
## of its top until the next print replaces it, or the player clicks it and carries it away
## (Game.printout).

## The group of the shop's printer; CompuFunDB prints to its first member.
const GROUP: StringName = &"printer"

## The seconds that the head takes to print one line.
@export var line_seconds: float = 0.12
## The paper that one line feeds, in metres along the page.
@export var line_pitch: float = 0.009
## How far the top of a finished page sticks out of the slot, in metres, at least.
@export var shown_length: float = 0.17
## The seconds of the form feed after the last line.
@export var feed_seconds: float = 0.4
## The sound of the line feed and the head printing one line, [member line_seconds] long.
@export var line_sound: SoundSet = preload("res://sounds/printer_line.tres")
## The sound of the form feed after the last line, [member feed_seconds] long.
@export var feed_sound: SoundSet = preload("res://sounds/printer_feed.tres")
## The sound of the page taken out of the printer.
@export var take_sound: SoundSet = preload("res://sounds/paper_handle.tres")
## The finished page's outline while a click takes it: pulsing, or the hover colour under the mouse;
## and how far it stands out around the page, in metres.
@export var outline: ClickableOutline = preload("res://rooms/clickable_outline.tres")
@export var outline_width: float = 0.012

var _tween: Tween
var _lines: PackedStringArray = []
var _hovered: bool = false
var _pulse_material: StandardMaterial3D
var _hover_material: StandardMaterial3D
var _pulse: Tween
# A card behind the page, a little larger: an outline grown from so thin a sheet hardly shows.
var _outline: MeshInstance3D

@onready var _sheet: MeshInstance3D = %Sheet
@onready var _text: Label3D = %Text
@onready var _speaker: AudioStreamPlayer3D = %Speaker
@onready var _hotspot: Hotspot = %Hotspot


func _ready() -> void:
	_pulse_material = Hotspot.ghost_material(outline.pulse_color)
	_hover_material = Hotspot.ghost_material(outline.hover_color)
	_hover_material.albedo_color.a = 1.0
	_outline = MeshInstance3D.new()
	_outline.mesh = BoxMesh.new()
	_outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sheet.get_parent().add_child.call_deferred(_outline)
	_hotspot.clicked.connect(func(_clicked: Hotspot) -> void: take_page())
	_hotspot.mouse_entered.connect(_set_hovered.bind(true))
	_hotspot.mouse_exited.connect(_set_hovered.bind(false))
	_set_takeable(false)


## Prints [param lines] on a new page: the old page goes, and the new one feeds out line by line
## with the print sound. A print during a print starts over with the new lines.
func print_page(lines: PackedStringArray) -> void:
	if _tween != null:
		_tween.kill()
	_lines = lines.duplicate()
	_set_takeable(false)
	_text.text = "\n".join(lines)
	_set_feed(0.0)
	_tween = create_tween()
	for i: int in lines.size():
		_tween.tween_callback(line_sound.play_on.bind(_speaker))
		_tween.tween_method(_set_feed, i * line_pitch, (i + 1) * line_pitch, line_seconds)
	var done := lines.size() * line_pitch
	var page := _sheet.get_aabb().size.y
	_tween.tween_callback(feed_sound.play_on.bind(_speaker))
	_tween.tween_method(_set_feed, done, clampf(done + line_pitch, shown_length, page), feed_seconds)
	_tween.tween_callback(_set_takeable.bind(not _lines.is_empty()))


## How far the page that prints is, 0 to 1, its form feed included; -1 while the printer is idle.
func progress() -> float:
	if _tween == null or not _tween.is_running():
		return -1.0
	return clampf(_tween.get_total_elapsed_time() / (_lines.size() * line_seconds + feed_seconds), 0.0, 1.0)


## Gives the finished page to the player to carry (Game.carry_printout); it leaves the printer. False,
## and the page stays, while a page prints, when no page is there, or while the player carries one.
func take_page() -> bool:
	if _lines.is_empty() or (_tween != null and _tween.is_running()) or not Game.carry_printout(_lines):
		return false
	_lines = []
	_text.text = ""
	_set_feed(0.0)
	_set_takeable(false)
	take_sound.play_at(self)
	return true


# The finished page takes clicks, and its outline pulses, while [param on].
func _set_takeable(on: bool) -> void:
	_hotspot.set_enabled(on)
	if not on:
		_hovered = false
	if _pulse != null:
		_pulse.kill()
		_pulse = null
	if on:
		_pulse = outline.pulse(_pulse_material, self)
	_show_outline()


func _set_hovered(on: bool) -> void:
	_hovered = on
	_show_outline()


func _show_outline() -> void:
	_outline.visible = _pulse != null
	_outline.material_override = _hover_material if _hovered else _pulse_material
	var page := _sheet.get_aabb()
	var shown := _sheet.position.y + outline_width
	(_outline.mesh as BoxMesh).size = Vector3(page.size.x + outline_width * 2.0, shown + outline_width, page.size.z)
	_outline.position = Vector3(_sheet.position.x, (shown - outline_width) / 2.0, _sheet.position.z - page.size.z * 2.0)


# Sticks the top of the page [param length] metres out of the slot; the rest is inside the printer.
func _set_feed(length: float) -> void:
	_sheet.position.y = minf(length, _sheet.get_aabb().size.y)
