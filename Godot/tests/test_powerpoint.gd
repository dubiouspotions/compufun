extends "res://tests/test.gd"
## PowerPoint on a customer's computer: it is installed everywhere and takes .ppt; from its Start
## menu entry it opens with its start dialog and a first slide; slides are added, typed in, given a
## layout and a design, deleted and sorted; Slide Show plays them over the screen; a .ppt saves and
## opens again with its recent file and Properties.

const WIN95 := "res://win95/win95.tscn"  # loaded at run time: its scripts name the Game autoload
const POWERPOINT := "res://win95/office/powerpoint.tscn"
const POWERPNT_PATH := "C:\\Program Files\\Microsoft Office\\Office\\POWERPNT.EXE"


func run() -> void:
	for path in DirAccess.get_files_at("res://customers"):
		var customer := load("res://customers/" + path) as Customer if path.ends_with(".tres") else null
		if customer == null or customer.computer == null or customer.computer.win95_setup == null:
			continue
		var setup := customer.computer.win95_setup.copy()
		var program := setup.file_at(POWERPNT_PATH)
		check("%s has PowerPoint, in the Start menu too" % path, [program != null and program.program == load(POWERPOINT), setup.file_at("C:\\WINDOWS\\Start Menu\\Programs\\Microsoft PowerPoint").target], [true, POWERPNT_PATH])

	var customer: Customer = load("res://customers/office_girl.tres")
	var job := Job.new(customer, Problem.new(), 0, 0)
	job.powered = true
	var win95: Control = (load(WIN95) as PackedScene).instantiate()
	win95.get_node("ComputerState").job = job
	root.add_child(win95)
	await process_frame
	var boot: Node = win95.get("_boot")
	if is_instance_valid(boot):
		await boot.finished
		await create_timer(1.0).timeout  # the boot plays the startup sound after finished
	var state: Node = win95.get_node("ComputerState")
	var desktop: Node = win95.get_node("Desktop")
	check(".ppt opens in PowerPoint", state.programs_for("ppt")[0].name, "POWERPNT.EXE")
	check("her Shortcut Bar has PowerPoint", state.tasks()[0].button("Microsoft PowerPoint") != null, true)

	win95.open_file(state.setup.file_at("C:\\WINDOWS\\Start Menu\\Programs\\Microsoft PowerPoint"))
	await process_frame
	var start: Control = desktop.active_window()
	var ppt: Control = null
	for window: Control in desktop.windows():
		if window.scene_file_path == POWERPOINT:
			ppt = window
	check("the Start menu opens PowerPoint, titled as 97 titles it", ppt.get_node("%TitleBar").title if ppt != null else "", "Microsoft PowerPoint - [Presentation1]")
	check("with its start dialog in front", start.get_node("%TitleBar").title, "PowerPoint")
	start.get_node("%Blank").button_pressed = true
	start.get_node("%Ok").pressed.emit()
	await process_frame
	var picker: Control = desktop.active_window()
	check("Blank presentation asks for the first slide's layout", [picker.get_node("%TitleBar").title, picker.layout], ["New Slide", "Title Slide"])
	picker.get_node("%Ok").pressed.emit()
	await process_frame
	check("one Title Slide", ppt.deck.slides.map(func(s: PptDeck.Slide) -> String: return s.layout), ["Title Slide"])
	check("the status bar", [ppt.get("_slide_cell").text, ppt.get("_design_cell").text], ["Slide 1 of 1", "Default Design"])

	var view: SlideView = ppt.get_node("%Slide")
	view.edit(0)
	var editor: TextEdit = view.find_children("*", "TextEdit", false, false)[0]
	editor.text = "Harbour Import AB"
	editor.text_changed.emit()
	check("typing in a placeholder fills the slide", ppt.deck.slides[0].title, "Harbour Import AB")
	view.stop_editing()

	ppt.new_slide_dialog()
	picker = desktop.active_window()
	check("New Slide offers Bulleted List after the first", picker.layout, "Bulleted List")
	picker.get_node("%Ok").pressed.emit()
	await process_frame
	ppt.deck.slides[1].title = "The plan"
	ppt.deck.slides[1].body = PackedStringArray(["Buy cheap", "\tRepeat"])
	ppt.add_slide("Title Only")
	check("three slides, the newest on show", [ppt.deck.slides.size(), ppt.current, ppt.get("_slide_cell").text], [3, 2, "Slide 3 of 3"])
	ppt.layout_dialog()
	picker = desktop.active_window()
	check("Slide Layout opens on the slide's layout, to reapply", [picker.get_node("%TitleBar").title, picker.layout, picker.get_node("%Ok").text, picker.get_node("%Prompt").text], ["Slide Layout", "Title Only", "Reapply", "Reapply the current master styles:"])
	picker.pick("Blank")
	check("another layout applies", [picker.get_node("%Ok").text, picker.get_node("%Prompt").text], ["Apply", "Change the layout of the slide to:"])
	picker.chosen.emit("Blank")
	picker.close()
	check("and changes it", ppt.deck.slides[2].layout, "Blank")
	ppt.delete_slide()
	check("Delete Slide", [ppt.deck.slides.size(), ppt.current], [2, 1])

	ppt.design_dialog()
	var designs: Control = desktop.active_window()
	designs.get_node("%Designs").select(2)
	designs.get_node("%Apply").pressed.emit()
	check("Apply Design", [ppt.deck.design, ppt.get("_design_cell").text, ppt.design() != null and ppt.design().background != null], ["Fireball", "Fireball", true])

	ppt.show_view(1)
	check("Slide Sorter shows a numbered thumbnail per slide", [ppt.get_node("%Sorter").visible, ppt.get_node("%Slides").get_child_count()], [true, 2])
	ppt.show_view(0)

	ppt.go_to(0)
	var show: Control = ppt.slide_show()
	check("Slide Show covers the screen from the current slide", [show.get_parent() == win95, show.at, show.get_node("%Slide").slide.title], [true, 0, "Harbour Import AB"])
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	show.call(&"_gui_input", click)
	check("a click goes to the next slide", show.at, 1)
	show.call(&"_gui_input", click)
	await process_frame
	check("past the last slide the show ends, back on that slide", [is_instance_valid(show), ppt.current], [false, 1])
	show = ppt.slide_show()
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	show.call(&"_gui_input", escape)
	await process_frame
	check("Esc ends it", is_instance_valid(show), false)

	var file := Win95File.new()
	file.name = "Pitch.ppt"
	state.setup.file_at("C:\\My Documents").children.append(file)
	ppt.open_file(file, state)
	check("an empty .ppt opens as one Title Slide, titled without its extension", [ppt.deck.slides.size(), ppt.get_node("%TitleBar").title], [1, "Microsoft PowerPoint - [Pitch]"])
	ppt.deck = PptDeck.parse("design: Dadstie\nslide: Title Slide\ntitle: Pitch\n")
	ppt.save()
	check("Save writes the text format", file.contents, "design: Dadstie\n\nslide: Title Slide\ntitle: Pitch\n")
	var file_menu: PopupMenu = ppt.get_node("%File")
	file_menu.about_to_popup.emit()
	var items: Array[String] = []
	for i in file_menu.item_count:
		items.append(file_menu.get_item_text(i))
	check("the File menu lists it", items.has("1 Pitch"), true)
	ppt.show_properties()
	check("Properties: no Template row", [ppt.blocked_by.get_node("%TitleBar").title, ppt.blocked_by.get_node("%Template").visible], ["Pitch Properties", false])

	root.remove_child(win95)
	win95.free()
