extends "res://tests/test.gd"
## A right-click outside an open popup closes it and opens the menu of what is under the mouse, in
## the same click, as in Win95: from the Start menu, from one of its submenus, from the volume
## popup, and from another right-click menu. A left-click outside only closes the popup.


func run() -> void:
	var bench: Control = load("res://ui/bench_screen.tscn").instantiate()
	root.add_child(bench)
	await process_frame
	var job := Job.new(load("res://customers/skater_bro.tres"), load("res://problems/dust_overheat.tres"), 0, 0)
	game.jobs = [job] as Array[Job]
	game.set_powered(job, true)
	await process_frame
	game.connect_cable(job)
	var win95: Control = bench._desktops.get(job)
	var boot: Node = win95.get("_boot")
	boot.set(&"_skipped", true)
	await boot.finished
	await create_timer(0.5).timeout
	for window: Node in win95.get_node("Desktop").call(&"windows"):
		window.call(&"close")  # the Welcome window
	await process_frame

	var start: Button = win95.find_child("StartButton", true, false)
	var start_menu: Window = start.get_node("StartMenu")
	var context: Window = win95.get("_context")
	var empty := win95.get_global_rect().position + Vector2(600, 300)
	var away := win95.get_global_rect().position + Vector2(500, 150)  # clear of the menu that opens at empty

	start.button_pressed = true
	await process_frame
	check("the Start menu opens", start_menu.visible, true)
	await _click(win95, empty, MOUSE_BUTTON_RIGHT)
	check("a right-click on the desktop closes the Start menu", [start_menu.visible, start.button_pressed], [false, false])
	check("and opens the desktop's menu", [context.visible, _first(context)], [true, "Arrange Icons"])

	var icon: Control = win95.get("_icons").get_child(0)
	await _click(win95, icon.get_global_rect().get_center(), MOUSE_BUTTON_RIGHT)
	check("a right-click on an icon swaps the desktop's menu for the icon's", [context.visible, _first(context)], [true, "Open"])
	check("at the new click", context.position, Vector2i(icon.get_global_rect().get_center()))

	await _click(win95, away, MOUSE_BUTTON_LEFT)
	check("a left-click on the desktop closes the menu", context.visible, false)

	start.button_pressed = true
	await process_frame
	start_menu.call(&"_open_submenu", 0)
	await process_frame
	check("Programs opens", start_menu.get(&"_sub") != null and start_menu.get(&"_sub").visible, true)
	await _click(win95, empty, MOUSE_BUTTON_RIGHT)
	check("a right-click on the desktop from a submenu closes both", [start_menu.visible, start_menu.get(&"_sub").visible], [false, false])
	check("and opens the desktop's menu", context.visible, true)
	await _click(win95, away, MOUSE_BUTTON_LEFT)

	start.button_pressed = true
	await process_frame
	await _click(win95, away, MOUSE_BUTTON_LEFT)
	check("a left-click on the desktop closes the Start menu", start_menu.visible, false)
	check("and opens no menu", context.visible, false)

	var systray: Node = win95.get_node("%Systray")
	systray.call(&"_open_volume")
	var volume: Popup = systray.get("_popup")
	await process_frame
	check("the volume popup opens", volume.visible, true)
	await _click(win95, empty, MOUSE_BUTTON_RIGHT)
	check("a right-click on the desktop closes the volume popup and opens the desktop's menu", [volume.visible, context.visible], [false, true])

	game.jobs = [] as Array[Job]
	bench.free()


func _first(menu: Window) -> String:
	var entries: Array = menu.get(&"_entries")
	return entries[0].label if not entries.is_empty() else ""


func _click(win95: Control, at: Vector2, button: MouseButton) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = button
		event.pressed = pressed
		event.button_mask = (MOUSE_BUTTON_MASK_RIGHT if button == MOUSE_BUTTON_RIGHT else MOUSE_BUTTON_MASK_LEFT) if pressed else 0
		event.position = at
		event.global_position = at
		win95.get_viewport().push_input(event, true)
		await process_frame
