class_name StoryLabBoard
extends HBoxContainer
## The Story Lab's week: a column per day with its weather and warp, and its errand cards in the order
## the customers come in, each under its band (the time of day that Game.daypart_of gives it).
## Alternatives (errands with one errand code) stack in one dashed card. Cards drag to another day,
## place or band, or onto a card to become its alternative; customers drag in from
## [method customer_strip] to make a new errand. A chip shows where each corruption sign starts; the
## chips, and the signs of [method sign_strip], drag onto a band or a card to start the sign there.

## The writer clicked the card of the errand file [param path].
signal errand_picked(path: String)
## The writer double-clicked the card of the errand file [param path]; its first click already
## emitted [signal errand_picked].
signal errand_double_clicked(path: String)
## The writer clicked the header of day [param day], 1 to 7.
signal day_picked(day: int)
## The writer asked for a new errand at the end of day [param day].
signal add_requested(day: int)
## The writer dropped the errand file [param path] on day [param day] at place [param index] (0 is
## the first, in the order before the move), or with [param alternative] onto the errands at that
## place. [param before_opening] is true when it lands in place 0 of the Before opening band.
signal errand_dropped(path: String, day: int, index: int, alternative: bool, before_opening: bool)
## The writer dropped [param customer] (a file name in customers/, without .tres) on day
## [param day] for a new errand at place [param index] (0 is the first; the errands from there move
## down), coming before opening with [param before_opening].
signal customer_dropped(customer: String, day: int, index: int, before_opening: bool)
## The writer clicked the chip of the corruption sign [param id].
signal sign_picked(id: StringName)
## The writer dropped the sign [param id] to start it at [param to]: {"day": 1 to 7, "key": "on start"
## or "close signs"}, or {"errand": path} for its drop-off. [param from] is the start that its chip
## showed (one of StoryCheck.sign_starts), or {} from [method sign_strip].
signal sign_dropped(id: StringName, from: Dictionary, to: Dictionary)

## The parts of a day column, in the order of the day.
enum Band {
	BEFORE_OPENING, ## Place 01, when it says comes: before opening.
	MORNING, ## Game.Daypart.MORNING as the customer comes in.
	MIDDAY, ## Game.Daypart.MIDDAY.
	AFTERNOON, ## Game.Daypart.AFTERNOON.
	AT_CLOSING, ## The day's on close flags and close signs; no errand comes then.
}

const DAYS: int = 7
const PORTRAIT_SIZE: int = 44
const BAND_NAMES: PackedStringArray = ["Before opening", "Morning", "Midday", "Afternoon", "At closing"]
const CUSTOMERS_DIR: String = "res://customers/"
const SIGN_COLOR := Color("c58cff")
const GAME := preload("res://game.gd")  # the script, not the autoload: tests compile this before autoloads exist

var _hinted: PanelContainer
var _hinted_style: StyleBox
## True from a double-click's press to its release: the release opens the errand full.
var _double_click: bool = false
## The shown week, from [method groups].
var _days: Array = []
var _cards: Dictionary = {}
var _sign_titles: Dictionary[StringName, String] = {}
## The shown sign chips, from [method sign_spots].
var _spots: Array[Dictionary] = []


## The errand files in [param paths] by day and place: for each day 1 to 7 (index 0 to 6), its
## errand codes in order, each as the paths that share it, sorted. Paths without an errand code are
## left out.
static func groups(paths: PackedStringArray) -> Array:
	var days: Array = []
	for d: int in DAYS:
		days.append([])
	var sorted := paths.duplicate()
	sorted.sort()
	var last_code := ""
	for path: String in sorted:
		var code := code_of(path)
		var day := code.substr(0, 2).to_int()
		if code == "" or day < 1 or day > DAYS:
			continue
		var day_groups: Array = days[day - 1]
		if code == last_code:
			day_groups[day_groups.size() - 1].append(path)
		else:
			day_groups.append([path])
		last_code = code
	return days


## The errand code at the start of [param path]'s file name, or "" when it has none.
static func code_of(path: String) -> String:
	var stem := path.get_file().get_basename()
	return stem.substr(0, 4) if stem.length() > 5 and stem.substr(0, 4).is_valid_int() and stem[4] == "_" else ""


