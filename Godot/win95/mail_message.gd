extends "res://win95/window.gd"
## One message in Microsoft Exchange's message window: who sent it and when, the subject, and the
## text. Previous and Next step through its folder; Delete moves it to Deleted Items. A new message
## ([method compose]) has To, Subject and the text to fill in, and Send.

const _ICONS := "res://win95/theme/icons/"

var _email: Email
var _computer: ComputerState


func _ready() -> void:
	super()
	var body: TextEdit = %Body
	body.add_theme_stylebox_override(&"read_only", body.get_theme_stylebox(&"normal"))  # Exchange shows a received message black on white
	body.add_theme_color_override(&"font_readonly_color", body.get_theme_color(&"font_color"))
	var bar: MenuBar = %MenuBar
	AppBar.add_menu(bar, "File", [["Save As...", null], ["Move...", null], ["Delete", _delete], [], ["Print...", null], [], ["Close", close]])
	AppBar.add_menu(bar, "Edit", [["Copy", null], ["Select All", func() -> void: %Body.select_all()]])
	AppBar.add_menu(bar, "View", [["Previous", _step.bind(-1)], ["Next", _step.bind(1)]])
	AppBar.add_menu(bar, "Insert", [["File...", null], ["Message...", null]])
	AppBar.add_menu(bar, "Format", [["Font...", null], ["Paragraph...", null]])
	AppBar.add_menu(bar, "Tools", [["Address Book...", null], ["Options...", null]])
	AppBar.add_menu(bar, "Compose", [["Reply to Sender", null], ["Reply to All", null], ["Forward", null]])
	AppBar.add_menu(bar, "Help", [["Microsoft Exchange Help Topics", null]])
	var row: HBoxContainer = %Toolbar
	AppBar.add_button(row, load(_ICONS + "printer_16.png"), "Print")
	AppBar.add_button(row, load(_ICONS + "delete_16.png"), "Delete", _delete)
	AppBar.add_gap(row)
	AppBar.add_button(row, load(_ICONS + "reply_16.png"), "Reply to Sender")
	AppBar.add_button(row, load(_ICONS + "reply_all_16.png"), "Reply to All")
	AppBar.add_button(row, load(_ICONS + "forward_16.png"), "Forward")
	AppBar.add_gap(row)
	AppBar.add_button(row, load(_ICONS + "arrow_up_16.png"), "Previous", _step.bind(-1))
	AppBar.add_button(row, load(_ICONS + "arrow_down_16.png"), "Next", _step.bind(1))
	AppBar.add_gap(row)
	AppBar.add_button(row, load(_ICONS + "start_help_16.png"), "Help")


## Shows [param email], one of [param computer]'s emails.
func show_email(email: Email, computer: ComputerState) -> void:
	_email = email
	_computer = computer
	%TitleBar.title = "%s - Microsoft Exchange" % (email.subject if email.subject != "" else "(no subject)")
	%From.text = email.from
	var sent := Win95Time.parse(email.sent) if email.sent != "" else {}
	%Sent.text = "%s %s" % [Win95Time.long_date(sent), Win95Time.clock(sent)] if not sent.is_empty() else ""
	%To.text = email.to
	%Subject.text = email.subject
	%Body.text = email.body


## Opens the window as a new message from [param computer], to write and Send.
func compose(computer: ComputerState) -> void:
	_computer = computer
	%TitleBar.title = "New Message - Microsoft Exchange"
	for row: StringName in [&"FromLabel", &"From", &"SentLabel", &"Sent"]:
		(%To as Label).get_parent().get_node(NodePath(row)).hide()
	var fields: Array[LineEdit] = []
	for shown: Label in [%To, %Subject]:
		var field := LineEdit.new()
		field.name = shown.name + "Edit"
		field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		shown.add_sibling(field)
		shown.hide()
		fields.append(field)
	%Body.editable = true
	%Body.text = ""
	var send := AppBar.add_button(%Toolbar, load(_ICONS + "mail_unread_16.png"), "Send", func() -> void:
		if _computer != null:
			_computer.send_email(fields[0].text, fields[1].text, %Body.text)
		close())
	for other: Node in %Toolbar.get_children():
		if other != send and other is CanvasItem:
			(other as CanvasItem).hide()  # reading a mail's buttons: a new one has nothing to reply to
	fields[0].grab_focus.call_deferred()


func _delete() -> void:
	if _computer == null or _email == null:
		return
	if _email.folder == Email.Folder.TRASH:
		_computer.purge_email(_email)
	else:
		_computer.move_email(_email, Email.Folder.TRASH)
	close()


# Previous and Next go through the messages in the same folder, in the order that the list shows.
func _step(direction: int) -> void:
	if _computer == null or _email == null:
		return
	var folder := _computer.setup.emails.filter(func(e: Email) -> bool: return e.folder == _email.folder)
	var at := folder.find(_email) + direction
	if at >= 0 and at < folder.size():
		show_email(folder[at], _computer)
		_computer.mark_read(folder[at])
