extends "res://tests/test.gd"
## The Office Assistant (win95/office/assistant/) in Word and Excel: he comes in and welcomes the player once
## per computer, offers help with a new letter that starts with "Dear", answers Help, shows a tip from
## tips.txt, keeps his options, hides until Help calls him back, and once corruption/no_clippy has
## taken him he stays away and Help fails as Office 97 does without him.

const WORD := "res://win95/office/word.tscn"
const EXCEL := "res://win95/office/excel.tscn"
const _ASSISTANT := preload("res://win95/office/assistant/assistant.gd")
const _WORDPAD := preload("res://win95/wordpad.gd")


func run() -> void:
	var desktop: Win95Desktop = load("res://win95/desktop.gd").new()
	desktop.size = Vector2(640, 480)
	root.add_child(desktop)
	await process_frame
	var word: OfficeWindow = desktop.open(load(WORD))
	var helper: Control = word.get_node("%AssistantLayer").get_child(0)
	check("Word gets the assistant", helper.get_script(), _ASSISTANT)
	check("who isn't there as Word opens", helper.is_showing(), false)
	await _seconds(helper.arrive_delay + 1.0)
	check("he comes in soon after", helper.is_showing(), true)
	check("bottom right, clear of the scroll bars and the status bar",
			(helper.get_node("%Frame") as Control).get_rect().end, helper.size - helper.corner_margin)
	var balloon: Control = helper.balloon()
	check("and welcomes the player", balloon.text().begins_with("Welcome to Microsoft Word!"), true)
	check("with Office 97's choices", balloon.options(), ["See key information for upgraders and new users",
			"Find out about the Office Assistant (That's me!)", "Start using Microsoft Word"])
	balloon.press("Start using Microsoft Word")
	await process_frame
	check("which closes the balloon", helper.balloon(), null)

	var excel: OfficeWindow = desktop.open(load(EXCEL))
	await _seconds(helper.arrive_delay + 1.0)
	var excel_helper: Control = excel.get_node("%AssistantLayer").get_child(0)
	check("Excel has him too, with no second welcome", [excel_helper.is_showing(), excel_helper.balloon()], [true, null])
	excel.help_requested.emit()
	check("and his Help", excel_helper.balloon().text().begins_with("What would you like to do?") if excel_helper.balloon() != null else false, true)
	excel.close()
	desktop.activate(word)

	var text: RichEditor = word.get_node("%Text")
	text.type_text("Dear Sir,")
	balloon = helper.balloon()
	check("a new document that starts with Dear is a letter",
			balloon.text() if balloon != null else "", "It looks like you're writing a letter.\n\nWould you like help?")
	check("he offers help with it", balloon.options() if balloon != null else [],
			["Get help with writing the letter", "Just type the letter without help", "Cancel"])
	balloon.press("Cancel")
	await process_frame
	text.type_text("\nDear me.")
	check("once per document", helper.balloon(), null)

	word.help_requested.emit()
	balloon = helper.balloon()
	check("Help asks what to do, and says that Help isn't installed", balloon.text().begins_with(
			"What would you like to do?\nThe Office Assistant cannot currently answer your questions."), true)
	check("with a tip waiting", balloon.options(), ["See a complete list of help topics", "Tips", "Options", "Close"])
	balloon.press("Tips")
	balloon = helper.balloon()
	var first: String = _ASSISTANT.tips_for("Microsoft Word")[0]
	check("Tips shows the first tip after an opener", _ASSISTANT.TIP_OPENERS.any(func(opener: String) -> bool:
			return balloon.text() == "%s %s" % [opener, first]), true)
	check("beside him", balloon.get(&"beside"), true)
	check("and puts his bulb out", (helper.get_node("%Bulb") as TextureButton).texture_normal.resource_path.get_file(), "bulb_unlit.png")
	balloon.press("Close")
	check("Word's tips are Office's and Word's, not Excel's",
			_ASSISTANT.tips_for("Microsoft Word").any(func(tip: String) -> bool: return tip.contains("Lotus")), false)
	check("Excel has its own", _ASSISTANT.tips_for("Microsoft Excel").any(func(tip: String) -> bool: return tip.contains("Lotus")), true)
	check("both have Office's", _ASSISTANT.tips_for("Microsoft Excel").has(first), true)

	helper.call(&"_on_menu_chosen", &"options")
	var dialog := _window(desktop, "assistant_options.tscn")
	check("Options opens the Office Assistant dialog", dialog.get_node("%TitleBar").title if dialog != null else "", "Office Assistant")
	dialog.call(&"set_option", &"tip_at_startup", true)
	(dialog.get_node("%Ok") as Button).pressed.emit()
	check("whose OK keeps the options", helper.options()[&"tip_at_startup"], true)

	helper.animate()
	helper.hide_assistant()
	await _seconds(0.6)
	check("Hide Assistant sends him away", helper.is_showing(), false)
	var second: OfficeWindow = desktop.open(load(WORD), false)
	await _seconds(helper.arrive_delay + 0.5)
	var second_helper: Control = second.get_node("%AssistantLayer").get_child(0)
	check("and he stays away from the next Word", second_helper.is_showing(), false)
	second.help_requested.emit()
	await _seconds(1.0)
	check("until Help calls him back", [second_helper.is_showing(), second_helper.balloon() != null], [true, true])
	second.close()

	var sign: Node = load("res://corruption/no_clippy.tscn").instantiate()
	root.add_child(sign)
	sign.call(&"_apply", 1)
	check("no_clippy takes him from the open Word", helper.is_showing(), false)
	word.help_requested.emit()
	var box := _window(desktop, "message_box.tscn")
	check("Help then falls back on Windows Help", [box.get_node("%TitleBar").title, box.get_node("%Text").text] if box != null else [],
			["Windows Help", "Cannot find the wdmain8.hlp file. Do you want to try to find this file yourself?"])
	for button: Button in box.get_node("%Buttons").get_children():
		if button.text == "No":
			button.pressed.emit()
	await process_frame
	box = _window(desktop, "message_box.tscn")
	check("which can't find Word's Help file", box.get_node("%Text").text if box != null else "",
			"Cannot find the wdmain8.hlp Help file. Check to see that the file exists on your disk. If it doesn't, you need to reinstall it.")
	var later: OfficeWindow = desktop.open(load(WORD), false)
	await _seconds(helper.arrive_delay + 0.5)
	check("and he never comes to a Word opened after", (later.get_node("%AssistantLayer").get_child(0) as Control).call(&"is_showing"), false)
	sign.call(&"_apply", 0)
	check("the sign gives him back when it ends", root.get_meta(_WORDPAD.ASSISTANT_TAKEN_META, false), false)
	sign.queue_free()
	desktop.queue_free()
	await process_frame


func _seconds(seconds: float) -> void:
	await create_timer(seconds).timeout


func _window(desktop: Node, scene_file: String) -> Control:
	for child: Node in desktop.get_children():
		if child.scene_file_path.ends_with(scene_file) and (child as Control).visible:
			return child
	return null