## The renames (old path to new path) that move [param path] to day [param day] at place
## [param index] of [param days] (from [method groups]), or with [param alternative] into the
## errands at that place, and number both days' errands again from 01 without gaps.
static func moves(days: Array, path: String, day: int, index: int, alternative: bool) -> Dictionary[String, String]:
	var after := _moved(days, path, day, index, alternative)
	var from_day := code_of(path).substr(0, 2).to_int()
	var renames: Dictionary[String, String] = {}
	var taken: Dictionary[String, bool] = {}
	for d: int in ([from_day, day] if from_day != day else [day]):
		var numbered: Array = after[d - 1]
		for g: int in numbered.size():
			for old: String in numbered[g]:
				var dir := old.get_base_dir() + "/"
				var stem := old.get_file().get_basename().substr(5)
				var new_path := "%s%02d%02d_%s.errand" % [dir, d, g + 1, stem]
				var copy := 2
				while taken.has(new_path):
					new_path = "%s%02d%02d_%s_%d.errand" % [dir, d, g + 1, stem, copy]
					copy += 1
				taken[new_path] = true
				if new_path != old:
					renames[old] = new_path
	return renames


# [param days] with [param path] moved as [method moves] moves it; "" is a new errand.
static func _moved(days: Array, path: String, day: int, index: int, alternative: bool) -> Array:
	var after: Array = days.duplicate(true)
	var from_day := code_of(path).substr(0, 2).to_int()
	if from_day >= 1 and from_day <= DAYS:
		var from_groups: Array = after[from_day - 1]
		for g: int in from_groups.size():
			var group: Array = from_groups[g]
			if path not in group:
				continue
			group.erase(path)
			if group.is_empty():
				from_groups.remove_at(g)
				if from_day == day and g < index:
					index -= 1
			break
	var to_groups: Array = after[day - 1]
	if alternative and index < to_groups.size():
		to_groups[index].append(path)
	else:
		to_groups.insert(clampi(index, 0, to_groups.size()), [path])
	return after


## The band of each place of [param day_groups] (one day of [method groups]) whose errands are in
## [param cards] (path to {"errand": Errand}), by the game's rule, Game.daypart_of: BEFORE_OPENING
## for place 01 when one of its errands comes before opening, else MORNING, MIDDAY or AFTERNOON.
## [param moving] comes after opening whatever its file says; a path without a card is a new errand
## that leaves its computer.
static func bands(day_groups: Array, cards: Dictionary, moving: String = "") -> Array[Band]:
	var day := Day.new()
	for g: int in day_groups.size():
		for path: String in day_groups[g]:
			var stand_in := Errand.new()
			stand_in.code = "01%02d" % (g + 1)
			var errand: Errand = cards[path]["errand"] if cards.has(path) else null
			if errand != null:
				stand_in.brings = errand.brings
				stand_in.before_opening = errand.before_opening and path != moving
			day.errands.append(stand_in)
	var found: Array[Band] = []
	for g: int in day_groups.size():
		if g == 0 and day.alternatives("0101").any(func(each: Errand) -> bool: return each.before_opening):
			found.append(Band.BEFORE_OPENING)
		else:
			found.append(Band[GAME.Daypart.find_key(GAME.daypart_of(day, g + 1))])
	return found


## The place on day [param day] of [param days] (0 is the first, in the order before the move) that
## puts the errand file [param path] in [param band]: the first place where [method bands] gives it
## that band, or the end of the day. "" is a new errand that leaves its computer. BEFORE_OPENING is
## place 0; the other bands never take place 0 from an errand that comes before opening.
static func place_for(days: Array, cards: Dictionary, day: int, band: Band, path: String = "") -> int:
	var day_groups: Array = days[day - 1]
	if band == Band.BEFORE_OPENING:
		return 0
	var first := 1 if not day_groups.is_empty() and bands(day_groups, cards, path)[0] == Band.BEFORE_OPENING else 0
	for index: int in range(first, day_groups.size() + 1):
		var after: Array = _moved(days, path, day, index, false)[day - 1]
		for g: int in after.size():
			if path in after[g]:
				if bands(after, cards, path)[g] == band:
					return index
				break
	return day_groups.size()


## The facts that [param day] sets at closing (its on close flags but the signs', which show as
## chips), in plain words, one line each.
static func closing_words(day: Day) -> PackedStringArray:
	var words := PackedStringArray()
	if day == null:
		return words
	for flag: StringName in day.close_flags:
		var value: int = day.close_flags[flag]
		if String(flag).begins_with("sign_"):
			continue
		elif value == 0:
			words.append("Forgets " + StoryFactPicker.humanize(flag))
		else:
			words.append("Remembers " + StoryFactPicker.humanize(flag) + ("" if value == 1 else " = %d" % value))
	return words


## Every start of the signs [param ids] in [param week], as the Signs section lists them
## (StoryCheck.sign_starts, from the story check's flag index): each {"id", "start"}. A problem's
## drop_off_signs start shows once.
static func all_sign_starts(week: StoryFiles.Week, ids: Array) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	if week == null:
		return found
	var index := StoryCheck.flag_index(week)
	for id: StringName in ids:
		var seen: Dictionary[String, bool] = {}
		for start: Dictionary in StoryCheck.sign_starts(week, index, id):
			if not seen.has(start["text"]):
				seen[start["text"]] = true
				found.append({"id": id, "start": start})
	return found


