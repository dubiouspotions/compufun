class_name AppBar
## Builds the menus and the toolbar of an app window from lists, as Exchange's windows have many
## of both. An item or a button without an action does nothing yet, and Stub marks it.


## Adds the menu [param title] to [param bar]. Each of [param items] is [label, action] (a
## Callable, or null for one that isn't built), or [] for a separator.
static func add_menu(bar: MenuBar, title: String, items: Array) -> PopupMenu:
	var menu := PopupMenu.new()
	menu.name = title
	var actions: Array[Callable] = []
	for item: Array in items:
		if item.is_empty():
			menu.add_separator()
			continue
		menu.add_item(item[0], actions.size())
		var action: Variant = item[1] if item.size() > 1 else null
		actions.append(action if action is Callable else Callable())
		if not action is Callable:
			menu.set_item_icon(menu.item_count - 1, Stub.dot())
	menu.id_pressed.connect(func(id: int) -> void:
		if actions[id].is_valid():
			actions[id].call())
	bar.add_child(menu)
	return menu


## Adds a toolbar button with [param icon] to [param row]; a null [param action] marks it a stub.
static func add_button(row: HBoxContainer, icon: Texture2D, tooltip: String, action: Variant = null) -> Button:
	var button := Button.new()
	button.icon = icon if action is Callable else Stub.mark(icon)
	button.tooltip_text = tooltip
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(24, 22)
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if action is Callable:
		button.pressed.connect(action)
	row.add_child(button)
	return button


## Adds the gap between groups of toolbar buttons.
static func add_gap(row: HBoxContainer) -> void:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(6, 0)
	row.add_child(gap)
