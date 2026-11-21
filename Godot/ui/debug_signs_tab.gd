extends VBoxContainer
## The Signs tab of the debug menu: every corruption sign, with its feature switch and its stage. The
## stage buttons set the sign's flag, as the trigger layer will.

var _rows: VBoxContainer


func _ready() -> void:
	var note := Label.new()
	note.text = "On: the feature switch (not saved). 0, 1, 2...: the stage that the trigger sets."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(note)
	_rows = VBoxContainer.new()
	add_child(_rows)
	Game.changed.connect(_refresh)
	visibility_changed.connect(_refresh)


func _refresh() -> void:
	if not is_visible_in_tree():
		return
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	var signs := get_tree().get_nodes_in_group(CorruptionSign.GROUP)
	if signs.is_empty():
		var none := Label.new()
		none.text = "No corruption signs in this scene."
		_rows.add_child(none)
	for node: Node in signs:
		var each := node as CorruptionSign
		var row := HBoxContainer.new()
		var on := CheckBox.new()
		on.text = "On"
		on.button_pressed = each.enabled
		on.toggled.connect(func(value: bool) -> void:
			each.enabled = value
			_refresh())
		row.add_child(on)
		var name_label := Label.new()
		name_label.text = "%s (%s)" % [each.title, each.id()]
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		for value: int in each.stages + 1:
			var button := Button.new()
			button.text = str(value)
			button.toggle_mode = true
			button.button_pressed = Game.flag(each.flag()) == value
			button.pressed.connect(each.set_stage.bind(value))
			row.add_child(button)
		_rows.add_child(row)
