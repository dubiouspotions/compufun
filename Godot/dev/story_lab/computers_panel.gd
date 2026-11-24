class_name StoryComputersPanel
extends HBoxContainer
## The Story Lab's Computers: what each customer did on their computer (story/computers/, the setup
## patches, docs/dialogue.md). On the left each customer with a Win95 computer, the start of the
## game and their errands; on the right the picked patch as text and the mails of the computer as
## it then arrives, editable. Edit on bench boots that computer in the game to change it on the real
## Win95, and Save patch writes what differs. Every edit hands the new text up with [signal saved].

## [param text] is the new text of the patch file [param path]; "" removes it.
signal saved(path: String, text: String)
## [param setup], [param customer]'s computer as it arrives on [param errand] (null: at the start),
## is to be edited on the bench.
signal bench_requested(customer: Customer, errand: Errand, setup: Win95Setup)

const SETTLE_SECONDS: float = 0.4
const _MAIL_COLUMNS: PackedStringArray = ["Folder", "From", "To", "Subject", "Sent", "Read", "Change"]
## The Email field of each column but Change, in order.
const _FIELDS: PackedStringArray = ["folder", "from", "to", "subject", "sent", "read"]
const _NEW_ADDRESS: String = "New address..."
## The From and To choice that removes the address.
const _NO_ADDRESS: String = "(none)"
## The Read column's text for unread and read; a double-click flips it. (An unticked check box draws nothing in the Lab's theme.)
const _READ: PackedStringArray = ["unread", "read"]


var _week: StoryFiles.Week
var _drafts: StoryDrafts
var _customer: Customer
var _errand: Errand
var _path: String = ""
## The computer before the patch, and with it: Save patch compares the bench with [member _before].
## Email.Folder's names, lowercase, in its order: how the table shows a folder.
var _folder_names := PackedStringArray(Email.Folder.keys().map(func(k: String) -> String: return k.to_lower()))
# True while a mail's typed text waits for the pause that saves it.
var _mail_pending: bool = false
# True while a save reloads the week, which opens the patch again.
var _saving: bool = false
# True while a save from the table or the bench reloads the week, which opens the patch again.
var _saving_table: bool = false
var _before: Win95Setup
var _after: Win95Setup
## The running copy that Edit on bench gave the game, until Save patch reads it.
var _bench: Win95Setup
# The open patch as read from its text, which the mail table shows and edits; null while the text has errors.
var _table: SetupPatch
# The patch that Edit on bench was pressed on: Save patch writes there.
var _bench_path: String = ""
var _list: ItemList
var _title: Label
var _about: Label
var _save_bench: Button
var _code: CodeEdit
var _errors: ItemList
var _mails: Tree
var _body: TextEdit
var _settle: Timer


func _ready() -> void:
	_build()


## Lists the customers and their errands of [param week], with [param drafts] over the files, and
## opens the open patch again.
func show_computers(week: StoryFiles.Week, drafts: StoryDrafts) -> void:
	_week = week
	_drafts = drafts
	_fill()


## The res:// path of the open patch file, which may not exist yet.
func path() -> String:
	return _path


## Opens the patch of [param customer] for [param errand], or their start patch for null.
func open(customer: Customer, errand: Errand) -> void:
	var file_name := SetupPatch.errand_name(errand) if errand != null else SetupPatch.customer_name(customer)
	var was := _path
	if SetupPatch.DIR + file_name + SetupPatch.EXTENSION != was:
		_settle_now()  # another patch: save this one's waiting edit first; a reload of this one leaves it waiting
	_customer = customer
	_errand = errand
	_path = SetupPatch.DIR + file_name + SetupPatch.EXTENSION
	_title.text = "%s, %s" % [customer.spoken_name(), _stage_name(errand)]
	_about.text = ("What %s's computer is like as the game starts, on top of its .tres." if errand == null else
			"What %s did on their computer before this visit; the problem's break comes after.") % customer.spoken_name()
	if _path != was or _code.text != _drafts.text(_path):  # the week reloading our own save keeps the caret
		_code.text = _drafts.text(_path)
		_code.clear_undo_history()
		_mark(PackedStringArray())
	if not (_saving_table and _path == was):  # nor does it rebuild the mails that the table just saved
		_rebuild()
	_show_save_bench()
	for i: int in _list.item_count:
		if _item_path(i) == _path:
			_list.select(i)


