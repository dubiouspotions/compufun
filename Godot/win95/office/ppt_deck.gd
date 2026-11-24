class_name PptDeck
extends RefCounted
## A PowerPoint presentation: its design and its slides. It reads and writes the plain text format
## of docs/ppt.md, which PowerPoint keeps in .ppt files.

## The AutoLayouts that the game builds, by their name in New Slide.
const LAYOUTS: PackedStringArray = ["Title Slide", "Bulleted List", "2 Column Text", "Title Only", "Blank"]
## The layout of a new slide after the first.
const DEFAULT_LAYOUT := "Bulleted List"


## One slide: its layout and the text of its placeholders.
class Slide:
	## One of [constant LAYOUTS].
	var layout := DEFAULT_LAYOUT
	## The title placeholder's text; lines apart by "\n". Blank has none.
	var title := ""
	## The body placeholder's paragraphs: the subtitle on Title Slide, the bullets on Bulleted List,
	## the left column on 2 Column Text. Title Only and Blank have none. A paragraph's leading tabs
	## are its outline level below the first: "\tRepeat" is a second-level bullet.
	var body: PackedStringArray = []
	## 2 Column Text's right column.
	var right: PackedStringArray = []

	func _init(slide_layout := DEFAULT_LAYOUT) -> void:
		layout = slide_layout

	## Whether the layout has a body placeholder.
	func has_body() -> bool:
		return layout in ["Title Slide", "Bulleted List", "2 Column Text"]

	## Whether the layout has a title placeholder.
	func has_title() -> bool:
		return layout != "Blank"


## The design template by its name in Apply Design, such as "High Voltage"; empty for the blank
## Default Design.
var design := ""
var slides: Array[Slide] = []
## The lines that [method parse] couldn't read, each with its line number.
var errors: PackedStringArray = []


## The presentation in [param text]. Lines it can't read are left out and listed in [member errors].
## Empty text is one Title Slide, as File > New makes it.
static func parse(text: String) -> PptDeck:
	var deck := PptDeck.new()
	var slide: Slide = null
	var number := 0
	for raw in text.split("\n"):
		number += 1
		var line := raw.strip_edges(false, true)
		if line.strip_edges() == "" or line.begins_with("#"):
			continue
		var colon := line.find(": ")
		var key := line.substr(0, colon) if colon > 0 else line.trim_suffix(":")
		var value := line.substr(colon + 2) if colon > 0 else ""
		match key:
			"design":
				deck.design = value
			"slide":
				if not LAYOUTS.has(value):
					deck.errors.append("line %d: no layout called '%s' (%s)" % [number, value, ", ".join(LAYOUTS)])
					value = DEFAULT_LAYOUT
				slide = Slide.new(value)
				deck.slides.append(slide)
			"title", "text", "right":
				if slide == null:
					deck.errors.append("line %d: '%s' before the first 'slide:'" % [number, key])
				elif key == "title":
					slide.title = value if slide.title == "" else slide.title + "\n" + value
				elif key == "text":
					slide.body.append(_level_in(value))
				else:
					slide.right.append(_level_in(value))
			_:
				deck.errors.append("line %d: '%s' is no design, slide, title, text or right line" % [number, line])
	if deck.slides.is_empty():
		deck.slides.append(Slide.new("Title Slide"))
	return deck


## The presentation in docs/ppt.md's format.
func to_text() -> String:
	var lines: PackedStringArray = []
	if design != "":
		lines.append("design: " + design)
	for slide in slides:
		if not lines.is_empty():
			lines.append("")
		lines.append("slide: " + slide.layout)
		for title_line in slide.title.split("\n", false):
			lines.append("title: " + title_line)
		for paragraph in slide.body:
			lines.append("text: " + _level_out(paragraph))
		for paragraph in slide.right:
			lines.append("right: " + _level_out(paragraph))
	return "\n".join(lines) + "\n"


# A file's paragraph: two leading spaces per level below the first, turned into tabs.
static func _level_in(value: String) -> String:
	var level := 0
	while value.substr(level * 2, 2) == "  ":
		level += 1
	return "\t".repeat(level) + value.substr(level * 2)


static func _level_out(paragraph: String) -> String:
	var level := 0
	while level < paragraph.length() and paragraph[level] == "\t":
		level += 1
	return "  ".repeat(level) + paragraph.substr(level)
