class_name RichDocument
extends RefCounted
## A formatted document as Word and WordPad edit it: paragraphs of text, each with its alignment,
## where every character has its own format: bold, italic, underline and a size. Positions are
## Vector2i(paragraph, column); column 0 is before the first character. Win95 files store it as RTF
## (Rtf).

enum Align { LEFT, CENTER, RIGHT, JUSTIFY }

## The format bits; a format also holds its size in half points, from bit SIZE_SHIFT on.
const BOLD := 1
const ITALIC := 2
const UNDERLINE := 4
const SIZE_SHIFT := 8
## Times New Roman 10 pt, plain: what Word 97 and WordPad type in a new document.
const DEFAULT_FORMAT := 20 << SIZE_SHIFT


## One paragraph: its text, one format per character, and its alignment.
class Paragraph:
	var text: String = ""
	var formats: PackedInt32Array = []
	var align: Align = Align.LEFT
	## The format of a character typed at the end, used while the paragraph is empty.
	var end_format: int = DEFAULT_FORMAT

	func copy() -> Paragraph:
		var other := Paragraph.new()
		other.text = text
		other.formats = formats.duplicate()
		other.align = align
		other.end_format = end_format
		return other


var paragraphs: Array[Paragraph] = [Paragraph.new()]


## The format with these settings; [param half_points] is the size in half points (20 is 10 pt).
static func make_format(bold: bool, italic: bool, underline: bool, half_points: int) -> int:
	return (BOLD if bold else 0) | (ITALIC if italic else 0) | (UNDERLINE if underline else 0) | (half_points << SIZE_SHIFT)


## The size of [param format] in half points.
static func half_points(format: int) -> int:
	return format >> SIZE_SHIFT


## [param format] with its size set to [param half_points].
static func with_size(format: int, half_points_: int) -> int:
	return (format & ((1 << SIZE_SHIFT) - 1)) | (half_points_ << SIZE_SHIFT)


## A document of [param text], one paragraph per line, all in [param format].
static func from_plain(text: String, format: int = DEFAULT_FORMAT) -> RichDocument:
	var document := RichDocument.new()
	document.insert(Vector2i.ZERO, text.replace("\r\n", "\n"), format)
	return document


## A copy that edits don't share.
func copy() -> RichDocument:
	var other := RichDocument.new()
	other.paragraphs.clear()
	for paragraph: Paragraph in paragraphs:
		other.paragraphs.append(paragraph.copy())
	return other


## The text without formatting, one line per paragraph.
func plain_text() -> String:
	return "\n".join(paragraphs.map(func(p: Paragraph) -> String: return p.text))


## The text from [param from] to [param to], one line per paragraph break.
func text_between(from: Vector2i, to: Vector2i) -> String:
	var a := mini_pos(from, to)
	var b := maxi_pos(from, to)
	if a.x == b.x:
		return paragraphs[a.x].text.substr(a.y, b.y - a.y)
	var parts: Array[String] = [paragraphs[a.x].text.substr(a.y)]
	for i: int in range(a.x + 1, b.x):
		parts.append(paragraphs[i].text)
	parts.append(paragraphs[b.x].text.substr(0, b.y))
	return "\n".join(parts)


## The position at the end of the document.
func end() -> Vector2i:
	return Vector2i(paragraphs.size() - 1, paragraphs[-1].text.length())


## [param at] moved into the document: a paragraph that exists, a column within it.
func clamp_pos(at: Vector2i) -> Vector2i:
	var row := clampi(at.x, 0, paragraphs.size() - 1)
	return Vector2i(row, clampi(at.y, 0, paragraphs[row].text.length()))


## The format that a character typed at [param at] takes: that of the character before it, or of the
## first one in the paragraph, or the paragraph's end format while it is empty.
func format_at(at: Vector2i) -> int:
	var paragraph := paragraphs[at.x]
	if paragraph.formats.is_empty():
		return paragraph.end_format
	return paragraph.formats[clampi(at.y - 1, 0, paragraph.formats.size() - 1)]


