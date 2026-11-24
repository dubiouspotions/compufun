extends "res://tests/test.gd"
## The Story Lab's Computers section (dev/story_lab/computers_panel.gd): a mail edited in the table
## and a file made on the bench (Game.edit_setup) become the errand's setup patch, a draft that the
## game plays: the office girl's computer then comes in with both.

const PATCH := "res://story/computers/0301_office_girl.setup"


func run() -> void:
	var drafts := StoryDrafts.new(user_dir() + "drafts/")
	drafts.git = func(_arguments: PackedStringArray) -> Dictionary: return {"code": 1, "out": ""}
	var lab: Control = (load("res://dev/story_lab/story_lab.tscn") as PackedScene).instantiate()
	lab.set("drafts", drafts)
	root.add_child(lab)
	await process_frame
	lab.call("show_section", "Computers")
	var panel: Control = lab.call("computers_panel")  # untyped: its script names the Game autoload
	var office_girl: Customer = load("res://customers/office_girl.tres")
	var errand: Errand
	for each: Errand in game.week.errands():
		if each.file_name() == "0301_office_girl":
			errand = each
	panel.call("open", office_girl, errand)
	check("the patch file is named after the errand", panel.call("path"), PATCH)
	var list: ItemList = panel.get("_list")
	check("the list picks it", list.get_item_text(list.get_selected_items()[0]).contains("0301_office_girl"), true)
	var mails: Tree = panel.get("_mails")
	var first := mails.get_root().get_first_child()
	check("the table lists her mails", first != null, true)
	check("with no patch yet, her mails show dim: on the computer already", first.get_custom_color(3), LabUI.DIM)
	panel.call("_edit_mail", first)
	await process_frame
	check("a cell left unchanged makes no draft", drafts.paths(), PackedStringArray())
	first = mails.get_root().get_first_child()  # the table was shown again
	first.select(1)
	check("a click picks the mail: its text shows, no cell opens", [(panel.get("_body") as TextEdit).text != "", first.is_editable(1)], [true, false])
	var was_read := first.get_text(5) == "read"
	first.select(5)
	panel.call("_edit_cell")  # a double-click
	await process_frame
	check("a double-click on Read flips it, as a draft: the mail, whole", [drafts.text(PATCH).begins_with("mail\n\tfolder:"), (panel.get("_after") as Win95Setup).emails[0].read], [true, not was_read])
	first = mails.get_root().get_first_child()
	check("the mail the patch now changes shows bright", first.get_custom_color(3) != LabUI.DIM, true)
	first.select(1)
	panel.call("_edit_cell")
	check("From edits as a dropdown of her addresses, and a new one", first.get_text(1).split(",")[-1], "New address...")
	var from_text: String = (first.get_metadata(0) as Email).from
	panel.call("_close_cells")  # Esc, then a click elsewhere
	check("a dropdown left without a pick is text again, showing the mail", [first.get_cell_mode(1), first.get_text(1)], [TreeItem.CELL_MODE_STRING, from_text])

	panel.call("_add_mail")
	var added: TreeItem = mails.get_selected()
	var setup_now: Win95Setup = panel.get("_after")
	check("Add mail picks a new mail to her, from someone she writes with", [added.get_text(3).begins_with("New mail"), added.get_text(2), added.get_text(1) not in ["", added.get_text(2)]], [true, setup_now.own_address(), true])
	added.select(1)
	panel.call("_edit_cell")
	added.set_range(1, Array(added.get_text(1).split(",")).find("New address..."))
	panel.call("_edit_mail", added)
	check("New address... opens the cell to type one", added.get_cell_mode(1), TreeItem.CELL_MODE_STRING)
	var kept: String = (added.get_metadata(0) as Email).from
	panel.call("_edit_mail", added)  # left without typing
	check("a new address left empty keeps the old one", (added.get_metadata(0) as Email).from, kept)
	await process_frame
	added = mails.get_root().get_children().back()
	added.select(1)
	panel.call("_edit_cell")
	added.set_range(1, Array(added.get_text(1).split(",")).find("New address..."))
	panel.call("_edit_mail", added)
	added.set_text(1, "Mom <mom@home.se>")
	panel.call("_edit_mail", added)
	await process_frame
	check("after the week reloads, the list still picks the open patch", list.get_item_text(list.get_selected_items()[0]).contains("0301_office_girl"), true)
	check("the typed address is saved and offered from then on", [drafts.text(PATCH).contains("from: Mom <mom@home.se>"), "Mom <mom@home.se>" in setup_now.addresses()], [true, true])
	check("the game plays it", game.story_errors, PackedStringArray())

	var code: CodeEdit = panel.get("_code")
	code.text = "# Her desk, Monday.\nset muted: false\n\n" + drafts.text(PATCH)
	panel.call("_save_text")
	await process_frame
	panel.call("_add_mail")
	await process_frame
	check("a table save keeps the comment and a line that holds", [drafts.text(PATCH).begins_with("# Her desk, Monday.\n"), drafts.text(PATCH).contains("set muted: false")], [true, true])
	panel.call("_add_mail")
	await process_frame
	var rows := mails.get_root().get_children()
	mails.deselect_all()
	panel.call("_delete_mail")
	check("Delete mail with none picked says so", (panel.get("_errors") as ItemList).get_item_text(0).begins_with("Pick the mail to delete"), true)
	rows[rows.size() - 2].select(0)
	panel.call("_delete_mail")
	await process_frame
	panel.call("_add_mail")
	await process_frame
	var errors: ItemList = panel.get("_errors")
	check("Add mail after a delete makes a mail of its own", [errors.item_count, mails.get_root().get_child_count()], [0, rows.size()])
	var saved_text := drafts.text(PATCH)
	code.text = saved_text + "set nonsense"
	panel.call("_add_mail")
	await process_frame
	check("with unsaved patch text, a table edit is refused and undone", [drafts.text(PATCH) == saved_text, code.text.ends_with("set nonsense"), mails.get_root().get_child_count(), errors.item_count], [true, true, rows.size(), 1])
	code.text = saved_text
	panel.call("_settle_now")

	var setup := SetupPatch.arriving(office_girl, errand, true, game.week.errands(), game.week.patches)
	check("Edit on bench puts her computer on the bench", lab.call("bench", office_girl, errand, setup), "")
	check("booted, connected, in the Screen View, running that copy", [game.connected != null, game.view, game.setups[office_girl.computer] == setup], [true, &"Screen", true])
	check("with no problem", game.connected.problem, null)
	check("its boot goes straight to the desktop", game.connected.skips_boot, true)
	var note := Win95File.new()
	note.name = "note.txt"
	note.contents = "Back at 2."
	setup.desktop.append(note)
	check("the bench counts only the visits up to this one as applied", ["0301_office_girl" in setup.patched, "0502_office_girl" in setup.patched], [true, false])
	for each: Errand in game.week.errands():
		if each.file_name() == "0502_office_girl":
			panel.call("open", office_girl, each)
	check("Save patch writes it, into the bench's own patch though another is open", [panel.call("save_bench"), panel.call("path")], ["", PATCH])
	check("the patch holds the file", drafts.text(PATCH).contains("file Desktop\\note.txt"), true)
	check("the game plays it", game.story_errors, PackedStringArray())

	game.setups.clear()
	var job := Job.new(office_girl, errand.problem, 0, 0)
	job.errand = errand
	var running: Win95Setup = game.setup_for(job)
	check("her computer comes in with the note", running.file_at("Desktop\\note.txt").contents, "Back at 2.")
	check("and the mail as the table left it, in its place", running.emails[0].read, not was_read)

	var start := SetupPatch.arriving(office_girl, null, true, game.week.errands(), game.week.patches)
	check("Edit on bench for the start of the game", lab.call("bench", office_girl, null, start), "")
	check("runs the start, with no visit's patch on it", [game.setups[office_girl.computer] == start, start.file_at("Desktop\\note.txt") == null], [true, true])
	lab.call("store", PATCH, drafts.text(PATCH) + "\nset left_handed: true\n")
	for each: Errand in game.week.errands():
		if each.file_name() == "0301_office_girl":
			errand = each
	check("Play here", game.play_errand(errand, Conversation.Trigger.PICKUP), "")
	check("makes her computer again, with the patch as it is now", game.setup_for(game.jobs[0]).left_handed, true)

	game.restore({"day": 1})  # its computer off the counter, so the week can lose the errand
	check("removing an errand", lab.call("store", "res://story/errands/0301_office_girl.errand", ""), "")
	check("removes its patch, so the week still plays", [drafts.text(PATCH), game.story_errors], ["", PackedStringArray()])
