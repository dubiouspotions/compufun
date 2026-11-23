class_name StoryFactPicker
extends Button
## A button that picks one fact (a story flag) for the Story Lab's condition and "remembers" editors.
## It shows the fact in plain words; a click opens a list of the known facts with a search field.
## Typing a name that isn't known offers it as a new fact, written the way flags are written: lower
## case, digits and underscores ("Skater told us" becomes skater_told_us as it is typed).

## The writer picked [param fact].
signal picked(fact: StringName)

## The known facts that the list offers, as flag names.
var facts: PackedStringArray = []
## The picked fact; &"" while none is.
var fact: StringName = &"":
	set(value):
		fact = value
		text = humanize(value) if value != &"" else "Pick a fact..."
		tooltip_text = "The fact %s. Click to pick another." % humanize(value) if value != &"" else "Pick a fact, or name a new one"

var _popup: PopupPanel
var _search: LineEdit
var _list: ItemList


func _init() -> void:
	fact = &""
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	clip_text = true
	pressed.connect(open)


## [param flag] in plain words: its underscores as spaces.
static func humanize(flag: StringName) -> String:
	return String(flag).replace("_", " ")


## [param typed] written as a flag name: lower case, spaces and dashes as underscores, other
## characters dropped, no double underscores.
static func slug(typed: String) -> String:
	var out := ""
	for c: String in typed.to_lower().replace(" ", "_").replace("-", "_"):
		if (c >= "a" and c <= "z") or (c >= "0" and c <= "9") or c == "_":
			if not (c == "_" and out.ends_with("_")):
				out += c
	return out


## Opens the list under the button, with the search field focused.
func open() -> void:
	if _popup == null:
		_build_popup()
	_search.text = ""
	_fill("")
	_popup.reset_size()
	var at := get_global_transform_with_canvas() * Vector2(0, size.y)
	if get_window().is_embedded():  # a picker inside another popup: place the list in the same embedder
		at += Vector2(get_window().position)
	_popup.popup(Rect2i(Vector2i(at), Vector2i(maxi(int(size.x), 280), 0)))
	_search.grab_focus.call_deferred()


## Picks [param name] as if the writer had picked it in the list.
func pick(name: StringName) -> void:
	var clean := StringName(slug(name).trim_prefix("_").trim_suffix("_"))
	if clean == &"":
		return
	fact = clean
	if _popup != null:
		_popup.hide()
	picked.emit(clean)


func _build_popup() -> void:
	_popup = PopupPanel.new()
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(280, 260)
	_popup.add_child(box)
	_search = LineEdit.new()
	_search.placeholder_text = "Search, or name a new fact"
	_search.tooltip_text = "Type to find a fact. A name that isn't in the list becomes a new fact."
	_search.text_changed.connect(_on_typed)
	_search.text_submitted.connect(func(_typed: String) -> void:
		for i: int in _list.item_count:
			if _list.is_item_selectable(i):
				pick(_list.get_item_metadata(i))
				return)
	box.add_child(_search)
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_activated.connect(func(index: int) -> void: pick(_list.get_item_metadata(index)))
	_list.item_clicked.connect(func(index: int, _at: Vector2, _button: int) -> void:
		if _list.is_item_selectable(index):
			pick(_list.get_item_metadata(index)))
	box.add_child(_list)
	add_child(_popup)


func _on_typed(typed: String) -> void:
	var clean := slug(typed)
	if clean != typed:
		_search.text = clean
		_search.caret_column = clean.length()
	_fill(clean)


func _fill(filter: String) -> void:
	_list.clear()
	var wanted := filter.trim_prefix("_").trim_suffix("_")
	if wanted == "":
		_list.add_item("New fact: type its name above")
		_list.set_item_selectable(0, false)
		_list.set_item_metadata(0, "")
	elif not facts.has(wanted):
		_list.add_item("New fact: " + humanize(wanted))
		_list.set_item_metadata(0, wanted)
	for known: String in facts:
		if wanted == "" or known.contains(wanted):
			_list.add_item(humanize(known))
			_list.set_item_metadata(_list.item_count - 1, known)
