@tool
class_name FlagField
extends HBoxContainer
## A text field of flags, written "name, name=2", with a menu that adds any flag that the project
## already uses, so a name is picked rather than typed. Also the one scan of who sets and who checks
## each flag, for the menu and the Week tab's flag table.

## The text changed, by typing or by a pick from the menu.
signal edited(text: String)

const GAME := preload("res://game.gd")
const SIGNS_DIR := "res://corruption/"

var edit: LineEdit
var _menu: MenuButton
## Returns the flags to offer: name to a short description.
var _known: Callable
var _offered: Array[StringName] = []


## [param known] returns the flags to offer, name to a short description.
func _init(text: String, placeholder: String, known: Callable) -> void:
	_known = known
	size_flags_horizontal = SIZE_EXPAND_FILL
	edit = LineEdit.new()
	edit.text = text
	edit.placeholder_text = placeholder
	edit.size_flags_horizontal = SIZE_EXPAND_FILL
	edit.text_changed.connect(func(changed: String) -> void: edited.emit(changed))
	add_child(edit)
	_menu = MenuButton.new()
	_menu.text = "+"
	_menu.tooltip_text = "Add a flag that the project already uses"
	_menu.flat = false
	_menu.about_to_popup.connect(_fill_menu)
	_menu.get_popup().index_pressed.connect(_pick)
	add_child(_menu)


func _fill_menu() -> void:
	var popup := _menu.get_popup()
	popup.clear()
	var known: Dictionary = _known.call()
	_offered.clear()
	for flag: StringName in known:
		_offered.append(flag)
	_offered.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	for flag: StringName in _offered:
		popup.add_item("%s    %s" % [flag, known[flag]])
	if _offered.is_empty():
		popup.add_item("No flags yet: type a new name")
		popup.set_item_disabled(0, true)


func _pick(index: int) -> void:
	if index >= _offered.size():
		return
	var names := edit.text.strip_edges()
	edit.text = String(_offered[index]) if names == "" else names + ", " + String(_offered[index])
	edited.emit(edit.text)


## Every Day file at Game.DAY_PATH, in order. Adds a message to [param errors] for a file that
## doesn't load as a Day.
static func load_days(errors: Array[String]) -> Array[Day]:
	var days: Array[Day] = []
	for number: int in range(1, 8):
		var path := GAME.DAY_PATH % number
		if not ResourceLoader.exists(path):
			continue
		var d := load(path) as Day
		if d == null:
			errors.append("%s is not a Day, or doesn't load" % path)
			continue
		days.append(d)
	return days


## Who sets and who checks each flag: {"setters": {flag: PackedStringArray},
## "checkers": {flag: PackedStringArray}, "signs": {sign flag: title}}. A setter or checker reads
## like "skater_bro/arrive" or "day 3"; a value other than 1 follows as " =2".
static func index(customers: Array[Customer], days: Array[Day], errors: Array[String]) -> Dictionary:
	var setters: Dictionary[StringName, PackedStringArray] = {}
	var checkers: Dictionary[StringName, PackedStringArray] = {}
	for c: Customer in customers:
		var who := c.resource_path.get_file().get_basename()
		for conversation: Conversation in c.conversations:
			if conversation != null:
				_scan(conversation, "%s/%s" % [who, conversation.id], setters, checkers)
	for d: Day in days:
		_note_sets(setters, d.set_flags, "day %d" % d.number)
		_note_sets(setters, d.close_flags, "closing day %d" % d.number)
	var signs := _sign_titles(errors)
	for flag: StringName in signs:
		_note(checkers, flag, "sign: " + signs[flag])
	return {"setters": setters, "checkers": checkers, "signs": signs}


## The flags of [param flag_index] (from [method index]) for the menu: name to who uses it.
static func offers(flag_index: Dictionary) -> Dictionary:
	var signs: Dictionary = flag_index["signs"]
	var setters: Dictionary = flag_index["setters"]
	var checkers: Dictionary = flag_index["checkers"]
	var known := {}
	for flag: StringName in setters.keys() + checkers.keys():
		if signs.has(flag):
			known[flag] = "sign: " + str(signs[flag])
		else:
			var users: PackedStringArray = setters.get(flag, PackedStringArray()) + checkers.get(flag, PackedStringArray())
			known[flag] = ", ".join(users.slice(0, 3)) + (", ..." if users.size() > 3 else "")
	return known


# Notes the flags that [param reply] and the tree under it set and check. [param where] names it;
# a choice under it adds its text.
static func _scan(reply: Reply, where: String, setters: Dictionary[StringName, PackedStringArray], checkers: Dictionary[StringName, PackedStringArray]) -> void:
	_note_sets(setters, reply.set_flags, where)
	_note_when(checkers, reply.when, where)
	for choice: Choice in reply.choices:
		if choice == null:
			continue
		var asked := "%s > \"%s\"" % [where, choice.text.left(30)]
		_note_when(checkers, choice.when, asked)
		for each: Reply in choice.replies:
			if each != null:
				_scan(each, asked, setters, checkers)


static func _note_when(checkers: Dictionary[StringName, PackedStringArray], when: Condition, where: String) -> void:
	if when == null:
		return
	for flag: StringName in when.need_flags:
		_note(checkers, flag, where)
	for flag: StringName in when.not_flags:
		_note(checkers, flag, where + " (not)")


static func _note_sets(setters: Dictionary[StringName, PackedStringArray], sets: Dictionary[StringName, int], where: String) -> void:
	for flag: StringName in sets:
		_note(setters, flag, where if sets[flag] == 1 else "%s =%d" % [where, sets[flag]])


static func _note(notes: Dictionary[StringName, PackedStringArray], flag: StringName, where: String) -> void:
	if not notes.has(flag):
		notes[flag] = PackedStringArray()
	notes[flag].append(where)


## The flag of every corruption sign scene, sign_<id>, to its title, read without instancing it.
static func _sign_titles(errors: Array[String]) -> Dictionary[StringName, String]:
	var titles: Dictionary[StringName, String] = {}
	var dir := DirAccess.open(SIGNS_DIR)
	if dir == null:
		errors.append("Couldn't open %s: %s" % [SIGNS_DIR, error_string(DirAccess.get_open_error())])
		return titles
	for file: String in dir.get_files():
		if not file.ends_with(".tscn"):
			continue
		var scene := load(SIGNS_DIR + file) as PackedScene
		if scene == null:
			errors.append("%s doesn't load" % (SIGNS_DIR + file))
			continue
		var state := scene.get_state()
		var title := file.get_basename()
		for i: int in state.get_node_property_count(0):
			if state.get_node_property_name(0, i) == &"title":
				title = state.get_node_property_value(0, i)
		titles[StringName("sign_" + file.get_basename())] = title
	return titles