## Where each of [param starts] (from [method all_sign_starts]) shows on the week of [param days] (from
## [method groups]) and [param cards]: each {"id", "start", "day" (1 to 7), "band" (a day's start:
## BEFORE_OPENING or MORNING for on start, by whether its first errand comes before opening;
## AT_CLOSING for on close and close signs; -1 on a card), "errand" (the card's path, or ""),
## "locked" (true for a problem's drop_off_signs, on each card whose errand has that problem)}.
static func sign_spots(starts: Array[Dictionary], days: Array, cards: Dictionary) -> Array[Dictionary]:
	var spots: Array[Dictionary] = []
	for each: Dictionary in starts:
		var start: Dictionary = each["start"]
		var spot := {"id": each["id"], "start": start, "day": 0, "band": -1, "errand": "", "locked": false}
		if start["day"] > 0:
			var day: int = start["day"]
			spot["day"] = day
			if start["detail"] != "on start":
				spot["band"] = Band.AT_CLOSING
			else:
				var first := bands(days[day - 1], cards)
				spot["band"] = Band.BEFORE_OPENING if not first.is_empty() and first[0] == Band.BEFORE_OPENING else Band.MORNING
			spots.append(spot)
		elif start["errand"] != "" and cards.has(start["errand"]):
			spot["errand"] = start["errand"]
			spot["day"] = code_of(start["errand"]).substr(0, 2).to_int()
			spots.append(spot)
		elif start["problem"] != &"":
			for path: String in cards:
				var errand: Errand = cards[path]["errand"]
				if errand != null and errand.problem != null and errand.problem.resource_path.get_file().get_basename() == String(start["problem"]):
					var locked := spot.duplicate()
					locked["errand"] = path
					locked["day"] = code_of(path).substr(0, 2).to_int()
					locked["locked"] = true
					spots.append(locked)
	return spots


## A wrapping row of every corruption sign (by title) that drags onto the board: dropped on a band or
## a card, it starts the sign there ([signal sign_dropped]).
static func sign_strip() -> Control:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 4)
	row.add_child(LabUI.label("Signs", 13, LabUI.DIM))
	var titles := StoryDayPanel.signs()
	for id: StringName in titles:
		var chip := _sign_chip_box(titles[id] if titles[id] != "" else StoryFactPicker.humanize(id), 12, 150)
		chip.mouse_default_cursor_shape = Control.CURSOR_DRAG
		chip.tooltip_text = "%s (%s)\nDrag onto a time of day or a customer's card to start it there." % [titles[id], id]
		chip.set_drag_forwarding(_sign_drag.bind(chip, id, {}, titles[id]), Callable(), Callable())
		row.add_child(chip)
	return row


static func _sign_drag(_at: Vector2, chip: Control, id: StringName, from: Dictionary, title: String) -> Variant:
	var preview := LabUI.chip(title if title != "" else String(id), SIGN_COLOR, 13)
	preview.add_theme_stylebox_override("normal", LabUI.box(LabUI.HOVER, 8, 4))
	chip.set_drag_preview(preview)
	return {"story_sign": id, "from": from}


# A small rounded chip in the signs' colour with [param text], cut with an ellipsis to [param width]
# pixels, or to the width that its container gives it when 0.
static func _sign_chip_box(text: String, font_size: int, width: int) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", LabUI.box(Color(SIGN_COLOR, 0.18), 6, 1))
	chip.mouse_filter = Control.MOUSE_FILTER_STOP
	var label := LabUI.label(text, font_size, SIGN_COLOR)
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.custom_minimum_size.x = width
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(label)
	return chip