## Writes what differs on the computer that Edit on bench put in the game as the open patch.
## Returns "" or why it can't.
func save_bench() -> String:
	if _bench == null:
		return _say("Edit on bench first.")
	if _path != _bench_path:  # another patch was picked since: the bench belongs to its own
		for i: int in _list.item_count:
			if _item_path(i) == _bench_path:
				var item: Array = _list.get_item_metadata(i)
				open(item[0], item[1])
				_list.select(i)
	if _path != _bench_path:
		return _say("Not saved: %s is gone from the week, so the bench has no patch to save to." % _bench_path.get_file())
	if Game.setups.get(_customer.computer) != _bench:
		_bench = null
		_show_save_bench()
		return _say("Not saved: the computer from Edit on bench is no longer the one in the game (Play here or a jump replaced it). Edit on bench again.")
	return _save_setup(_bench)


## The computer on the bench that [method save_bench] reads; for the Lab, which starts it.
func benched(setup: Win95Setup) -> void:
	_bench = setup
	_bench_path = _path
	_show_save_bench()


# Save patch names the bench's patch when another is open, as it saves there.
func _show_save_bench() -> void:
	_save_bench.disabled = _bench == null
	_save_bench.text = "Save patch" if _bench == null or _bench_path == _path else "Save patch to %s" % _bench_path.get_file().get_basename()


func _stage_name(errand: Errand) -> String:
	if errand == null:
		return "start of the game"
	return "day %d, %s" % [errand.day_number(), errand.file_name()]


# Builds the computer before and with the patch from the week, and shows its mails.
func _rebuild() -> void:
	_build_computer()
	var parsed := SetupPatch.parse(_drafts.text(_path), _path)
	_table = parsed.value if parsed.errors.is_empty() else null
	_show_mails()


# Builds the computer before and with the patch, from the week: what Save patch compares, and the
# addresses that From and To offer.
func _build_computer() -> void:
	var errands := _week.errands()
	_before = SetupPatch.arriving(_customer, _errand, false, errands, _week.patches)
	_after = SetupPatch.arriving(_customer, _errand, true, errands, _week.patches)


func _fill() -> void:
	_list.clear()
	for each: String in LabUI.resource_names(StoryFormat.CUSTOMERS_DIR):
		var customer := load(StoryFormat.CUSTOMERS_DIR + each + ".tres") as Customer
		if customer == null:
			push_error("Story Lab: %s%s.tres doesn't load as a Customer" % [StoryFormat.CUSTOMERS_DIR, each])
			continue
		if customer.computer == null or customer.computer.win95_setup == null:
			continue
		var stages: Array = [null]
		stages.append_array(_week.errands().filter(func(e: Errand) -> bool: return e.customer == customer))
		for stage: Variant in stages:
			var errand := stage as Errand
			var text := customer.spoken_name() if errand == null else "      " + _stage_name(errand)
			var file_name := SetupPatch.errand_name(errand) if errand != null else SetupPatch.customer_name(customer)
			var has_patch := _drafts.text(SetupPatch.DIR + file_name + SetupPatch.EXTENSION) != ""
			_list.add_item(text + ("   (patch)" if has_patch else ""))
			_list.set_item_metadata(_list.item_count - 1, [customer, errand])
			_list.set_item_custom_fg_color(_list.item_count - 1, LabUI.TEXT if has_patch else LabUI.DIM)
	var reopen := 0  # the open patch again, by path: a reloaded week has new Errand objects
	for i: int in _list.item_count:
		if _item_path(i) == _path:
			reopen = i
	if _list.item_count > 0:
		var item: Array = _list.get_item_metadata(reopen)
		open(item[0], item[1])


