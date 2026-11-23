extends "res://tests/test.gd"
## The printed page outlines itself while a click takes it: pulsing in the Open sign's colour, light
## blue under the mouse; no outline while it prints, nor once it is taken.

const PAGE: PackedStringArray = ["FIX: Clogged CPU fan", "1. Open case"]


func run() -> void:
	var printer: Node3D = load("res://props/printer.tscn").instantiate()  # untyped: Printer names Game
	root.add_child(printer)
	await process_frame
	var outline: MeshInstance3D = printer.get("_outline")
	var look: ClickableOutline = printer.get("outline")
	check("no page: no outline", outline.visible, false)
	printer.call("print_page", PAGE)
	check("while it prints: no outline", outline.visible, false)
	await create_timer(PAGE.size() * float(printer.get("line_seconds")) + float(printer.get("feed_seconds")) + 0.3).timeout
	var pulse := outline.material_override as StandardMaterial3D
	check("printed: an outline in the clickable pulse colour", [outline.visible, pulse.albedo_color.r, pulse.albedo_color.g, pulse.albedo_color.b], [true, look.pulse_color.r, look.pulse_color.g, look.pulse_color.b])
	var alphas := {}
	for i: int in int(look.pulse_seconds * FPS):
		alphas[snappedf(pulse.albedo_color.a, 0.1)] = true
		await process_frame
	check("it pulses from full down to the low and back", [alphas.has(1.0), alphas.has(snappedf(look.pulse_low, 0.1))], [true, true])
	var hotspot: Area3D = printer.get_node("%Hotspot")
	hotspot.mouse_entered.emit()
	var hover := outline.material_override as StandardMaterial3D
	check("under the mouse, the hover colour", [hover.albedo_color.r, hover.albedo_color.g, hover.albedo_color.b], [look.hover_color.r, look.hover_color.g, look.hover_color.b])
	hotspot.mouse_exited.emit()
	check("taken", printer.call("take_page"), true)
	check("taken: no outline", outline.visible, false)
	printer.queue_free()
	await process_frame
