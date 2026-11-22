extends "res://tests/test.gd"
## Game loads the week from the story files as it starts, and Game.load_story reloads it with
## drafts over them: a draft that breaks a file returns its errors and keeps the week that plays; a
## good draft plays at once, in the day that plays. A visitor who waits beside the computer that
## they show survives a restore.

const GAME := preload("res://game.gd")
const DAY_1: String = "res://story/days/day_1.day"
const SHOWS: String = "res://story/errands/0599_hat_guy.errand"


func run() -> void:
	check("the week loaded as the game started", [game.story_errors, game.week != null, game.day_numbers()], [PackedStringArray(), true, [1, 2, 3, 4, 5, 6, 7]])
	var week: RefCounted = game.week
	check("restore day 1", game.restore({"day": 1, "phase": "OPEN"}), "")
	var before: Dictionary = game.snapshot()

	var errors: PackedStringArray = game.load_story(drafts({"res://story/errands/0598_nobody.errand": "customer: nobody_at_all\n"}))
	check("a broken draft returns its error, naming the file", errors.size() == 1 and errors[0].begins_with("res://story/errands/0598_nobody.errand:1:"), true)
	check("and the week that plays stays", [game.week == week, game.snapshot() == before], [true, true])
	check("the errors are kept for the screen", game.story_errors, errors)

	var day_text := FileAccess.get_file_as_string(DAY_1)
	var rainy := day_text.replace("weather: clear", "weather: rain") if day_text.contains("weather: clear") else "weather: rain\n" + day_text
	check("a good draft loads", game.load_story(drafts({DAY_1: rainy})), PackedStringArray())
	check("it plays at once, in the same day", [game.week != week, game.day.rain, game.day_number, game.phase], [true, true, 1, GAME.Phase.OPEN])

	var shows := "customer: hat_guy\nproblem: dust_overheat\ncomputer: shows\n\n== drop-off\n(neutral) Look.\n\n== pick-up\n(neutral) Bye.\n"
	check("an errand that shows its computer loads", game.load_story(drafts({SHOWS: shows})), PackedStringArray())
	var codes: PackedStringArray = game.day_of(5).codes()
	var waiting := {"day": 5, "arrivals": codes.size(), "visitor": "res://customers/hat_guy.tres", "visit": "DROP_OFF", "visitor_state": "WAITING",
			"jobs": [{"errand": "0599_hat_guy", "slot": 0}], "focus_slot": 0}
	check("restore a visitor waiting beside the computer that they show", game.restore(waiting), "")
	check("he waits, carrying nothing", [game.visitor_state, game.visitor_carries(), game.errand.file_name()], [GAME.VisitorState.WAITING, false, "0599_hat_guy"])
	check("a snapshot names the job's errand", game.snapshot()["jobs"][0]["errand"], "0599_hat_guy")
	waiting["jobs"] = []
	check("he can't wait without it on the counter", game.restore(waiting) != "", true)

	var refused: PackedStringArray = game.load_story()
	check("a week without the waiting visitor's errand is refused, and keeps playing", [refused.size(), game.errand.file_name()], [1, "0599_hat_guy"])
	game.restore({"day": 1})
	check("without drafts, the files play again", [game.load_story(), game.day_of(1).rain == day_text.contains("weather: rain")], [PackedStringArray(), true])


func drafts(texts: Dictionary) -> Dictionary[String, String]:
	var typed: Dictionary[String, String] = {}
	typed.assign(texts)
	return typed
