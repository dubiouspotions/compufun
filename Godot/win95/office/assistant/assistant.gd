extends Control
## The Office Assistant: Office 97's Clippit in a small window in the bottom right corner of an Office
## 97 app (OfficeWindow.assistant). He comes in soon after the app opens, welcomes the player once per
## computer, moves now and then, lights his bulb with a tip from tips.txt, offers help with a letter
## that starts with "Dear", answers Help, and hides from his right-click menu or his X. Once Cambion
## has taken him (corruption/no_clippy) he never comes, and Help fails as Office 97 does without
## him. docs/win95-reference.md, "Office Assistant", has what the reference shows.

## The group of every assistant; corruption/no_clippy.gd calls _sync_assistant on it.
const GROUP: StringName = &"win95_office_assistants"
## The tips: one per line under [Office], [Word] or [Excel]; # starts a note.
const TIPS_FILE := "res://win95/office/assistant/tips.txt"
## Each animation: its steps, each [pose, seconds]. The poses are clippy_<pose>.png, Clippit's frames
## that tools/crop_clippy.sh cuts from Office 97; "rest" is the rest pose (_rest_pose).
const ANIMATIONS: Dictionary[StringName, Array] = {
	&"Blink": [[&"blink", 0.15], [&"rest", 0.0]],
	&"LookDown": [[&"glance", 1.4], [&"rest", 0.0]],
	&"LookAround": [[&"look", 1.2], [&"glance", 0.6], [&"rest", 0.0]],
	&"Thinking": [[&"glance", 0.5], [&"look", 1.2], [&"glance", 0.4], [&"rest", 0.0]],
	&"Explain": [[&"point", 0.15], [&"point_far", 1.4], [&"point", 0.15], [&"rest", 0.0]],
	&"GetAttention": [[&"squash", 0.12], [&"stretch", 0.15], [&"squash", 0.12], [&"stretch_arm", 0.5], [&"rest", 0.0]],
	&"Turn": [[&"turn", 0.9], [&"rest", 0.0]],
}
## The animations that he plays now and then by himself.
const IDLE: Array[StringName] = [&"Blink", &"Blink", &"LookDown", &"LookAround", &"Turn"]
## The file that Help looks for once the assistant is gone, by app; this install has no Help.
const HELP_FILES: Dictionary[String, String] = {
	"Microsoft Word": "wdmain8.hlp",
	"Microsoft Excel": "C:\\PROGRAM FILES\\MICROSOFT OFFICE\\OFFICE\\XLMAIN8.HLP",
}
## What the tip balloon says before the tip; Office 97 picks one.
const TIP_OPENERS: Array[String] = ["Check out today's tip:", "Tip of the day:", "Today's tip is:"]
## His options, as the Options tab names them, with Office 97's defaults. Only tip_at_startup (and
## the tab's Reset my tips) change what he does.
const OPTIONS: Dictionary[StringName, bool] = {
	&"respond_to_f1": true, &"help_with_wizards": true, &"display_alerts": true, &"search_programming": false,
	&"move_when_in_the_way": true, &"guess_help_topics": true, &"make_sounds": true,
	&"tips_features": true, &"tips_mouse": true, &"tips_keyboard": false,
	&"high_priority_only": false, &"tip_at_startup": false,
}

const _WORDPAD := preload("res://win95/wordpad.gd")
const _BALLOON := preload("res://win95/office/assistant/balloon.gd")
const _MESSAGE := preload("res://win95/message_box.tscn")
const _OPTIONS_DIALOG := preload("res://win95/office/assistant/assistant_options.tscn")
const _BULB_LIT := preload("res://win95/office/assistant/bulb_lit.png")
const _BULB_UNLIT := preload("res://win95/office/assistant/bulb_unlit.png")
const _QUESTION := preload("res://win95/theme/icons_extracted/message_question_32.png")
const _INFORMATION := preload("res://win95/theme/icons_extracted/message_info_32.png")
const _POSE := "res://win95/office/assistant/clippy_%s.png"
const _MEMORY_META: StringName = &"office_assistant"
const _LETTER := "^\\s*Dear[\\s,:]"

