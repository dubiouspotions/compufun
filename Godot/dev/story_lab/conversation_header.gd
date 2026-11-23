class_name StoryConversationHeader
extends VBoxContainer
## The Story Lab's row above a conversation's graph: what the conversation must get across, whether
## it plays only once, when it plays, its voice effect, and the words of its leave buttons. Edits
## change the conversation in place, then emit [signal edited].

## The conversation changed in place; the owner writes its story file from it.
signal edited

const SCENE: String = "res://dev/story_lab/conversation_header.tscn"
const EFFECTS_DIR: String = "res://voices/effects/"

## The known facts that the "Only when" editor offers, as flag names.
var facts: PackedStringArray = []

var _conversation: Conversation
var _brief: LineEdit
var _once: CheckBox
var _when: Button
var _effect: OptionButton
var _leave: LineEdit
var _back: LineEdit
var _error: Label


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	var about := HBoxContainer.new()
	about.add_child(_words("What this conversation must get across"))
	_brief = _field("Say it in plain words; the game doesn't show it", "The brief of this conversation, for the people who write and play it")
	_brief.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	about.add_child(_brief)
	add_child(about)
	var plays := HFlowContainer.new()
	plays.add_theme_constant_override("h_separation", 10)
	_once = CheckBox.new()
	_once.text = "Plays only once"
	_once.tooltip_text = "After it has played, it doesn't play again, even when everything else matches"
	_once.toggled.connect(func(on: bool) -> void:
		if _conversation != null and _conversation.once != on:
			_conversation.once = on
			edited.emit())
	plays.add_child(_once)
	plays.add_child(_words("Only when"))
	_when = Button.new()
	_when.tooltip_text = "The facts and days that this conversation needs to play. Click to change them."
	_when.pressed.connect(_edit_when)
	plays.add_child(_when)
	plays.add_child(_words("Voice effect"))
	_effect = OptionButton.new()
	_effect.tooltip_text = "How every line of this conversation sounds, unless a line has its own effect"
	_effect.add_item("None")
	for name: String in LabUI.resource_names(EFFECTS_DIR):
		_effect.add_item(name)
	_effect.item_selected.connect(_set_effect)
	plays.add_child(_effect)
	add_child(plays)
	var buttons := HFlowContainer.new()
	buttons.add_theme_constant_override("h_separation", 10)
	buttons.add_child(_words("Leave button"))
	_leave = _field(Conversation.new().leave_text, "The button that ends the conversation, under a list where every choice comes back")
	buttons.add_child(_leave)
	buttons.add_child(_words("Back button"))
	_back = _field(Conversation.new().back_text, "The button that goes back to the list above, under a deeper list where every choice comes back")
	buttons.add_child(_back)
	add_child(buttons)
	_error = LabUI.label("", 13, LabUI.BAD)
	_error.hide()
	add_child(_error)
	_brief.text_submitted.connect(func(_text: String) -> void: _commit())
	_brief.focus_exited.connect(_commit)
	for field: LineEdit in [_leave, _back]:
		field.text_submitted.connect(func(_text: String) -> void: _commit())
		field.focus_exited.connect(_commit)


## The header scene, made.
static func make() -> StoryConversationHeader:
	return (load(SCENE) as PackedScene).instantiate() as StoryConversationHeader


## Shows [param conversation]'s settings to edit; null shows nothing.
func show_conversation(conversation: Conversation) -> void:
	_conversation = conversation
	visible = conversation != null
	if conversation == null:
		return
	var defaults := Conversation.new()
	_brief.text = conversation.brief
	_once.set_pressed_no_signal(conversation.once)
	_when.text = StoryConditionEditor.describe(conversation.when)
	_effect.select(0)
	for i: int in _effect.item_count:
		if conversation.effect != null and _effect.get_item_text(i) == conversation.effect.resource_path.get_file().get_basename():
			_effect.select(i)
	_leave.text = "" if conversation.leave_text == defaults.leave_text else conversation.leave_text
	_back.text = "" if conversation.back_text == defaults.back_text else conversation.back_text
	_error.hide()


# Writes the text fields into the conversation, and says why not when a button's words can't be
# written to the story file.
func _commit() -> void:
	if _conversation == null:
		return
	var defaults := Conversation.new()
	for field: LineEdit in [_leave, _back]:
		if field.text.contains("[") or field.text.contains("]"):
			_error.text = "A button's words can't have [ or ] in them."
			_error.show()
			return
	_error.hide()
	var brief := _brief.text.strip_edges()
	var leave := _leave.text.strip_edges() if _leave.text.strip_edges() != "" else defaults.leave_text
	var back := _back.text.strip_edges() if _back.text.strip_edges() != "" else defaults.back_text
	if brief == _conversation.brief and leave == _conversation.leave_text and back == _conversation.back_text:
		return
	_conversation.brief = brief
	_conversation.leave_text = leave
	_conversation.back_text = back
	edited.emit()


func _set_effect(index: int) -> void:
	var effect: VoiceEffect = null
	if index > 0:
		var path := EFFECTS_DIR + _effect.get_item_text(index) + ".tres"
		effect = load(path) as VoiceEffect
		if effect == null:
			push_error("Story Lab: %s doesn't load as a VoiceEffect" % path)
			_error.text = "The voice effect %s doesn't load." % _effect.get_item_text(index)
			_error.show()
			return
	if effect != _conversation.effect:
		_conversation.effect = effect
		edited.emit()


func _edit_when() -> void:
	var editor := StoryConditionEditor.make(facts)
	editor.edit(_conversation.when)
	StoryConditionEditor.popup(_when, "This conversation plays only when...", editor, func() -> void:
		var when := editor.condition()
		var before := StoryFormat.write_condition(_conversation.when) if _conversation.when != null else ""
		if (StoryFormat.write_condition(when) if when != null else "") == before:
			return
		_conversation.when = when
		_when.text = StoryConditionEditor.describe(when)
		edited.emit())


func _words(text: String) -> Label:
	return LabUI.label(text, 13, LabUI.DIM)


func _field(placeholder: String, tip: String) -> LineEdit:
	var field := LineEdit.new()
	field.placeholder_text = placeholder
	field.tooltip_text = tip
	field.custom_minimum_size.x = 200
	return field
