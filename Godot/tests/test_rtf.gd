extends "res://tests/test.gd"
## .doc files hold RTF (win95/rtf.gd): Word and WordPad write bold, italic, underline, sizes and
## aligned paragraphs and read them back; a hand-written file with a font table, codes and Unicode
## reads; a file that isn't RTF reads as plain text.

const HAND_WRITTEN := """{\\rtf1\\ansi\\deff0{\\fonttbl{\\f0\\froman Times New Roman;}}{\\colortbl;\\red255\\green0\\blue0;}
{\\info{\\title Tax letter}{\\author Old Dude}}
\\pard\\qc\\b\\fs32 Dear Tax Office\\b0\\par
\\pard\\fs20 I paid {\\i every} caf\\'e9 bill\\emdash \\u8364? 12.\\par
{\\*\\generator Writer}\\pard\\qr {\\ul Yours}\\par
}"""


func run() -> void:
	var document := RichDocument.from_plain("Hello\nworld")
	document.set_bits(Vector2i(0, 0), Vector2i(0, 5), RichDocument.BOLD, true)
	document.set_bits(Vector2i(1, 0), Vector2i(1, 2), RichDocument.ITALIC | RichDocument.UNDERLINE, true)
	document.set_size(Vector2i(1, 2), Vector2i(1, 5), 48)
	document.set_align(Vector2i(1, 0), Vector2i(1, 0), RichDocument.Align.CENTER)
	var rtf := Rtf.write(document)
	check("written as RTF", [Rtf.is_rtf(rtf), rtf.contains("{\\b\\fs20 Hello}"), rtf.contains("\\pard\\qc")], [true, true, true])
	var back := Rtf.read(rtf)
	check("the text comes back", back.plain_text(), "Hello\nworld")
	check("and the formats", [back.paragraphs[0].formats, back.paragraphs[1].formats], [document.paragraphs[0].formats, document.paragraphs[1].formats])
	check("and the alignment", [back.paragraphs[0].align, back.paragraphs[1].align], [RichDocument.Align.LEFT, RichDocument.Align.CENTER])
	check("written again, the same", Rtf.write(back), rtf)

	var hand := Rtf.read(HAND_WRITTEN)
	check("a hand-written file: tables, info and \\* groups skipped", hand.plain_text(), "Dear Tax Office\nI paid every café bill—€ 12.\nYours")
	check("its heading is bold 16 pt, centred", [hand.paragraphs[0].formats[0], hand.paragraphs[0].align],
			[RichDocument.make_format(true, false, false, 32), RichDocument.Align.CENTER])
	check("its italic group ends with the group", [hand.paragraphs[1].formats[7] & RichDocument.ITALIC, hand.paragraphs[1].formats[13] & RichDocument.ITALIC], [RichDocument.ITALIC, 0])
	check("\\pard takes the centring back, \\qr aligns right", [hand.paragraphs[1].align, hand.paragraphs[2].align], [RichDocument.Align.LEFT, RichDocument.Align.RIGHT])
	check("underline in a group", hand.paragraphs[2].formats[0] & RichDocument.UNDERLINE, RichDocument.UNDERLINE)

	var plain := Rtf.read("taxes 1995\r\nsee the shoebox")
	check("plain text reads as paragraphs", [plain.paragraphs.size(), plain.plain_text()], [2, "taxes 1995\nsee the shoebox"])
	var tricky := RichDocument.from_plain("a {brace} and \\ back\tslash å")
	check("braces, backslashes, tabs and Unicode survive", Rtf.read(Rtf.write(tricky)).plain_text(), tricky.plain_text())
	var empty_line := RichDocument.from_plain("one\n\nthree")
	check("an empty paragraph survives", Rtf.read(Rtf.write(empty_line)).plain_text(), "one\n\nthree")
