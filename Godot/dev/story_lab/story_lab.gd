class_name StoryLab
extends Control
## The Story Lab (Dev menu, F4 or Cmd+4): writers edit the story files (docs/dialogue.md) in the
## running game. On top, the week board; below, the picked errand or day. Every edit that parses is
## a draft (StoryDrafts) that the game plays at once. While the Lab shows, the game is paused.

const CUSTOMERS_DIR: String = "res://customers/"
## The story check, when the game has one: static missing_links(week) and flag_index(week).
const STORY_CHECK: String = "res://story/story_check.gd"

## The GitHub repo that Send makes the issue in, as owner/name; "" reads git's remote origin.
@export var github_repo: String = ""
## The number of the GitHub project (the board) that the issue joins; 0 joins none.
@export var github_project: int = 4

## True: edits go straight into res://story/ in the checkout, and no drafts play (the Dev menu's
## Save to checkout).
var to_checkout: bool:
	get:
		return drafts.to_checkout
	set(on):
		drafts.to_checkout = on
		if is_node_ready():
			_after_store()
			_checkout_chip.visible = on
			_say("Save to checkout is on: edits change res://story/ in this checkout." if on else "Save to checkout is off: edits are drafts again.")

## The drafts that the Lab edits. Replace it before the Lab enters the tree to keep them elsewhere.
var drafts: StoryDrafts = StoryDrafts.new()

var _week: StoryFiles.Week
## Errand file path to {"errand": Errand, "problems": PackedStringArray, "draft": bool}.
var _cards: Dictionary = {}
var _selected: String = ""
var _holding: bool = false
var _was_paused: bool = false

var _board: StoryLabBoard
var _status: Label
var _problems: Label
var _lower: Control
var _errand_panel: StoryErrandPanel
var _day_panel: StoryDayPanel
var _hint: Label
var _drafts_button: Button
var _drafts_panel: StoryDraftsPanel
var _send_button: Button
var _checkout_chip: Label
var _send_panel: StorySendPanel
var _customers: PopupMenu
var _add_day: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	drafts.to_checkout = StoryDrafts.saves_to_checkout()
	_build()
	var errors := drafts.load_drafts()
	refresh()
	var changed_on_main := StoryDraftsPanel.main_changed(drafts)
	if not errors.is_empty():
		_say("Some drafts don't read: " + "; ".join(errors), true)
	elif not changed_on_main.is_empty():
		_say("Main changed %d files since you edited them: open Drafts to compare." % changed_on_main.size(), true)
	else:
		_say("Click an errand to open it. Drag a card to move it.")
	_hold(is_visible_in_tree())


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_inside_tree():
		_hold(is_visible_in_tree())
	elif what == NOTIFICATION_EXIT_TREE:
		_hold(false)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_ESCAPE and visible:
		if _drafts_panel.visible:
			_drafts_panel.hide()
		elif _send_panel.visible:
			_send_panel.hide()
		else:
			hide()
		get_viewport().set_input_as_handled()


## Loads the week again from the story files with the drafts over them, and shows it.
func refresh() -> void:
	var texts := drafts.texts()
	_week = StoryFiles.load_week(texts)
	var links := _missing_links()
	_cards.clear()
	for path: String in StoryFiles.files(StoryFiles.ERRANDS_DIR, ".errand", texts):
		var parsed := StoryFormat.parse_errand(drafts.text(path), path)
		var problems := parsed.errors.duplicate()
		for link: String in links:
			if link.begins_with(path) or link.begins_with(StoryDrafts.repo_path(path)):
				problems.append(link)
		_cards[path] = {"errand": parsed.value as Errand, "problems": problems, "draft": drafts.has(path)}
	if not _cards.has(_selected):
		_selected = ""
	var drafted_days: Array[int] = []
	for path: String in drafts.paths():
		if path.begins_with(StoryFiles.DAYS_DIR):
			drafted_days.append(path.get_file().get_basename().trim_prefix("day_").to_int())
	_board.show_week(_week.days, _cards, _selected, drafted_days)
	_problems.text = "" if _week.errors.is_empty() else "%d problems in the story files (hover)" % _week.errors.size()
	_problems.tooltip_text = "\n".join(_week.errors)
	_errand_panel.flags = flag_names()
	_drafts_button.text = "Drafts (%d)" % drafts.paths().size()
	_send_button.disabled = drafts.paths().is_empty()
	_send_button.tooltip_text = "Make a GitHub issue of your drafts" if not drafts.to_checkout else "Save to checkout is on: commit the files with git instead"
	if _selected == "" and _errand_panel.visible:
		_show_lower(_hint)


