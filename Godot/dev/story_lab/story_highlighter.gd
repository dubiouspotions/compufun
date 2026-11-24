class_name StoryHighlighter
extends SyntaxHighlighter
## Colours a conversation of a story file (docs/dialogue.md): the "==" line, brief:, a line's mood
## and each mood inside it, the player's - and + choices, set, if and else, and [tags].

const KEYWORD := Color("c792ea")
const TAG := Color("9d8cd6")
const FLAG := Color("f0c674")
const MINUS := Color("ffb454")
const PLUS := Color("5fd39a")

## The moods that the customer's person has; a line with another mood shows it in red.
var moods: Dictionary[StringName, bool] = {}


func _get_line_syntax_highlighting(line: int) -> Dictionary:
	var text := get_text_edit().get_line(line)
	var depth := 0
	while depth < text.length() and text[depth] == "\t":
		depth += 1
	var body := text.substr(depth)
	var colors := {}
	if text.begins_with("=="):
		colors[0] = {"color": LabUI.ACCENT}
		_tags(colors, text, 0)
	elif body.begins_with("brief:"):
		colors[depth] = {"color": LabUI.DIM}
	elif body.begins_with("- ") or body.begins_with("+ "):
		colors[depth] = {"color": MINUS if body[0] == "-" else PLUS}
		colors[depth + 2] = {"color": LabUI.PLAYER}
		_tags(colors, text, depth + 2)
	elif body.begins_with("set "):
		colors[depth] = {"color": KEYWORD}
		colors[depth + 4] = {"color": FLAG}
	elif body.begins_with("if ") or body == "else":
		colors[depth] = {"color": KEYWORD}
		if body.length() > 3:
			colors[depth + 3] = {"color": FLAG}
	elif body.begins_with("("):
		var close := body.find(")")
		var mood := StringName(body.substr(1, close - 1)) if close > 0 else &""
		colors[depth] = {"color": _mood_color(mood)}
		if close > 0:
			colors[depth + close + 1] = {"color": LabUI.TEXT}
			_mood_changes(colors, text, depth + close + 1)
			_tags(colors, text, depth + close + 1)
	else:
		colors[depth] = {"color": LabUI.TEXT}
		_mood_changes(colors, text, depth)
	var sorted := {}
	var columns := colors.keys()
	columns.sort()
	for column: int in columns:
		sorted[column] = colors[column]
	return sorted


func _mood_color(mood: StringName) -> Color:
	return LabUI.GOOD if moods.is_empty() or moods.has(mood) else LabUI.BAD


# Colours each "(mood)" inside the line from [param from] on as the leading mood is coloured.
func _mood_changes(colors: Dictionary, text: String, from: int) -> void:
	var end := text.find(" [", from)
	for found: RegExMatch in StoryFormat.mood_change().search_all(text.substr(0, end if end >= 0 else text.length()), from):
		colors[found.get_start()] = {"color": _mood_color(StringName(found.get_string(1)))}
		colors[found.get_end()] = {"color": LabUI.TEXT}


# Colours the trailing [tags] of [param text] from [param from] on.
func _tags(colors: Dictionary, text: String, from: int) -> void:
	var at := text.find(" [", from)
	if at >= 0 and text.strip_edges(false, true).ends_with("]"):
		colors[at + 1] = {"color": TAG}