# The patch path of list item [param i].
func _item_path(i: int) -> String:
	var item: Array = _list.get_item_metadata(i)
	var errand := item[1] as Errand
	return SetupPatch.DIR + (SetupPatch.errand_name(errand) if errand != null else SetupPatch.customer_name(item[0])) + SetupPatch.EXTENSION


func _settle_now() -> void:
	if _settle != null and not _settle.is_stopped():
		_settle.stop()
		_on_settle()


# Saves the text when it parses.
func _save_text() -> void:
	if _path == "" or _code.text == _drafts.text(_path):
		return
	var text := _code.text if _code.text.strip_edges() != "" else ""
	var parsed := SetupPatch.parse(text, _path)
	_mark(parsed.errors)
	if parsed.errors.is_empty():
		saved.emit(_path, text)


# Saves the patch that makes the computer before this visit into the bench's [param after]: what
# differs, and the stored patch's reset, comments and lines that still hold. Returns "" or why not.
func _save_setup(after: Win95Setup) -> String:
	if _saving_table or _saving:
		return _say("Not saved: another save of this patch is still going on.")  # a programmer error: saves don't nest
	if _code.text != _drafts.text(_path):
		return _say("Not saved: the patch text above has changes that aren't saved yet, or errors (marked). Wait a moment or fix them, then try again.")
	var made: Variant = SetupPatch.between(_before, after)
	if made is String:
		return _say("Not saved: " + made)
	var patch: SetupPatch = made
	var stored := SetupPatch.parse(_drafts.text(_path), _path)
	if stored.errors.is_empty():
		patch.reset = _before != null and (stored.value as SetupPatch).reset
		SetupPatch.keep_holding(stored.value, patch, after)
	var text := _written(patch)
	var check := SetupPatch.parse(text, _path)
	var applied := SetupPatch.arriving(_customer, _errand, false, _week.errands(), _week.patches)
	(check.value as SetupPatch).apply(applied)
	var left: Variant = SetupPatch.between(applied, after)
	if not check.errors.is_empty() or not (left is SetupPatch and (left as SetupPatch).is_empty()):
		return _say("Not saved: the patch doesn't read back as the computer: %s" % (check.errors if not check.errors.is_empty() else (left as SetupPatch).write() if left is SetupPatch else left))
	_mark(PackedStringArray())
	if text != _drafts.text(_path) and not (stored.errors.is_empty() and text == _written(stored.value)):  # else it says the same: no draft
		_code.text = text
		_saving_table = false  # a bench save shows its mails: the reload rebuilds the table
		_saving = true
		saved.emit(_path, text)
		_saving = false
		_saving_table = false
	if not patch.left_out.is_empty():
		_say("Saved, but a patch can't hold these, so they are left out: " + "; ".join(patch.left_out))
	return ""


# [param patch] as the open patch's text: the stored text's comments first, as a save can't place them.
func _written(patch: SetupPatch) -> String:
	var comments := Array(_drafts.text(_path).split("\n")).filter(func(line: String) -> bool: return line.begins_with("#"))
	var body := "" if patch.is_empty() else patch.write()
	if comments.is_empty():
		return body
	return "\n".join(comments) + "\n" + ("\n" + body if body != "" else "")


func _say(text: String) -> String:
	_errors.clear()
	_errors.add_item(text)
	_errors.set_item_metadata(0, -1)
	_errors.visible = true
	return text


func _mark(errors: PackedStringArray) -> void:
	for line: int in _code.get_line_count():
		_code.set_line_background_color(line, Color.TRANSPARENT)
	_errors.clear()
	for error: String in errors:
		var rest := error.trim_prefix(_path + ":")
		var line := rest.get_slice(":", 0).to_int() - 1
		if line >= 0 and line < _code.get_line_count():
			_code.set_line_background_color(line, Color(LabUI.BAD, 0.22))
		_errors.add_item("line %d: %s" % [line + 1, rest.substr(rest.find(":") + 1).strip_edges()])
		_errors.set_item_metadata(_errors.item_count - 1, line)
	_errors.visible = not errors.is_empty()


