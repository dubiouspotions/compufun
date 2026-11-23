extends "res://tests/test.gd"
## Display Properties: Background lists (None), the stock wallpapers and the .bmp pictures in
## C:\WINDOWS, and Apply sets the wallpaper; Appearance applies a scheme; a SettingCheck on the
## wallpaper reports the fix; a palette emits changed only when a colour changes.

const COMPUTER_STATE_PATH := "res://win95/computer_state.gd"  # loaded at run time: it names the Game autoload
const STOCK := ["Black Thatch", "Blue Rivets", "Bubbles", "Carved Stone", "Circles", "Houndstooth",
	"Pinstripe", "Setup", "Straw Mat", "Tiles", "Triangles", "Waves"]


func run() -> void:
	var red_blocks: Texture2D = load("res://win95/wallpapers/red_blocks.png")
	var castle := file("castle_01.bmp")
	castle.picture = ImageTexture.create_from_image(Image.create_empty(8, 8, false, Image.FORMAT_RGB8))
	var short := file("REDBLK.BMP")
	short.picture = ImageTexture.create_from_image(Image.create_empty(8, 8, false, Image.FORMAT_RGB8))
	var windows := folder("WINDOWS", [load("res://win95/system_stock.tres"), castle, short, file("blank.bmp"), file("setup.txt")])
	var computer := Computer.new()
	computer.win95_setup = Win95Setup.new()
	computer.win95_setup.drive_c = [windows]
	computer.win95_setup.wallpaper = red_blocks

	var ugly := SettingCheck.new()
	ugly.setting = &"wallpaper"
	ugly.broken_value = red_blocks
	var job := Job.new(customer(computer), software_problem(ugly), 0, 0)
	game.jobs = [job] as Array[Job]
	var state: Node = load(COMPUTER_STATE_PATH).new()
	state.job = job
	root.add_child(state)
	await process_frame  # _ready waits for the first frame under -s
	var setup: Win95Setup = state.setup
	var desktop: Control = load("res://win95/desktop.gd").new()  # loaded at run time, like ComputerState
	desktop.computer = state
	root.add_child(desktop)

	var display: Applet = load("res://win95/applets/display.tres")
	var sheet := open(desktop, display)
	var tabs: TabContainer = sheet.get_node("%Tabs")
	check("four tabs", range(tabs.get_tab_count()).map(func(i: int) -> String: return tabs.get_tab_title(i)), ["Background", "Screen Saver", "Appearance", "Settings"])
	var list: ItemList = sheet.find_child("Wallpapers", true, false)
	var names: Array = range(list.item_count).map(func(i: int) -> String: return list.get_item_text(i))
	var expected: Array = STOCK + ["castle_01", "Redblk", "Red Blocks"]
	expected.sort_custom(func(a: String, b: String) -> bool: return a.naturalnocasecmp_to(b) < 0)
	check("(None), the stock wallpapers, the .bmp pictures in C:\\WINDOWS and the current one", names, ["(None)"] + expected)
	check("the current wallpaper is selected", list.get_item_text(list.get_selected_items()[0]), "Red Blocks")
	check("broken at boot", job.software_fixed, false)

	choose(list, "castle_01")
	var apply_button: Button = sheet.get_node("%Apply")
	check("choosing enables Apply", apply_button.disabled, false)
	apply_button.pressed.emit()
	check("Apply sets the picture as the wallpaper", setup.wallpaper, setup.file_at("C:\\WINDOWS\\castle_01.bmp").picture)
	check("and the SettingCheck reports the fix", job.software_fixed, true)
	choose(list, "(None)")
	apply_button.pressed.emit()
	check("(None) clears the wallpaper", setup.wallpaper, null)
	close(sheet)

	sheet = open(desktop, display)
	list = sheet.find_child("Wallpapers", true, false)
	check("an empty wallpaper selects (None)", list.get_selected_items(), PackedInt32Array([0]))
	check("Red Blocks leaves the list once it isn't the wallpaper", range(list.item_count).any(func(i: int) -> bool: return list.get_item_text(i) == "Red Blocks"), false)
	var scheme: OptionButton = sheet.find_child("Scheme", true, false)
	check("the stock palette shows Windows Standard", scheme.get_item_text(scheme.selected), "Windows Standard")
	check("27 schemes", scheme.item_count, 27)
	var rose := index_of(scheme, "Rose")
	scheme.select(rose)
	scheme.item_selected.emit(rose)
	(sheet.get_node("%Ok") as Button).pressed.emit()
	check("OK applies the scheme", setup.palette.resource_name, "Rose")
	check("and keeps the wallpaper", setup.wallpaper, null)
	await process_frame

	var odd := Win95Palette.new()
	odd.face_color = Color.RED
	var emits := [0]
	odd.changed.connect(func() -> void: emits[0] += 1)
	odd.face_color = Color.RED
	check("a palette set to the colour it has emits no change", emits[0], 0)

	var hc: Win95Palette = load("res://win95/theme/schemes/high_contrast_black.tres")
	var theme := (load("res://win95/win95.tres") as Theme).duplicate(true) as Theme
	hc.paint(theme)
	check("High Contrast Black paints the labels white", theme.get_color(&"font_color", &"Label"), Color.WHITE)
	check("and the title bar purple", (theme.get_stylebox(&"panel", &"TitleBar") as StyleBoxFlat).bg_color, hc.active_title_color)
	var glyphs := hc.atlas().get_image()
	check("and the check box's inside black", glyphs.get_pixel(48, 3), Color.BLACK)
	check("and its glyphs white", glyphs.get_pixel(54, 33), Color.WHITE)
	setup.palette = odd
	sheet = open(desktop, display)
	scheme = sheet.find_child("Scheme", true, false)
	check("a palette that is no scheme leaves the box empty", scheme.selected, -1)
	close(sheet)

	desktop.free()
	state.free()
	game.jobs = [] as Array[Job]


func open(desktop: Control, applet: Applet) -> Control:
	var sheet: Control = applet.sheet.instantiate()
	desktop.add_child(sheet)
	return sheet


func close(sheet: Control) -> void:
	(sheet.get_node("%Cancel") as Button).pressed.emit()


func choose(list: ItemList, item: String) -> void:
	for i in list.item_count:
		if list.get_item_text(i) == item:
			list.select(i)
			list.item_selected.emit(i)
			return
	push_error("no %s in the wallpaper list" % item)


func index_of(box: OptionButton, item: String) -> int:
	for i in box.item_count:
		if box.get_item_text(i) == item:
			return i
	return -1


func customer(computer: Computer) -> Customer:
	var c := Customer.new()
	c.computer = computer
	return c


func file(file_name: String) -> Win95File:
	var f := Win95File.new()
	f.name = file_name
	return f


func folder(folder_name: String, children: Array[Resource]) -> Win95File:
	var f := Win95File.new()
	f.name = folder_name
	f.is_folder = true
	f.children = children
	return f