## Inserts [param text] at [param at] in [param format]; a "\n" starts a new paragraph, aligned as
## the one that it splits. Returns the position after the inserted text.
func insert(at: Vector2i, text: String, format: int) -> Vector2i:
	var pos := clamp_pos(at)
	var lines := text.split("\n")
	var paragraph := paragraphs[pos.x]
	var tail_text := paragraph.text.substr(pos.y)
	var tail_formats := paragraph.formats.slice(pos.y)
	paragraph.text = paragraph.text.substr(0, pos.y)
	paragraph.formats = paragraph.formats.slice(0, pos.y)
	for i: int in lines.size():
		if i > 0:
			var next := Paragraph.new()
			next.align = paragraph.align
			next.end_format = format
			paragraphs.insert(pos.x + i, next)
			paragraph = next
		paragraph.text += lines[i]
		for c: int in lines[i].length():
			paragraph.formats.append(format)
		if lines[i] != "":
			paragraph.end_format = format
	var after := Vector2i(pos.x + lines.size() - 1, paragraph.text.length())
	paragraph.text += tail_text
	paragraph.formats.append_array(tail_formats)
	return after


## Deletes the text between [param from] and [param to], in either order, joining their paragraphs.
## Returns the start of the deleted range.
func delete(from: Vector2i, to: Vector2i) -> Vector2i:
	var a := clamp_pos(mini_pos(from, to))
	var b := clamp_pos(maxi_pos(from, to))
	var first := paragraphs[a.x]
	var last := paragraphs[b.x]
	var kept_format := first.formats[a.y] if a.y < first.formats.size() else first.end_format
	first.text = first.text.substr(0, a.y) + last.text.substr(b.y)
	first.formats = first.formats.slice(0, a.y) + last.formats.slice(b.y)
	for i: int in b.x - a.x:
		paragraphs.remove_at(a.x + 1)
	if first.text.is_empty():
		first.end_format = kept_format
	return a


## Sets the format bits in [param mask] to [param on] for the characters from [param from] to
## [param to]; an empty paragraph in the range gets them on its end format.
func set_bits(from: Vector2i, to: Vector2i, mask: int, on: bool) -> void:
	_each_format(from, to, func(format: int) -> int: return (format | mask) if on else (format & ~mask))


## Sets the size of the characters from [param from] to [param to] to [param half_points_].
func set_size(from: Vector2i, to: Vector2i, half_points_: int) -> void:
	_each_format(from, to, func(format: int) -> int: return with_size(format, half_points_))


## True when every character from [param from] to [param to] has all of [param mask]'s bits; with
## an empty range, the format at [param from].
func all_have(from: Vector2i, to: Vector2i, mask: int) -> bool:
	var a := mini_pos(from, to)
	var b := maxi_pos(from, to)
	if a == b:
		return format_at(a) & mask == mask
	for row: int in range(a.x, b.x + 1):
		var paragraph := paragraphs[row]
		var start := a.y if row == a.x else 0
		var stop := b.y if row == b.x else paragraph.text.length()
		for column: int in range(start, stop):
			if paragraph.formats[column] & mask != mask:
				return false
	return true


## Aligns the paragraphs from [param from] to [param to].
func set_align(from: Vector2i, to: Vector2i, align: Align) -> void:
	for row: int in range(mini(from.x, to.x), maxi(from.x, to.x) + 1):
		paragraphs[row].align = align


## The earlier of two positions.
static func mini_pos(a: Vector2i, b: Vector2i) -> Vector2i:
	return a if a.x < b.x or (a.x == b.x and a.y <= b.y) else b


## The later of two positions.
static func maxi_pos(a: Vector2i, b: Vector2i) -> Vector2i:
	return b if mini_pos(a, b) == a else a


func _each_format(from: Vector2i, to: Vector2i, change: Callable) -> void:
	var a := mini_pos(from, to)
	var b := maxi_pos(from, to)
	for row: int in range(a.x, b.x + 1):
		var paragraph := paragraphs[row]
		var start := a.y if row == a.x else 0
		var stop := b.y if row == b.x else paragraph.text.length()
		for column: int in range(start, stop):
			paragraph.formats[column] = change.call(paragraph.formats[column])
		if paragraph.text.is_empty() or stop == paragraph.text.length():
			paragraph.end_format = change.call(paragraph.end_format)