## A row of every customer in customers/ (face and name) that drags onto the board: dropped on a
## day or a band, it asks for a new errand there ([signal customer_dropped]). A click on a chip calls
## [param picked] with the customer (a file name in customers/, without .tres).
static func customer_strip(picked: Callable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(LabUI.label("Customers", 13, LabUI.DIM))
	for customer_name: String in LabUI.resource_names(CUSTOMERS_DIR):
		var customer := load(CUSTOMERS_DIR + customer_name + ".tres") as Customer
		if customer == null:
			push_error("Story Lab: %s%s.tres doesn't load as a Customer" % [CUSTOMERS_DIR, customer_name])
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", LabUI.box(LabUI.RAISED, 8, 2))
		chip.mouse_default_cursor_shape = Control.CURSOR_DRAG
		chip.mouse_filter = Control.MOUSE_FILTER_STOP
		chip.name = customer_name
		chip.tooltip_text = "%s\nClick for their errands. Drag onto a day or a time of day for a new errand." % customer_name
		var shown := customer.spoken_name() if customer != null else customer_name
		var drag := func(_at: Vector2) -> Variant:
			var preview := LabUI.chip(shown, LabUI.TEXT, 15)
			preview.add_theme_stylebox_override("normal", LabUI.box(LabUI.HOVER, 8, 4))
			chip.set_drag_preview(preview)
			return {"story_customer": customer_name}
		chip.set_drag_forwarding(drag, Callable(), Callable())
		chip.gui_input.connect(func(event: InputEvent) -> void:
			var click := event as InputEventMouseButton
			# On release, as a card acts: what the click opens rebuilds the Lab.
			if click != null and not click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
				picked.call(customer_name))
		var inside := HBoxContainer.new()
		inside.add_theme_constant_override("separation", 6)
		inside.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(inside)
		inside.add_child(portrait(customer, 28))
		var label := LabUI.label(shown, 13)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inside.add_child(label)
		row.add_child(chip)
	return row


## Outlines the chip of [param customer] (a file name in customers/) in [param strip], from
## [method customer_strip]; "" outlines none.
static func highlight_customer(strip: Control, customer: String) -> void:
	for chip: Node in strip.get_children():
		if chip is PanelContainer:
			var style := LabUI.box(LabUI.RAISED if chip.name != customer else Color(LabUI.ACCENT, 0.3), 8, 2)
			style.border_color = LabUI.ACCENT
			style.set_border_width_all(2 if chip.name == customer else 0)
			(chip as PanelContainer).add_theme_stylebox_override("panel", style)


## Shows [param days] (Day 1 to 7) with the errand files of [param cards]: path to
## {"errand": Errand, "problems": PackedStringArray (parse errors and missing links), "draft": bool}.
## [param selected] is the open errand's path, [param drafted_days] the days with a draft. The sign
## chips show the starts in [param week]; null shows none.
func show_week(days: Array[Day], cards: Dictionary, selected: String, drafted_days: Array[int], week: StoryFiles.Week = null) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_hinted = null
	if _sign_titles.is_empty():
		_sign_titles = StoryDayPanel.signs()
	add_theme_constant_override("separation", 10)
	_cards = cards
	_days = groups(PackedStringArray(cards.keys()))
	_spots = sign_spots(all_sign_starts(week, _sign_titles.keys()), _days, cards)
	for d: int in DAYS:
		var day: Day = days[d] if d < days.size() else null
		add_child(_column(d + 1, day, _days[d], cards, selected, (d + 1) in drafted_days))


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_hint(null, null)


func _column(number: int, day: Day, day_groups: Array, cards: Dictionary, selected: String, drafted: bool) -> Control:
	var column := PanelContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := LabUI.box(LabUI.CARD, 12, 3)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.border_color = LabUI.LINE
	style.set_border_width_all(1)
	column.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	column.add_child(box)
	var head := _header(number, day, drafted)
	head.set_drag_forwarding(Callable(), _can_drop_end, _drop_end.bind(number, day_groups.size()))
	box.add_child(head)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.set_drag_forwarding(Callable(), _can_drop_end, _drop_end.bind(number, day_groups.size()))
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)
	var placed := bands(day_groups, cards)
	for band: Band in [Band.BEFORE_OPENING, Band.MORNING, Band.MIDDAY, Band.AFTERNOON]:
		var first := placed.find(band)
		var section := _band(number, band, day_groups[first][0] if first >= 0 else "")
		var cards_box: VBoxContainer = section.get_child(0)
		_add_chips(cards_box, _spots.filter(func(spot: Dictionary) -> bool: return spot["day"] == number and spot["band"] == band))
		for g: int in day_groups.size():
			if placed[g] != band:
				continue
			var group: Array = day_groups[g]
			if group.size() == 1:
				cards_box.add_child(_card(group[0], cards[group[0]], selected, number, g, section, band))
			else:
				cards_box.add_child(_alternatives(group, cards, selected, number, g, section, band))
		if first < 0:
			var empty := LabUI.label("drop here", 11, Color(LabUI.DIM, 0.6))
			empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			empty.clip_text = true
			cards_box.add_child(empty)
		list.add_child(section)
	list.add_child(_closing(number, day))
	var add := LabUI.button("+  Errand", func() -> void: add_requested.emit(number), &"FlatButton")
	add.tooltip_text = "Add an errand at the end of day %d" % number
	box.add_child(add)
	return column


