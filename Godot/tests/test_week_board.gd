extends "res://tests/test.gd"
## The Week tab draws a column per day file and a row per flag, and a drop moves an errand from one
## day to another. Nothing is saved.

const WeekBoard := preload("res://addons/week_board/week_board.gd")


func run() -> void:
	var board := WeekBoard.new()
	root.add_child(board)
	await process_frame
	var columns: Array[Node] = board._columns.get_children()
	check("a column per day file", columns.size(), game.day_numbers().size())
	var flags: Array[String] = []
	for row: TreeItem in board._flags.get_root().get_children():
		flags.append(row.get_text(0))
	check("the Pipedream sign's flag is listed", flags.has("sign_pipedream"), true)
	check("the missing links list is filled", board._links.item_count > 0, true)
	board._days[0].set_flags = {&"sign_pipedream": 1}
	board._fill_flags()
	var setter := ""
	for row: TreeItem in board._flags.get_root().get_children():
		if row.get_text(0) == "sign_pipedream":
			setter = row.get_text(1)
	check("a day that sets a flag is listed as its setter", setter.contains("day 1"), true)

	var field := FlagField.new("flag_a", "", board._offers)
	root.add_child(field)
	field._fill_menu()
	var picked := field._offered.find(&"sign_pipedream")
	check("the picker offers the Pipedream's flag", picked >= 0, true)
	field._pick(picked)
	check("a pick adds it to the field", field.edit.text, "flag_a, sign_pipedream")

	var day_1: Day = board._days[0]
	var day_2: Day = board._days[1]
	var moved: Errand = day_1.errands[0]
	var size_1: int = day_1.errands.size()
	var size_2: int = day_2.errands.size()
	var list_2: ItemList = _list(columns[1])
	check("day 2 has room", board._can_drop(day_2, {"week_day": day_1, "index": 0}), size_2 < game.MAX_CUSTOMERS)
	board._drop(list_2, day_2, Vector2(-1, -1), {"week_day": day_1, "index": 0})
	var landed: Errand = day_2.errands[-1]
	check("dropped at the end of day 2, the same customer and problem", [day_1.errands.size(), day_2.errands.size(), landed.customer, landed.problem], [size_1 - 1, size_2 + 1, moved.customer, moved.problem])
	check("both days unsaved", board.unsaved_status().contains("day_1") and board.unsaved_status().contains("day_2"), true)


func _list(column: Node) -> ItemList:
	for child: Node in column.get_children():
		if child is ItemList:
			return child
	return null
