extends "res://tests/test.gd"
## The Story Lab (dev/story_lab/): its week board, moving cards, editing text, drafts and the issue
## that Send makes, on a week of story files written as drafts over an emptied checkout.

const DIR := "user://test_story_lab/"
const ERRANDS := "res://story/errands/"
const SKATER := ERRANDS + "0101_skater_bro.errand"
const NICE := ERRANDS + "0102_nice_guy.errand"
const OFFICE := ERRANDS + "0201_office_girl.errand"
const SKATER_TEXT := """customer: skater_bro
problem: dust_overheat
brief:
	Meet the skater.

== drop-off
(neutral) Yo! Is this the computer repair shop?
- Welcome to CompuFun!
	(happy) Sweet!

== pick-up
(happy) Dude!
"""
const DAY_TEXT := "weather: clear\nwarp: 0\n"


func run() -> void:
	_clear(DIR)
	var drafts := test_drafts(DIR + "drafts/")
	for path: String in StoryFiles.files(ERRANDS, ".errand"):
		drafts.put(path, "")
	for n: int in range(1, 8):
		drafts.put("res://story/days/day_%d.day" % n, DAY_TEXT)
	drafts.put(SKATER, SKATER_TEXT)
	drafts.put(NICE, "customer: nice_guy\n")
	drafts.put(OFFICE, "customer: office_girl\nproblem: no_sound\n")
	drafts.put(ERRANDS + "0701_hat_guy.errand", "customer: hat_guy\n")
	drafts.put(ERRANDS + "0702_young_entrepreneur.errand", "customer: young_entrepreneur\nwhen: not gone_young_entrepreneur\n")
	drafts.put(ERRANDS + "0702_retired_accountant.errand", "customer: retired_accountant\n")
	var lab: Control = (load("res://dev/story_lab/story_lab.tscn") as PackedScene).instantiate()
	lab.set("drafts", drafts)
	root.add_child(lab)
	await process_frame
	_board_lists_the_week(lab)
	_moving_a_card_renames_through_drafts(lab, drafts)
	_a_text_edit_with_an_error_keeps_the_last_good_draft(lab, drafts)
	var reason: String = lab.call("play", (lab.call("errand_panel") as StoryErrandPanel).errand(), Conversation.Trigger.ARRIVE)
	check("Play hides the Lab only when the game plays it", lab.visible, reason != "")
	lab.show()
	_the_bible_edits_its_pages(lab, drafts)
	lab.queue_free()
	await process_frame
	_a_draft_equal_to_the_file_disappears()
	_a_draft_that_main_changed_shows_it()
	_the_issue_has_each_file_and_its_diff()
	_save_to_checkout_writes_the_files()


## Drafts in [param dir] that never ask git.
static func test_drafts(dir: String) -> StoryDrafts:
	var drafts := StoryDrafts.new(dir)
	drafts.git = func(_arguments: PackedStringArray) -> Dictionary: return {"code": 1, "out": ""}
	return drafts


func _board_lists_the_week(lab: Control) -> void:
	var cards: Dictionary = lab.call("cards")
	check("the board has every errand", cards.size(), 6)
	check("a card holds its parsed errand", (cards[SKATER]["errand"] as Errand).customer.resource_path, "res://customers/skater_bro.tres")
	check("a card that parses has no problems", cards[SKATER]["problems"], PackedStringArray())
	check("a card knows it is a draft", cards[SKATER]["draft"], true)
	var groups := StoryLabBoard.groups(PackedStringArray(cards.keys()))
	check("day 1 has two places", groups[0].size(), 2)
	check("day 7's second place has two alternatives", groups[6][1], [ERRANDS + "0702_retired_accountant.errand", ERRANDS + "0702_young_entrepreneur.errand"])
	check("the board shows a column per day", lab.find_children("*", "StoryLabBoard", true, false)[0].get_child_count(), 7)
	check("a written drop-off shows as written", StoryLabBoard.drop_off_state(cards[SKATER]["errand"]), 2)
	check("an errand without a drop-off shows none", StoryLabBoard.drop_off_state(cards[NICE]["errand"]), 0)


func _moving_a_card_renames_through_drafts(lab: Control, drafts: StoryDrafts) -> void:
	check("the move succeeds", lab.call("move_errand", NICE, 2, 0, false), "")
	var texts := drafts.texts()
	check("the moved errand has its new code", texts.get(ERRANDS + "0201_nice_guy.errand"), "customer: nice_guy\n")
	check("the errand it went before moves down", texts.get(ERRANDS + "0202_office_girl.errand"), "customer: office_girl\nproblem: no_sound\n")
	check("the old files are gone", [texts.has(NICE), texts.has(OFFICE)], [false, false])
	check("the move onto alternatives shares their code", lab.call("move_errand", ERRANDS + "0701_hat_guy.errand", 7, 1, true), "")
	texts = drafts.texts()
	check("the alternatives close the gap to 0701", [texts.has(ERRANDS + "0701_hat_guy.errand"), texts.has(ERRANDS + "0701_retired_accountant.errand"), texts.has(ERRANDS + "0701_young_entrepreneur.errand")], [true, true, true])
	check("no 0702 is left", StoryFiles.files(ERRANDS, ".errand", texts).has(ERRANDS + "0702_retired_accountant.errand"), false)


