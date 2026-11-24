extends CorruptionSign
## The close button of a Win95 window, the [x], floats over the right side of [member target]'s head
## in the shop wherever the camera sees it: as they walk in, talk, wait and walk out. A click sends
## them away for good ([method Game.dismiss_visitor]).

## The one customer whom the [x] shows over; null shows it over nobody.
@export var target: Customer

## Where the middle of the [x] floats, from the middle of the customer's head, in metres along the
## camera's right and up.
@export var offset: Vector2 = Vector2(0.18, 0.12)

@onready var _close: Button = %Close

var _shop: Shop
var _world: SubViewportContainer


func _ready() -> void:
	_close.visible = false
	_close.pressed.connect(Game.dismiss_visitor)
	_shop = _find_shop()
	# Right before drawing, after the camera tween moved: the [x] never lags behind the head.
	RenderingServer.frame_pre_draw.connect(_follow)
	super()


func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_follow):
		RenderingServer.frame_pre_draw.disconnect(_follow)
	# The [x] lives in the UI layer, outside this node.
	if _close.get_parent() != self:
		_close.queue_free()


func _apply(shown_stage: int) -> void:
	var shown := shown_stage > 0 and target != null and Game.visitor == target
	if shown and _shop == null:
		push_error("customer_x: %s is not inside a Shop" % get_path())
		shown = false
	if shown and _close.get_parent() == self:
		var ui := get_tree().get_first_node_in_group(&"ui_layer") as CanvasLayer
		_world = get_tree().get_first_node_in_group(&"world_post") as SubViewportContainer
		if ui == null or _world == null:
			push_error("customer_x: no CanvasLayer in the group ui_layer or no SubViewportContainer in world_post")
			return
		_close.reparent(ui, false)
		ui.move_child(_close, 0)  # under every UI screen: it floats in the world
	shown = shown and _close.get_parent() != self
	set_process(shown)
	_close.visible = shown
	if shown:
		_follow()


# frame_pre_draw fires only when a frame is drawn; a headless run draws none.
func _process(_delta: float) -> void:
	_follow()


func _follow() -> void:
	if not is_processing() or not _shop.is_node_ready():
		return
	var head := _shop.visitor_head_point(offset)
	var on_screen := head.is_finite() and Rect2(Vector2.ZERO, _shop.get_viewport().get_visible_rect().size).has_point(head)
	_close.visible = on_screen
	if on_screen:
		var at := _world.get_global_transform() * (head * float(_world.stretch_shrink))
		_close.position = at - _close.size * _close.scale * 0.5


func _find_shop() -> Shop:
	var node := get_parent()
	while node != null and not node is Shop:
		node = node.get_parent()
	return node as Shop
