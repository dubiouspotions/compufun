extends "res://tests/test.gd"
## The row above a conversation's graph writes its brief, "plays only once", "only when", voice
## effect and leave and back buttons into the conversation, which the story file then writes as its
## tags.


func run() -> void:
	var parsed := StoryFormat.parse_errand("customer: skater_bro\n\n== drop-off\n(neutral) Yo!\n", "res://story/errands/0101_skater_bro.errand")
	var errand := parsed.value as Errand
	var talk := errand.conversations[0]
	var header := StoryConversationHeader.make()
	root.add_child(header)
	header.show_conversation(talk)
	var edits := [0]
	header.edited.connect(func() -> void: edits[0] += 1)
	var brief := _field(header, "Say it in plain words; the game doesn't show it")
	var leave := _field(header, "That's all, thanks.")
	var back := _field(header, "Something else...")
	check("the buttons show their default words as hints", [leave.text, leave.placeholder_text, back.placeholder_text], ["", "That's all, thanks.", "Something else..."])

	brief.text = "He arrives cheerful."
	brief.text_submitted.emit(brief.text)
	(header.find_children("*", "CheckBox", true, false)[0] as CheckBox).button_pressed = true
	var effect: OptionButton = header.find_children("*", "OptionButton", true, false)[0]
	var glitch := -1
	for i: int in effect.item_count:
		if effect.get_item_text(i) == "cambion_glitch":
			glitch = i
	effect.select(glitch)
	effect.item_selected.emit(glitch)
	leave.text = "Bye."
	leave.text_submitted.emit("Bye.")
	check("each change edits the conversation", [talk.brief, talk.once, talk.effect.resource_path, talk.leave_text, talk.back_text], ["He arrives cheerful.", true, "res://voices/effects/cambion_glitch.tres", "Bye.", "Something else..."])
	check("and is signalled", edits[0], 4)

	var when: Button = header.find_children("*", "Button", true, false).filter(func(b: Button) -> bool: return b.text == "always")[0]
	when.pressed.emit()
	var editor: StoryConditionEditor = when.find_children("*", "StoryConditionEditor", true, false)[0]
	(editor.find_children("*", "Button", true, false).filter(func(b: Button) -> bool: return b.text == "+ another fact")[0] as Button).pressed.emit()
	(editor.find_children("*", "StoryFactPicker", true, false)[0] as StoryFactPicker).pick(&"skater_cambion")
	(when.find_children("*", "PopupPanel", true, false)[0] as PopupPanel).hide()
	check("Only when sets the condition, and says it", [talk.when.need_flags, when.text], [[&"skater_cambion"], "skater cambion"])
	check("the story file writes them all as tags", StoryFormat.write_errand(errand).contains("== drop-off [if skater_cambion] [once] [effect cambion_glitch] [leave Bye.]\nbrief: He arrives cheerful."), true)

	back.text = "Go [back]"
	back.text_submitted.emit(back.text)
	check("a button's words with brackets are refused", talk.back_text, "Something else...")


func _field(header: Node, placeholder: String) -> LineEdit:
	for node: Node in header.find_children("*", "LineEdit", true, false):
		if (node as LineEdit).placeholder_text == placeholder:
			return node
	return null
