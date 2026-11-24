class_name XlsSheet
extends RefCounted
## The worksheet of an Excel .xls file: its cells, their formatting and the column widths. It reads
## and writes the plain text cell format that docs/xls.md describes, and turns a cell's value into
## the text that the grid shows. Cells and columns count from 0: A1 is (0, 0), B3 is (1, 2).

## How a cell lines up its text. GENERAL puts numbers on the right and text on the left.
enum Align { GENERAL, LEFT, CENTER, RIGHT }
## How a cell shows a number. GENERAL shows it as typed, up to ten digits; the others round it to
## [member Cell.decimals] places. CURRENCY is "$1,234.50", as typing "$" makes it; ACCOUNTING is the
## Currency Style button's, with the "$" at the cell's left edge; COMMA is the Comma Style button's,
## ACCOUNTING without the "$".
enum Format { GENERAL, NUMBER, CURRENCY, ACCOUNTING, PERCENT, COMMA }

## Excel 97's columns, A to IV, and rows.
const COLUMNS := 256
const ROWS := 65536
## A column's width, in characters of Arial 10, when the file doesn't set it.
const STANDARD_WIDTH := 8.43

const _ALIGN_WORDS: Dictionary[String, Align] = {"left": Align.LEFT, "center": Align.CENTER, "right": Align.RIGHT}
const _FORMAT_WORDS: Dictionary[String, Format] = {"number": Format.NUMBER, "currency": Format.CURRENCY, "accounting": Format.ACCOUNTING, "percent": Format.PERCENT, "comma": Format.COMMA}
## The decimals of each format when the file or the toolbar names none.
const DEFAULT_DECIMALS: Dictionary[Format, int] = {Format.NUMBER: 2, Format.CURRENCY: 2, Format.ACCOUNTING: 2, Format.PERCENT: 0, Format.COMMA: 2}


## One cell: what the player typed and how it looks.
class Cell:
	## The text as typed: "1.5", "Apples", "'007" (a leading apostrophe keeps it text).
	var value: String = ""
	var bold := false
	var italic := false
	var underline := false
	var align := Align.GENERAL
	var format := Format.GENERAL
	## The places after the point for every format but GENERAL.
	var decimals := 0

	## True when the cell has neither a value nor formatting, so the sheet needn't keep it.
	func is_blank() -> bool:
		return value == "" and not bold and not italic and not underline and align == Align.GENERAL and format == Format.GENERAL

	func duplicate() -> Cell:
		var copy := Cell.new()
		copy.value = value
		copy.bold = bold
		copy.italic = italic
		copy.underline = underline
		copy.align = align
		copy.format = format
		copy.decimals = decimals
		return copy


## The cells that hold a value or formatting, by (column, row).
var cells: Dictionary[Vector2i, Cell] = {}
## The widths, in characters, of the columns that don't have [constant STANDARD_WIDTH], by column.
var widths: Dictionary[int, float] = {}
## What [method parse] couldn't read, one "Line 3: ..." each. Empty for a clean file.
var errors: PackedStringArray = []


## Reads [param text], an .xls file in the format of docs/xls.md. A line that it can't read is left
## out and named in [member errors]; the rest of the sheet still loads.
static func parse(text: String) -> XlsSheet:
	var sheet := XlsSheet.new()
	var lines := text.split("\n")
	for i: int in lines.size():
		var line := lines[i].trim_suffix("\r")
		if line.strip_edges() == "" or line.begins_with("#"):
			continue
		var problem := sheet._read_line(line)
		if problem != "":
			sheet.errors.append("Line %d: %s (%s)" % [i + 1, problem, line])
	return sheet


## The sheet as an .xls file: column widths first, then the cells row by row.
func to_text() -> String:
	var lines: PackedStringArray = []
	var columns := widths.keys()
	columns.sort()
	for column: int in columns:
		lines.append("%s width: %s" % [column_name(column), general(widths[column])])
	var places := cells.keys()
	places.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	for place: Vector2i in places:
		var cell: Cell = cells[place]
		var words: PackedStringArray = [cell_name(place)]
		for flag: String in ["bold", "italic", "underline"]:
			if cell.get(flag):
				words.append(flag)
		if cell.align != Align.GENERAL:
			words.append(_ALIGN_WORDS.find_key(cell.align))
		if cell.format != Format.GENERAL:
			words.append(_FORMAT_WORDS.find_key(cell.format))
			if cell.decimals != DEFAULT_DECIMALS[cell.format]:
				words.append(str(cell.decimals))
		lines.append("%s: %s" % [" ".join(words), cell.value])
	return "\n".join(lines) + ("\n" if not lines.is_empty() else "")


