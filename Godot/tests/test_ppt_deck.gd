extends "res://tests/test.gd"
## PowerPoint's .ppt text format (docs/ppt.md): it reads slides, layouts and placeholders, reports
## the lines it can't read, and writes back what it read.


func run() -> void:
	var text := "# a comment\ndesign: High Voltage\n\nslide: Title Slide\ntitle: Harbour Import AB\ntext: Midsummer 1996\n\nslide: 2 Column Text\ntitle: Two\ntitle: lines\ntext: left\nright: right one\nright: right two\n"
	var deck := PptDeck.parse(text)
	check("the design", deck.design, "High Voltage")
	check("two slides with their layouts", deck.slides.map(func(s: PptDeck.Slide) -> String: return s.layout), ["Title Slide", "2 Column Text"])
	check("the title slide's placeholders", [deck.slides[0].title, deck.slides[0].body], ["Harbour Import AB", PackedStringArray(["Midsummer 1996"])])
	check("a two-line title and both columns", [deck.slides[1].title, deck.slides[1].body, deck.slides[1].right], ["Two\nlines", PackedStringArray(["left"]), PackedStringArray(["right one", "right two"])])
	check("no errors", deck.errors, PackedStringArray())
	check("it writes back what it read, comments aside", PptDeck.parse(deck.to_text()).to_text(), deck.to_text())
	check("the written text", deck.to_text(), "design: High Voltage\n\nslide: Title Slide\ntitle: Harbour Import AB\ntext: Midsummer 1996\n\nslide: 2 Column Text\ntitle: Two\ntitle: lines\ntext: left\nright: right one\nright: right two\n")

	var bad := PptDeck.parse("text: early\nslide: Org Chart\ntitle: x\nbullet: y\n")
	check("an unknown layout becomes a Bulleted List", bad.slides[0].layout, "Bulleted List")
	check("each line it can't read is named", bad.errors.size(), 3)
	check("with its line number", bad.errors[0].begins_with("line 1:"), true)
	check("an empty file is one Title Slide", PptDeck.parse("").slides.map(func(s: PptDeck.Slide) -> String: return s.layout), ["Title Slide"])
