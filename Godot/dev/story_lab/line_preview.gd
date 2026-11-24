class_name StoryLinePreview
extends Control
## The game's own dialogue box (ui/dialogue_overlay.tscn) over the Story Lab, showing one customer
## line as the game shows it: the portrait of its mood, the name, the text typing out and the voice.
## It stays until a click, Esc or Shift+Enter closes it, and takes every key and click while it
## shows, so the text behind it doesn't change.

## The preview closed.
signal closed

const OVERLAY: String = "res://ui/dialogue_overlay.tscn"
## The game's theme: the box looks as it does in the game, not in the Lab's theme.
const GAME_THEME: String = "res://ui/theme.tres"
## How dark the shade behind the box is, so the Lab recedes; 0 for none.
const SHADE: float = 0.45

var _overlay: DialogueOverlay


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = load(GAME_THEME) as Theme
	if theme == null:
		push_error("Story Lab: %s doesn't load; the preview uses the Lab's theme" % GAME_THEME)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, SHADE)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var scene := load(OVERLAY) as PackedScene
	if scene == null:
		push_error("Story Lab: %s doesn't load, so lines can't be previewed" % OVERLAY)
	else:
		_overlay = scene.instantiate() as DialogueOverlay
		_overlay.auto_advance_seconds = 0.0  # the line stays until the writer closes it
		add_child(_overlay)
	hide()


## Shows [param line] of [param customer] in the dialogue box, speaking under [param conversation]'s
## voice effect when the line has none (null for none). A leaving line or a line with a look shows in
## the box all the same. Returns "" or why it can't show, and then stays closed.
func show_line(customer: Customer, line: DialogueLine, conversation: Conversation) -> String:
	if _overlay == null:
		return "%s doesn't load" % OVERLAY
	if customer == null or customer.person == null:
		return "%s has no portraits to show" % (customer.spoken_name() if customer != null else "The errand has no customer, so it")
	if line == null or line.text.strip_edges() == "":
		return "the line has no words yet"
	var said := line.duplicate() as DialogueLine
	said.leaving = false
	said.look = &""
	var one := Conversation.new()
	one.id = "story_lab/preview"
	one.lines.append(said)
	one.effect = conversation.effect if conversation != null else null
	show()
	_overlay.start(customer, one)
	return ""


## The line that the box shows; null while the preview is closed.
func shown_line() -> DialogueLine:
	return _overlay.shown_line() if visible and _overlay != null else null


## Closes the preview and hushes its voice; nothing happens while it is closed.
func close() -> void:
	if not visible:
		return
	_overlay.hush()
	hide()
	closed.emit()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var key := event as InputEventKey
	var click := event as InputEventMouseButton
	if key != null:
		var shift_enter := key.shift_pressed and (key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER)
		if key.pressed and not key.echo and (key.keycode == KEY_ESCAPE or shift_enter):
			close()
		get_viewport().set_input_as_handled()
	elif click != null:
		if click.pressed:
			close()
		get_viewport().set_input_as_handled()