# Shows the mails of the patch (mail and unmail lines), keeping the picked one picked.
func _show_mails() -> void:
	var picked := _mails.get_selected()
	var picked_mail: Email = picked.get_metadata(0) if picked != null else null
	_mails.clear()
	var root := _mails.create_item()
	var reselect: TreeItem
	if _table != null:
		for mail: Email in _table.mails + _table.unmailed:
			var row := _mails.create_item(root)
			row.set_metadata(0, mail)
			_show_row(row)
			if mail == picked_mail:
				reselect = row
	if reselect != null:
		reselect.select(0)
	_mail_selected()


# The text of [param column] of [param row]: a dropdown's choice, or the cell's text.
func _cell(row: TreeItem, column: int) -> String:
	if row.get_cell_mode(column) != TreeItem.CELL_MODE_RANGE:
		return row.get_text(column)
	return row.get_text(column).split(",")[int(row.get_range(column))]


# Takes the cells of [param row] into its mail, and saves; "New address..." opens the cell to type one.
func _edit_mail(row: TreeItem) -> void:
	var mail: Email = row.get_metadata(0)
	for column: int in [1, 2]:
		if _cell(row, column) == _NEW_ADDRESS:
			row.select(column)  # picking closes and refills the cells, so it opens after
			row.set_cell_mode(column, TreeItem.CELL_MODE_STRING)
			row.set_text(column, "")
			row.set_editable(column, true)
			_mails.edit_selected.call_deferred(true)
			return
	if _is_unmail(mail):
		mail.subject = row.get_text(3)
		mail.sent = row.get_text(4)
		_save_table.call_deferred()
		return
	var hers := _hers(mail)
	var shown := func(field: String) -> Variant: return (hers if hers != null and not _sets(mail, field) else mail).get(field)
	var values := {
		"folder": _folder_names.find(_cell(row, 0)), "from": _address(row, 1, shown.call("from")), "to": _address(row, 2, shown.call("to")),
		"subject": row.get_text(3), "sent": row.get_text(4), "read": row.get_text(5) == _READ[1],
	}
	for field: String in _FIELDS:
		if values[field] != shown.call(field):  # only what the cell changed: the rest stays as the patch has it
			_set_field(mail, field, values[field])
	_save_table.call_deferred()  # the save reloads the week, which the Tree refuses inside its own signal


# The address in [param column] of [param row]: "(none)" picked removes it; a new address left
# without typing one keeps [param was], as leaving the cell is a cancel.
func _address(row: TreeItem, column: int, was: String) -> String:
	var text := _cell(row, column)
	if text == _NO_ADDRESS:
		return ""
	return text if text.strip_edges() != "" else was


# Writes the table's patch as the open patch, with the stored text's comments. Refused (the patch text
# has unsaved edits or errors), the table goes back to the stored patch. Returns "" or why not.
func _save_table() -> String:
	var refused := ""
	if _table == null:
		refused = "Not saved: the patch text above has errors (marked). Fix them, and the table shows its mails."
	elif _code.text != _drafts.text(_path):
		refused = "Not saved: the patch text above has changes that aren't saved yet, or errors (marked). Wait a moment or fix them, then try again."
	var text := _written(_table) if refused == "" else ""
	if refused == "" and not SetupPatch.parse(text, _path).errors.is_empty():
		refused = "Not saved: the table's patch doesn't read back: %s" % SetupPatch.parse(text, _path).errors
	if refused != "":
		_rebuild()
		return _say(refused)
	_mark(PackedStringArray())
	if text != _drafts.text(_path):
		_code.text = text
		_saving_table = true
		_saving = true
		saved.emit(_path, text)
		_saving = false
		_saving_table = false
		_build_computer()  # the reload kept the table; the computer has the new patch now
	_show_mails()
	return ""


func _is_unmail(mail: Email) -> bool:
	return _table != null and mail in _table.unmailed


