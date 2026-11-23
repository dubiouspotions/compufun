extends "res://tests/test.gd"
## The Story Lab's week board in bands (Before opening, Morning, Midday, Afternoon, At closing): the
## band of each card on the committed week, a drop into each band, and a customer dropped onto an
## empty Afternoon.

const GAME := preload("res://game.gd")
const TEST_STORY_LAB := preload("res://tests/test_story_lab.gd")
const ERRANDS := "res://story/errands/"


func run() -> void:
	await _the_committed_week_has_its_bands()
	await _drops_land_in_their_band()


func _the_committed_week_has_its_bands() -> void:
	var lab := await _lab(TEST_STORY_LAB.test_drafts(user_dir() + "committed/"))
	var cards: Dictionary = lab.call("cards")
	var days := StoryLabBoard.groups(PackedStringArray(cards.keys()))
	check("day 1: the manager before opening, then morning, midday and afternoon", StoryLabBoard.bands(days[0], cards), [StoryLabBoard.Band.BEFORE_OPENING, StoryLabBoard.Band.MORNING, StoryLabBoard.Band.MIDDAY, StoryLabBoard.Band.AFTERNOON])
	check("the manager is day 1's first errand", days[0][0], [ERRANDS + "0101_middle_manager.errand"])
	var week := StoryFiles.load_week()
	for d: int in StoryLabBoard.DAYS:
		var day: Day = week.days[d]
		var expected: Array[StoryLabBoard.Band] = []
		for place: int in day.codes().size():
			var first := place == 0 and day.alternatives(day.codes()[0]).any(func(each: Errand) -> bool: return each.before_opening)
			expected.append(StoryLabBoard.Band.BEFORE_OPENING if first else StoryLabBoard.Band[GAME.Daypart.find_key(GAME.daypart_of(day, place + 1))])
		check("day %d: each card's band is its daypart in the game" % (d + 1), StoryLabBoard.bands(days[d], cards), expected)
	var board := _board(lab)
	check("day 1 shows the manager under Before opening", _shown(board, 1, "BeforeOpening"), ["0101_middle_manager.errand"])
	check("and the accountant under Midday", _shown(board, 1, "Midday"), ["0103_retired_accountant.errand"])
	lab.queue_free()
	await process_frame