## How far the window keeps from the app's bottom right corner: clear of the scroll bars and the
## status bar.
@export var corner_margin := Vector2(18, 38)
## The seconds between two idle animations, at random between x and y.
@export var idle_gap := Vector2(6.0, 14.0)
## The seconds after the app opens before he comes in.
@export var arrive_delay := 0.7

## The app that he helps.
var window: OfficeWindow

var _balloon: Control
var _animation: Tween
var _idle := Timer.new()
var _letter := RegEx.create_from_string(_LETTER)
var _letter_offered := false
var _tip_waiting := true
var _moved := false
var _dragging := false
var _menu: ContextMenu


func _ready() -> void:
	add_to_group(GROUP)
	_idle.one_shot = true
	_idle.timeout.connect(_on_idle)
	add_child(_idle)
	%Close.pressed.connect(hide_assistant)
	%Bulb.pressed.connect(show_tip)
	%Frame.gui_input.connect(_on_frame_input)
	%Bar.gui_input.connect(_on_bar_input)
	resized.connect(_place)


## Joins [param app]: listens to its Help and its edits, and comes in unless he is hidden or gone.
func attach(app: OfficeWindow) -> void:
	window = app
	window.help_requested.connect(_on_help)
	window.document_edited.connect(_on_edited)
	if _gone() or _memory()[&"hidden"]:
		return
	var arrival := Timer.new()
	arrival.one_shot = true
	arrival.timeout.connect(func() -> void:
		arrival.queue_free()
		if not _gone() and not %Frame.visible:
			_arrive(_greet))
	add_child(arrival)
	arrival.start(arrive_delay)


## True while he is on screen.
func is_showing() -> bool:
	return %Frame.visible


## The balloon that he shows, or null.
func balloon() -> Control:
	return _balloon if is_instance_valid(_balloon) and _balloon.is_inside_tree() else null


## Leaves until the player asks for help again, as Hide Assistant and his X do.
func hide_assistant() -> void:
	_memory()[&"hidden"] = true
	_close_balloon()
	_leave()


## Plays [param animation] (a key of ANIMATIONS), or a random one for an empty name, as Animate! does.
func animate(animation: StringName = &"") -> void:
	if animation == &"":
		animation = ANIMATIONS.keys().pick_random()
	if not ANIMATIONS.has(animation):
		push_error("Office Assistant: no animation %s in %s" % [animation, ANIMATIONS.keys()])
		return
	if _animation != null:
		_animation.kill()
	var clip: TextureRect = %Clip
	_animation = create_tween()
	for step: Array in ANIMATIONS[animation]:
		var pose: StringName = step[0]
		_animation.tween_callback(func() -> void: _show_pose(pose))
		if step[1] > 0.0:
			_animation.tween_interval(step[1])
	_animation.tween_callback(_wait_idle)


## Shows the waiting tip, or the last one, beside him, and puts his bulb out.
func show_tip() -> void:
	var tip: String = _next_tip() if _tip_waiting else _memory().get(&"last_tip", "")
	if tip == "":
		return
	_tip_waiting = false
	%Bulb.texture_normal = _BULB_UNLIT
	_memory()[&"last_tip"] = tip
	_say(true, "", "%s %s" % [TIP_OPENERS.pick_random(), tip], [],
			[[&"", "Back", false], [&"", "Next", false], [&"close", "Close"]],
			clampf((%Frame as Control).position.x - 40.0, 200.0, 480.0), _BULB_LIT)