# A click picks a mail; a double-click or Enter edits the picked cell, so picking never opens an
# editor by accident. Folder, From and To become dropdowns while edited; an address with a comma,
# which a dropdown can't hold, is typed instead. The table is rebuilt after each edit.
func _edit_cell() -> void:
	var row := _mails.get_selected()
	if row == null:
		return
	var mouse := _mails.get_local_mouse_position()
	var column := _mails.get_column_at_position(mouse) if _mails.get_item_at_position(mouse) == row else _mails.get_selected_column()
	if column < 0:
		column = 3  # Enter with no cell picked: the subject
	if column == 6:
		return  # Change says what the line does; it follows from the mail
	if _is_unmail(row.get_metadata(0)) and column not in [3, 4]:
		_say("An unmail line has only the sent and subject of the mail it deletes.")
		return
	row.select(column)
	if column == 5:
		row.set_text(5, _READ[int(row.get_text(5) != _READ[1])])
		_edit_mail(row)
		return
	var current := row.get_text(column)
	var options: Array = []
	if column == 0:
		options = Array(_folder_names)
	elif column in [1, 2] and not current.contains(","):
		options = Array(_after.addresses()).filter(func(a: String) -> bool: return not a.contains(","))
		options.push_front(_NO_ADDRESS)
		if current == "":
			current = _NO_ADDRESS
		options.append(_NEW_ADDRESS)
	if not options.is_empty():
		row.set_cell_mode(column, TreeItem.CELL_MODE_RANGE)
		row.set_text(column, ",".join(options))
		row.set_range(column, options.find(current))
	row.set_editable(column, true)
	_mails.edit_selected(true)


# Closes every cell: only a double-clicked one opens (_edit_cell). On every pick and every click,
# so a cell left open by Esc doesn't edit on the next click.
func _close_cells() -> void:
	for each: TreeItem in _mails.get_root().get_children():
		for column: int in _MAIL_COLUMNS.size():
			each.set_editable(column, false)
			if each.get_cell_mode(column) != TreeItem.CELL_MODE_STRING:
				each.set_cell_mode(column, TreeItem.CELL_MODE_STRING)  # a closed dropdown draws nothing
		_show_row(each)  # a cell left mid-edit (Esc) shows its mail again


# Shows [param row]'s mail in its cells, as text; an unmail line deletes the mail of that sent and
# subject, so it shows only those.
func _show_row(row: TreeItem) -> void:
	var mail: Email = row.get_metadata(0)
	if _is_unmail(mail):
		var gone := ["deletes", "", "", mail.subject, mail.sent, "", "deletes her mail"]
		for column: int in gone.size():
			row.set_text(column, gone[column])
		return
	var hers := _hers(mail)
	for column: int in _FIELDS.size():
		var field := _FIELDS[column]
		var kept := hers != null and not _sets(mail, field)  # her mail's own value: the patch leaves it
		var value: Variant = (hers if kept else mail).get(field)
		row.set_text(column, _folder_names[value] if field == "folder" else _READ[int(value)] if field == "read" else str(value))
		row.set_custom_color(column, LabUI.DIM if kept else LabUI.TEXT)
		row.set_tooltip_text(column, "Her mail's own; the patch leaves it." if kept else "")
	row.set_text(6, "changes her mail" if hers != null else "new")
	row.set_tooltip_text(6, "Her mail of this sent and subject is on the computer: the patch sets the bright fields, the dim ones stay hers." if hers != null else "A new mail on the computer.")


# The mail on the computer before this visit that [param mail] changes (the same sent and subject),
# or null for a new mail.
func _hers(mail: Email) -> Email:
	if _before == null:
		return null
	for each: Email in _before.emails:
		if each.sent == mail.sent and each.subject == mail.subject:
			return each
	return null


# True when the patch sets [param field] of [param mail]: every field of a mail it writes whole.
func _sets(mail: Email, field: String) -> bool:
	var key := "%s %s" % [mail.sent, mail.subject]
	return not _table.mail_given.has(key) or field in _table.mail_given[key] or field in ["sent", "subject"]


