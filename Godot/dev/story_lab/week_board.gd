class_name StoryLabBoard
extends HBoxContainer
## The Story Lab's week: a column per day with its weather and warp, and a card per errand in the
## order the customers come in. Alternatives (errands with one errand code) stack in one dashed
## card. Cards drag to another day or place, or onto a card to become its alternative.

## The writer clicked the card of the errand file [param path].
signal errand_picked(path: String)
## The writer clicked the header of day [param day], 1 to 7.
signal day_picked(day: int)
## The writer asked for a new errand at the end of day [param day].
signal add_requested(day: int)
## The writer dropped the errand file [param path] on day [param day] at place [param index] (0 is
## the first, in the order before the move), or with [param alternative] onto the errands at that
## place.
signal errand_dropped(path: String, day: int, index: int, alternative: bool)

const DAYS: int = 7
const PORTRAIT_SIZE: int = 44

var _hinted: PanelContainer
var _hinted_style: StyleBox


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
	var after: Array = days.duplicate(true)
	var from_day := code_of(path).substr(0, 2).to_int()
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
	var renames: Dictionary[String, String] = {}
	var taken: Dictionary[String, bool] = {}
	for d: int in ([from_day, day] if from_day != day else [day]):
		var numbered: Array = after[d - 1]
		for g: int in numbered.size():
			for old: String in numbered[g]:
				var dir := old.get_base_dir() + "/"
				var name := old.get_file().get_basename().substr(5)
				var new_path := "%s%02d%02d_%s.errand" % [dir, d, g + 1, name]
				var copy := 2
				while taken.has(new_path):
					new_path = "%s%02d%02d_%s_%d.errand" % [dir, d, g + 1, name, copy]
					copy += 1
				taken[new_path] = true
				if new_path != old:
					renames[old] = new_path
	return renames


## Shows [param days] (Day 1 to 7) with the errand files of [param cards]: path to
## {"errand": Errand, "problems": PackedStringArray (parse errors and missing links), "draft": bool}.
## [param selected] is the open errand's path, [param drafted_days] the days with a draft.
func show_week(days: Array[Day], cards: Dictionary, selected: String, drafted_days: Array[int]) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_hinted = null
	add_theme_constant_override("separation", 10)
	var day_groups := groups(PackedStringArray(cards.keys()))
	for d: int in DAYS:
		var day: Day = days[d] if d < days.size() else null
		add_child(_column(d + 1, day, day_groups[d], cards, selected, (d + 1) in drafted_days))


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
	box.add_child(_header(number, day, drafted))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.set_drag_forwarding(Callable(), _can_drop_end, _drop_end.bind(number, day_groups.size()))
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	for g: int in day_groups.size():
		var group: Array = day_groups[g]
		if group.size() == 1:
			list.add_child(_card(group[0], cards[group[0]], selected, number, g))
		else:
			list.add_child(_alternatives(group, cards, selected, number, g))
	var add := LabUI.button("+  Errand", func() -> void: add_requested.emit(number), &"FlatButton")
	add.tooltip_text = "Add an errand at the end of day %d" % number
	box.add_child(add)
	return column


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


func _alternatives(group: Array, cards: Dictionary, selected: String, day: int, index: int) -> Control:
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
		box.add_child(_card(path, cards[path], selected, day, index))
	return frame


func _card(path: String, info: Dictionary, selected: String, day: int, index: int) -> Control:
	var errand: Errand = info["errand"]
	var problems: PackedStringArray = info["problems"]
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _card_style(path == selected, ""))
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.tooltip_text = "%s\nDrag to another day or place, or onto a card to make an alternative." % path.get_file()
	card.gui_input.connect(func(event: InputEvent) -> void:
		var click := event as InputEventMouseButton
		# On release: picking rebuilds the board, which frees the card before a drag can start.
		if click != null and not click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			errand_picked.emit(path))
	card.set_drag_forwarding(_drag.bind(path, errand), _can_drop.bind(card), _drop.bind(card, day, index))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)
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


func _can_drop(at: Vector2, data: Variant, card: PanelContainer) -> bool:
	if not (data is Dictionary and data.has("story_errand")):
		return false
	_hint(card, _card_style(false, _zone(card, at)))
	return true


func _drop(at: Vector2, data: Variant, card: PanelContainer, day: int, index: int) -> void:
	var zone := _zone(card, at)
	_hint(null, null)
	errand_dropped.emit(data["story_errand"], day, index + (1 if zone == "after" else 0), zone == "alternative")


func _can_drop_end(_at: Vector2, data: Variant) -> bool:
	_hint(null, null)
	return data is Dictionary and data.has("story_errand")


func _drop_end(_at: Vector2, data: Variant, day: int, count: int) -> void:
	errand_dropped.emit(data["story_errand"], day, count, false)


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