## The errand files on the board: path to {"errand", "problems", "draft"}.
func cards() -> Dictionary:
	return _cards


## Makes [param text] the text of the story file [param path] ("" removes it), plays the week with
## it, and shows it. Returns "" or what failed.
func store(path: String, text: String) -> String:
	var failed := drafts.put(path, text)
	if failed != "":
		_say("Not saved: " + failed, true)
		return failed
	_after_store()
	return ""


## Moves the errand file [param path] to day [param day] at place [param index], or with
## [param alternative] onto the errands at that place, renaming files through the drafts. Returns ""
## or what failed.
func move_errand(path: String, day: int, index: int, alternative: bool) -> String:
	var renames := StoryLabBoard.moves(StoryLabBoard.groups(PackedStringArray(_cards.keys())), path, day, index, alternative)
	if renames.is_empty():
		return ""
	var failed := drafts.rename(renames)
	if failed != "":
		_say("Not moved: " + failed, true)
		return failed
	if renames.has(_selected):
		_selected = renames[_selected]
	_after_store()
	_say("Moved %s to %s." % [path.get_file(), renames.get(path, path).get_file()])
	return ""


## Opens the errand file [param path] below the board.
func open_errand(path: String) -> void:
	_selected = path
	refresh()
	if _cards.has(path):
		_show_lower(_errand_panel)
		_errand_panel.show_errand(path, drafts.text(path))


## Opens day [param number] (1 to 7) below the board.
func open_day(number: int) -> void:
	_selected = ""
	refresh()
	var path := "%sday_%d.day" % [StoryFiles.DAYS_DIR, number]
	_show_lower(_day_panel)
	_day_panel.show_day(path, drafts.text(path) if drafts.text(path) != "" else "weather: clear\nwarp: 0\n")


## The open errand panel (for its edits).
func errand_panel() -> StoryErrandPanel:
	return _errand_panel


## Every flag that the week sets or checks, the corruption signs' flags, and each customer's
## <customer>_runs_cambion and gone_<customer>, sorted: what the text view offers.
func flag_names() -> PackedStringArray:
	var found: Dictionary[String, bool] = {}
	if ResourceLoader.exists(STORY_CHECK):
		var check := load(STORY_CHECK) as Script
		if check != null:
			for flag: Variant in (check.call("flag_index", _week) as Dictionary):
				found[String(flag)] = true
	for day: Day in _week.days:
		for flag: StringName in day.set_flags.keys() + day.close_flags.keys():
			found[flag] = true
		for id: StringName in day.close_signs:
			found["sign_" + id] = true
		for errand: Errand in day.errands:
			_note_condition(found, errand.when)
			for c: Conversation in errand.conversations:
				_note_condition(found, c.when)
				_note_reply(found, c)
	for id: StringName in StoryDayPanel.signs():
		found["sign_" + id] = true
	for customer: String in LabUI.resource_names(CUSTOMERS_DIR):
		found[customer + "_runs_cambion"] = true
		found["gone_" + customer] = true
	var names := PackedStringArray(found.keys())
	names.sort()
	return names


func _note_reply(found: Dictionary[String, bool], reply: Reply) -> void:
	if reply == null:
		return
	for flag: StringName in reply.set_flags:
		found[flag] = true
	_note_condition(found, reply.when)
	for choice: Choice in reply.choices:
		_note_condition(found, choice.when)
		for answer: Reply in choice.replies:
			_note_reply(found, answer)
	_note_reply(found, reply.then)


func _note_condition(found: Dictionary[String, bool], when: Condition) -> void:
	if when == null:
		return
	for flag: StringName in when.need_flags + when.not_flags:
		found[flag] = true


func _show_lower(shown: Control) -> void:
	for child: Node in _lower.get_children():
		(child as Control).visible = child == shown


func _remove_errand(path: String) -> void:
	if store(path, "") == "":
		_selected = ""
		_show_lower(_hint)
		refresh()
		_say("Removed %s. Discard its draft to bring it back." % path.get_file())


func _drafts_changed() -> void:
	_after_store()
	if _selected != "":
		open_errand(_selected)


func _store_edit(path: String, text: String) -> void:
	store(path, text)


func _after_store() -> void:
	var errors: PackedStringArray = Game.load_story(drafts.texts())
	refresh()
	if errors.is_empty():
		_say("Saved. The game plays it now." if not drafts.to_checkout else "Saved into the checkout.")
	else:
		_say("Saved, but the game can't play the week: " + errors[0], true)
		_problems.text = "%d problems: the game keeps the week it had (hover)" % errors.size()
		_problems.tooltip_text = "\n".join(errors)


