extends "res://tests/test.gd"
## The Week tab draws a column per day file and a row per flag, and a drop moves a customer from one
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

	var day_1: Day = board._days[0]
	var day_2: Day = board._days[1]
	var moved: Customer = day_1.customers[0]
	var size_1 := day_1.customers.size()
	var size_2 := day_2.customers.size()
	var list_2: ItemList = _list(columns[1])
	check("day 2 has room", board._can_drop(day_2, {"week_day": day_1, "index": 0}), size_2 < Day.MAX_CUSTOMERS)
	board._drop(list_2, day_2, Vector2(-1, -1), {"week_day": day_1, "index": 0})
	check("dropped at the end of day 2", [day_1.customers.size(), day_2.customers.size(), day_2.customers[-1]], [size_1 - 1, size_2 + 1, moved])
	check("both days unsaved", board.unsaved_status().contains("day_1") and board.unsaved_status().contains("day_2"), true)


func _list(column: Node) -> ItemList:
	for child: Node in column.get_children():
		if child is ItemList:
			return child
	return null
