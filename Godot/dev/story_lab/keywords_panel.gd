class_name StoryKeywordsPanel
extends VBoxContainer
## The Story Lab's Keywords: the words that also find a symptom in CompuFunDB's search
## (story/symptoms.keywords), as editable text. Each edit that parses is a new text of the file,
## which [signal saved] hands up.

## [param text] is the new text of the keywords file [param path]; "" removes it.
signal saved(path: String, text: String)

const SETTLE_SECONDS: float = 0.4

var _drafts: StoryDrafts
var _symptoms: PackedStringArray = []
var _code: CodeEdit
var _errors: ItemList
var _settle: Timer


func _ready() -> void:
	_build()


## Shows the keywords file with [param drafts] over it; [param week] gives the symptoms.
func show_keywords(drafts: StoryDrafts, week: StoryFiles.Week) -> void:
	_settle_now()
	_drafts = drafts
	_symptoms.clear()
	for problem: Problem in week.problems.values():
		for symptom: String in problem.symptoms:
			if symptom not in _symptoms:
				_symptoms.append(symptom)
	_symptoms.sort()
	var text := drafts.text(StoryFiles.KEYWORDS_PATH)
	if text != _code.text:
		_code.text = text
		_code.clear_undo_history()
	_mark(PackedStringArray())


func _settle_now() -> void:
	if _settle != null and not _settle.is_stopped():
		_settle.stop()
		_save()


func _save() -> void:
	if _drafts == null or _code.text == _drafts.text(StoryFiles.KEYWORDS_PATH):
		return
	var text := _code.text if _code.text.strip_edges() != "" else ""
	var keywords: Dictionary[String, PackedStringArray] = {}
	var errors := StoryFormat.parse_keywords(text, StoryFiles.KEYWORDS_PATH, keywords)
	for symptom: String in keywords:
		if symptom not in _symptoms:
			errors.append("%s:%d: no problem lists the symptom '%s'" % [StoryFiles.KEYWORDS_PATH, _line_of(symptom) + 1, symptom])
	_mark(errors)
	if errors.is_empty():
		saved.emit(StoryFiles.KEYWORDS_PATH, text)


func _line_of(symptom: String) -> int:
	for line: int in _code.get_line_count():
		if _code.get_line(line).strip_edges().begins_with(symptom + ":"):
			return line
	return -1


# Adds a line for each symptom that has none yet, for the writer to fill in.
func _add_missing() -> void:
	var text := _code.text.strip_edges(false, true)
	for symptom: String in _symptoms:
		if _line_of(symptom) < 0:
			text += ("\n" if text != "" else "") + symptom + ": "
	_code.text = text
	_settle.start()


func _mark(errors: PackedStringArray) -> void:
	for line: int in _code.get_line_count():
		_code.set_line_background_color(line, Color.TRANSPARENT)
	_errors.clear()
	for error: String in errors:
		var rest := error.trim_prefix(StoryFiles.KEYWORDS_PATH + ":")
		var line := rest.get_slice(":", 0).to_int() - 1
		if line >= 0 and line < _code.get_line_count():
			_code.set_line_background_color(line, Color(LabUI.BAD, 0.22))
		_errors.add_item("line %d: %s" % [line + 1, rest.substr(rest.find(":") + 1).strip_edges()])
	_errors.visible = not errors.is_empty()


func _build() -> void:
	add_theme_constant_override("separation", 8)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_settle = Timer.new()
	_settle.one_shot = true
	_settle.wait_time = SETTLE_SECONDS
	_settle.timeout.connect(_save)
	add_child(_settle)
	add_child(LabUI.label("Keywords", 22))
	var about := LabUI.label("Words that also find a symptom in CompuFunDB's search, one symptom per line: \"Computer runs hot: heat, warm, overheating\". A search finds a symptom when its name and keywords together hold every word typed.", 13, LabUI.DIM)
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(about)
	add_child(LabUI.button("Add the symptoms without keywords", _add_missing))
	_code = CodeEdit.new()
	_code.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_code.gutters_draw_line_numbers = true
	_code.add_theme_constant_override("line_spacing", 6)
	_code.text_changed.connect(func() -> void: _settle.start())
	add_child(_code)
	_errors = ItemList.new()
	_errors.custom_minimum_size.y = 70
	_errors.add_theme_color_override("font_color", LabUI.BAD)
	_errors.visible = false
	add_child(_errors)
