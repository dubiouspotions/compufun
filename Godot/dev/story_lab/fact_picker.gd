class_name StoryFactPicker
extends Button
## A button that picks one fact (a story flag) for the Story Lab's condition and "remembers" editors.
## It shows the fact in plain words; a click opens a search field and a list of the known facts in
## [member list_host], under the picker. Typing a name that isn't known offers it as a new fact;
## the writer's words become a flag name (lower case, digits and underscores) only when picked:
## "Skater told us" becomes skater_told_us.

## The writer picked [param fact].
signal picked(fact: StringName)

## The known facts that the list offers, as flag names.
var facts: PackedStringArray = []
## Where the search field and the list open; the editor puts it right under the picker's row.
var list_host: Control
## The picked fact; &"" while none is.
var fact: StringName = &"":
	set(value):
		fact = value
		text = humanize(value) if value != &"" else "Pick a fact..."
		tooltip_text = "The fact \"%s\". Click to pick another." % humanize(value) if value != &"" else "Pick a fact, or name a new one"

var _search: LineEdit
var _list: ItemList


func _init() -> void:
	fact = &""
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	clip_text = true
	pressed.connect(func() -> void:
		if is_open():
			close()
		else:
			open())


## [param flag] in plain words: its underscores as spaces.
static func humanize(flag: StringName) -> String:
	return String(flag).replace("_", " ")


## [param typed] written as a flag name: lower case, spaces and dashes as underscores, other
## characters dropped, no double underscores and none at either end.
static func slug(typed: String) -> String:
	var out := ""
	for c: String in typed.to_lower().strip_edges().replace(" ", "_").replace("-", "_"):
		if (c >= "a" and c <= "z") or (c >= "0" and c <= "9") or c == "_":
			if not (c == "_" and out.ends_with("_")):
				out += c
	return out.trim_prefix("_").trim_suffix("_")


## Whether the search field and the list show.
func is_open() -> bool:
	return list_host != null and list_host.visible and _search != null


## Opens the search field and the list in [member list_host], the field focused.
func open() -> void:
	if list_host == null:
		push_error("StoryFactPicker: no list_host to open the list in")
		return
	if _search == null:
		_build()
	_search.text = ""
	_fill("")
	list_host.show()
	_search.grab_focus.call_deferred()


## Hides the search field and the list.
func close() -> void:
	if list_host != null:
		list_host.hide()


## Picks [param name], a flag name or the writer's words for one, as if picked in the list.
func pick(name: String) -> void:
	var clean := StringName(slug(name))
	if clean == &"":
		return
	fact = clean
	close()
	picked.emit(clean)


func _build() -> void:
	_search = LineEdit.new()
	_search.placeholder_text = "Search, or name a new fact"
	_search.tooltip_text = "Type to find a fact. Words that aren't in the list become a new fact."
	_search.text_changed.connect(_fill)
	_search.text_submitted.connect(func(_typed: String) -> void:
		for i: int in _list.item_count:
			if _list.is_item_selectable(i):
				pick(_list.get_item_metadata(i))
				return)
	_search.gui_input.connect(func(event: InputEvent) -> void:
		var key := event as InputEventKey
		if key != null and key.pressed and key.keycode == KEY_ESCAPE:
			_search.accept_event()
			close())
	list_host.add_child(_search)
	_list = ItemList.new()
	_list.custom_minimum_size.y = 180
	_list.item_activated.connect(func(index: int) -> void: pick(_list.get_item_metadata(index)))
	_list.item_clicked.connect(func(index: int, _at: Vector2, _button: int) -> void:
		if _list.is_item_selectable(index):
			pick(_list.get_item_metadata(index)))
	list_host.add_child(_list)


func _fill(typed: String) -> void:
	_list.clear()
	var wanted := slug(typed)
	if wanted == "":
		_list.add_item("New fact: type its name above")
		_list.set_item_selectable(0, false)
		_list.set_item_metadata(0, "")
	elif not facts.has(wanted):
		_list.add_item("New fact: " + typed.strip_edges())
		_list.set_item_metadata(0, typed)
	for known: String in facts:
		if wanted == "" or known.contains(wanted):
			_list.add_item(humanize(known))
			_list.set_item_metadata(_list.item_count - 1, known)
