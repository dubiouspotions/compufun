extends CorruptionSign
## Text in the shop turns into the Windows font: the post-its and the week calendar (the group
## shop_text), the post-it that the Workview writes in UI text, and the storage room's sign.

## The Windows font.
@export var font: Font = preload("res://win95/theme/fonts/w95fa_pixel_bold.ttf")

var _ui_theme: Theme
# What each node outside shop_text showed before this sign: its font, or its theme for a Control.
var _before: Dictionary[Node, Variant] = {}


func _ready() -> void:
	_ui_theme = Theme.new()
	_ui_theme.default_font = font
	get_tree().node_added.connect(_on_node_added)
	super()


func _apply(shown_stage: int) -> void:
	var on := shown_stage > 0
	for node: Node in get_tree().get_nodes_in_group(&"shop_text"):
		_set_font(node, font if on else null)
	for storage: Node in get_tree().get_nodes_in_group(&"storage_room"):
		for label: Node in storage.find_children("*", "Label3D", true, false):
			_swap(label, &"font", font, on)
	for layer: Node in get_tree().get_nodes_in_group(&"ui_layer"):
		for child: Node in layer.get_children():
			if child is PostItLabel:
				_swap(child, &"theme", _ui_theme, on)


# A post-it comes with each new job: it takes the font as it enters the tree.
func _on_node_added(node: Node) -> void:
	if node.is_in_group(&"shop_text") and stage() > 0:
		_set_font(node, font)


func _set_font(node: Node, shown: Font) -> void:
	if not &"font" in node:
		push_error("win_font: %s is in the group shop_text but has no font" % node.get_path())
		return
	node.set(&"font", shown)


# Sets [param property] to [param value] while [param on], and back to what it was when off.
func _swap(node: Node, property: StringName, value: Variant, on: bool) -> void:
	if on:
		if not _before.has(node):
			_before[node] = node.get(property)
		node.set(property, value)
	elif _before.has(node):
		node.set(property, _before[node])
		_before.erase(node)
