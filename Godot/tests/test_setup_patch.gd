extends "res://tests/test.gd"
## Setup patches (SetupPatch): the patch between two setups makes one into the other, also through
## its text; a patch converges on what the player did; a picture without a file is refused; and the
## patches of a customer's errands go on once each, in errand code order, a reset starting again.


func run() -> void:
	var office_girl: Customer = load("res://customers/office_girl.tres")
	var before := office_girl.computer.win95_setup.copy()
	var after := office_girl.computer.win95_setup.copy()
	after.volume = 41.0
	after.muted = true
	after.wallpaper = load("res://win95/wallpapers/bubbles.png")
	var letter := Win95File.new()
	letter.name = "letter.txt"
	letter.contents = "Dear Kent,\n\n\tthe printer jams again.\n"
	letter.modified = "Tuesday, May 28, 1996 9:14:02 PM"
	var docs := Win95File.new()
	docs.name = "Letters"
	docs.is_folder = true
	docs.children.append(letter)
	after.drive_c.append(docs)
	after.desktop[0].desktop_position = Vector2(300, 200)
	var gone := after.desktop.pop_back() as Win95File
	after.emails[0].read = not after.emails[0].read
	after.emails[0].folder = Email.Folder.TRASH
	var mail := Email.new()
	mail.from = "Kent <kent@modemlandia.se>"
	mail.subject = "Lunch?"
	mail.sent = "1996-05-30 11:02"
	mail.body = "Friday at noon.\nKent"
	var typing := Email.new()  # a text being typed: it ends in a space or a line break
	typing.subject = "Draft"
	typing.sent = "1996-05-30 11:05"
	typing.body = "the "
	after.emails.append(typing)
	var quoting := typing.duplicate() as Email
	quoting.subject = "\"Quoted\""
	quoting.body = "Dear Kent,\n\n"
	after.emails.append(quoting)
	after.emails.append(mail)

	var made: Variant = SetupPatch.between(before, after)
	check("a patch comes between two setups", made is SetupPatch, true)
	var patch: SetupPatch = made
	check("it deletes the desktop icon that went", patch.deleted, PackedStringArray(["Desktop\\" + gone.name]))
	check("it sets what changed", patch.settings.keys(), [&"wallpaper", &"volume", &"muted"])
	var text := patch.write()
	var moved := "file Desktop\\%s\n\tdesktop_position: Vector2(300, 200)\n" % after.desktop[0].name
	check("a moved icon says only where it stands", text.contains(moved), true)
	var parsed := SetupPatch.parse(text, "test.setup")
	check("its text reads back without errors", parsed.errors, PackedStringArray())
	check("and writes the same text", (parsed.value as SetupPatch).write(), text)
	var patched := office_girl.computer.win95_setup.copy()
	(parsed.value as SetupPatch).apply(patched)
	var left: SetupPatch = SetupPatch.between(patched, after)
	check("the read patch makes the setup into the other: nothing left between them", left.write(), "\n")
	check("texts with a space or line break at an end, or a leading quote, read back as they were", patched.emails.filter(func(m: Email) -> bool: return m.subject in ["Draft", "\"Quoted\""]).map(func(m: Email) -> Array: return [m.subject, m.body]), [["Draft", "the "], ["\"Quoted\"", "Dear Kent,\n\n"]])
	check("the letter keeps its tab and its last line break", patched.file_at("C:\\Letters\\letter.txt").contents, letter.contents)

	var converging := SetupPatch.parse("delete Desktop\\gone.txt\nfile C:\\New Folder\\Deep\\a.txt\n\tcontents: hi\n", "test.setup")
	check("converging patch reads", converging.errors, PackedStringArray())
	(converging.value as SetupPatch).apply(patched)
	check("deleting what is gone is fine; a missing folder is made", patched.file_at("C:\\New Folder\\Deep\\a.txt").contents, "hi")

	var drawn := Win95File.new()
	drawn.name = "cat.bmp"
	drawn.picture = ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGB8))
	after.desktop.append(drawn)
	var refused: Variant = SetupPatch.between(before, after)
	check("a picture that no file holds is refused, by name", refused is String and (refused as String).contains("cat.bmp"), true)

	var bad := SetupPatch.parse("set loudness: 3\nfile D:\\x\nmail\n\tfolder: attic\nset volume: 50\nreset\n", "bad.setup")
	check("bad lines are each named", bad.errors.size(), 4)
	check("an int volume reads as a float", (bad.value as SetupPatch).settings.get(&"volume"), 50.0)

	var first := errand("0201", office_girl)
	var second := errand("0302", office_girl)
	var third := errand("0503", office_girl)
	var patches: Dictionary[String, SetupPatch] = {
		"office_girl": SetupPatch.parse("set volume: 10\n", "s").value,
		"0201_office_girl": SetupPatch.parse("set volume: 20\nset muted: true\n", "a").value,
		"0302_office_girl": SetupPatch.parse("reset\nset pointer_trails: 3\n", "b").value,
		"0503_office_girl": SetupPatch.parse("set volume: 50\n", "c").value,
	}
	var errands: Array[Errand] = [third, first, second]
	var running := SetupPatch.start(office_girl, patches)
	check("the start patch is on a new copy", running.volume, 10.0)
	SetupPatch.catch_up(running, office_girl, first, true, errands, patches)
	check("the first visit's patch", [running.volume, running.muted], [20.0, true])
	running.volume = 33.0
	SetupPatch.catch_up(running, office_girl, first, true, errands, patches)
	check("a patch goes on once", running.volume, 33.0)
	SetupPatch.catch_up(running, office_girl, second, false, errands, patches)
	check("before the second visit: nothing more", running.pointer_trails, 0)
	SetupPatch.catch_up(running, office_girl, third, true, errands, patches)
	check("a reset starts again from the start patch, then the later patches go on", [running.muted, running.pointer_trails, running.volume], [false, 3, 50.0])
	check("each errand is there once", running.patched, PackedStringArray(["0201_office_girl", "0302_office_girl", "0503_office_girl"]))


func errand(code: String, customer: Customer) -> Errand:
	var made := Errand.new()
	made.code = code
	made.customer = customer
	made.file = "res://story/errands/%s_%s.errand" % [code, SetupPatch.customer_name(customer)]
	return made
