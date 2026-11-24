class_name StoryLab
extends Control
## The Story Lab (Dev menu, F4 or Cmd+4): writers edit the story files (docs/dialogue.md) in the
## running game. On top, the week board; below, the picked errand or day. Every edit that parses is
## a draft (StoryDrafts) that the game plays at once. While the Lab shows, the game is paused.

const CUSTOMERS_DIR: String = "res://customers/"
## The story check, when the game has one: static missing_links(week) and flag_index(week).

## The GitHub repo that Send makes the issue in, as owner/name; "" reads git's remote origin.
@export var github_repo: String = ""

## True: edits go straight into res://story/ in the checkout, and no drafts play (the Dev menu's
## Save to checkout).
var to_checkout: bool:
	get:
		return drafts != null and drafts.to_checkout
	set(on):
		if drafts == null:
			return  # _ready reads the setting itself
		drafts.to_checkout = on
		if is_node_ready():
			_after_store()
			_checkout_chip.visible = on
			_say("Save to checkout is on: edits change res://story/ in this checkout." if on else "Save to checkout is off: edits are drafts again.")

## The drafts that the Lab edits. Set it before the Lab enters the tree to keep them elsewhere, as it
## is; null: the writer's drafts in user://story_drafts/, saved to the checkout while the Dev menu's
## Save to checkout is on.
var drafts: StoryDrafts

var _week: StoryFiles.Week
## Errand file path to {"errand": Errand, "problems": PackedStringArray, "draft": bool}.
var _cards: Dictionary = {}
var _selected: String = ""
var _holding: bool = false
## True while the Lab is hidden for Play: Esc brings it back.
var _playing: bool = false
var _was_paused: bool = false
var _was_low_processor: bool = false
## The game's viewports that stopped drawing while the Lab shows, with the update mode each had.
var _frozen: Dictionary[SubViewport, SubViewport.UpdateMode] = {}
## The canvas items below the Lab that the renderer hides while it shows; their nodes stay visible.
var _covered: Array[CanvasItem] = []

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
var _week_view: Control
var _bible: StoryBiblePanel
var _keywords: StoryKeywordsPanel
var _problem_panel: StoryProblemPanel
var _sign_panel: StorySignPanel
var _call_outs: StoryCallOutsPanel
var _sections: ButtonGroup
var _send_panel: StorySendPanel
var _customers: PopupMenu
var _add_day: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if drafts == null:
		drafts = StoryDrafts.new()
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
		if visible:
			_playing = false
		_hold(is_visible_in_tree())
	elif what == NOTIFICATION_EXIT_TREE:
		_hold(false)


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if _playing and not visible and key != null and key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		show()
		get_viewport().set_input_as_handled()


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
		var parsed := StoryFormat.parse_errand(drafts.text(path), path, _week.problems)
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
	_board.show_week(_week.days, _cards, _selected, drafted_days, _week)
	_problems.text = "" if _week.errors.is_empty() else "%d problems in the story files (hover)" % _week.errors.size()
	_problems.tooltip_text = "\n".join(_week.errors)
	_errand_panel.flags = flag_names()
	_day_panel.facts = _errand_panel.flags
	_errand_panel.problems = _week.problems
	if _problem_panel.visible:
		_problem_panel.show_problems(_week.problems, drafts)
	if _sign_panel.visible:
		_sign_panel.show_signs(_week)
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
## [param alternative] onto the errands at that place, renaming files through the drafts. With
## [param before_opening] it comes before opening if it lands in place 01; an errand that leaves
## place 01, or is moved without it, comes after opening. Returns "" or what failed.
func move_errand(path: String, day: int, index: int, alternative: bool, before_opening: bool = false) -> String:
	var days := StoryLabBoard.groups(PackedStringArray(_cards.keys()))
	var renames := StoryLabBoard.moves(days, path, day, index, alternative)
	var comes := _comes_changes(days, renames, path, day, before_opening)
	if renames.is_empty() and comes.is_empty():
		return ""
	var failures := PackedStringArray([drafts.rename(renames)])
	for moved: String in comes:
		failures.append(drafts.put(moved, with_comes(drafts.text(moved), comes[moved])))
	var failed := "\n".join(Array(failures).filter(func(f: String) -> bool: return f != ""))
	if failed != "":
		_after_store()
		_say("Not moved: " + failed, true)
		return failed
	if renames.has(_selected):
		_selected = renames[_selected]
	_after_store()
	_say("Moved %s to %s." % [path.get_file(), renames.get(path, path).get_file()])
	return ""


