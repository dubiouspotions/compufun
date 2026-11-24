class_name Rtf
## Reads and writes the RTF that Word and WordPad keep in .doc files: a small subset (bold, italic,
## underline, font size, paragraphs and their alignment), as Word 97 and WordPad read it. Writers can
## author a .doc by hand in that subset; anything else in a file (fonts, colours, pictures, document
## info) is skipped on reading. A file that isn't RTF reads as plain text, one paragraph per line.

## Groups whose content is no text: they are skipped whole.
const _SKIPPED := ["fonttbl", "colortbl", "stylesheet", "info", "pict", "header", "footer", "headerl", "headerr",
		"footerl", "footerr", "fldinst", "object", "listtable", "listoverridetable", "rsidtbl", "generator", "xmlnstbl"]
## Control symbols and words that stand for one character.
const _CHARACTERS := {"~": "\u00a0", "-": "", "_": "\u2011", "tab": "\t", "emdash": "\u2014", "endash": "\u2013",
		"lquote": "\u2018", "rquote": "\u2019", "ldblquote": "\u201c", "rdblquote": "\u201d", "bullet": "\u2022"}
const _ALIGN_WORDS := {"ql": RichDocument.Align.LEFT, "qc": RichDocument.Align.CENTER, "qr": RichDocument.Align.RIGHT, "qj": RichDocument.Align.JUSTIFY}


## True when [param text] is RTF: it starts with "{\rtf".
static func is_rtf(text: String) -> bool:
	return text.strip_edges(true, false).begins_with("{\\rtf")


## The document in [param text]: RTF, or plain text when it isn't (see [method is_rtf]).
static func read(text: String) -> RichDocument:
	if not is_rtf(text):
		return RichDocument.from_plain(text)
	var document := RichDocument.new()
	var at := Vector2i.ZERO
	var format := RichDocument.make_format(false, false, false, 24)  # RTF's default size is 12 pt
	var align := RichDocument.Align.LEFT
	var stack: Array[Array] = []  # [format, skipping depth] of each open group
	var skipping := 0  # the depth of the group being skipped, 0 for none
	var skip_chars := 0  # characters after a \u that stand in for it
	var i := 0
	var n := text.length()
	while i < n:
		var c := text[i]
		if c == "{":
			stack.append([format, skipping])
			i += 1
			if skipping == 0 and text.substr(i, 2) == "\\*":
				skipping = stack.size()
			continue
		if c == "}":
			if stack.is_empty():
				break
			var saved: Array = stack.pop_back()
			format = saved[0]
			if skipping > stack.size():
				skipping = 0
			i += 1
			continue
		if c == "\r" or c == "\n":
			i += 1
			continue
		if c != "\\":
			var run_end := i
			while run_end < n and not text[run_end] in ["\\", "{", "}", "\r", "\n"]:
				run_end += 1
			if skipping == 0:
				var run := text.substr(i, run_end - i)
				if skip_chars > 0:
					var dropped := mini(skip_chars, run.length())
					run = run.substr(dropped)
					skip_chars -= dropped
				at = _put(document, at, run, format, align)
			i = run_end
			continue
		# A control word or symbol.
		i += 1
		if i >= n:
			break
		c = text[i]
		if not _is_letter(c):
			i += 1
			if skipping != 0:
				continue
			if c == "'" and i + 2 <= n:
				var code := text.substr(i, 2).hex_to_int()
				i += 2
				if skip_chars > 0:
					skip_chars -= 1
				else:
					at = _put(document, at, _cp1252(code), format, align)
			elif c in ["\\", "{", "}"]:
				at = _put(document, at, c, format, align)
			elif _CHARACTERS.has(c):
				at = _put(document, at, _CHARACTERS[c], format, align)
			continue
		var word_end := i
		while word_end < n and _is_letter(text[word_end]):
			word_end += 1
		var word := text.substr(i, word_end - i)
		var number_end := word_end
		if number_end < n and text[number_end] == "-":
			number_end += 1
		while number_end < n and text[number_end].is_valid_int():
			number_end += 1
		var has_number := number_end > word_end
		var number := text.substr(word_end, number_end - word_end).to_int() if has_number else 1
		i = number_end
		if i < n and text[i] == " ":
			i += 1  # the space that ends a control word is part of it
		if skipping != 0:
			continue
		if word in _SKIPPED:
			skipping = stack.size()
			continue
		match word:
			"b":
				format = _bit(format, RichDocument.BOLD, number != 0)
			"i":
				format = _bit(format, RichDocument.ITALIC, number != 0)
			"ul":
				format = _bit(format, RichDocument.UNDERLINE, number != 0)
			"ulnone":
				format = _bit(format, RichDocument.UNDERLINE, false)
			"fs":
				format = RichDocument.with_size(format, maxi(number, 2))
			"plain":
				format = RichDocument.make_format(false, false, false, 24)
			"pard":
				align = RichDocument.Align.LEFT
				document.paragraphs[at.x].align = align
			"par", "line":
				document.paragraphs[at.x].end_format = format if document.paragraphs[at.x].text.is_empty() else document.paragraphs[at.x].end_format
				at = document.insert(at, "\n", format)
				document.paragraphs[at.x].align = align
			"u":
				at = _put(document, at, String.chr(number if number >= 0 else number + 65536), format, align)
				skip_chars = 1
			_:
				if _ALIGN_WORDS.has(word):
					align = _ALIGN_WORDS[word]
					document.paragraphs[at.x].align = align
				elif _CHARACTERS.has(word):
					at = _put(document, at, _CHARACTERS[word], format, align)
	document.paragraphs[-1].end_format = format if document.paragraphs[-1].text.is_empty() else document.paragraphs[-1].end_format
	if document.paragraphs.size() > 1 and document.paragraphs[-1].text.is_empty():
		document.paragraphs.pop_back()  # the \par that ends the last paragraph starts no new one
	return document


