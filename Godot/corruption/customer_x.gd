extends CorruptionSign
## The close button of a Win95 window, the [x], hovers at the top right corner of a regular customer
## ([member Customer.regular]) in the dialogue while they talk. A click sends them away for good
## ([method Game.dismiss_visitor]).

## Where the middle of the [x] hovers, from the customer's top right corner, in pixels of the UI.
@export var offset: Vector2 = Vector2(8.0, -8.0)

@onready var _close: Button = %Close


func _ready() -> void:
	_close.visible = false
	_close.pressed.connect(Game.dismiss_visitor)
	super()


func _exit_tree() -> void:
	# The [x] lives in the dialogue overlay, outside this node.
	if _close.get_parent() != self:
		_close.queue_free()


func _apply(shown_stage: int) -> void:
	var talking := Game.visitor != null and Game.visitor.regular and Game.visitor_state == Game.VisitorState.TALKING
	if shown_stage > 0 and talking and _close.get_parent() == self:
		var overlay := get_tree().get_first_node_in_group(&"dialogue_overlay") as DialogueOverlay
		if overlay == null:
			push_error("customer_x: no DialogueOverlay in the group dialogue_overlay")
			return
		_close.reparent(overlay, false)
	var shown := shown_stage > 0 and talking and _close.get_parent() != self
	set_process(shown)
	_close.visible = shown
	if shown:
		_follow()


func _process(_delta: float) -> void:
	_follow()


func _follow() -> void:
	var corner := (_close.get_parent() as DialogueOverlay).portrait_corner()
	_close.visible = corner.is_finite()
	if _close.visible:
		_close.position = corner + offset - _close.size * _close.scale * 0.5