# A band's drop target, holding its title; its cards go into its child VBoxContainer. [param first] is
# its first errand's path, "" when it has none.
func _band(number: int, band: Band, first: String) -> PanelContainer:
	var section := PanelContainer.new()
	section.name = BAND_NAMES[band].to_pascal_case()
	section.add_theme_stylebox_override("panel", _band_style(false))
	section.set_drag_forwarding(Callable(), _can_drop_band.bind(section, band, first), _drop_band.bind(number, band))
	if first == "" and band in [Band.MIDDAY, Band.AFTERNOON]:
		section.tooltip_text = "No customer comes in at %s, so no sign can start then: a sign starts with a customer's drop-off." % BAND_NAMES[band].to_lower()
	var cards_box := VBoxContainer.new()
	cards_box.add_theme_constant_override("separation", 6)
	section.add_child(cards_box)
	cards_box.add_child(LabUI.label(BAND_NAMES[band], 11, LabUI.DIM))
	return section


# At closing: the day's on close flags and close signs. It takes only signs: no errand comes then.
func _closing(number: int, day: Day) -> Control:
	var section := PanelContainer.new()
	section.name = "AtClosing"
	section.mouse_filter = Control.MOUSE_FILTER_STOP
	section.add_theme_stylebox_override("panel", _band_style(false))
	section.set_drag_forwarding(Callable(), _can_drop_band.bind(section, Band.AT_CLOSING, ""), _drop_band.bind(number, Band.AT_CLOSING))
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 2)
	section.add_child(lines)
	lines.add_child(LabUI.label(BAND_NAMES[Band.AT_CLOSING], 11, LabUI.DIM))
	var chips := _spots.filter(func(spot: Dictionary) -> bool: return spot["day"] == number and spot["band"] == Band.AT_CLOSING)
	_add_chips(lines, chips)
	var words := closing_words(day)
	if words.is_empty() and chips.is_empty():
		words.append("Nothing happens")
	for line: String in words:
		var label := LabUI.label(line, 12, LabUI.CHANGED if line != "Nothing happens" else Color(LabUI.DIM, 0.6))
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = 40
		lines.add_child(label)
	section.tooltip_text = "Edit them in the day: click its header. Drop a sign here to start it at closing."
	return section


# The chips of [param spots], one per line, at the end of [param into].
func _add_chips(into: Control, spots: Array) -> void:
	for spot: Dictionary in spots:
		into.add_child(_sign_chip(spot))


# The chip of a sign's start: a click opens the sign, a drag moves the start unless it is locked.
func _sign_chip(spot: Dictionary) -> Control:
	var id: StringName = spot["id"]
	var start: Dictionary = spot["start"]
	var title := _sign_titles.get(id, "") as String
	var text := title if title != "" else StoryFactPicker.humanize(id)
	if start["value"] == 0:
		text = "Stops: " + text
	elif start["value"] > 1:
		text += " (stage %d)" % start["value"]
	if start["detail"] == "close signs":
		text = "Until morning: " + text
	elif String(start["detail"]).contains(" > "):
		text = "If picked: " + text
	var chip := _sign_chip_box(text, 11, 0)
	chip.name = "Sign_" + id
	chip.tooltip_text = "%s (%s)\n%s\n" % [text, id, start["text"]]
	if spot["locked"]:
		var frame := LabUI.box(Color(SIGN_COLOR, 0.0), 6, 1)
		frame.border_color = Color(SIGN_COLOR, 0.6)
		frame.set_border_width_all(1)
		chip.add_theme_stylebox_override("panel", frame)
		chip.tooltip_text += "It comes with the problem's mechanics (problems/%s.tres), so it doesn't move here. Click to open it in Signs." % start["problem"]
	else:
		chip.tooltip_text += "Click to open it in Signs; drag it to start it somewhere else."
		chip.mouse_filter = Control.MOUSE_FILTER_PASS
		chip.mouse_default_cursor_shape = Control.CURSOR_DRAG
		chip.set_drag_forwarding(_sign_drag.bind(chip, id, start, title), Callable(), Callable())
	chip.gui_input.connect(func(event: InputEvent) -> void:
		var click := event as InputEventMouseButton
		if click != null and click.button_index == MOUSE_BUTTON_LEFT:
			chip.accept_event()
			if not click.pressed:
				sign_picked.emit(id))
	return chip


func _band_style(hint: bool) -> StyleBoxFlat:
	var style := LabUI.box(Color(LabUI.HOVER, 0.5) if hint else Color(LabUI.FIELD, 0.5), 6, 3)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.border_color = LabUI.ACCENT
	style.set_border_width_all(2 if hint else 0)
	return style


