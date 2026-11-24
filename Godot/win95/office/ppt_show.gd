extends Control
## PowerPoint's Slide Show: the presentation's slides one at a time over the whole screen, taskbar
## too. A click, Space, Enter, N, Right, Down or Page Down goes to the next slide; Backspace, P,
## Left, Up or Page Up to the one before; Esc ends the show, and so does going past the last slide.

## The show ended; [param at] is the slide it ended on, from 0.
signal ended(at: int)

var deck: PptDeck
var designs: Array[PptDesign] = []
## The slide on show, from 0.
var at := 0

@onready var _view: SlideView = %Slide


## Shows [param shown] from slide [param from], in [param with_designs]' design by its name.
func start(shown: PptDeck, with_designs: Array[PptDesign], from := 0) -> void:
	deck = shown
	designs = with_designs
	at = clampi(from, 0, deck.slides.size() - 1)
	_show()
	grab_focus()


## The next slide, or the end after the last.
func next() -> void:
	if at + 1 >= deck.slides.size():
		finish()
	else:
		at += 1
		_show()


## The slide before, if there is one.
func previous() -> void:
	if at > 0:
		at -= 1
		_show()


## Ends the show.
func finish() -> void:
	if is_queued_for_deletion():
		return
	ended.emit(at)
	queue_free()


func _show() -> void:
	var design: PptDesign = null
	for candidate in designs:
		if candidate.name == deck.design:
			design = candidate
	_view.show_slide(deck.slides[at], design)


func _gui_input(event: InputEvent) -> void:
	var press := event as InputEventMouseButton
	if press != null and press.pressed:
		accept_event()
		if press.button_index == MOUSE_BUTTON_LEFT:
			next()
		return
	var key := event as InputEventKey
	if key == null or not key.pressed:
		return
	accept_event()
	match key.keycode:
		KEY_ESCAPE:
			finish()
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_N, KEY_RIGHT, KEY_DOWN, KEY_PAGEDOWN:
			next()
		KEY_BACKSPACE, KEY_P, KEY_LEFT, KEY_UP, KEY_PAGEUP:
			previous()