## The cell at [param place], or null when it is blank.
func cell_at(place: Vector2i) -> Cell:
	return cells.get(place)


## Stores [param cell] at [param place], or forgets the place when the cell is blank.
func put(place: Vector2i, cell: Cell) -> void:
	if cell == null or cell.is_blank():
		cells.erase(place)
	else:
		cells[place] = cell


## The width of [param column] in characters.
func width_of(column: int) -> float:
	return widths.get(column, STANDARD_WIDTH)


## Sets the width of [param column] in characters; [constant STANDARD_WIDTH] forgets it.
func set_width(column: int, characters: float) -> void:
	characters = clampf(snappedf(characters, 0.01), 0.0, 255.0)
	if is_equal_approx(characters, STANDARD_WIDTH):
		widths.erase(column)
	else:
		widths[column] = characters


## The text that the grid shows for [param cell]: the number in its format, or the text without a
## leading apostrophe. Accounting's "$" is not in it: see [method symbol].
static func shown(cell: Cell) -> String:
	if cell == null:
		return ""
	if not is_number(cell.value):
		return cell.value.trim_prefix("'")
	var number := cell.value.to_float()
	match cell.format:
		Format.NUMBER:
			return _fixed(number, cell.decimals, false)
		Format.COMMA, Format.ACCOUNTING:
			if is_zero_approx(number):
				return "-" + " ".repeat(cell.decimals + 1)
			var figures := _fixed(absf(number), cell.decimals, true)
			return "(%s)" % figures if number < 0.0 else figures + " "  # the space lines it up with a ")"
		Format.CURRENCY:
			var amount := "$" + _fixed(absf(number), cell.decimals, true)
			return "(%s)" % amount if number < 0.0 else amount
		Format.PERCENT:
			return _fixed(number * 100.0, cell.decimals, false) + "%"
	return general(number)


## The currency symbol that the grid shows at the left edge of [param cell]: "$" for a number in
## ACCOUNTING, else "".
static func symbol(cell: Cell) -> String:
	return "$" if cell != null and cell.format == Format.ACCOUNTING and is_number(cell.value) else ""


## The text that the formula bar shows for [param cell]: its value, with a percentage as one.
static func edit_text(cell: Cell) -> String:
	if cell == null:
		return ""
	if cell.format == Format.PERCENT and is_number(cell.value):
		return general(cell.value.to_float() * 100.0) + "%"
	return cell.value


## True when [param value] is a number as Excel reads one: "12", "-1.5", ".5", "3E+2".
static func is_number(value: String) -> bool:
	var number := RegEx.create_from_string("^[+-]?(\\d+\\.?\\d*|\\.\\d+)([eE][+-]?\\d+)?$")
	return number.search(value) != null


## Reads what the player typed into [param cell], as Excel does: "$1,234.50" is 1234.5 in Currency
## with 2 decimals, "12%" is 0.12 in Percent, "1,234" is 1234 in Comma style. Anything else is kept
## as typed, a leading "=" too: this Excel has no formulas.
static func enter(cell: Cell, typed: String) -> void:
	var stripped := typed.strip_edges()
	var currency := stripped.begins_with("$")
	var percent := stripped.ends_with("%")
	var bare := stripped.trim_prefix("$").trim_suffix("%")
	var grouped := bare.contains(",")
	bare = bare.replace(",", "")
	if (currency or percent or grouped) and not (currency and percent) and is_number(bare) and _grouped_right(stripped):
		var number := bare.to_float() / (100.0 if percent else 1.0)
		cell.value = general(number)
		if cell.format == Format.GENERAL:
			cell.format = Format.CURRENCY if currency else (Format.PERCENT if percent else Format.COMMA)
			cell.decimals = bare.length() - bare.find(".") - 1 if bare.contains(".") else 0
			if currency and bare.contains("."):
				cell.decimals = 2
		return
	cell.value = stripped if is_number(stripped) else typed


## [param number] as Excel's General format shows it: no trailing zeros, at most ten digits.
static func general(number: float) -> String:
	if is_equal_approx(number, roundf(number)) and absf(number) < 1e11:
		return str(int(roundf(number)))
	if absf(number) >= 1e11 or absf(number) < 1e-9:
		return String.num_scientific(number).to_upper()
	var digits := maxi(0, 9 - floori(log(absf(number)) / log(10.0)))
	return String.num(number, digits)