func _a_text_edit_with_an_error_keeps_the_last_good_draft(lab: Control, drafts: StoryDrafts) -> void:
	var parts := StoryErrandPanel.split(SKATER_TEXT)
	check("a file splits into its header and conversations", parts["sections"].size(), 2)
	check("and joins back to the same text", StoryErrandPanel.join(parts["header"], parts["sections"]), SKATER_TEXT)
	lab.call("open_errand", SKATER)
	var panel: StoryErrandPanel = lab.call("errand_panel")
	check("the panel opens the errand", panel.path(), SKATER)
	var broken := "== drop-off\n(neutral) Yo!\n- Welcome! [bogus]\n\t(happy) Sweet!"
	var errors := panel.edit_section(broken)
	check("an error names its line in the section", errors, PackedStringArray(["3: [bogus] is not a tag of a choice: if or end"]))
	check("the draft keeps its last good text", drafts.text(SKATER), SKATER_TEXT)
	errors = panel.edit_section("== drop-off\n(neutral) Yo!\n- Welcome!\n\t(happy) Sweet!")
	check("the fixed text has no errors", errors, PackedStringArray())
	check("the fixed text is the draft, the other conversation as it was", drafts.text(SKATER), SKATER_TEXT.replace("(neutral) Yo! Is this the computer repair shop?\n- Welcome to CompuFun!", "(neutral) Yo!\n- Welcome!"))
	check("the panel holds the errand as the draft parses", panel.errand().problem.short_name, &"dust_overheat")
	var code: CodeEdit = panel.find_children("*", "CodeEdit", true, false)[0]
	code.text = "== drop-off\n("
	code.set_caret_line(1)
	code.set_caret_column(1)
	panel.call("_complete")
	var offered := code.get_code_completion_options().map(func(o: Dictionary) -> String: return o["display_text"])
	check("after ( the text view offers the person's moods", "thinking" in offered and "happy" in offered, true)
	code.text = "== drop-off\n- Hi\n\tset sk"
	code.set_caret_line(2)
	code.set_caret_column(7)
	panel.call("_complete")
	offered = code.get_code_completion_options().map(func(o: Dictionary) -> String: return o["display_text"])
	check("after set it offers the week's flags", "skater_bro_runs_cambion" in offered, true)
	panel.show_errand(SKATER, drafts.text(SKATER))


func _a_draft_equal_to_the_file_disappears() -> void:
	var drafts := test_drafts(DIR + "equal/drafts/")
	drafts.checkout = DIR + "equal/checkout/"
	DirAccess.make_dir_recursive_absolute(drafts.checkout + "story/errands")
	var file := FileAccess.open(drafts.checkout + "story/errands/0101_skater_bro.errand", FileAccess.WRITE)
	file.store_string(SKATER_TEXT)
	file.close()
	check("a changed text is a draft", [drafts.put(SKATER, "customer: skater_bro\n"), drafts.has(SKATER)], ["", true])
	check("the draft is on disk", FileAccess.file_exists(DIR + "equal/drafts/story/errands/0101_skater_bro.errand"), true)
	check("the file's own text drops the draft", [drafts.put(SKATER, SKATER_TEXT), drafts.has(SKATER)], ["", false])
	check("and its file", FileAccess.file_exists(DIR + "equal/drafts/story/errands/0101_skater_bro.errand"), false)
	drafts.put(SKATER, "customer: skater_bro\n")
	file = FileAccess.open(drafts.checkout + "story/errands/0101_skater_bro.errand", FileAccess.WRITE)
	file.store_string("customer: skater_bro\n")
	file.close()
	var reloaded := test_drafts(DIR + "equal/drafts/")
	reloaded.checkout = drafts.checkout
	check("drafts load without errors", reloaded.load_drafts(), PackedStringArray())
	check("a draft that main has now disappears on load", reloaded.has(SKATER), false)


func _a_draft_that_main_changed_shows_it() -> void:
	var drafts := StoryDrafts.new(DIR + "main/drafts/")
	drafts.checkout = DIR + "main/checkout/"
	drafts.git = func(arguments: PackedStringArray) -> Dictionary:
		match arguments[0]:
			"rev-parse":
				return {"code": 0, "out": "c0ffee\n"}
			"cat-file":
				return {"code": 0, "out": ""}
			"show":
				return {"code": 0, "out": SKATER_TEXT if arguments[1] == "c0ffee:Godot/story/errands/0101_skater_bro.errand" else ""}
		return {"code": 1, "out": ""}
	DirAccess.make_dir_recursive_absolute(drafts.checkout + "story/errands")
	var file := FileAccess.open(drafts.checkout + "story/errands/0101_skater_bro.errand", FileAccess.WRITE)
	file.store_string(SKATER_TEXT)
	file.close()
	drafts.put(SKATER, "customer: skater_bro\n")
	check("a draft remembers the commit it started from", drafts.start_commit(SKATER), "c0ffee")
	check("main hasn't changed it yet", drafts.main_changed(SKATER), false)
	file = FileAccess.open(drafts.checkout + "story/errands/0101_skater_bro.errand", FileAccess.WRITE)
	file.store_string(SKATER_TEXT + "\n== phone\n")
	file.close()
	check("main changed it since", StoryDraftsPanel.main_changed(drafts), PackedStringArray([SKATER]))
	check("the draft is still the writer's", drafts.text(SKATER), "customer: skater_bro\n")


