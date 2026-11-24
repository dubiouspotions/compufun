extends "res://tests/test.gd"
## The trash can's outline pulses like the Open sign's exactly while a click on it would throw
## something away: a new part, a broken one, the boot floppy, the carried printout (raised or not).
## It stops when the hand is empty and no page is carried, also in the Trash view over a full can, and
## shows the light blue hover outline under the mouse.

const PAGE: PackedStringArray = ["FIX: Clogged CPU fan", "1. Open case"]

var _can: Node3D  # not TrashCan: it names the Game autoload
var _outline: MeshInstance3D
var _pulse: StandardMaterial3D


func run() -> void:
	_can = load("res://props/trash_can.tscn").instantiate()
	root.add_child(_can)
	await process_frame
	_outline = _can.get_node("%Outline")
	_pulse = _can.get("_pulse_material")
	var look: ClickableOutline = _can.get("outline")
	check("the can's outline looks like the Open sign's", look, load("res://rooms/clickable_outline.tres"))
	check("empty hand, no page: dark", _pulsing(), false)

	game.take_new_part(Part.named(&"fan"))
	check("a new part in the hand: it pulses", _pulsing(), true)
	check("in the pulse colour", [_pulse.albedo_color.r, _pulse.albedo_color.g, _pulse.albedo_color.b], [look.pulse_color.r, look.pulse_color.g, look.pulse_color.b])
	var alphas := {}
	for i: int in int(look.pulse_seconds * FPS):
		alphas[snappedf(_pulse.albedo_color.a, 0.1)] = true
		await process_frame
	check("from full down to the sign's low and back", [alphas.has(1.0), alphas.has(snappedf(look.pulse_low, 0.1))], [true, true])
	var hotspot: Area3D = _can.get_node("%Hotspot")
	hotspot.mouse_entered.emit()
	var hover := _outline.material_override as StandardMaterial3D
	check("under the mouse, the light blue outline", [_outline.visible, hover.albedo_color.r, hover.albedo_color.g, hover.albedo_color.b], [true, look.hover_color.r, look.hover_color.g, look.hover_color.b])
	hotspot.mouse_exited.emit()
	_click()
	check("thrown away: it stops", [game.hand, _pulsing()], [null, false])

	check("restore a broken fan in the hand", game.restore({"hand": ["fan!"]}), "")
	check("a broken part: it pulses", [game.hand.broken, _pulsing()], [true, true])
	_click()
	check("thrown away: it stops", [game.hand, _pulsing()], [null, false])

	check("restore the boot floppy in A:", game.restore({"jobs": [
		{"customer": "res://customers/young_entrepreneur.tres", "problem": "bootfloppy", "slot": 0}],
		"focus_slot": 0, "connected_slot": -1, "view": "Right"}), "")
	game.eject_floppy(game.jobs[0])
	check("the boot floppy in the hand: it pulses", [game.hand.part.id(), _pulsing()], [&"floppy", true])
	_click()
	check("thrown away: it stops", [game.hand, _pulsing()], [null, false])

	game.carry_printout(PAGE)
	check("a carried page and an empty hand: it pulses", _pulsing(), true)
	game.take_new_part(Part.named(&"fan"))
	_click()
	check("the part goes first, and the page still pulses it", [game.hand, game.printout, _pulsing()], [null, PAGE, true])
	_click()
	check("the page thrown away: it stops", [game.printout, _pulsing()], [PackedStringArray(), false])

	game.go_to_view(_can.get("look_view"))
	check("in the Trash view over a full can: clickable, dark", [hotspot.input_ray_pickable, _pulsing()], [true, false])
	_click()
	check("a click takes the top piece back, and it pulses again", [game.hand != null, _pulsing()], [true, true])
	_can.queue_free()
	await process_frame


# True while the outline shows the pulse material and its tween runs.
func _pulsing() -> bool:
	var tween: Tween = _can.get("_pulse")
	var on := _outline.visible and _outline.material_override == _pulse and tween != null and tween.is_running()
	check("the pulse matches the can's own rule", on, _can.call("can_throw"))
	return on


func _click() -> void:
	var hotspot: Node = _can.get_node("%Hotspot")
	hotspot.emit_signal(&"clicked", hotspot)
