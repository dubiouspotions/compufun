class_name PopupCatcher
extends Control
## Closes a popup on a click anywhere outside it, as Win95 menus close. An embedded popup doesn't
## do that by itself. The catcher covers its host under the popup, eats the click, and goes away
## with the popup.


## Covers [param host] while [param popup] is open; call it just before popup().
static func attach(popup: Popup, host: Control) -> void:
	var catcher := PopupCatcher.new()
	catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	catcher.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			catcher.accept_event()
			popup.hide())
	popup.popup_hide.connect(catcher.queue_free, CONNECT_ONE_SHOT)
	host.add_child(catcher)
	catcher.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
