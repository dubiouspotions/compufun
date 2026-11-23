extends "res://tests/test.gd"
## The Story Lab's Problems section (dev/story_lab/problem_panel.gd) on the real week: the list, a new
## text-only problem, the form's edits as drafts, and the symptom warning.

const DIR := "user://test_story_lab_problems/"
const PROBLEMS := "res://story/problems/"
const DUST := PROBLEMS + "dust_overheat.problem"
const HAUNTED := PROBLEMS + "haunted_printer.problem"


func run() -> void:
	_clear(DIR)
	var drafts := StoryDrafts.new(DIR + "drafts/")
	drafts.git = func(_arguments: PackedStringArray) -> Dictionary: return {"code": 1, "out": ""}
	var lab: Control = (load("res://dev/story_lab/story_lab.tscn") as PackedScene).instantiate()
	lab.set("drafts", drafts)
	root.add_child(lab)
	await process_frame
	lab.call("show_section", "Problems")
	var panel: StoryProblemPanel = lab.call("problem_panel")
	_the_list_has_every_problem(panel)
	_a_new_problem_is_text_only(lab, panel, drafts)
	_the_form_edits_a_draft(panel, drafts)
	_a_changed_symptom_warns_on_a_built_problem(panel, drafts)
	check("Send names a problem file in the title", StoryIssue.title([{"path": DUST}] as Array[Dictionary], ""), "Story: problem dust_overheat")
	lab.queue_free()
	await process_frame


func _the_list_has_every_problem(panel: StoryProblemPanel) -> void:
	var files := StoryFiles.files(PROBLEMS, ".problem")
	check("the list has a row per problem file", (panel.get("_list") as VBoxContainer).get_child_count(), files.size())
	check("the first problem opens", panel.problem_id(), StringName(files[0].get_file().get_basename()))
	check("a problem with mechanics is built", StoryProblemPanel.built(load("res://problems/dust_overheat.tres") as Problem), true)
	check("a typed name becomes an id", StoryProblemPanel.id_of(" Haunted Printer-2! "), "haunted_printer_2")


func _a_new_problem_is_text_only(lab: Control, panel: StoryProblemPanel, drafts: StoryDrafts) -> void:
	check("+ Problem makes one", panel.add_problem("Haunted printer"), "")
	check("as a draft with its name on the post-it", drafts.text(HAUNTED), "post-it: Haunted printer\n")
	check("and opens it", panel.problem_id(), &"haunted_printer")
	var week: StoryFiles.Week = lab.get("_week")
	check("the week has it, without mechanics", [week.problems.has(&"haunted_printer"), StoryProblemPanel.built(week.problems[&"haunted_printer"])], [true, false])
	check("a second one by that name is refused", panel.add_problem("haunted printer"), "There is a problem haunted_printer already.")


func _the_form_edits_a_draft(panel: StoryProblemPanel, drafts: StoryDrafts) -> void:
	panel.open_problem(&"dust_overheat")
	var before := StoryFormat.parse_problem(drafts.text(DUST), DUST).value as Problem
	var post_it: LineEdit = panel.get("_post_it")
	post_it.text = "Runs hot, then dies"
	panel.call("_save")
	var after := StoryFormat.parse_problem(drafts.text(DUST), DUST).value as Problem
	check("the post-it is a draft", after.perceived_issue, "Runs hot, then dies")
	check("the rest of the file stays", [after.symptoms, after.hardware_steps, after.symptom_shows], [before.symptoms, before.hardware_steps, before.symptom_shows])
	check("the game plays the draft", (game.get("story_drafts") as Dictionary).get(DUST, ""), drafts.text(DUST))
	var hardware: VBoxContainer = panel.get("_hardware")
	panel.call("_move", hardware.get_child(0), 1)
	after = StoryFormat.parse_problem(drafts.text(DUST), DUST).value as Problem
	check("moving a step down reorders the draft", [after.hardware_steps[0], after.hardware_steps[1]], [before.hardware_steps[1], before.hardware_steps[0]])
	var saved := drafts.text(DUST)
	post_it.text = ""
	panel.call("_save")
	check("an empty post-it says so in plain words", (panel.get("_errors") as Label).text, "Write the post-it: what the customer says is wrong.")
	check("and keeps the last draft", drafts.text(DUST), saved)
	post_it.text = "Runs hot, then dies"
	panel.call("_save")


func _a_changed_symptom_warns_on_a_built_problem(panel: StoryProblemPanel, drafts: StoryDrafts) -> void:
	var symptoms: VBoxContainer = panel.get("_symptoms")
	var first: LineEdit = symptoms.get_child(0).get_child(0)
	var old := first.text
	first.text = "Shuts off by itself"
	panel.call("_save")
	var warning: Label = panel.get("_warning")
	check("rewording a checked symptom warns", "tell a developer" in warning.text and old in warning.text, true)
	check("but saves", "Shuts off by itself" in drafts.text(DUST), true)
	panel.open_problem(&"haunted_printer")
	panel.call("_add_symptom", "Prints by itself", "pages come out at night")
	panel.call("_save")
	check("a new symptom on a problem without mechanics doesn't warn", warning.text, "")
	check("its symptom and how it shows are drafted", drafts.text(HAUNTED), "post-it: Haunted printer\nsymptoms:\n\tPrints by itself\n\t\tshows: pages come out at night\n")


static func _clear(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for sub: String in DirAccess.get_directories_at(dir):
		_clear(dir.path_join(sub))
		DirAccess.remove_absolute(dir.path_join(sub))
	for file: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(file))