## The tips that [param app] shows, in order: [Office]'s and the app's own ("Word" for
## "Microsoft Word"). Errors on a missing or empty file.
static func tips_for(app: String) -> Array[String]:
	var text := FileAccess.get_file_as_string(TIPS_FILE)
	if text.is_empty():
		push_error("Office Assistant: can't read %s: %s" % [TIPS_FILE, error_string(FileAccess.get_open_error())])
		return []
	var own := app.trim_prefix("Microsoft ")
	var section := ""
	var found: Array[String] = []
	for raw: String in text.split("\n"):
		var line := raw.strip_edges()
		if line.begins_with("#") or line.is_empty():
			continue
		if line.begins_with("[") and line.ends_with("]"):
			section = line.substr(1, line.length() - 2)
		elif section == "Office" or section == own:
			found.append(line)
	return found


## The options as the player set them on this computer; OPTIONS has the names.
func options() -> Dictionary:
	return _memory()[&"options"]


## Starts the tips over, as Reset my tips does.
func reset_tips() -> void:
	_memory()[&"tip"] = 0


func _sync_assistant() -> void:
	if _gone():
		_close_balloon()
		if _menu != null:
			_menu.hide()
		if _animation != null:
			_animation.kill()
		%Frame.hide()
		_idle.stop()


func _gone() -> bool:
	return is_inside_tree() and get_tree().root.get_meta(_WORDPAD.ASSISTANT_TAKEN_META, false)


# What he remembers on this computer: kept on the desktop, so every Office app shares it.
func _memory() -> Dictionary:
	var keeper: Node = window.get_parent() if window != null and window.get_parent() != null else self
	if not keeper.has_meta(_MEMORY_META):
		keeper.set_meta(_MEMORY_META, {&"hidden": false, &"welcomed": false, &"tip": 0, &"last_tip": "",
				&"options": OPTIONS.duplicate()})
	return keeper.get_meta(_MEMORY_META)


func _next_tip() -> String:
	var tips := tips_for(window.app_title() if window != null else "")
	if tips.is_empty():
		return ""
	var memory := _memory()
	var tip := tips[memory[&"tip"] % tips.size()]
	memory[&"tip"] += 1
	return tip


# Rises into his window from below, then [param then].
func _arrive(then: Callable = Callable()) -> void:
	_place()
	%Frame.show()
	%Bulb.visible = true
	%Bulb.texture_normal = _BULB_LIT if _tip_waiting else _BULB_UNLIT
	var clip: TextureRect = %Clip
	clip.texture = load(_POSE % &"stretch")
	clip.position.y = (%Stage as Control).size.y
	if _animation != null:
		_animation.kill()
	_animation = create_tween()
	_animation.tween_property(clip, ^"position:y", -6.0, 0.35).set_ease(Tween.EASE_OUT)
	_animation.tween_property(clip, ^"position:y", 0.0, 0.15).set_ease(Tween.EASE_IN)
	_animation.tween_callback(_show_pose.bind(&"rest"))
	_animation.tween_interval(0.2)
	if then.is_valid():
		_animation.tween_callback(then)
	_animation.tween_callback(_wait_idle)


# Sinks out of his window, which then closes.
func _leave() -> void:
	_idle.stop()
	if _animation != null:
		_animation.kill()
	if not %Frame.visible:
		return
	var clip: TextureRect = %Clip
	clip.texture = load(_POSE % &"glance")
	_animation = create_tween()
	_animation.tween_property(clip, ^"position:y", (%Stage as Control).size.y, 0.3).set_ease(Tween.EASE_IN)
	_animation.tween_callback(%Frame.hide)
	_animation.tween_callback(func() -> void: clip.position.y = 0.0)


# The first time on this computer, the welcome; else the tip of the day if the player asked for it.
func _greet() -> void:
	var memory := _memory()
	if not memory[&"welcomed"]:
		memory[&"welcomed"] = true
		_welcome()
	elif options()[&"tip_at_startup"]:
		show_tip()