## Adds an errand for [param customer] (a file name in customers/, without .tres) on day [param day]
## at place [param index] (0 is the first; the errands from there move down), coming before opening
## with [param before_opening], and opens it. Returns "" or what failed.
func add_errand(customer: String, day: int, index: int, before_opening: bool = false) -> String:
	var day_groups: Array = StoryLabBoard.groups(PackedStringArray(_cards.keys()))[day - 1]
	var path := "%s%02d%02d_%s.errand" % [StoryFiles.ERRANDS_DIR, day, day_groups.size() + 1, customer]
	var failed := store(path, "customer: %s\n\n== drop-off\n" % customer)
	if failed != "":
		return failed
	_selected = path
	failed = move_errand(path, day, index, false, before_opening)
	if failed != "":
		return failed
	open_errand(_selected)
	_say("Added %s. Write what the visit is for, then the drop-off." % _selected.get_file())
	return ""


## [param text], an errand file, with "comes: before opening" in its header when [param before],
## and without a comes: line when not.
static func with_comes(text: String, before: bool) -> String:
	var lines := Array(text.split("\n"))
	var header_end := lines.size()
	for i: int in lines.size():
		if String(lines[i]).begins_with("=="):
			header_end = i
			break
	for i: int in range(header_end - 1, -1, -1):
		if String(lines[i]).begins_with("comes:"):
			lines.remove_at(i)
			header_end -= 1
	var at := 0
	for i: int in header_end:
		var line: String = lines[i]
		if line.begins_with("customer:") or line.begins_with("problem:") or line.begins_with("computer:"):
			at = i + 1
	if before:
		lines.insert(at, "comes: " + StoryFormat.COMES.find_key(true))
	return "\n".join(PackedStringArray(lines))


# The errands of the move's days whose "comes: before opening" changes, by their path after the
# move: true adds it. Only place 01 can come before opening.
func _comes_changes(days: Array, renames: Dictionary[String, String], path: String, day: int, before_opening: bool) -> Dictionary[String, bool]:
	var changes: Dictionary[String, bool] = {}
	for d: int in [StoryLabBoard.code_of(path).substr(0, 2).to_int(), day]:
		if d < 1 or d > StoryLabBoard.DAYS:
			continue
		for group: Array in days[d - 1]:
			for old: String in group:
				var after: String = renames.get(old, old)
				var now: bool = (_cards[old]["errand"] as Errand).before_opening
				var wanted := (before_opening if old == path else now) and StoryLabBoard.code_of(after).substr(2, 2) == "01"
				if wanted != now:
					changes[after] = wanted
	return changes


## Starts the corruption sign [param id] at [param to] ({"day": 1 to 7, "key": "on start" or
## "close signs"}, or {"errand": path}: its first drop-off sets the flag as it starts) and removes
## the start [param from] (one of StoryCheck.sign_starts; {} for none), through the drafts. The flag
## keeps the value that [param from] set (0 stops the sign); a start from on close, or one that
## doesn't set 1, stays on close at closing. A problem's drop_off_signs don't move. Returns "" or
## what failed.
func move_sign(id: StringName, from: Dictionary, to: Dictionary) -> String:
	if from.get("problem", &"") != &"":
		return _refuse_sign("%s comes with the problem %s's mechanics; change it in problems/%s.tres" % [id, from["problem"], from["problem"]])
	var value: int = from.get("value", 1)
	var texts: Dictionary[String, String] = {}
	var failed := ""
	if from.get("day", 0) > 0:
		failed = _day_sign(texts, from["day"], from["detail"], id, value, false)
	elif from.get("errand", "") != "":
		var path: String = from["errand"]
		texts[path] = StorySignStarts.without_set(drafts.text(path), from["detail"], id, value)
	if failed == "" and to.has("day"):
		var key: String = to["key"]
		if key == "close signs" and (from.get("detail", "") == "on close" or value != 1):
			key = "on close"
		failed = _day_sign(texts, to["day"], key, id, value, true)
	elif failed == "" and to.has("errand"):
		var path: String = to["errand"]
		texts[path] = StorySignStarts.with_drop_off_set(texts.get(path, drafts.text(path)), id, value)
	if failed != "":
		return _refuse_sign(failed)
	for path: String in texts:
		if texts[path] != drafts.text(path):
			failed = drafts.put(path, texts[path])
			if failed != "":
				_after_store()
				return _refuse_sign(failed)
	_after_store()
	_say("Moved the sign %s." % id if not from.is_empty() else "Started the sign %s." % id)
	return ""


