extends "res://tests/test.gd"
## Each computer's BIOS screens come from its Hardware: the summary box stays square for every
## machine, and a VESA 486 shows no Plug and Play, PCI or DMI.


func run() -> void:
	var machines := {"default": Hardware.new()}
	for name in ["skater_bro", "young_entrepreneur"]:
		var customer: Customer = load("res://customers/%s.tres" % name)
		check("%s has hardware" % name, customer.computer.hardware != null, true)
		machines[name] = customer.computer.hardware
	for name: String in machines:
		var hardware: Hardware = machines[name]
		var widths := {}
		for line in hardware.summary_lines():
			widths[line.length()] = true
		check("%s: the summary box is square" % name, widths.keys(), [76])
	var old_486: Hardware = machines["skater_bro"]
	var pentium: Hardware = machines["young_entrepreneur"]
	check("486: copyright year from the BIOS date", old_486.post_lines()[1], "Copyright (C) 1984-94, CompuFun Ltd.")
	check("486: no Plug and Play", "\n".join(old_486.post_lines()).contains("Plug and Play"), false)
	check("486: no PCI or DMI", old_486.boot_lines(), PackedStringArray())
	check("486: fast page memory", "\n".join(old_486.summary_lines()).contains("FP DRAM"), true)
	check("Pentium: Plug and Play", "\n".join(pentium.post_lines()).contains("Plug and Play"), true)
	check("1996 board: DMI check", pentium.boot_lines()[-1], "Verifying DMI Pool Data ........")
	check("1995 board: no DMI check", "\n".join(machines["default"].boot_lines()).contains("DMI"), false)
