extends "res://tests/test.gd"
## The MS-DOS Prompt's short 8.3 names, and the dates that DIR reads from Properties' format.

const PROMPT := preload("res://win95/ms_dos_prompt.gd")


func run() -> void:
	var taken := {}
	check("an 8.3 name stays", PROMPT.short_name("NOTEPAD.EXE", taken), "NOTEPAD.EXE")
	check("lower case goes up", PROMPT.short_name("todo.txt", taken), "TODO.TXT")
	check("spaces go, ~1 marks it", PROMPT.short_name("taxes 1995.txt", taken), "TAXES1~1.TXT")
	check("a long folder name", PROMPT.short_name("Start Menu", taken), "STARTM~1")
	check("the next one counts up", PROMPT.short_name("castle_01.bmp", taken), "CASTLE~1.BMP")
	check("and again", PROMPT.short_name("castle_02.bmp", taken), "CASTLE~2.BMP")
	var t := Win95Time.parse_long("Thursday, May 30, 1996 11:12:44 PM")
	check("long date", [t.year, t.month, t.day, t.hour, t.minute, t.second], [1996, 5, 30, 23, 12, 44])
	check("not a date", Win95Time.parse_long("yesterday"), {})