func _day_sign(texts: Dictionary[String, String], day: int, key: String, id: StringName, value: int, add: bool) -> String:
	var path := "%sday_%d.day" % [StoryFiles.DAYS_DIR, day]
	var edited := StorySignStarts.day_edit(texts.get(path, drafts.text(path)), path, key, id, value, add)
	if edited.has("error"):
		return edited["error"]
	texts[path] = edited["text"]
	return ""


func _refuse_sign(why: String) -> String:
	_say("Sign not moved: " + why, true)
	return why


## Opens the corruption sign [param id] in the Signs section.
func open_sign(id: StringName) -> void:
	show_section("Signs")
	_sign_panel.open_sign(id)


## Plays [param errand]'s conversation for [param trigger] in the game (Game.play_errand) and hides
## the Lab; Esc or F4 brings it back on the same errand. Returns why it can't play, or "".
func play(errand: Errand, trigger: Conversation.Trigger) -> String:
	var reason: String = Game.play_errand(errand, trigger)
	if reason != "":
		_say("Can't play it: " + reason, true)
		return reason
	hide()
	_playing = true
	return ""


## Shows the "Week" (the board and the picked errand or day), the "Problems", the "Signs", the
## "Call-outs", the "Keywords" or the "Bible".
func show_section(section: String) -> void:
	for button: BaseButton in _sections.get_buttons():
		button.set_pressed_no_signal((button as Button).text == section)
	_week_view.visible = section == "Week"
	_problem_panel.visible = section == "Problems"
	_sign_panel.visible = section == "Signs"
	_call_outs.visible = section == "Call-outs"
	_bible.visible = section == "Bible"
	_keywords.visible = section == "Keywords"
	if section == "Problems":
		_problem_panel.show_problems(_week.problems, drafts)
	elif section == "Signs":
		_sign_panel.show_signs(_week)
	elif section == "Call-outs":
		_call_outs.show_call_outs(drafts)
	elif section == "Bible":
		_bible.show_pages(drafts)
	elif section == "Keywords":
		_keywords.show_keywords(drafts, _week)


## Opens the problem [param id] in the Problems section.
func open_problem(id: StringName) -> void:
	show_section("Problems")
	_problem_panel.open_problem(id)


## The Call-outs section (for its edits).
func call_outs_panel() -> StoryCallOutsPanel:
	return _call_outs


## The Signs section.
func sign_panel() -> StorySignPanel:
	return _sign_panel


## The Problems section (for its edits).
func problem_panel() -> StoryProblemPanel:
	return _problem_panel


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
	for flag: Variant in StoryCheck.flag_index(_week):
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
	if _problem_panel.visible and _problem_panel.problem_id() != &"":
		_problem_panel.open_problem(_problem_panel.problem_id())
	if _call_outs.visible:
		_call_outs.show_call_outs(drafts)
	if _keywords.visible:
		_keywords.show_keywords(drafts, _week)


func _store_page(path: String, text: String) -> void:
	var failed := drafts.put(path, text)
	if failed != "":
		_say("Not saved: " + failed, true)
		return
	refresh()
	_say("Saved %s." % path.get_file() if text != "" else "Removed %s. Discard its draft to bring it back." % path.get_file())


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


func _missing_links() -> PackedStringArray:
	return StoryCheck.missing_links(_week)


func _hold(on: bool) -> void:
	if on == _holding:
		return
	_holding = on
	if on:
		_was_paused = get_tree().paused
		get_tree().paused = true
	else:
		get_tree().paused = _was_paused
	_freeze_game(on)


# The Lab covers the paused game, so its viewports keep their last picture, and the window draws
# only when the Lab changes: an idle Lab costs nothing. A viewport that always updates counts as a
# change in every frame, so low processor mode alone doesn't stop the drawing.
func _freeze_game(on: bool) -> void:
	if on:
		for node in get_tree().root.find_children("*", "SubViewport", true, false):
			var viewport := node as SubViewport
			if viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS and not is_ancestor_of(viewport):
				_frozen[viewport] = viewport.render_target_update_mode
				viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_cover_game()
		_was_low_processor = OS.low_processor_usage_mode
		OS.low_processor_usage_mode = true
		return
	for viewport: Variant in _frozen:
		if is_instance_valid(viewport):
			(viewport as SubViewport).render_target_update_mode = _frozen[viewport]
	_frozen.clear()
	for item: Variant in _covered:
		if is_instance_valid(item):
			RenderingServer.canvas_item_set_visible((item as CanvasItem).get_canvas_item(), (item as CanvasItem).visible)
	_covered.clear()
	OS.low_processor_usage_mode = _was_low_processor


