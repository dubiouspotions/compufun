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
	var mails: Tree = panel.get("_mails")
	var first := mails.get_root().get_first_child()
	check("the table lists her mails", first != null, true)
	panel.call("_edit_mail", first)
	check("a cell clicked and left unchanged makes no draft", drafts.paths(), PackedStringArray())
	var was_read := first.is_checked(5)
	first.set_checked(5, not was_read)
	panel.call("_edit_mail", first)
	check("the table edit is a draft: the mail, whole", drafts.text(PATCH).begins_with("mail\n\tfolder:"), true)
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
