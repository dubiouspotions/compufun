extends "res://win95/window.gd"
## Microsoft Exchange's viewer, as the desktop's Inbox opens it: the folder tree on the left, the
## messages of the selected folder on the right, unread ones bold. A double-click opens a message
## in its own window, which marks it read. Delete moves a message to Deleted Items, and deletes it
## for good from there. The emails are the computer's (Win95Setup.emails).

const _MESSAGE := preload("res://win95/mail_message.tscn")
const _ICONS := "res://win95/theme/icons/"

## The folders in the tree, in Exchange's order, under Microsoft Exchange and Personal Folders.
const _FOLDERS: Array[Email.Folder] = [Email.Folder.TRASH, Email.Folder.INBOX, Email.Folder.OUTBOX, Email.Folder.SENT]
const _FOLDER_NAMES := {
	Email.Folder.TRASH: "Deleted Items",
	Email.Folder.INBOX: "Inbox",
	Email.Folder.OUTBOX: "Outbox",
	Email.Folder.SENT: "Sent Items",
}

var _computer: ComputerState
var _folder: Email.Folder = Email.Folder.INBOX
var _shown: Array[Email] = []

@onready var _folders: FolderTree = %Folders
@onready var _messages: ReportList = %Messages


func _ready() -> void:
	super()
	var desktop := get_parent() as Win95Desktop
	_computer = desktop.computer if desktop != null else null
	if _computer == null:
		push_error("Inbox: not on a Win95Desktop with a computer, so there is no mail to show")
	else:
		_computer.changed.connect(_sync)
	_build_bars()
	var columns: Array[ReportList.Column] = [
		ReportList.Column.new("", 12, load(_ICONS + "mark_important_8.png")),
		ReportList.Column.new("", 18, load(_ICONS + "mark_mail_8.png")),
		ReportList.Column.new("", 14, load(_ICONS + "mark_clip_8.png")),
		ReportList.Column.new("From", 80),
		ReportList.Column.new("Subject", 116),
		ReportList.Column.new("Received", 90),
	]
	_messages.set_columns(columns)
	_messages.row_activated.connect(func(index: int) -> void: open_message(_shown[index]))
	_folders.item_selected.connect(func(index: int) -> void:
		if index >= 2:
			_folder = _FOLDERS[index - 2]
			_messages.selected = -1
			_sync())
	_sync()


## Opens [param email] in a message window and marks it read.
func open_message(email: Email) -> void:
	var desktop := get_parent() as Win95Desktop
	var window: Node = desktop.open(_MESSAGE, false)
	window.closed.connect(window.queue_free)
	window.show_email(email, _computer)
	if _computer != null:
		_computer.mark_read(email)


func _build_bars() -> void:
	var bar: MenuBar = %MenuBar
	var open_selected := func() -> void:
		if _messages.selected >= 0:
			open_message(_shown[_messages.selected])
	AppBar.add_menu(bar, "File", [["Open", open_selected], ["Move...", _move_selected], ["Delete", _delete_selected], [], ["Close", close]])
	AppBar.add_menu(bar, "Edit", [["Mark as Read", _mark_selected_read], ["Mark as Unread", _mark_selected_unread], ["Mark All as Read", _mark_all_read]])
	AppBar.add_menu(bar, "View", [["Folders", null], ["Columns...", null], ["Sort...", null]])
	AppBar.add_menu(bar, "Tools", [["Deliver Now", null], ["Address Book...", null], ["Options...", null]])
	AppBar.add_menu(bar, "Compose", [["New Message", new_message], [], ["Reply to Sender", null], ["Reply to All", null], ["Forward", null]])
	AppBar.add_menu(bar, "Help", [["Microsoft Exchange Help Topics", null], [], ["About Microsoft Exchange", null]])
	var row: HBoxContainer = %Toolbar
	AppBar.add_button(row, load(_ICONS + "folder_open_16.png"), "Up One Level")
	AppBar.add_button(row, load(_ICONS + "tree_16.png"), "Show/Hide Folder List", func() -> void: %FoldersField.visible = not %FoldersField.visible)
	AppBar.add_gap(row)
	AppBar.add_button(row, load(_ICONS + "mail_new_16.png"), "New Message", new_message)
	AppBar.add_gap(row)
	AppBar.add_button(row, load(_ICONS + "printer_16.png"), "Print")
	AppBar.add_button(row, load(_ICONS + "delete_16.png"), "Delete", _delete_selected)
	AppBar.add_gap(row)
	AppBar.add_button(row, load(_ICONS + "reply_16.png"), "Reply to Sender")
	AppBar.add_button(row, load(_ICONS + "reply_all_16.png"), "Reply to All")
	AppBar.add_button(row, load(_ICONS + "forward_16.png"), "Forward")
	AppBar.add_gap(row)
	AppBar.add_button(row, load(_ICONS + "inbox_16.png"), "Inbox", func() -> void:
		_folder = Email.Folder.INBOX
		_sync())
	AppBar.add_gap(row)
	AppBar.add_button(row, load(_ICONS + "start_help_16.png"), "Help")