func _header(number: int, day: Day, drafted: bool) -> Control:
	var head := PanelContainer.new()
	head.add_theme_stylebox_override("panel", LabUI.box(LabUI.RAISED, 8, 3))
	head.mouse_filter = Control.MOUSE_FILTER_STOP
	head.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	head.tooltip_text = "Day %d: weather, warp, flags, signs and notes" % number
	head.gui_input.connect(func(event: InputEvent) -> void:
		var click := event as InputEventMouseButton
		if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			day_picked.emit(number))
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 4)
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(rows)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_child(top)
	var title := LabUI.label("Day %d" % number, 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	if drafted:
		top.add_child(LabUI.chip("draft", LabUI.CHANGED, 11))
	top.add_child(_weather_icon(day != null and day.rain))
	var warp := day.warp if day != null else 0.0
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(0, 6)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.draw.connect(func() -> void:
		bar.draw_rect(Rect2(Vector2.ZERO, bar.size), LabUI.FIELD)
		bar.draw_rect(Rect2(Vector2.ZERO, Vector2(bar.size.x * warp, bar.size.y)), Color("b05cff").lerp(LabUI.BAD, warp)))
	var warp_row := HBoxContainer.new()
	warp_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var warp_label := LabUI.label("warp %s" % snappedf(warp, 0.01), 12, LabUI.DIM)
	warp_row.add_child(warp_label)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	warp_row.add_child(bar)
	rows.add_child(warp_row)
	return head


# A sun, or a cloud with rain.
func _weather_icon(rain: bool) -> Control:
	var icon := Control.new()
	icon.custom_minimum_size = Vector2(24, 22)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.draw.connect(func() -> void:
		var c := Vector2(12, 10)
		if not rain:
			for i: int in 8:
				var a := TAU * i / 8.0
				icon.draw_line(c + Vector2.from_angle(a) * 7.0, c + Vector2.from_angle(a) * 10.0, Color("ffd166"), 2.0, true)
			icon.draw_circle(c, 5.0, Color("ffd166"))
			return
		var cloud := Color("aab3c5")
		icon.draw_circle(Vector2(8, 9), 5.0, cloud)
		icon.draw_circle(Vector2(14, 7), 6.0, cloud)
		icon.draw_rect(Rect2(4, 9, 16, 4), cloud)
		for x: float in [7.0, 12.0, 17.0]:
			icon.draw_line(Vector2(x, 15), Vector2(x - 2, 21), Color("5aa9ff"), 2.0, true))
	icon.tooltip_text = "Rain" if rain else "Clear"
	return icon


func _alternatives(group: Array, cards: Dictionary, selected: String, day: int, index: int, section: PanelContainer, band: Band) -> Control:
	var frame := PanelContainer.new()
	var empty := StyleBoxEmpty.new()
	empty.set_content_margin_all(6)
	frame.add_theme_stylebox_override("panel", empty)
	frame.draw.connect(func() -> void:
		var r := Rect2(Vector2(1, 1), frame.size - Vector2(2, 2))
		var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
		for i: int in 4:
			frame.draw_dashed_line(corners[i], corners[(i + 1) % 4], LabUI.DIM, 1.5, 6.0))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	frame.add_child(box)
	box.add_child(LabUI.label("%s: the first that matches comes" % StoryLabBoard.code_of(group[0]), 11, LabUI.DIM))
	for path: String in group:
		box.add_child(_card(path, cards[path], selected, day, index, section, band))
	return frame


func _card(path: String, info: Dictionary, selected: String, day: int, index: int, section: PanelContainer, band: Band) -> Control:
	var errand: Errand = info["errand"]
	var problems: PackedStringArray = info["problems"]
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _card_style(path == selected, ""))
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.tooltip_text = "%s\nDouble-click to open it full. Drag to another day, place or time of day, or onto a card to make an alternative." % path.get_file()
	card.gui_input.connect(func(event: InputEvent) -> void:
		var click := event as InputEventMouseButton
		if click == null or click.button_index != MOUSE_BUTTON_LEFT:
			return
		if click.pressed:
			_double_click = click.double_click
		# On release: picking rebuilds the board, which frees the card before a drag can start.
		elif _double_click:
			_double_click = false
			errand_double_clicked.emit(path)
		else:
			errand_picked.emit(path))
	card.set_drag_forwarding(_drag.bind(path, errand), _can_drop.bind(card, section), _drop.bind(card, day, index, band, path))
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 4)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(stack)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(row)
	_add_chips(stack, _spots.filter(func(spot: Dictionary) -> bool: return spot["errand"] == path))
	row.add_child(portrait(errand.customer, PORTRAIT_SIZE))
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 0)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	var name_label := LabUI.label(errand.customer.spoken_name() if errand.customer != null else path.get_file().get_basename().substr(5), 15)
	name_label.clip_text = true
	text.add_child(name_label)
	var what := "no repair" if errand.problem == null else String(errand.problem.short_name)
	if errand.brings == Errand.Brings.NOTHING:
		what += ", no computer"
	elif errand.brings == Errand.Brings.SHOWS:
		what += ", shows it"
	var what_label := LabUI.label(what, 12, LabUI.DIM)
	what_label.clip_text = true
	text.add_child(what_label)
	if errand.when != null:
		var when_label := LabUI.label("if " + StoryFormat.write_condition(errand.when), 11, LabUI.PLAYER)
		when_label.clip_text = true
		text.add_child(when_label)
	var side := VBoxContainer.new()
	side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side.add_theme_constant_override("separation", 2)
	row.add_child(side)
	var code_row := HBoxContainer.new()
	code_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	code_row.add_theme_constant_override("separation", 4)
	side.add_child(code_row)
	if info.get("draft", false):
		var dot := LabUI.chip("draft", LabUI.CHANGED, 10)
		dot.tooltip_text = "Edited: a draft that main doesn't have yet"
		dot.mouse_filter = Control.MOUSE_FILTER_PASS
		code_row.add_child(dot)
	code_row.add_child(LabUI.label(errand.code, 11, LabUI.DIM))
	side.add_child(_status_dots(errand))
	if not problems.is_empty():
		var badge := LabUI.chip("! %d" % problems.size(), LabUI.BAD, 11)
		badge.tooltip_text = "\n".join(problems)
		badge.mouse_filter = Control.MOUSE_FILTER_PASS
		badge.size_flags_horizontal = Control.SIZE_SHRINK_END
		side.add_child(badge)
	return card


