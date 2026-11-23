class_name ClickableOutline
extends Resource
## How the outline of a thing that takes a click now looks: the Open sign, the phone, a printed page.
## It pulses in [member pulse_color] while the thing can be clicked, and shows [member hover_color]
## under the mouse. One file (clickable_outline.tres) for all of them, so they look alike.

## The pulse's colour.
@export var pulse_color: Color = Color(1.0, 0.82, 0.2)
## The pulse's opacity at the bottom of each pulse, 0 to 1; the top is 1.
@export_range(0.0, 1.0, 0.01) var pulse_low: float = 0.2
## How long one pulse takes, in seconds.
@export var pulse_seconds: float = 1.2
## The outline under the mouse, over the pulse.
@export var hover_color: Color = Color(0.75, 0.9, 1.0)


## A see-through outline in [member pulse_color] for a mesh's material_overlay, [param width]
## metres wide, for [method pulse].
func pulse_material(width: float) -> StandardMaterial3D:
	var material := Hotspot.outline_material(pulse_color, width)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


## An outline in [member hover_color] for a mesh's material_overlay, [param width] metres wide.
func hover_material(width: float) -> StandardMaterial3D:
	return Hotspot.outline_material(hover_color, width)


## Pulses the opacity of [param material] (a transparent one) from 1 down to [member pulse_low] and
## back, once every [member pulse_seconds], until the returned tween, bound to [param owner], is
## killed.
func pulse(material: BaseMaterial3D, owner: Node) -> Tween:
	var tween := owner.create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	tween.tween_property(material, "albedo_color:a", pulse_low, pulse_seconds / 2.0).from(1.0)
	tween.tween_property(material, "albedo_color:a", 1.0, pulse_seconds / 2.0)
	return tween