func _drops_land_in_their_band() -> void:
	var drafts := TEST_STORY_LAB.test_drafts(user_dir() + "drops/")
	for path: String in StoryFiles.files(ERRANDS, ".errand"):
		drafts.put(path, "")
	for n: int in range(1, 8):
		drafts.put("res://story/days/day_%d.day" % n, "weather: clear\nwarp: 0\n")
	drafts.put("res://story/days/day_1.day", "weather: clear\nwarp: 0\non close: sign_logo_blue, met_skater\nclose signs: posters_bounce\n")
	drafts.put(ERRANDS + "0101_middle_manager.errand", "customer: middle_manager\ncomputer: none\ncomes: before opening\n")
	drafts.put(ERRANDS + "0102_skater_bro.errand", "customer: skater_bro\n")
	drafts.put(ERRANDS + "0103_office_girl.errand", "customer: office_girl\n")
	drafts.put(ERRANDS + "0201_nice_guy.errand", "customer: nice_guy\n")
	drafts.put(ERRANDS + "0202_hat_guy.errand", "customer: hat_guy\n")
	drafts.put(ERRANDS + "0203_retired_accountant.errand", "customer: retired_accountant\n")
	drafts.put(ERRANDS + "0204_activist_guy.errand", "customer: activist_guy\n")
	drafts.put(ERRANDS + "0301_nice_lady.errand", "customer: nice_lady\n")
	drafts.put(ERRANDS + "0302_attractive_guy.errand", "customer: attractive_guy\n")
	var lab := await _lab(drafts)
	var board := _board(lab)
	var cards: Dictionary = lab.call("cards")
	check("day 1 starts before opening, morning, midday", StoryLabBoard.bands(StoryLabBoard.groups(PackedStringArray(cards.keys()))[0], cards), [StoryLabBoard.Band.BEFORE_OPENING, StoryLabBoard.Band.MORNING, StoryLabBoard.Band.MIDDAY])
	check("an empty Afternoon still shows, with no card", _shown(board, 1, "Afternoon"), [])
	check("At closing says the day's on close flags and close signs", StoryLabBoard.closing_words((lab.get("_week") as StoryFiles.Week).days[0], StoryDayPanel.signs()),
		PackedStringArray(["From now on: The logo turns Windows blue", "Remembers met skater", "Until morning: The logos and a poster bounce off the walls like the Solitaire win"]))

	board.drop_in({"story_customer": "young_entrepreneur"}, 3, StoryLabBoard.Band.AFTERNOON)
	check("a customer dropped onto day 3's empty Afternoon is a new errand at its end", drafts.text(ERRANDS + "0303_young_entrepreneur.errand"), "customer: young_entrepreneur\n\n== drop-off\n")
	check("and shows under Afternoon", _shown(_board(lab), 3, "Afternoon"), ["0303_young_entrepreneur.errand"])
	check("and is open", (lab.call("errand_panel") as StoryErrandPanel).path(), ERRANDS + "0303_young_entrepreneur.errand")

	_board(lab).drop_in({"story_errand": ERRANDS + "0204_activist_guy.errand"}, 1, StoryLabBoard.Band.MIDDAY)
	var texts := drafts.texts()
	check("a card dropped into Midday takes Midday's first place", texts.get(ERRANDS + "0103_activist_guy.errand"), "customer: activist_guy\n")
	check("the errand that was there moves down", texts.has(ERRANDS + "0104_office_girl.errand"), true)

	_board(lab).drop_in({"story_errand": ERRANDS + "0203_retired_accountant.errand"}, 2, StoryLabBoard.Band.MORNING)
	texts = drafts.texts()
	check("a card dropped into Morning goes first", [texts.has(ERRANDS + "0201_retired_accountant.errand"), texts.has(ERRANDS + "0202_nice_guy.errand"), texts.has(ERRANDS + "0203_hat_guy.errand")], [true, true, true])

	_board(lab).drop_in({"story_errand": ERRANDS + "0203_hat_guy.errand"}, 2, StoryLabBoard.Band.BEFORE_OPENING)
	texts = drafts.texts()
	check("a card dropped into Before opening is place 01 and comes before opening", texts.get(ERRANDS + "0201_hat_guy.errand"), "customer: hat_guy\ncomes: before opening\n")
	check("and shows there", _shown(_board(lab), 2, "BeforeOpening"), ["0201_hat_guy.errand"])

	_board(lab).drop_in({"story_errand": ERRANDS + "0201_hat_guy.errand"}, 2, StoryLabBoard.Band.AFTERNOON)
	texts = drafts.texts()
	check("a card dragged out of Before opening into Afternoon goes last and comes after opening", texts.get(ERRANDS + "0203_hat_guy.errand"), "customer: hat_guy\n")
	check("day 2 is morning, midday, afternoon again", _shown(_board(lab), 2, "Afternoon"), ["0203_hat_guy.errand"])

	_board(lab).drop_in({"story_errand": ERRANDS + "0101_middle_manager.errand"}, 1, StoryLabBoard.Band.MORNING)
	check("the manager dragged into Morning stays first, after opening", drafts.text(ERRANDS + "0101_middle_manager.errand"), "customer: middle_manager\ncomputer: none\n")
	check("and shows under Morning", _shown(_board(lab), 1, "Morning"), ["0101_middle_manager.errand", "0102_skater_bro.errand"])
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


# The file names of the cards under band [param section] (its node name) of day [param day].
func _shown(board: StoryLabBoard, day: int, section: String) -> Array:
	var band: Control = board.get_child(day - 1).find_child(section, true, false)
	if band == null:
		return ["no band " + section]
	var names: Array = []
	for card: Control in band.find_children("*", "PanelContainer", true, false):
		if card.tooltip_text.ends_with(".errand") or card.tooltip_text.contains(".errand\n"):
			names.append(card.tooltip_text.get_slice("\n", 0))
	return names
