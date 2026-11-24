extends "res://tests/test.gd"
## The Story Lab's text view: unfinished text that outlives a quit, saving at once, and the line
## preview in the game's dialogue box.

const ERRANDS := "res://story/errands/"
const SKATER := ERRANDS + "0101_skater_bro.errand"
const NICE := ERRANDS + "0102_nice_guy.errand"
const HEADER := "customer: skater_bro\nproblem: dust_overheat\nbrief:\n\tMeet the skater."
const DROP_OFF := "== drop-off\n(neutral) Yo! Is this the computer repair shop?\n- Welcome to CompuFun!\n\t(happy) Sweet!\n(thinking) So, my computer."
const PICK_UP := "== pick-up\n(happy) Dude!"
const BROKEN := "== drop-off\n(neutral) Yo! Is this the computer repair shop?\n- Welcome to CompuFun! [bogus]\n\t(happy) Sweet!\n(thinking) So, my computer."
const PLAY := "Play this line in the game's dialogue box"

var drafts: StoryDrafts
var lab: Control  # untyped: StoryLab names the Game autoload, which a test script compiled under -s can't
var panel: StoryErrandPanel
var code: CodeEdit


func run() -> void:
	_unfinished_sections_line_up()
	drafts = test_drafts(user_dir() + "drafts/")
	for path: String in StoryFiles.files(ERRANDS, ".errand"):
		drafts.put(path, "")
	for n: int in range(1, 8):
		drafts.put("res://story/days/day_%d.day" % n, "weather: clear\nwarp: 0\n")
	drafts.put(SKATER, _skater(DROP_OFF))
	drafts.put(NICE, "customer: nice_guy\n")
	lab = (load("res://dev/story_lab/story_lab.tscn") as PackedScene).instantiate() as Control
	lab.set("drafts", drafts)
	root.add_child(lab)
	await process_frame
	lab.call("open_story", SKATER)
	panel = lab.call("errand_panel")
	panel.show_view("Text")
	code = panel.find_children("*", "CodeEdit", true, false)[0]
	await process_frame
	_text_that_does_not_parse_is_unfinished_text()
	await _hiding_or_closing_saves_at_once()
	await _shift_enter_shows_the_line_in_the_dialogue_box()
	await _the_graph_play_shows_the_same_preview()
	lab.queue_free()
	await process_frame


## Drafts in [param dir] that never ask git.
static func test_drafts(dir: String) -> StoryDrafts:
	var made := StoryDrafts.new(dir)
	made.git = func(_arguments: PackedStringArray) -> Dictionary: return {"code": 1, "out": ""}
	return made


static func _skater(drop_off: String) -> String:
	return StoryErrandPanel.join(HEADER, PackedStringArray([drop_off, PICK_UP]))


func _unfinished_sections_line_up() -> void:
	var good := _skater(DROP_OFF)
	check("text without unfinished text has no unfinished conversations", StoryErrandPanel.unfinished_sections(good, ""), {})
	check("a broken conversation stands in for its own", StoryErrandPanel.unfinished_sections(good, _skater(BROKEN)), {0: BROKEN})
	var split := DROP_OFF + "\n\n== pick-up [bogus]\n(happy) Yo"
	check("one that grew a section stays one", StoryErrandPanel.unfinished_sections(good, _skater(split)), {0: split})
	var headless := StoryErrandPanel.join(HEADER + "\n\n(neutral) Yo!", PackedStringArray([PICK_UP]))
	check("lines that lost their == line stand in for the conversation", StoryErrandPanel.unfinished_sections(good, headless), {0: "(neutral) Yo!"})
	var merged := StoryErrandPanel.join(HEADER, PackedStringArray([DROP_OFF + "\n(happy) Dude! [bogus]"]))
	check("two that merged go to the first, and the second is emptied", StoryErrandPanel.unfinished_sections(good, merged), {0: DROP_OFF + "\n(happy) Dude! [bogus]", 1: ""})


