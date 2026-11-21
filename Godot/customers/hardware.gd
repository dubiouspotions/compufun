class_name Hardware
extends Resource
## What a computer's BIOS finds as it boots. The boot sequence builds its screens from it, so two
## computers boot differently. The defaults are a Pentium 100 on an Intel Triton board, late 1995.

## The BIOS maker, as the screens name it.
@export var bios_maker: String = "CompuFun"
## The BIOS version, after its name: v4.50G on a 486, v4.51PG with Plug and Play.
@export var bios_version: String = "v4.51PG"
## The BIOS id at the bottom of the POST: the BIOS date (MM/DD/YY), the chipset and the board.
## The date's year sets the copyright year; a year from 96 adds the DMI check.
@export var bios_id: String = "11/09/95-i430FX-2A59CF4BC-00"
## The CPU as the BIOS names it, such as "PENTIUM-S" or "486DX2".
@export var cpu: String = "PENTIUM-S"
@export var cpu_mhz: int = 100
## Kilobytes of memory: the first 640K are base memory, the rest extended.
@export var memory_kb: int = 16384
## Kilobytes of L2 cache; 0 is none.
@export var cache_kb: int = 256
## True for EDO memory, false for the older fast page mode.
@export var edo: bool = true
## The hard drive on the primary master, as it names itself; empty is none.
@export var hard_drive: String = "QUANTUM FIREBALL1080A"
@export var hard_drive_mb: int = 1033
## The CD-ROM drive on the secondary master, as it names itself; empty is none.
@export var cd_rom: String = "MITSUMI CD-ROM FX400"
## The PCI devices, one per line: device, function, vendor id, device id, IRQ (NA for none) and
## class. Empty is a VESA local bus board: no PCI and no Plug and Play.
@export var pci_devices: PackedStringArray = [
	"7 1 8086 1230 14 IDE Controller",
	"11 0 5333 8811 NA Display Controller",
]

const _WIDTH: int = 76


## The power-on self test, one line at a time, in BBCode. %MEMORY% is the memory test.
func post_lines() -> PackedStringArray:
	var lines: PackedStringArray = [
		"%s Modular BIOS %s%s" % [bios_maker, bios_version, ", An Energy Star Ally" if energy_star() else ""],
		"Copyright (C) 1984-%s, %s Ltd." % [_year(), bios_maker],
		"",
		"%s CPU at %dMHz" % [cpu, cpu_mhz],
		"%MEMORY%",
		"",
	]
	if not pci_devices.is_empty():
		lines.append_array([
			"%s Plug and Play BIOS Extension  v1.0A" % bios_maker,
			"Copyright (C) 19%s, %s Ltd." % [_year(), bios_maker],
		])
	lines.append_array([
		"   Detecting HDD Primary Master   ... %s" % _or_none(hard_drive),
		"   Detecting HDD Primary Slave    ... [Press [color=#ffffff]F4[/color] to skip]",
		"   Detecting HDD Secondary Master ... %s" % _or_none(cd_rom),
		"   Detecting HDD Secondary Slave  ... None",
	])
	return lines


## True for a BIOS from 1993 on, when Energy Star had begun: the POST shows its logo.
func energy_star() -> bool:
	return int(_year()) >= 93


## The lines at the bottom of the screen during the POST, in BBCode.
func footer_lines() -> PackedStringArray:
	return ["Press [color=#ffffff]DEL[/color] to enter SETUP", bios_id]


## The system summary that replaces the POST, all at once.
func summary_lines() -> PackedStringArray:
	var mode := 4 if not pci_devices.is_empty() else 3
	var disk := "None"
	if hard_drive != "":
		disk = "%s,Mode %d,%dMB" % ["LBA" if hard_drive_mb > 504 else "Normal", mode, hard_drive_mb]
	var line := "─".repeat(_WIDTH - 2)
	return [
		"┌" + line + "┐",
		"│" + _centre("System Configurations") + "│",
		"├" + line + "┤",
		_row("CPU Type         : " + cpu, "Base Memory      : %8dK" % 640),
		_row("Co-Processor     : Installed", "Extended Memory  : %8dK" % (memory_kb - 640)),
		_row("CPU Clock        : %dMHz" % cpu_mhz, "Cache Memory     : " + ("%8dK" % cache_kb if cache_kb > 0 else "    None")),
		"├" + line + "┤",
		_row("Diskette Drive A : 1.44M, 3.5 in.", "Display Type     : EGA/VGA"),
		_row("Diskette Drive B : None", "Serial Port(s)   : 3F8 2F8"),
		_row("Pri. Master Disk : " + disk, "Parallel Port(s) : 378"),
		_row("Pri. Slave  Disk : None", "%s Row(s)%s: %s" % ["EDO DRAM" if edo else "FP DRAM", " " if edo else "  ", "0 1"]),
		_row("Sec. Master Disk : " + ("CDROM,Mode %d" % mode if cd_rom != "" else "None"), "L2 Cache Type    : " + ("Pipeline Burst" if edo and cache_kb > 0 else "Asynchronous" if cache_kb > 0 else "None")),
		_row("Sec. Slave  Disk : None"),
		"└" + line + "┘",
	]


## The lines after the summary, before the boot: the PCI devices and the DMI check, if the board
## has them.
func boot_lines() -> PackedStringArray:
	var lines: PackedStringArray = []
	if pci_devices.is_empty():
		return lines
	var rule := "-".repeat(_WIDTH)
	lines.append_array(["", "PCI device listing.....", "Bus No. Device No. Func No. Vendor ID  Device ID  Device Class       IRQ", rule])
	for device in pci_devices:
		var f := device.split(" ", false, 5)
		if f.size() < 6:
			push_error("Hardware: the PCI device \"%s\" needs device, function, vendor, device id, IRQ and class" % device)
			continue
		lines.append("   0    %6s    %6s       %4s       %4s     %-18s %3s" % [f[0], f[1], f[2], f[3], f[5], f[4]])
	lines.append(rule)
	if int(_year()) >= 96:
		lines.append_array(["", "Verifying DMI Pool Data ........"])
	return lines


# The two digits of the year in bios_id, such as "95".
func _year() -> String:
	return bios_id.substr(6, 2)


func _or_none(device: String) -> String:
	return device if device != "" else "None"


func _row(left: String, right: String = "") -> String:
	return "│ " + (left.rpad(37) + right).rpad(_WIDTH - 4).left(_WIDTH - 4) + " │"


func _centre(text: String) -> String:
	var space := _WIDTH - 2 - text.length()
	return " ".repeat(space / 2) + text + " ".repeat(space - space / 2)