## [param document] as RTF, in the subset that [method read] reads back.
static func write(document: RichDocument) -> String:
	var out := "{\\rtf1\\ansi\\deff0{\\fonttbl{\\f0\\froman Times New Roman;}}\n"
	var align_words := {RichDocument.Align.CENTER: "\\qc", RichDocument.Align.RIGHT: "\\qr", RichDocument.Align.JUSTIFY: "\\qj"}
	for paragraph: RichDocument.Paragraph in document.paragraphs:
		out += "\\pard" + align_words.get(paragraph.align, "") + " "
		var start := 0
		while start < paragraph.text.length():
			var format := paragraph.formats[start]
			var stop := start
			while stop < paragraph.text.length() and paragraph.formats[stop] == format:
				stop += 1
			out += "{%s %s}" % [_format_words(format), _escape(paragraph.text.substr(start, stop - start))]
			start = stop
		if paragraph.text.is_empty():
			out += "{%s }" % _format_words(paragraph.end_format)
		out += "\\par\n"
	return out + "}"


static func _format_words(format: int) -> String:
	var words := "\\fs%d" % RichDocument.half_points(format)
	if format & RichDocument.BOLD:
		words = "\\b" + words
	if format & RichDocument.ITALIC:
		words = "\\i" + words
	if format & RichDocument.UNDERLINE:
		words = "\\ul" + words
	return words


static func _escape(text: String) -> String:
	var out := ""
	for c: String in text:
		var code := c.unicode_at(0)
		if c in ["\\", "{", "}"]:
			out += "\\" + c
		elif c == "\t":
			out += "\\tab "
		elif code < 128:
			out += c
		else:
			out += "\\u%d?" % (code if code < 32768 else code - 65536)
	return out


static func _put(document: RichDocument, at: Vector2i, text: String, format: int, align: RichDocument.Align) -> Vector2i:
	if text.is_empty():
		return at
	document.paragraphs[at.x].align = align
	return document.insert(at, text, format)


static func _bit(format: int, bit: int, on: bool) -> int:
	return (format | bit) if on else (format & ~bit)


static func _is_letter(c: String) -> bool:
	return (c >= "a" and c <= "z") or (c >= "A" and c <= "Z")


# The character that Windows-1252, RTF's \ansi code page, has at [param code].
static func _cp1252(code: int) -> String:
	const HIGH := "\u20ac\u0081\u201a\u0192\u201e\u2026\u2020\u2021\u02c6\u2030\u0160\u2039\u0152\u008d\u017d\u008f\u0090\u2018\u2019\u201c\u201d\u2022\u2013\u2014\u02dc\u2122\u0161\u203a\u0153\u009d\u017e\u0178"
	return HIGH[code - 128] if code >= 128 and code < 160 else String.chr(code)
