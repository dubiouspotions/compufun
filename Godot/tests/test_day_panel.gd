extends "res://tests/test.gd"
## The Story Lab's day panel shows what a day remembers as it starts and at closing as facts, writes
## a picked fact into the day file, and shows the corruption signs by title.

const DAY := "weather: rain\nwarp: 0.3\non start: sign_pipedream\non close: skater_cambion=0\n"


func run() -> void:
	var panel := StoryDayPanel.new()
	panel.facts = PackedStringArray(["sign_pipedream", "skater_cambion"])
	root.add_child(panel)
	await process_frame
	var saved: Array[String] = []
	panel.saved.connect(func(_path: String, text: String) -> void: saved.append(text))
	panel.show_day("res://story/days/day_3.day", DAY)
	var editors := panel.find_children("*", "StoryFlagsEditor", true, false)
	check("on start and on close are two remember editors", editors.size(), 2)
	var on_start := editors[0] as StoryFlagsEditor
	var on_close := editors[1] as StoryFlagsEditor
	check("they show the day's facts", [on_start.flags(), on_close.flags()], [{&"sign_pipedream": 1}, {&"skater_cambion": 0}])
	for button: Node in on_start.find_children("*", "Button", true, false):
		if (button as Button).text == "+ another fact":
			(button as Button).pressed.emit()
	var pickers := on_start.find_children("*", "StoryFactPicker", true, false)
	(pickers[pickers.size() - 1] as StoryFactPicker).pick("Skater told us")
	check("a picked fact is written into the day file", saved.size() > 0 and saved[saved.size() - 1].contains("on start: sign_pipedream, skater_told_us"), true)
	var raw := PackedStringArray()
	for node: Node in panel.find_children("*", "", true, false):
		var words: String = node.get(&"placeholder_text") if node is LineEdit else (node.get(&"text") if node is Button else "")
		if words.contains("_") or words.contains("="):
			raw.append(words)
	check("no field or button shows flag syntax", raw, PackedStringArray())