func _welcome() -> void:
	var app := window.app_title()
	_say(false, "Welcome to %s!" % app, "I'm the Office Assistant, and my job is to help you with this application.",
			[[&"", "See key information for upgraders and new users"],
			[&"about", "Find out about the Office Assistant (That's me!)"], [&"close", "Start using %s" % app]], [], 120.0)


func _about() -> void:
	_say(false, "Hi. I'm your Office Assistant.", "\n\n".join([
			"My job is to help you with the Microsoft Office product family.  When you need help, just click this button on the Standard toolbar.  [img]res://win95/office/icons/assistant.png[/img]",
			"Whenever you need help, just ask.  Click on me, and I'll try to automatically guess the help you need.  If you see a help topic you like, click it.  If not, just type your question, and then click Search.  I'll show you the answers I have to your question.",
			"You can change my options or even choose another Office Assistant.  Just click on me with the right mouse button and pick the \"Options...\" command.",
			"To learn more about the Office Assistant, click me and ask about \"Office Assistant.\""]),
			[], [[&"welcome", "OK"]], 400.0)


# "What would you like to do?", as Office 97 answers without its Help files.
func _offer_help() -> void:
	_say(false, "What would you like to do?",
			"The Office Assistant cannot currently answer your questions.  Run Setup again to make sure all the necessary Help files are correctly installed.",
			[[&"", "See a complete list of help topics"]],
			[[&"tips", "Tips", _tip_waiting], [&"options", "Options"], [&"close", "Close"]], 236.0)


func _offer_letter() -> void:
	_letter_offered = true
	animate(&"GetAttention")
	_say(false, "", "It looks like you're writing a letter.\n\nWould you like help?",
			[[&"", "Get help with writing the letter"], [&"close", "Just type the letter without help"]],
			[[&"close", "Cancel"]], 108.0)


func _say(beside: bool, heading: String, text: String, choices: Array, buttons: Array, width: float,
		icon: Texture2D = null) -> void:
	_close_balloon()
	_balloon = _BALLOON.new()
	_balloon.beside = beside
	_balloon.picked.connect(_on_picked)
	add_child(_balloon)
	_aim()
	_balloon.say(heading, text, choices, buttons, width, icon)
	_settle()


func _close_balloon() -> void:
	if balloon() != null:
		_balloon.queue_free()
	_balloon = null
	_settle()


# Office 97 rests him on another frame while a balloon is open.
func _rest_pose() -> StringName:
	return &"listen" if balloon() != null else &"rest"


func _show_pose(pose: StringName) -> void:
	(%Clip as TextureRect).texture = load(_POSE % (_rest_pose() if pose == &"rest" else pose))


# A running animation's next step overrides this, and its last step rests him the same way.
func _settle() -> void:
	if is_node_ready() and %Frame.visible:
		_show_pose(&"rest")


func _on_picked(id: StringName) -> void:
	match id:
		&"close":
			_close_balloon()
		&"about":
			_about()
		&"welcome":
			_welcome()
		&"tips":
			show_tip()
		&"options":
			_close_balloon()
			_open_options()
		_:
			push_error("Office Assistant: the balloon has no choice %s" % id)


func _on_help() -> void:
	if _gone():
		_help_without_assistant()
		return
	_memory()[&"hidden"] = false
	if %Frame.visible:
		_offer_help()
	else:
		_arrive(_offer_help)


# Office 97 without its assistant falls back on Windows Help, which can't find the app's Help file.
func _help_without_assistant() -> void:
	var help_file: String = HELP_FILES.get(window.app_title(), "wdmain8.hlp")
	var box := _message_box()
	if box == null:
		return
	var answers: Array[String] = ["Yes", "No"]
	box.ask("Windows Help", "Cannot find the %s file. Do you want to try to find this file yourself?" % help_file,
			answers, _QUESTION)
	box.answered.connect(func(_answer: String) -> void:
		var told := _message_box()
		if told != null:
			told.inform("Windows Help", "Cannot find the %s Help file. Check to see that the file exists on your disk. If it doesn't, you need to reinstall it." % help_file, _INFORMATION))


