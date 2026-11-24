extends "res://tests/test.gd"
## Microsoft Exchange on a customer's computer: Mark as Unread, Move to another folder, and a new
## message that Send puts in Sent Items, from the sender of the computer's sent mails, dated today.

const WIN95 := "res://win95/win95.tscn"  # loaded at run time: it names the Game autoload
const INBOX := "res://win95/inbox.tscn"


func run() -> void:
	var computer := Computer.new()
	computer.win95_setup = Win95Setup.new()
	var received := mail(Email.Folder.INBOX, "Kent <kent@modemlandia.se>", true)
	var sent := mail(Email.Folder.SENT, "Desk 4 <desk4@harbourimport.se>", true)
	computer.win95_setup.emails = [received, sent] as Array[Email]
	var customer := Customer.new()
	customer.computer = computer
	var job := Job.new(customer, Problem.new(), 0, 0)
	job.powered = true
	job.skips_boot = true
	var win95: Control = (load(WIN95) as PackedScene).instantiate()
	win95.get_node("ComputerState").job = job
	root.add_child(win95)
	await process_frame
	check("a boot that skips shows the desktop at once", [win95.get("pointer_visible"), job.skips_boot, win95.get("_boot")], [true, false, null])
	var desktop: Node = win95.get_node("Desktop")
	var setup: Win95Setup = win95.get_node("ComputerState").setup
	var inbox: Node = desktop.open(load(INBOX), false)
	await process_frame
	var copy := setup.emails[0]

	(inbox.get("_messages") as Control).set("selected", 0)
	inbox.call("_mark_selected_unread")
	check("Mark as Unread", copy.read, false)
	inbox.call("_move_selected")
	var menu: PopupMenu = inbox.get_children().filter(func(n: Node) -> bool: return n is PopupMenu).back()
	check("Move lists the other folders", range(menu.item_count).map(func(i: int) -> String: return menu.get_item_text(i)), ["Deleted Items", "Outbox", "Sent Items"])
	menu.id_pressed.emit(Email.Folder.TRASH)
	check("the picked folder takes it", copy.folder, Email.Folder.TRASH)

	inbox.call("new_message")
	await process_frame
	var window: Node = desktop.windows().back()
	window.get_node("%Body").text = "See you at noon."
	(window.find_child("ToEdit", true, false) as LineEdit).text = "Kent <kent@modemlandia.se>"
	(window.find_child("SubjectEdit", true, false) as LineEdit).text = "Lunch"
	var shown: Array = window.get_node("%Toolbar").get_children().filter(func(n: Node) -> bool: return n is CanvasItem and n.visible)
	check("a new message has only Send", shown.map(func(n: Node) -> String: return n.get("tooltip_text")), ["Send"])
	var send: Button = shown[0]
	send.pressed.emit()
	var new: Email = setup.emails.back()
	check("Send puts it in Sent Items, from the computer's sender", [new.folder, new.from, new.to, new.subject, new.body, new.read],
			[Email.Folder.SENT, sent.from, "Kent <kent@modemlandia.se>", "Lunch", "See you at noon.", true])
	check("dated today", new.sent.begins_with("1996-05-31 "), true)


func mail(folder: Email.Folder, from: String, read: bool) -> Email:
	var made := Email.new()
	made.folder = folder
	made.from = from
	made.subject = "Hello"
	made.sent = "1996-05-30 10:00" if folder == Email.Folder.INBOX else "1996-05-30 11:00"
	made.read = read
	return made
