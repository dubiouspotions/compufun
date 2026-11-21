extends CorruptionSign
## Now and then the office trash can blinks into the Win95 Recycle Bin for a moment. Only the can's
## body hides: its outline and its clicks keep working.

## The meshes of the trash can (group trash_can) that the Recycle Bin stands in for.
const CAN_BODY: Array[NodePath] = [^"Outer", ^"Inner"]

## The seconds between two blinks: a random time from x to y.
@export var wait_seconds: Vector2 = Vector2(6.0, 15.0)
## The seconds that the Recycle Bin stays.
@export var blink_seconds: float = 0.4

var _can: Node3D
var _body: Array[Node3D] = []
var _on: bool = false
var _left: float = 0.0
var _random := RandomNumberGenerator.new()

@onready var _bin: Node3D = %RecycleBin


func _ready() -> void:
	_can = get_tree().get_first_node_in_group(&"trash_can") as Node3D
	if _can == null:
		push_error("win_trash: no Node3D in the group trash_can")
	else:
		for path: NodePath in CAN_BODY:
			var part := _can.get_node_or_null(path) as Node3D
			if part == null:
				push_error("win_trash: the trash can %s has no %s" % [_can.get_path(), path])
			else:
				_body.append(part)
	super()


func _apply(shown_stage: int) -> void:
	var on := shown_stage >= 1 and _can != null
	if on and not _on:
		_left = _random.randf_range(wait_seconds.x, wait_seconds.y)
	_on = on
	set_process(on)
	if not on:
		_show_bin(false)


func _process(delta: float) -> void:
	_left -= delta
	if _left > 0.0:
		return
	var blink := not _bin.visible
	_show_bin(blink)
	_left = blink_seconds if blink else _random.randf_range(wait_seconds.x, wait_seconds.y)


func _show_bin(on: bool) -> void:
	if _can != null:
		_bin.global_transform = _can.global_transform
	_bin.visible = on
	for part: Node3D in _body:
		part.visible = not on