## A square thumbnail of [param customer]'s face (or else portrait), or a grey square without one.
static func portrait(customer: Customer, edge: int) -> Control:
	var picture := TextureRect.new()
	picture.custom_minimum_size = Vector2(edge, edge)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var person := customer.person if customer != null else null
	if person != null and person.face != null:
		picture.texture = person.face
		return picture
	if person != null and not person.portraits.is_empty():
		picture.texture = person.portraits.get(&"neutral", person.portraits.values()[0])
		return picture
	var blank := ColorRect.new()
	blank.color = LabUI.RAISED
	blank.custom_minimum_size = picture.custom_minimum_size
	blank.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.free()
	return blank


# Two dots: the brief written, and the drop-off empty, brief only or written.
func _status_dots(errand: Errand) -> Control:
	var dots := Control.new()
	dots.custom_minimum_size = Vector2(30, 14)
	dots.mouse_filter = Control.MOUSE_FILTER_PASS
	var drop_off := drop_off_state(errand)
	dots.tooltip_text = "Brief: %s\nDrop-off: %s" % ["written" if errand.brief != "" else "not yet", ["missing", "brief only", "written"][drop_off]]
	dots.draw.connect(func() -> void:
		_dot(dots, Vector2(7, 7), 1.0 if errand.brief != "" else 0.0)
		_dot(dots, Vector2(23, 7), drop_off / 2.0))
	return dots


## How far the errand's first drop-off is written: 0 there is none, 1 it has only a brief, 2 it
## has lines.
static func drop_off_state(errand: Errand) -> int:
	for c: Conversation in errand.conversations:
		if c.trigger == Conversation.Trigger.ARRIVE:
			return 2 if not c.lines.is_empty() or not c.choices.is_empty() else 1
	return 0


func _dot(on: Control, center: Vector2, fill: float) -> void:
	var color := LabUI.GOOD if fill >= 1.0 else (LabUI.CHANGED if fill > 0.0 else LabUI.DIM)
	on.draw_arc(center, 5.0, 0.0, TAU, 20, color, 1.5, true)
	if fill >= 1.0:
		on.draw_circle(center, 4.0, color)
	elif fill > 0.0:
		on.draw_colored_polygon(_half_disc(center, 4.0), color)


