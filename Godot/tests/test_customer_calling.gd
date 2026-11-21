extends "res://tests/test.gd"
## A waiting customer climbs through the moods two lines at a time, then stays annoyed.


func run() -> void:
	var calling: Node = load("res://ui/customer_calling.tscn").instantiate()
	root.add_child(calling)
	await process_frame
	var lines: Conversation = load("res://customers/conversations/waiting.tres")
	calling._moods = calling._by_pose(lines.lines)
	check("five moods, calmest first", calling._moods.map(func(m: Array) -> StringName: return m[0].pose), [&"neutral", &"thinking", &"irritated01", &"irritated02", &"irritated03"])
	var moods := []
	for step in 16:
		moods.append(calling._mood_of(step))
	check("two lines per mood, then round the angriest two", moods, [0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 3, 3, 4, 4, 3, 3])
