extends "res://win95/window.gd"
## PowerPoint's New Slide dialog (Insert > New Slide), and the same picker as Slide Layout (Format >
## Slide Layout): a picture per AutoLayout, the chosen one's name, and OK or Apply.

## The player chose [param layout], one of PptDeck.LAYOUTS, with OK or Apply, or by a double-click.
signal chosen(layout: String)

## The layout that the dialog opens on.
var layout := PptDeck.DEFAULT_LAYOUT

var _current := ""  # as Slide Layout, the slide's own layout


func _ready() -> void:
	super()
	var group := ButtonGroup.new()
	for name in PptDeck.LAYOUTS:
		var picture := Button.new()
		picture.toggle_mode = true
		picture.flat = true
		picture.button_group = group
		picture.custom_minimum_size = Vector2(66, 54)
		picture.focus_mode = Control.FOCUS_NONE
		picture.tooltip_text = name
		picture.set_meta(&"layout", name)
		picture.draw.connect(_draw_layout.bind(picture, name))
		picture.toggled.connect(func(on: bool) -> void:
			if on:
				_pick(name))
		picture.gui_input.connect(func(event: InputEvent) -> void:
			var press := event as InputEventMouseButton
			if press != null and press.double_click:
				_choose())
		%Layouts.add_child(picture)
	%Ok.pressed.connect(_choose)
	%Cancel.pressed.connect(close)
	closed.connect(queue_free)
	_select(layout)


## Opens as Slide Layout on [param current], the slide's layout: Reapply for that one, Apply for
## another, as PowerPoint 97 words them.
func as_slide_layout(current: String) -> void:
	%TitleBar.title = "Slide Layout"
	_current = current
	_select(current)


## Picks [param name] as if the player clicked its picture.
func pick(name: String) -> void:
	_select(name)


func _select(name: String) -> void:
	layout = name
	for picture: Button in %Layouts.get_children():
		picture.set_pressed_no_signal(picture.get_meta(&"layout") == name)
		picture.queue_redraw()
	%LayoutName.text = name
	_word_buttons()


func _pick(name: String) -> void:
	layout = name
	%LayoutName.text = name
	for picture: Button in %Layouts.get_children():
		picture.queue_redraw()
	_word_buttons()


func _word_buttons() -> void:
	if _current == "":
		return
	%Prompt.text = "Reapply the current master styles:" if layout == _current else "Change the layout of the slide to:"
	%Ok.text = "Reapply" if layout == _current else "Apply"


func _choose() -> void:
	chosen.emit(layout)
	close()


# A small slide with a drop shadow and grey bars where the layout's placeholders are, as New Slide
# draws it; the picked one is framed in navy.
func _draw_layout(picture: Button, name: String) -> void:
	var page := Rect2(Vector2(8, 6), Vector2(48, 38))
	if picture.button_pressed:
		picture.draw_rect(page.grow(4), Color("#000080"), false, 3.0)
	picture.draw_rect(Rect2(page.position + Vector2(2, 2), page.size), Color.BLACK)
	picture.draw_rect(page, Color.WHITE)
	picture.draw_rect(page, Color.BLACK, false)
	var places: Array = SlideView.PLACES.get(name, [])
	for i in places.size():
		var place: Rect2 = places[i]
		var rect := Rect2(page.position + place.position * page.size, place.size * page.size)
		if i == 0:
			picture.draw_rect(Rect2(rect.position + Vector2(2, rect.size.y * 0.3), Vector2(rect.size.x - 4, 3)), Color(0.5, 0.5, 0.5))
		elif name == "Title Slide":
			picture.draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.25, 2), Vector2(rect.size.x * 0.5, 3)), Color(0.5, 0.5, 0.5))
		else:
			picture.draw_rect(rect.grow(-1), Color(0.5, 0.5, 0.5), false)
			for row in 4:
				var y := rect.position.y + 3 + row * 4
				picture.draw_rect(Rect2(Vector2(rect.position.x + 2, y), Vector2(1, 1)), Color.BLACK)
				picture.draw_rect(Rect2(Vector2(rect.position.x + 5, y), Vector2(rect.size.x - 8, 1)), Color(0.5, 0.5, 0.5))