func _message_box() -> Node:
	var desktop := window.get_parent() as Win95Desktop
	if desktop == null:
		push_error("Office Assistant: %s is not on a Win95Desktop, so Help has nowhere to show its message" % window.app_title())
		return null
	var box: Node = desktop.open(_MESSAGE, false)
	box.closed.connect(box.queue_free)
	return box


# Only in a new document: a letter that the player opens and edits is no news to him.
func _on_edited() -> void:
	if _letter_offered or _gone() or not %Frame.visible or window.file != null:
		return
	if _letter.search(window.document_text()) != null:
		_offer_letter()


func _on_idle() -> void:
	if %Frame.visible and balloon() == null:
		animate(IDLE.pick_random())
	else:
		_wait_idle()


func _wait_idle() -> void:
	if is_inside_tree() and %Frame.visible:
		_idle.start(randf_range(idle_gap.x, idle_gap.y))


func _open_options() -> void:
	var desktop := window.get_parent() as Win95Desktop
	if desktop == null:
		push_error("Office Assistant: %s is not on a Win95Desktop, so Options has nowhere to open" % window.app_title())
		return
	var dialog: Node = desktop.open(_OPTIONS_DIALOG, false)
	dialog.call(&"edit", self)


func _on_frame_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed:
		return
	if click.button_index == MOUSE_BUTTON_RIGHT:
		_open_menu(click.global_position)
		accept_event()
	elif click.button_index == MOUSE_BUTTON_LEFT and (%Stage as Control).get_global_rect().has_point(click.global_position):
		_on_help()  # a click on him asks for help, as in Office 97
		accept_event()


func _open_menu(at: Vector2) -> void:
	if _menu == null:
		_menu = ContextMenu.new()
		add_child(_menu, false, Node.INTERNAL_MODE_BACK)
		_menu.chosen.connect(_on_menu_chosen)
		var top: Control = self
		while top.get_parent() is Control:
			top = top.get_parent()
		_menu.outside = top
	_menu.open(at, [
		ContextMenu.item("&Hide Assistant", &"hide", false, balloon() != null),
		ContextMenu.separator(),
		ContextMenu.item("See &Tips", &"tips", false, not _tip_waiting),
		ContextMenu.item("&Options...", &"options"),
		ContextMenu.item("&Choose Assistant...", &""),
		ContextMenu.item("&Animate!", &"animate"),
	])


func _on_menu_chosen(id: StringName) -> void:
	match id:
		&"hide":
			hide_assistant()
		&"tips":
			show_tip()
		&"options":
			_open_options()
		&"animate":
			animate()
		_:
			push_error("Office Assistant: his menu has no item %s" % id)


# A press on his title bar drags his window around the app.
func _on_bar_input(event: InputEvent) -> void:
	var press := event as InputEventMouseButton
	if press != null and press.button_index == MOUSE_BUTTON_LEFT:
		_dragging = press.pressed
		return
	var motion := event as InputEventMouseMotion
	if motion != null and _dragging:
		_moved = true
		var frame: Control = %Frame
		frame.position = (frame.position + motion.relative).clamp(Vector2.ZERO, (size - frame.size).max(Vector2.ZERO))
		_aim()


# Bottom right of the app, until the player moves him; inside it either way.
func _place() -> void:
	var frame: Control = %Frame
	frame.size = frame.get_combined_minimum_size()
	var room := (size - frame.size).max(Vector2.ZERO)
	frame.position = frame.position.clamp(Vector2.ZERO, room) if _moved else (size - corner_margin - frame.size).clamp(Vector2.ZERO, room)
	_aim()


func _aim() -> void:
	if balloon() == null:
		return
	var frame: Control = %Frame
	_balloon.aim = frame.position + (Vector2(0, 20) if _balloon.beside else Vector2(24, 0))
	_balloon.place()
