class_name CompufunDB
extends PanelContainer
## CompufunDB on the work computer: the symptoms and the repair steps of each problem. It reads
## every Problem file in res://problems/, so the database is never a second copy of the problems.

const PROBLEMS_DIR: String = "res://problems/"

var _problems: Array[Problem] = []

@onready var _list: ItemList = %ProblemList
@onready var _steps: Label = %StepsLabel
@onready var _offline: Label = %OfflineLabel


func _ready() -> void:
	_load_problems()
	_list.item_selected.connect(_on_selected)
	Game.changed.connect(_sync)
	_sync()


func _load_problems() -> void:
	for file: String in ResourceLoader.list_directory(PROBLEMS_DIR):
		if not file.ends_with(".tres"):
			continue
		var problem := load(PROBLEMS_DIR + file) as Problem
		if problem == null:
			push_error("CompufunDB: %s%s is not a Problem" % [PROBLEMS_DIR, file])
			continue
		_problems.append(problem)
	if _problems.is_empty():
		push_error("CompufunDB: no Problem files in %s" % PROBLEMS_DIR)
		_steps.text = "No problems found in %s" % PROBLEMS_DIR
	for problem: Problem in _problems:
		_list.add_item(", ".join(problem.symptoms))


func _on_selected(index: int) -> void:
	var problem := _problems[index]
	var text := "%s\n" % problem.short_name
	text += _numbered("Hardware", problem.hardware_steps)
	text += _numbered("Software", problem.software_steps)
	_steps.text = text


func _numbered(title: String, steps: PackedStringArray) -> String:
	if steps.is_empty():
		return ""
	var text := "\n%s:\n" % title
	for i: int in steps.size():
		text += "%d. %s\n" % [i + 1, steps[i]]
	return text


func _sync() -> void:
	var offline := Game.phase == Game.Phase.CALLING
	_offline.visible = offline
	_list.visible = not offline
	_steps.visible = not offline