# The missing links of the week from the story check, or none while the game has no check.
func _missing_links() -> PackedStringArray:
	if not ResourceLoader.exists(STORY_CHECK):
		return PackedStringArray()
	var check := load(STORY_CHECK) as Script
	if check == null:
		push_error("Story Lab: %s doesn't load" % STORY_CHECK)
		return PackedStringArray()
	return check.call("missing_links", _week)


func _hold(on: bool) -> void:
	if on == _holding:
		return
	_holding = on
	if on:
		_was_paused = get_tree().paused
		get_tree().paused = true
	else:
		get_tree().paused = _was_paused


func _say(text: String, bad: bool = false) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", LabUI.BAD if bad else LabUI.DIM)
	if bad:
		push_warning("Story Lab: " + text)


func _add_errand(day: int) -> void:
	_add_day = day
	_customers.clear()
	for name: String in LabUI.resource_names(CUSTOMERS_DIR):
		_customers.add_item(name)
	_customers.position = Vector2i(get_global_mouse_position())
	_customers.popup()


func _add_errand_for(index: int) -> void:
	var customer := _customers.get_item_text(index)
	var day_groups: Array = StoryLabBoard.groups(PackedStringArray(_cards.keys()))[_add_day - 1]
	var path := "%s%02d%02d_%s.errand" % [StoryFiles.ERRANDS_DIR, _add_day, day_groups.size() + 1, customer]
	if store(path, "customer: %s\n\n== drop-off\n" % customer) == "":
		open_errand(path)
		_say("Added %s. Write what the visit is for, then the drop-off." % path.get_file())


func _build() -> void:
	theme = LabUI.make_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop := ColorRect.new()
	backdrop.color = Color(LabUI.BG, 0.98)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	margin.add_child(page)
	page.add_child(_top_bar())
	_board = StoryLabBoard.new()
	_board.custom_minimum_size.y = 390
	_board.errand_picked.connect(open_errand)
	_board.errand_dropped.connect(move_errand)
	_board.add_requested.connect(_add_errand)
	_board.day_picked.connect(open_day)
	page.add_child(_board)
	_lower = Control.new()
	_lower.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(_lower)
	_hint = LabUI.label("Click an errand card to open it, or a day's header for its weather, warp, signs and notes.", 16, LabUI.DIM)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_errand_panel = StoryErrandPanel.new()
	_errand_panel.saved.connect(_store_edit)
	_errand_panel.remove_requested.connect(_remove_errand)
	_day_panel = StoryDayPanel.new()
	_day_panel.saved.connect(_store_edit)
	for shown: Control in [_hint, _errand_panel, _day_panel]:
		shown.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_lower.add_child(shown)
	_show_lower(_hint)
	_drafts_panel = StoryDraftsPanel.new()
	_drafts_panel.changed.connect(_drafts_changed)
	add_child(_drafts_panel)
	_send_panel = StorySendPanel.new()
	_send_panel.github_repo = github_repo
	_send_panel.github_project = github_project
	_send_panel.sent.connect(func(text: String, ok: bool) -> void: _say(text, not ok))
	add_child(_send_panel)
	_customers = PopupMenu.new()
	_customers.id_pressed.connect(_add_errand_for)
	add_child(_customers)


func _top_bar() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(LabUI.label("Story Lab", 26))
	row.add_child(LabUI.chip("Game paused", LabUI.ACCENT, 13))
	_checkout_chip = LabUI.chip("Saves to checkout", LabUI.CHANGED, 13)
	_checkout_chip.tooltip_text = "Edits change res://story/ in this checkout; commit them with git. Dev menu (F3) turns it off."
	_checkout_chip.mouse_filter = Control.MOUSE_FILTER_PASS
	_checkout_chip.visible = drafts.to_checkout
	row.add_child(_checkout_chip)
	_status = LabUI.label("", 14, LabUI.DIM)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.clip_text = true
	_status.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(_status)
	_problems = LabUI.label("", 13, LabUI.CHANGED)
	_problems.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(_problems)
	_drafts_button = LabUI.button("Drafts", func() -> void: _drafts_panel.show_drafts(drafts))
	_drafts_button.tooltip_text = "Your edits that main doesn't have yet"
	row.add_child(_drafts_button)
	_send_button = LabUI.button("Send", func() -> void: _send_panel.show_send(drafts), &"AccentButton")
	row.add_child(_send_button)
	row.add_child(LabUI.button("Close  Esc", hide))
	return row