# Sets [param field] of the patch's [param mail] to [param value], recording that the patch sets it.
# A new sent or subject on a mail that changes hers makes it a new mail and deletes hers, as the two
# say which mail it is.
func _set_field(mail: Email, field: String, value: Variant) -> void:
	var hers := _hers(mail)
	var key := "%s %s" % [mail.sent, mail.subject]
	if hers != null and field in ["sent", "subject"] and value != mail.get(field):
		var gone := Email.new()
		gone.sent = mail.sent
		gone.subject = mail.subject
		_table.unmailed.append(gone)
		for other: String in _FIELDS + PackedStringArray(["body"]):
			if not _sets(mail, other):
				mail.set(other, hers.get(other))
		_table.mail_given.erase(key)
		mail.set(field, value)
		return
	if mail.get(field) == value and _sets(mail, field):
		return
	mail.set(field, value)
	var new_key := "%s %s" % [mail.sent, mail.subject]
	if _table.mail_given.has(key):
		var given := _table.mail_given[key]
		_table.mail_given.erase(key)
		if field not in given:
			given.append(field)
		_table.mail_given[new_key] = given


func _mail_selected() -> void:
	var row := _mails.get_selected()
	_close_cells()
	_body.placeholder_text = "This mail has no text yet: type it here." if row != null else "Pick a mail to edit its text."
	_body.editable = row != null and not _is_unmail(row.get_metadata(0))
	var picked: Email = row.get_metadata(0) if row != null else null
	var hers := _hers(picked) if picked != null and not _is_unmail(picked) else null
	var inherited := hers != null and not _sets(picked, "body")
	_body.add_theme_color_override("font_color", LabUI.DIM if inherited else LabUI.TEXT)  # her own text, dim like her fields
	var text := (hers.body if inherited else picked.body) if picked != null else ""
	if _body.text != text:
		_body.text = text


func _body_changed() -> void:
	var row := _mails.get_selected()
	if row != null and not _is_unmail(row.get_metadata(0)):
		var mail: Email = row.get_metadata(0)
		var hers := _hers(mail)
		if hers != null and not _sets(mail, "body") and _body.text == hers.body:
			return  # her text, shown as the mail is picked: nothing changed
		_set_field(mail, "body", _body.text)
		_body.add_theme_color_override("font_color", LabUI.TEXT)
		_mail_pending = true
		_settle.start()


func _add_mail() -> void:
	if _after == null or _table == null:
		_say("Pick a computer's patch on the left first, with no errors in its text.")
		return
	var mail := Email.new()
	var date: Dictionary = Game.date_of(_errand.day_number() if _errand != null else 1)
	mail.sent = "%04d-%02d-%02d 09:00" % [date.year, date.month, date.day]
	var taken := (_after.emails + _table.mails).map(func(m: Email) -> String: return "%s %s" % [m.sent, m.subject])
	var number := _after.emails.size() + 1
	while "%s New mail %d" % [mail.sent, number] in taken:  # a patch tells mails apart by sent and subject
		number += 1
	mail.subject = "New mail %d" % number
	mail.to = _after.own_address()
	for address: String in _after.addresses():
		if address != mail.to:
			mail.from = address
			break
	_table.mails.append(mail)
	if _save_table() == "":
		for row: TreeItem in _mails.get_root().get_children():
			if row.get_metadata(0) == mail:
				row.select(3)
		_mail_selected()


## Takes the picked mail out of the patch: a mail line, or an unmail line.
func _delete_mail() -> void:
	var row := _mails.get_selected()
	if row == null:
		_say("Pick the mail to delete first: click it in the table.")
		return
	var mail: Email = row.get_metadata(0)
	_table.mails.erase(mail)
	_table.unmailed.erase(mail)
	_save_table()


# Saves what the pause was waiting for: the mail text typed, or the patch text.
func _on_settle() -> void:
	if _mail_pending:
		_mail_pending = false
		_save_table()
	else:
		_save_text()