func _the_issue_has_each_file_and_its_diff() -> void:
	check("a diff has its hunk and context", StoryIssue.diff("a\nb\nc\nd\ne\nf\ng\nh\ni\n", "a\nb\nc\nd\nE\nf\ng\nh\ni\nj\n"),
		"@@ -2,8 +2,9 @@\n b\n c\n d\n-e\n+E\n f\n g\n h\n i\n+j\n")
	check("far changes make two hunks", StoryIssue.diff("1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n", "one\n2\n3\n4\n5\n6\n7\n8\n9\nten\n"),
		"@@ -1,4 +1,4 @@\n-1\n+one\n 2\n 3\n 4\n@@ -7,4 +7,4 @@\n 7\n 8\n 9\n-10\n+ten\n")
	check("a new file is all additions", StoryIssue.diff("", "x\ny\n"), "@@ -0,0 +1,2 @@\n+x\n+y\n")
	var changed: Array[Dictionary] = [
		{"path": SKATER, "text": SKATER_TEXT, "old": SKATER_TEXT.replace("Dude!", "Hey."), "commit": "c0ffee"},
		{"path": "res://story/days/day_3.day", "text": "", "old": DAY_TEXT, "commit": "c0ffee"},
	]
	check("the title names the codes and days", StoryIssue.title(changed, "The skater cheers\nmore"), "Story: 0101, day 3: The skater cheers")
	var body := StoryIssue.body(changed, "The skater cheers", "Ada")
	check("the body starts with the note", body.begins_with("The skater cheers\n"), true)
	check("it names the writer", "by Ada" in body, true)
	check("it names the file, what happened and the start commit", "### `Godot/story/errands/0101_skater_bro.errand` (changed, started from `c0ffee`)" in body, true)
	check("it holds the whole new text", "```\n" + SKATER_TEXT + "```\n" in body, true)
	check("and the diff", "```diff\n--- a/Godot/story/errands/0101_skater_bro.errand\n+++ b/Godot/story/errands/0101_skater_bro.errand\n@@ -9,4 +9,4 @@\n \t(happy) Sweet!\n \n == pick-up\n-(happy) Hey.\n+(happy) Dude!\n```" in body, true)
	check("a removed file has its diff to nothing", "### `Godot/story/days/day_3.day` (removed, started from `c0ffee`)\n\nDiff against the file in the writer's checkout:\n\n```diff\n--- a/Godot/story/days/day_3.day\n+++ /dev/null\n@@ -1,2 +0,0 @@\n-weather: clear\n-warp: 0\n```" in body, true)


func _save_to_checkout_writes_the_files() -> void:
	var drafts := test_drafts(DIR + "checkout/drafts/")
	drafts.checkout = DIR + "checkout/checkout/"
	drafts.put(NICE, "customer: nice_guy\n")
	drafts.to_checkout = true
	check("drafts wait while Save to checkout is on", drafts.texts(), {})
	check("an edit writes the checkout", drafts.put(SKATER, SKATER_TEXT), "")
	check("the file is there", FileAccess.get_file_as_string(drafts.checkout + "story/errands/0101_skater_bro.errand"), SKATER_TEXT)
	check("and no draft", FileAccess.file_exists(DIR + "checkout/drafts/story/errands/0101_skater_bro.errand"), false)
	check("removing deletes the file", [drafts.put(SKATER, ""), FileAccess.file_exists(drafts.checkout + "story/errands/0101_skater_bro.errand")], ["", false])
	drafts.to_checkout = false
	check("the drafts come back when it is off", drafts.texts().keys(), [NICE])


func _the_bible_edits_its_pages(lab: Control, drafts: StoryDrafts) -> void:
	lab.call("show_section", "Bible")
	var bible: StoryBiblePanel = lab.find_children("*", "StoryBiblePanel", true, false)[0]
	bible.saved.emit("res://story/bible/cast.md", "# The cast\n")
	check("a bible page is a draft", drafts.text("res://story/bible/cast.md"), "# The cast\n")
	bible.show_pages(drafts)
	bible.open_page("res://story/bible/cast.md")
	check("the bible opens it", bible.path(), "res://story/bible/cast.md")
	lab.call("show_section", "Week")


## Removes the files under [param dir], a test folder in user://.
static func _clear(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for sub: String in DirAccess.get_directories_at(dir):
		_clear(dir.path_join(sub))
		DirAccess.remove_absolute(dir.path_join(sub))
	for file: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(file))