func _delete_selected() -> void:
	if _computer == null or _messages.selected < 0:
		return
	var email := _shown[_messages.selected]
	if email.folder == Email.Folder.TRASH:
		_computer.purge_email(email)
	else:
		_computer.move_email(email, Email.Folder.TRASH)


func _mark_selected_read() -> void:
	if _computer != null and _messages.selected >= 0:
		_computer.mark_read(_shown[_messages.selected])


func _mark_selected_unread() -> void:
	if _computer != null and _messages.selected >= 0:
		_computer.mark_read(_shown[_messages.selected], false)


## Opens a new message to write, which Send puts in Sent Items.
func new_message() -> void:
	var desktop := get_parent() as Win95Desktop
	var window: Node = desktop.open(_MESSAGE, false)
	window.closed.connect(window.queue_free)
	window.compose(_computer)


# Lists the other folders under the mouse; the one picked takes the selected message.
func _move_selected() -> void:
	if _computer == null or _messages.selected < 0:
		return
	var email := _shown[_messages.selected]
	var menu := PopupMenu.new()
	for folder in _FOLDERS:
		if folder != email.folder:
			menu.add_item(_FOLDER_NAMES[folder], folder)
	menu.id_pressed.connect(func(id: int) -> void: _computer.move_email(email, id as Email.Folder))
	menu.popup_hide.connect(menu.queue_free)
	add_child(menu)
	menu.popup(Rect2i(Vector2i(get_global_mouse_position()), Vector2i.ZERO))


func _mark_all_read() -> void:
	for email: Email in _shown.duplicate():
		_computer.mark_read(email)


func _sync() -> void:
	var emails: Array[Email] = _computer.setup.emails if _computer != null and _computer.setup != null else ([] as Array[Email])
	_shown = emails.filter(func(e: Email) -> bool: return e.folder == _folder)
	var rows: Array[ReportList.Row] = []
	var unread := 0
	for email in _shown:
		if not email.read:
			unread += 1
		var received := Win95Time.parse(email.sent) if email.sent != "" else {}
		var when := "%s %s" % [Win95Time.short_date(received), Win95Time.clock(received)] if not received.is_empty() else ""
		var envelope := load(_ICONS + ("mail_read_16.png" if email.read else "mail_unread_16.png"))
		rows.append(ReportList.Row.new([null, envelope, null, email.sender_name(), email.subject, when], not email.read))
	_messages.set_rows(rows)
	var items: Array[FolderTree.Item] = [
		FolderTree.Item.new("Microsoft Exchange", load(_ICONS + "inbox_16.png"), 0),
		FolderTree.Item.new("Personal Folders", load(_ICONS + "personal_folders_16.png"), 1),
	]
	for folder in _FOLDERS:
		var has_unread := emails.any(func(e: Email) -> bool: return e.folder == folder and not e.read)
		var icon := "folder_open_16.png" if folder == _folder else "folder_closed_16.png"
		items.append(FolderTree.Item.new(_FOLDER_NAMES[folder], load(_ICONS + icon), 2, has_unread))
	_folders.set_items(items)
	_folders.selected = 2 + _FOLDERS.find(_folder)
	%TitleBar.title = "%s - Microsoft Exchange" % _FOLDER_NAMES[_folder]
	%Count.text = "%d Item%s%s" % [_shown.size(), "" if _shown.size() == 1 else "s", ", %d Unread" % unread if unread > 0 else ""]