func _build() -> void:
	add_theme_constant_override("separation", 14)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_settle = Timer.new()
	_settle.one_shot = true
	_settle.wait_time = SETTLE_SECONDS
	_settle.timeout.connect(_on_settle)
	add_child(_settle)
	var left := PanelContainer.new()
	left.custom_minimum_size.x = 360
	add_child(left)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	left.add_child(column)
	column.add_child(LabUI.label("Computers", 22))
	var about := LabUI.label("What the customers did on their computers: at the start of the game, and before each visit.", 13, LabUI.DIM)
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(about)
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(func(index: int) -> void:
		var picked: Array = _list.get_item_metadata(index)
		open(picked[0], picked[1]))
	column.add_child(_list)
	var right := PanelContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(right)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 8)
	right.add_child(page)
	_title = LabUI.label("", 18)
	page.add_child(_title)
	_about = LabUI.label("", 13, LabUI.DIM)
	_about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(_about)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	page.add_child(buttons)
	buttons.add_child(LabUI.button("Edit on bench", func() -> void:
		_settle_now()
		var setup := SetupPatch.arriving(_customer, _errand, true, _week.errands(), _week.patches)
		bench_requested.emit(_customer, _errand, setup)))
	_save_bench = LabUI.button("Save patch", save_bench)
	_save_bench.tooltip_text = "Writes what differs on the computer from Edit on bench as this patch."
	_save_bench.disabled = true
	buttons.add_child(_save_bench)
	var split := VSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(split)
	_code = CodeEdit.new()
	_code.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_code.gutters_draw_line_numbers = true
	_code.indent_use_spaces = false
	_code.indent_size = 4
	_code.placeholder_text = "No patch: the computer comes as the visit before left it. Edit on bench, or write it here."
	_code.text_changed.connect(func() -> void: _settle.start())
	split.add_child(_code)
	var mail_box := VBoxContainer.new()
	mail_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(mail_box)
	var mail_row := HBoxContainer.new()
	mail_row.add_theme_constant_override("separation", 8)
	mail_box.add_child(mail_row)
	mail_row.add_child(LabUI.label("Mails in this patch", 15))
	mail_row.add_child(LabUI.button("Add mail", _add_mail))
	mail_row.add_child(LabUI.button("Delete mail", _delete_mail))
	mail_row.add_child(LabUI.label("Click a mail to edit its text below; double-click a cell to change it. A mail with the sent and subject of one she has replaces it.", 13, LabUI.DIM))
	_mails = Tree.new()
	_mails.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_mails.custom_minimum_size.y = 160
	_mails.hide_root = true
	_mails.select_mode = Tree.SELECT_ROW  # a click picks the whole mail
	_mails.columns = _MAIL_COLUMNS.size()
	_mails.column_titles_visible = true
	for i: int in _MAIL_COLUMNS.size():
		_mails.set_column_title(i, _MAIL_COLUMNS[i])
		_mails.set_column_expand(i, i in [1, 2, 3])
		_mails.set_column_custom_minimum_width(i, [110, 0, 0, 0, 170, 60, 150][i])
	_mails.item_edited.connect(func() -> void: _edit_mail(_mails.get_edited()))
	_mails.item_selected.connect(_mail_selected)
	_mails.cell_selected.connect(_mail_selected)
	_mails.item_activated.connect(_edit_cell)
	_mails.item_mouse_selected.connect(func(_at: Vector2, _button: int) -> void: _close_cells())
	mail_box.add_child(_mails)
	_body = TextEdit.new()
	_body.custom_minimum_size.y = 100
	_body.placeholder_text = "Pick a mail to edit its text."
	_body.text_changed.connect(_body_changed)
	mail_box.add_child(_body)
	_errors = ItemList.new()
	_errors.custom_minimum_size.y = 70
	_errors.add_theme_color_override("font_color", LabUI.BAD)
	_errors.visible = false
	_errors.item_clicked.connect(func(index: int, _at: Vector2, _button: int) -> void:
		var line: int = _errors.get_item_metadata(index)
		if line >= 0:
			_code.set_caret_line(line)
			_code.grab_focus())
	page.add_child(_errors)