func _text_that_does_not_parse_is_unfinished_text() -> void:
	var errors := panel.edit_section(BROKEN)
	check("the broken text has its error", errors, PackedStringArray(["3: [bogus] is not a tag of a choice: if or end"]))
	check("it is unfinished text", drafts.unfinished(SKATER), _skater(BROKEN))
	check("and not the draft", drafts.text(SKATER), _skater(DROP_OFF))
	check("texts and paths, which the game and Send read, don't see it", [drafts.texts()[SKATER], drafts.paths().has(SKATER)], [_skater(DROP_OFF), true])
	check("the issue sends the last text that parsed", StoryIssue.files(drafts).filter(func(f: Dictionary) -> bool: return f["path"] == SKATER)[0]["text"], _skater(DROP_OFF))
	check("the game plays the last text that parsed", StoryFiles.load_week(drafts.texts()).errors, PackedStringArray())
	var after_quit := test_drafts(drafts.dir)
	check("it outlives a quit", [after_quit.load_drafts(), after_quit.unfinished(SKATER), after_quit.texts().has(SKATER)], [PackedStringArray(), _skater(BROKEN), true])
	check("the drafts panel lists it", StoryDraftsPanel.edited(drafts).has(SKATER), true)
	var send: Control = lab.get("_send_panel")
	send.call("show_send", drafts)
	check("Send says it leaves it out", (send.get("_unfinished") as Label).text.contains("errands/0101_skater_bro.errand"), true)
	send.hide()

	lab.call("open_errand", NICE)
	lab.call("open_story", SKATER)
	check("reopened, the text view shows it", [panel.get("_view"), code.text], ["Text", BROKEN])
	check("with its error", (panel.get("_errors") as ItemList).get_item_text(0), "line 3: [bogus] is not a tag of a choice: if or end")
	check("the status line says so", (lab.get("_status") as Label).text.begins_with("0101_skater_bro.errand has unfinished text"), true)
	check("the graph keeps the last version that parsed", panel.errand().conversations[0].choices[0].text, "Welcome to CompuFun!")

	errors = panel.edit_section(DROP_OFF + "\n- Bye.")
	check("a version that parses saves", [errors, drafts.text(SKATER)], [PackedStringArray(), _skater(DROP_OFF + "\n- Bye.")])
	check("and clears the unfinished text, on disk too", [drafts.has_unfinished(SKATER), FileAccess.file_exists(drafts.dir + "unfinished/story/errands/0101_skater_bro.errand")], [false, false])

	drafts.put_unfinished(NICE, "customer: nice_guy\n\n== drop-off\n- Hi [bogus]\n")
	var moves: Dictionary[String, String] = {NICE: ERRANDS + "0103_nice_guy.errand"}
	check("a rename moves the unfinished text along", [drafts.rename(moves), drafts.has_unfinished(NICE), drafts.unfinished(ERRANDS + "0103_nice_guy.errand").contains("bogus")], ["", false, true])
	check("removing the file drops it", [drafts.put(ERRANDS + "0103_nice_guy.errand", ""), drafts.unfinished_paths()], ["", PackedStringArray()])
	drafts.put(NICE, "customer: nice_guy\n")
	panel.edit_section(DROP_OFF)


func _hiding_or_closing_saves_at_once() -> void:
	code.set_line(2, "- Welcome to CompuFun! [bogus]")
	await process_frame
	check("typing waits for the typing to settle", [(panel.get("_settle") as Timer).is_stopped(), drafts.has_unfinished(SKATER)], [false, false])
	lab.hide()
	check("hiding the Lab keeps it at once", drafts.unfinished(SKATER), _skater(BROKEN))
	lab.show()
	code.set_line(2, "- Welcome to CompuFun!")
	await process_frame
	lab.propagate_notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	check("a close request (Cmd+Q) saves at once", [drafts.text(SKATER), drafts.has_unfinished(SKATER)], [_skater(DROP_OFF), false])


func _shift_enter_shows_the_line_in_the_dialogue_box() -> void:
	var preview: Control = lab.call("line_preview")
	code.grab_focus()
	code.set_caret_line(2)
	code.set_caret_column(4)
	var shift_enter := _key(KEY_ENTER, "")
	shift_enter.shift_pressed = true
	root.push_input(shift_enter)
	await process_frame
	var person: Person = (load("res://customers/skater_bro.tres") as Customer).person
	var shown := preview.call("shown_line") as DialogueLine
	var face: TextureRect = preview.find_children("PortraitTexture", "TextureRect", true, false)[0]
	check("Shift+Enter on a choice shows the line above in the dialogue box", [preview.visible, shown.text if shown != null else "", face.texture], [true, "Yo! Is this the computer repair shop?", person.portraits[&"neutral"]])
	check("and leaves the text and the cursor as they were", [code.text, code.get_caret_line(), code.get_caret_column()], [DROP_OFF, 2, 4])
	root.push_input(_key(KEY_ESCAPE, ""))
	await process_frame
	check("Esc closes it, and the Lab stays", [preview.visible, lab.visible, code.text], [false, true, DROP_OFF])
	code.set_caret_line(3)
	root.push_input(shift_enter.duplicate() as InputEvent)
	await process_frame
	check("on a customer line it shows that line", (preview.call("shown_line") as DialogueLine).text if (preview.call("shown_line") as DialogueLine) != null else "", "Sweet!")
	root.push_input(shift_enter.duplicate() as InputEvent)
	await process_frame
	check("Shift+Enter again closes it, without a new line", [preview.visible, code.text], [false, DROP_OFF])


func _the_graph_play_shows_the_same_preview() -> void:
	panel.show_view("Graph")
	await process_frame
	var graph: GraphEdit = panel.find_children("*", "GraphEdit", true, false)[0]
	var talk := panel.errand().conversations[0]
	var play: Button = graph.call("box_of", talk).find_children("*", "Button", true, false).filter(func(b: Button) -> bool: return b.tooltip_text == PLAY)[0]
	play.pressed.emit()
	var preview: Control = lab.call("line_preview")
	check("the graph's Play shows its line in the same preview", [preview.visible, (preview.call("shown_line") as DialogueLine).text if (preview.call("shown_line") as DialogueLine) != null else ""], [true, talk.lines[0].text])
	preview.call("close")
	panel.show_view("Text")


func _key(keycode: Key, typed: String) -> InputEventKey:
	var key := InputEventKey.new()
	key.keycode = keycode
	key.pressed = true
	key.unicode = typed.unicode_at(0) if typed != "" else 0
	return key

