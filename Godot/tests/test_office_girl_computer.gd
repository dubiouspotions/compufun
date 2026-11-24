extends "res://tests/test.gd"
## The office girl's computer is her own, not a copy of the young entrepreneur's, and her inverted
## colours (day 3) still break it and a new scheme still fixes it. Display Properties lists her own
## wallpaper as "Flowers & Hearts", also under the desktop prank (day 5), and it fixes the prank.

const DISPLAY_BACKGROUND := "res://win95/applets/display_background.gd"


func run() -> void:
	var sam: Customer = load("res://customers/office_girl.tres")
	var nick: Customer = load("res://customers/young_entrepreneur.tres")
	var hers := sam.computer.win95_setup
	var his := nick.computer.win95_setup
	check("registered to her", hers.registered_owner, sam.person.name)
	check("her own wallpaper, scheme and product id", [hers.wallpaper == his.wallpaper, hers.palette == his.palette, hers.product_id == his.product_id], [false, false, false])
	var names := func(files: Array[Win95File]) -> Array: return files.map(func(file: Win95File) -> String: return file.name)
	var shared: Array = names.call(hers.desktop).filter(func(file_name: String) -> bool: return file_name in names.call(his.desktop))
	check("no desktop file of his", shared, [])
	check("her own hardware", sam.computer.hardware.bios_id == nick.computer.hardware.bios_id, false)

	var inverted: Problem = load("res://problems/inverted_colors.tres")
	var running := hers.copy()
	check("her scheme isn't the broken one", inverted.software_check.is_fixed(running), true)
	inverted.software_check.apply_break(running)
	check("the break inverts her colours", inverted.software_check.is_fixed(running), false)
	running.palette = hers.palette
	check("her own scheme fixes it", inverted.software_check.is_fixed(running), true)

	var display: Node = load(DISPLAY_BACKGROUND).new()
	var listed: Dictionary = display.call(&"wallpapers", hers)
	check("her wallpaper is listed once, as Flowers & Hearts", [listed.get("Flowers & Hearts") == hers.wallpaper, listed.values().count(hers.wallpaper)], [true, 1])
	var prank: Problem = load("res://problems/desktop_prank.tres")
	var pranked := hers.copy()
	prank.software_check.apply_break(pranked)
	listed = display.call(&"wallpapers", pranked)
	check("under the prank it is still listed", [listed.get("Flowers & Hearts") == hers.wallpaper, listed.has("prank")], [true, true])
	pranked.wallpaper = listed["Flowers & Hearts"]
	for folder: Win95File in pranked.desktop.duplicate():
		pranked.desktop.append_array(folder.children)
		pranked.desktop.erase(folder)
	check("Flowers & Hearts and the icons back fix the prank", prank.software_check.is_fixed(pranked), true)
	display.free()
