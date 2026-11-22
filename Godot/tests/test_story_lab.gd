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
	lab.queue_free()
	await process_frame


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


## Removes the files under [param dir], a test folder in user://.
static func _clear(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for sub: String in DirAccess.get_directories_at(dir):
		_clear(dir.path_join(sub))
		DirAccess.remove_absolute(dir.path_join(sub))
	for file: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(file))