## The name of [param column]: A, B, ... Z, AA, ... IV.
static func column_name(column: int) -> String:
	var name := ""
	var n := column + 1
	while n > 0:
		var rest := (n - 1) % 26
		name = char(65 + rest) + name
		n = (n - 1) / 26
	return name


## The name of the cell at [param place], such as "B3".
static func cell_name(place: Vector2i) -> String:
	return "%s%d" % [column_name(place.x), place.y + 1]


## The column named [param letters] (A to IV, any case), or -1.
static func column_of(letters: String) -> int:
	var upper := letters.to_upper()
	if upper.is_empty() or upper.length() > 2:
		return -1
	var column := 0
	for letter: String in upper:
		if letter < "A" or letter > "Z":
			return -1
		column = column * 26 + (letter.unicode_at(0) - 64)
	return column - 1 if column <= COLUMNS else -1


## The place of the cell named [param name] ("B3", any case), or (-1, -1).
static func place_of(name: String) -> Vector2i:
	var found := RegEx.create_from_string("^([A-Za-z]{1,2})([1-9][0-9]*)$").search(name)
	if found == null:
		return Vector2i(-1, -1)
	var column := column_of(found.get_string(1))
	var row := found.get_string(2).to_int() - 1
	if column < 0 or row >= ROWS:
		return Vector2i(-1, -1)
	return Vector2i(column, row)


# Reads one line that isn't blank or a comment; returns what is wrong with it, or "".
func _read_line(line: String) -> String:
	var colon := line.find(":")
	if colon < 0:
		return "no colon between the cell and its value"
	var words := line.substr(0, colon).strip_edges().split(" ", false)
	var value := line.substr(colon + 1).trim_prefix(" ")
	if words.is_empty():
		return "no cell before the colon"
	var column := column_of(words[0])
	if column >= 0:
		if words.size() != 2 or words[1] != "width":
			return "a column takes only \"width\", as in \"B width: 12\""
		if not value.strip_edges().is_valid_float():
			return "the width \"%s\" is no number" % value
		set_width(column, value.strip_edges().to_float())
		return ""
	var place := place_of(words[0])
	if place.x < 0:
		return "\"%s\" is no cell between A1 and IV65536" % words[0]
	var cell := Cell.new()
	cell.value = value
	for i: int in range(1, words.size()):
		var word := words[i].to_lower()
		if word in ["bold", "italic", "underline"]:
			cell.set(word, true)
		elif _ALIGN_WORDS.has(word):
			cell.align = _ALIGN_WORDS[word]
		elif _FORMAT_WORDS.has(word):
			cell.format = _FORMAT_WORDS[word]
			cell.decimals = DEFAULT_DECIMALS[cell.format]
		elif word.is_valid_int() and cell.format != Format.GENERAL and _FORMAT_WORDS.has(words[i - 1].to_lower()):
			cell.decimals = clampi(word.to_int(), 0, 30)
		else:
			return "unknown word \"%s\"" % words[i]
	put(place, cell)
	return ""


# A number with [param decimals] places, with thousands commas when [param grouped].
static func _fixed(number: float, decimals: int, grouped: bool) -> String:
	var scale := pow(10.0, decimals)
	var rounded := signf(number) * floorf(absf(number) * scale + 0.5) / scale  # half away from zero, as Excel rounds
	var text := ("%." + str(decimals) + "f") % rounded
	if not grouped:
		return text
	var minus := "-" if text.begins_with("-") else ""
	text = text.trim_prefix("-")
	var point := text.find(".")
	var whole := text.substr(0, point) if point >= 0 else text
	var rest := text.substr(point) if point >= 0 else ""
	var out := ""
	while whole.length() > 3:
		out = "," + whole.right(3) + out
		whole = whole.left(whole.length() - 3)
	return minus + whole + out + rest


# True when the commas in [param typed] sit between groups of three digits, as in "1,234,567.5".
static func _grouped_right(typed: String) -> bool:
	if not typed.contains(","):
		return true
	var digits := typed.trim_prefix("$").trim_suffix("%").trim_prefix("-")
	var whole := digits.get_slice(".", 0).split(",")
	for i: int in range(1, whole.size()):
		if whole[i].length() != 3:
			return false
	return whole[0].length() in [1, 2, 3]