# Hides from the renderer what draws below the Lab, without hiding the nodes, which the game reads:
# a shader that reads TIME, such as the Screen View's CRT, redraws the window every frame.
func _cover_game() -> void:
	var layer := get_canvas_layer_node().layer if get_canvas_layer_node() != null else 0
	var node: Node = self
	while node.get_parent() != null:
		for sibling in node.get_parent().get_children():
			if sibling == node:
				continue
			var items: Array[Node] = []
			if sibling is CanvasItem:
				items.append(sibling)
			elif sibling is CanvasLayer and (sibling as CanvasLayer).layer < layer:
				items.assign(sibling.get_children().filter(func(child: Node) -> bool: return child is CanvasItem))
			for item: Node in items:
				RenderingServer.canvas_item_set_visible((item as CanvasItem).get_canvas_item(), false)
				_covered.append(item as CanvasItem)
		node = node.get_parent()


func _say(text: String, bad: bool = false) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", LabUI.BAD if bad else LabUI.DIM)
	if bad:
		push_warning("Story Lab: " + text)


func _add_errand(day: int) -> void:
	_add_day = day
	_customers.clear()
	for customer_name: String in LabUI.resource_names(CUSTOMERS_DIR):
		_customers.add_item(customer_name)
	_customers.position = Vector2i(get_global_mouse_position())
	_customers.popup()


func _add_errand_for(index: int) -> void:
	var day_groups: Array = StoryLabBoard.groups(PackedStringArray(_cards.keys()))[_add_day - 1]
	add_errand(_customers.get_item_text(index), _add_day, day_groups.size())


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
	_week_view = VBoxContainer.new()
	_week_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_week_view.add_theme_constant_override("separation", 12)
	page.add_child(_week_view)
	_problem_panel = StoryProblemPanel.new()
	_problem_panel.saved.connect(_store_edit)
	_problem_panel.hide()
	page.add_child(_problem_panel)
	_sign_panel = StorySignPanel.new()
	_sign_panel.day_picked.connect(func(day: int) -> void:
		show_section("Week")
		open_day(day))
	_sign_panel.errand_picked.connect(func(path: String) -> void:
		show_section("Week")
		open_errand(path))
	_sign_panel.problem_picked.connect(open_problem)
	_sign_panel.hide()
	page.add_child(_sign_panel)
	_call_outs = StoryCallOutsPanel.new()
	_call_outs.saved.connect(_store_edit)
	_call_outs.hide()
	page.add_child(_call_outs)
	_keywords = StoryKeywordsPanel.new()
	_keywords.saved.connect(_store_edit)
	_keywords.hide()
	page.add_child(_keywords)
	_bible = StoryBiblePanel.new()
	_bible.saved.connect(_store_page)
	_bible.hide()
	page.add_child(_bible)
	_board = StoryLabBoard.new()
	_board.custom_minimum_size.y = 480
	_board.errand_picked.connect(open_errand)
	_board.errand_dropped.connect(move_errand)
	_board.customer_dropped.connect(add_errand)
	_board.sign_dropped.connect(move_sign)
	_board.sign_picked.connect(open_sign)
	_board.add_requested.connect(_add_errand)
	_board.day_picked.connect(open_day)
	_week_view.add_child(StoryLabBoard.customer_strip())
	_week_view.add_child(StoryLabBoard.sign_strip())
	_week_view.add_child(_board)
	_lower = Control.new()
	_lower.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_week_view.add_child(_lower)
	_hint = LabUI.label("Click an errand card to open it, or a day's header for its weather, warp, signs and notes.", 16, LabUI.DIM)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_errand_panel = StoryErrandPanel.new()
	_errand_panel.saved.connect(_store_edit)
	_errand_panel.remove_requested.connect(_remove_errand)
	_errand_panel.play_requested.connect(play)
	_errand_panel.edit_problem_requested.connect(open_problem)
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
	_sections = ButtonGroup.new()
	var sections := LabUI.segmented(PackedStringArray(["Week", "Problems", "Signs", "Call-outs", "Keywords", "Bible"]), _sections)
	for button: BaseButton in _sections.get_buttons():
		button.custom_minimum_size.x = 90
		button.toggled.connect(func(on: bool) -> void:
			if on:
				show_section((button as Button).text))
	row.add_child(sections)
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