func _half_disc(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i: int in 13:
		points.append(center + Vector2.from_angle(PI * 0.5 + PI * i / 12.0) * radius)
	return points


func _card_style(selected: bool, hint: String) -> StyleBoxFlat:
	var style := LabUI.box(LabUI.RAISED, 8, 3)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.border_color = LabUI.ACCENT if selected or hint != "" else LabUI.LINE
	style.set_border_width_all(2 if selected else 1)
	match hint:
		"before":
			style.set_border_width_all(0)
			style.border_width_top = 4
		"after":
			style.set_border_width_all(0)
			style.border_width_bottom = 4
		"alternative":
			style.set_border_width_all(3)
	return style


func _drag(_at: Vector2, path: String, errand: Errand) -> Variant:
	var preview := LabUI.chip(errand.customer.spoken_name() if errand.customer != null else path.get_file(), LabUI.TEXT, 15)
	preview.add_theme_stylebox_override("normal", LabUI.box(LabUI.HOVER, 8, 4))
	set_drag_preview(preview)
	return {"story_errand": path}


func _zone(card: Control, at: Vector2) -> String:
	var share := at.y / maxf(card.size.y, 1.0)
	return "before" if share < 0.3 else ("after" if share > 0.7 else "alternative")


# A customer dropped on a card goes into the card's band; a sign starts with the card's drop-off.
func _can_drop(at: Vector2, data: Variant, card: PanelContainer, section: PanelContainer) -> bool:
	if not _dragged(data):
		return false
	if data.has("story_customer"):
		return _can_drop_band(at, data, section, Band.MORNING, "")
	_hint(card, _card_style(false, "alternative" if data.has("story_sign") else _zone(card, at)))
	return true


func _drop(at: Vector2, data: Variant, card: PanelContainer, day: int, index: int, band: Band, path: String) -> void:
	_hint(null, null)
	if data.has("story_customer"):
		drop_in(data, day, band)
		return
	if data.has("story_sign"):
		sign_dropped.emit(data["story_sign"], data["from"], {"errand": path})
		return
	var zone := _zone(card, at)
	var place := index + (1 if zone == "after" else 0)
	errand_dropped.emit(data["story_errand"], day, place, zone == "alternative", band == Band.BEFORE_OPENING and place == 0)


# [param first] is the band's first errand's path, "" when it has none: Midday and Afternoon then
# refuse signs. At closing takes only signs.
func _can_drop_band(_at: Vector2, data: Variant, section: PanelContainer, band: Band, first: String) -> bool:
	if not _dragged(data):
		return false
	var is_sign: bool = data.has("story_sign")
	if band == Band.AT_CLOSING and not is_sign:
		return false
	if is_sign and first == "" and band in [Band.MIDDAY, Band.AFTERNOON]:
		return false
	_hint(section, _band_style(true))
	return true


func _drop_band(_at: Vector2, data: Variant, day: int, band: Band) -> void:
	drop_in(data, day, band)


## Drops [param data], a drag of the board ({"story_errand": path}), of [method customer_strip]
## ({"story_customer": name}) or of a sign ({"story_sign": id, "from": its start or {}}), into
## [param band] of day [param day] (1 to 7). An errand goes to the place that [method place_for]
## gives ([signal errand_dropped]), a customer makes an errand there ([signal customer_dropped]), and
## a sign starts as the day starts (Before opening, Morning), at closing, or with the drop-off of the
## band's first errand (Midday, Afternoon) ([signal sign_dropped]). A drop that the band refuses
## (an errand at closing, a sign in a band without errands) is an error.
func drop_in(data: Dictionary, day: int, band: Band) -> void:
	_hint(null, null)
	if data.has("story_sign"):
		var to := {}
		match band:
			Band.BEFORE_OPENING, Band.MORNING:
				to = {"day": day, "key": "on start"}
			Band.AT_CLOSING:
				to = {"day": day, "key": "close signs"}
			_:
				var placed := bands(_days[day - 1], _cards)
				if band not in placed:
					push_error("Story Lab: no customer comes at %s on day %d, so the sign %s can't start then" % [BAND_NAMES[band], day, data["story_sign"]])
					return
				to = {"errand": _days[day - 1][placed.find(band)][0]}
		sign_dropped.emit(data["story_sign"], data.get("from", {}), to)
		return
	if band == Band.AT_CLOSING:
		push_error("Story Lab: %s dropped at closing on day %d, where no errand comes" % [data, day])
		return
	var path: String = data.get("story_errand", "")
	var place := place_for(_days, _cards, day, band, path)
	if path != "":
		errand_dropped.emit(path, day, place, false, band == Band.BEFORE_OPENING)
	else:
		customer_dropped.emit(data["story_customer"], day, place, band == Band.BEFORE_OPENING)


func _can_drop_end(_at: Vector2, data: Variant) -> bool:
	_hint(null, null)
	return _dragged(data) and not data.has("story_sign")


func _drop_end(_at: Vector2, data: Variant, day: int, count: int) -> void:
	if data.has("story_customer"):
		customer_dropped.emit(data["story_customer"], day, count, false)
	else:
		errand_dropped.emit(data["story_errand"], day, count, false, false)


static func _dragged(data: Variant) -> bool:
	return data is Dictionary and (data.has("story_errand") or data.has("story_customer") or data.has("story_sign"))


# Shows [param style] on [param card] while a drop over it is possible; null puts it back.
func _hint(card: PanelContainer, style: StyleBox) -> void:
	if _hinted != null and is_instance_valid(_hinted) and _hinted != card:
		_hinted.add_theme_stylebox_override("panel", _hinted_style)
		_hinted = null
	if card == null:
		return
	if _hinted != card:
		_hinted = card
		_hinted_style = card.get_theme_stylebox("panel")
	card.add_theme_stylebox_override("panel", style)
