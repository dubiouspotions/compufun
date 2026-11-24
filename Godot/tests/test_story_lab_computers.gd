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
	first.select(1)
	panel.call("_edit_cell")
	check("From edits as a dropdown of her addresses, and a new one", first.get_text(1).split(",")[-1], "New address...")

	panel.call("_add_mail")
	var added: TreeItem = mails.get_selected()
	var setup_now: Win95Setup = panel.get("_after")
	check("Add mail picks a new mail to her, from someone she writes with", [added.get_text(3).begins_with("New mail"), added.get_text(2), added.get_text(1) not in ["", added.get_text(2)]], [true, setup_now.own_address(), true])
	added.select(1)
	panel.call("_edit_cell")
	added.set_range(1, Array(added.get_text(1).split(",")).find("New address..."))
	panel.call("_edit_mail", added)
	check("New address... opens the cell to type one", added.get_cell_mode(1), TreeItem.CELL_MODE_STRING)
	added.set_text(1, "Mom <mom@home.se>")
	panel.call("_edit_mail", added)
	await process_frame
	check("after the week reloads, the list still picks the open patch", list.get_item_text(list.get_selected_items()[0]).contains("0301_office_girl"), true)
	check("the typed address is saved and offered from then on", [drafts.text(PATCH).contains("from: Mom <mom@home.se>"), "Mom <mom@home.se>" in setup_now.addresses()], [true, true])
	check("the game plays it", game.story_errors, PackedStringArray())

	var setup := SetupPatch.arriving(office_girl, errand, true, game.week.errands(), game.week.patches)
	check("Edit on bench puts her computer on the bench", lab.call("bench", office_girl, errand, setup), "")
	check("booted, connected, in the Screen View, running that copy", [game.connected != null, game.view, game.setups[office_girl.computer] == setup], [true, &"Screen", true])
	check("with no problem", game.connected.problem, null)
	check("its boot goes straight to the desktop", game.connected.skips_boot, true)
	var note := Win95File.new()
	note.name = "note.txt"
	note.contents = "Back at 2."
	setup.desktop.append(note)
	check("Save patch writes it", panel.call("save_bench"), "")
	check("the patch holds the file", drafts.text(PATCH).contains("file Desktop\\note.txt"), true)
	check("the game plays it", game.story_errors, PackedStringArray())

	game.setups.clear()
	var job := Job.new(office_girl, errand.problem, 0, 0)
	job.errand = errand
	var running: Win95Setup = game.setup_for(job)
	check("her computer comes in with the note", running.file_at("Desktop\\note.txt").contents, "Back at 2.")
	check("and the mail as the table left it, in its place", running.emails[0].read, not was_read)
