class_name PopupCatcher
extends Control
## Closes a popup on a click anywhere outside it, as Win95 menus close. An embedded popup doesn't
## do that by itself. The catcher covers its host under the popup, eats the click, and goes away
## with the popup. A right-click outside closes the popup and goes on to what is under it, so the
## desktop's menu opens in the same click, as in Win95.


## Covers [param host] while [param popup] is open; call it just before popup().
static func attach(popup: Popup, host: Control) -> void:
	var catcher := PopupCatcher.new()
	catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	catcher.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			catcher.accept_event()
			popup.hide())
	var pass_on := func(event: InputEvent) -> void: catcher._pass_on(popup, event)
	popup.window_input.connect(pass_on)
	popup.popup_hide.connect(func() -> void:
		popup.window_input.disconnect(pass_on)
		catcher.queue_free(), CONNECT_ONE_SHOT)
	host.add_child(catcher)
	catcher.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


# The focused popup gets every press, also outside it, so a right-click never reaches the catcher.
func _pass_on(popup: Popup, event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null or not button.pressed or button.button_index != MOUSE_BUTTON_RIGHT \
			or Rect2(Vector2.ZERO, popup.size).has_point(button.position):
		return
	mouse_filter = MOUSE_FILTER_IGNORE
	popup.hide()
	get_viewport().push_input(button.xformed_by(Transform2D(0.0, Vector2(popup.position))), true)
