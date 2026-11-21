extends CorruptionSign
## The computer mouse on the bench (group desk_mouse) turns into the icon of the Win95 Mouse applet,
## standing upright in its place like a cut-out. The icon keeps its own turn and size from this
## scene; it stands on the spot where the mouse lies.

## The applet whose icon replaces the mouse.
@export var applet: Applet

@onready var _icon: Sprite3D = %Icon


func _ready() -> void:
	if applet == null or applet.icon == null:
		push_error("mouse_icon: %s has no applet with an icon" % scene_file_path)
	else:
		_icon.texture = applet.icon
	super()


func _apply(shown_stage: int) -> void:
	var mice := get_tree().get_nodes_in_group(&"desk_mouse")
	if mice.is_empty():
		push_error("mouse_icon: no computer mouse in the group desk_mouse")
	for mouse: Node3D in mice:
		mouse.visible = shown_stage == 0
	var spot := mice.front() as Node3D if not mice.is_empty() else null
	_icon.visible = shown_stage > 0 and spot != null
	if _icon.visible:
		# Its feet on the spot: the sprite's origin is its middle.
		_icon.global_position = spot.global_position - _icon.global_basis.y * _icon.get_aabb().position.y
