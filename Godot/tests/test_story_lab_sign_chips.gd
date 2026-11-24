extends "res://tests/test.gd"
## The corruption signs on the Story Lab's week board: where the committed week's starts show, a
## sign dropped at the start of a day, at closing, in a band and on a card, and a chip moved.

const TEST_STORY_LAB := preload("res://tests/test_story_lab.gd")
const ERRANDS := "res://story/errands/"
const DAYS := "res://story/days/"


func run() -> void:
	await _the_committed_starts_show_where_they_start()
	await _drops_write_the_starts()


func _the_committed_starts_show_where_they_start() -> void:
	var lab := await _lab(TEST_STORY_LAB.test_drafts(user_dir() + "committed/"))
	var shown := PackedStringArray()
	for spot: Dictionary in _spots(lab):
		shown.append(_where(spot))
	shown.sort()
	var expected := PackedStringArray([
		"blood_puddle on 0703_skater_bro.errand, locked",
		"calc_666 day 1 BEFORE_OPENING",
		"customer_x day 6 MORNING",
		"customer_x=0 day 7 MORNING",
		"logo_blue day 3 AT_CLOSING",
		"logo_cambion day 6 AT_CLOSING",
		"no_clippy on 0303_retired_accountant.errand",
		"pointer_escape day 3 MORNING",
		"pointer_escape=0 day 7 AT_CLOSING",
		"posters_bounce day 5 AT_CLOSING",
		"win_phone day 7 MORNING",
	])
	expected.sort()
	check("each start of the committed week shows in its band or on its card", shown, expected)
	var board := _board(lab)
	check("day 1's on start chip sits in Before opening", board.get_child(0).find_child("BeforeOpening", true, false).find_child("Sign_calc_666", true, false) != null, true)
	var locked: Control = _card(board, 7, "0703_skater_bro.errand").find_child("Sign_blood_puddle", true, false)
	check("the problem's sign shows on its card, and doesn't drag", [locked != null, locked.mouse_filter if locked != null else -1], [true, Control.MOUSE_FILTER_STOP])
	lab.queue_free()
	await process_frame


