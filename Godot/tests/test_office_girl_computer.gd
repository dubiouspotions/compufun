extends "res://tests/test.gd"
## The office girl's computer is her own, not a copy of the young entrepreneur's, and her inverted
## colours (day 3) still break it and a new scheme still fixes it.


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