func _drops_write_the_starts() -> void:
	var drafts := TEST_STORY_LAB.test_drafts(user_dir() + "drops/")
	for path: String in StoryFiles.files(ERRANDS, ".errand"):
		drafts.put(path, "")
	for n: int in range(1, 8):
		drafts.put(DAYS + "day_%d.day" % n, "weather: clear\nwarp: 0\n")
	drafts.put(DAYS + "day_2.day", "weather: clear\nwarp: 0\non start: sign_logo_blue\n")
	drafts.put(ERRANDS + "0101_skater_bro.errand", "customer: skater_bro\n\n== drop-off\n(neutral) Yo!\n")
	drafts.put(ERRANDS + "0102_office_girl.errand", "customer: office_girl\ndaypart: midday\n\n== drop-off\nbrief: She is late.\n(neutral) Hi.\n")
	drafts.put(ERRANDS + "0201_hat_guy.errand", "customer: hat_guy\n")
	drafts.put(ERRANDS + "0202_nice_guy.errand", "customer: nice_guy\n\n== drop-off\nset met_nice, sign_no_clippy\n(happy) Hello!\n")
	var lab := await _lab(drafts)

	_board(lab).drop_in({"story_sign": &"calc_666", "from": {}}, 1, StoryLabBoard.Band.MORNING)
	check("a sign dropped on Morning starts with the day", drafts.text(DAYS + "day_1.day"), "weather: clear\nwarp: 0\non start: sign_calc_666\n")
	_board(lab).drop_in({"story_sign": &"posters_bounce", "from": {}}, 1, StoryLabBoard.Band.AT_CLOSING)
	check("a sign dropped on At closing is one of the day's close signs", drafts.text(DAYS + "day_1.day"), "weather: clear\nwarp: 0\non start: sign_calc_666\nclose signs: posters_bounce\n")
	_board(lab).drop_in({"story_sign": &"pipedream", "from": {}}, 1, StoryLabBoard.Band.MIDDAY)
	check("a sign dropped on Midday starts with its first errand's drop-off, under the brief", drafts.text(ERRANDS + "0102_office_girl.errand"), "customer: office_girl\ndaypart: midday\n\n== drop-off\nbrief: She is late.\nset sign_pipedream\n(neutral) Hi.\n")
	check("a sign dropped on a card starts with its drop-off, made when it has none", lab.call("move_sign", &"folder_popup", {}, {"errand": ERRANDS + "0201_hat_guy.errand"}), "")
	check("the card's errand file", drafts.text(ERRANDS + "0201_hat_guy.errand"), "customer: hat_guy\n\n== drop-off\nset sign_folder_popup\n")
	check("an Afternoon without a customer says why it takes no sign", String(_board(lab).get_child(1).find_child("Afternoon", true, false).tooltip_text).begins_with("No customer comes in at afternoon"), true)

	var clippy := _spot(lab, &"no_clippy")
	check("the chip on Nice guy's card is the drop-off's start", [clippy["errand"], clippy["start"]["detail"]], [ERRANDS + "0202_nice_guy.errand", "0202/drop-off/1"])
	_board(lab).drop_in({"story_sign": &"no_clippy", "from": clippy["start"]}, 2, StoryLabBoard.Band.AT_CLOSING)
	check("a moved chip leaves the conversation it came from", drafts.text(ERRANDS + "0202_nice_guy.errand"), "customer: nice_guy\n\n== drop-off\nset met_nice\n(happy) Hello!\n")
	var blue := _spot(lab, &"logo_blue")
	_board(lab).drop_in({"story_sign": &"logo_blue", "from": blue["start"]}, 1, StoryLabBoard.Band.MORNING)
	check("and the day it came from", drafts.text(DAYS + "day_2.day"), "weather: clear\nwarp: 0\nclose signs: no_clippy\n")
	check("into the day it went to", drafts.text(DAYS + "day_1.day"), "weather: clear\nwarp: 0\non start: sign_calc_666, sign_logo_blue\nclose signs: posters_bounce\n")
	_board(lab).drop_in({"story_sign": &"folder_popup", "from": _spot(lab, &"folder_popup")["start"]}, 3, StoryLabBoard.Band.MORNING)
	check("a drop-off left with nothing goes", drafts.text(ERRANDS + "0201_hat_guy.errand"), "customer: hat_guy\n")
	check("the chips show where they went", [_where(_spot(lab, &"no_clippy")), _where(_spot(lab, &"logo_blue"))], ["no_clippy day 2 AT_CLOSING", "logo_blue day 1 MORNING"])
	lab.queue_free()
	await process_frame


func _lab(drafts: StoryDrafts) -> Control:
	var lab: Control = (load("res://dev/story_lab/story_lab.tscn") as PackedScene).instantiate()
	lab.set("drafts", drafts)
	root.add_child(lab)
	await process_frame
	return lab


func _board(lab: Control) -> StoryLabBoard:
	return lab.find_children("*", "StoryLabBoard", true, false)[0]


func _spots(lab: Control) -> Array[Dictionary]:
	var cards: Dictionary = lab.call("cards")
	var week: StoryFiles.Week = lab.get("_week")
	return StoryLabBoard.sign_spots(StoryLabBoard.all_sign_starts(week, StoryDayPanel.signs().keys()), StoryLabBoard.groups(PackedStringArray(cards.keys())), cards)


func _spot(lab: Control, id: StringName) -> Dictionary:
	for spot: Dictionary in _spots(lab):
		if spot["id"] == id:
			return spot
	return {"id": id, "errand": "", "start": {"detail": "", "value": 1}, "day": 0, "band": -1, "locked": false}


# A spot in words: "<id>[=value] day <n> <band>" or "<id>[=value] on <errand file>[, locked]".
func _where(spot: Dictionary) -> String:
	var value: int = spot["start"]["value"]
	var id := String(spot["id"]) + ("" if value == 1 else "=%d" % value)
	if spot["errand"] != "":
		return "%s on %s%s" % [id, String(spot["errand"]).get_file(), ", locked" if spot["locked"] else ""]
	return "%s day %d %s" % [id, spot["day"], StoryLabBoard.Band.find_key(spot["band"]) if spot["band"] >= 0 else "nowhere"]


func _card(board: StoryLabBoard, day: int, file: String) -> Control:
	for card: Control in board.get_child(day - 1).find_children("*", "PanelContainer", true, false):
		if card.tooltip_text.begins_with(file + "\n"):
			return card
	return null
