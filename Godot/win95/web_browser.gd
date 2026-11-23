extends "res://win95/window.gd"
## Netscape Navigator 2.0: a 1996 web browser that shows HTML 3.2 pages from drive C. No computer in
## the shop has a modem, so a web address fails as Netscape failed offline: the meteors fly while
## it contacts the host, then an alert, and the page before stays. No forms, frames, scripts or
## style sheets: they came later.

enum FileMenu { CLOSE }

## The file extensions that this app opens, lower case, without the dot.
@export var opens: Array[String] = ["htm", "html"]
## The page that the window opens with and that Home goes to.
@export var home := "http://home.netscape.com/"
## Seconds that Netscape tries to reach a host before it gives up; 0 gives up at once.
@export var contact_seconds := 2.5
## How many meteors fly across the N at a time.
@export var meteors := 3
## Meteors that cross the N per second, each.
@export var meteor_speed := 1.5

const _MESSAGE := preload("res://win95/message_box.tscn")

## The URL of the page on show, absolute; empty while the window is blank.
var url := ""
## The title of the page on show; empty when it has none.
var page_title := ""

var _state: ComputerState
var _history: Array[String] = []
var _at := -1
var _app_title := ""
var _loading := -1.0  # seconds into contacting a host; below 0 while not
var _load := 0  # counts the pages asked for, so a slow one doesn't replace a newer one

@onready var _page: RichTextLabel = %Page
@onready var _address: LineEdit = %Address
@onready var _status: Label = %Status


func _ready() -> void:
	super()
	_app_title = %TitleBar.title
	%File.id_pressed.connect(func(id: int) -> void:
		if id == FileMenu.CLOSE:
			request_close())
	%Back.pressed.connect(back)
	%Forward.pressed.connect(forward)
	%Home.pressed.connect(func() -> void: navigate(home))
	_address.text_submitted.connect(navigate)
	_page.meta_clicked.connect(func(link: Variant) -> void: navigate(str(link)))
	_page.meta_hover_started.connect(func(link: Variant) -> void: _status.text = link)
	_page.meta_hover_ended.connect(func(_link: Variant) -> void: _status.text = "")
	%Meteors.draw.connect(_draw_meteors)
	set_process(false)
	_buttons()
	if url == "":
		navigate(home)


func _process(delta: float) -> void:
	_loading += delta
	%Meteors.queue_redraw()


## Shows [param opened], an .htm file in [param state]'s running copy, whose links can reach the
## other files on drive C.
func open_file(opened: Win95File, state: ComputerState) -> void:
	_state = state
	_go("file:///" + state.path_of(opened).replace("\\", "/"))


## Goes to [param address] as the player typed it: without a scheme it is a web address, or a
## file when it starts with a drive letter.
func navigate(address: String) -> void:
	address = address.strip_edges()
	if address == "":
		return
	if not "://" in address and not address.begins_with("mailto:"):
		var is_path := address.length() > 1 and address[1] == ":"
		address = ("file:///" + address.replace("\\", "/")) if is_path else "http://" + address
	_go(resolve(url, address) if url != "" else address)


## Back to the page before, if there is one.
func back() -> void:
	if _at > 0 and await _open(_history[_at - 1]):
		_at -= 1
		_buttons()


## Forward to the page that Back left, if there is one.
func forward() -> void:
	if _at < _history.size() - 1 and await _open(_history[_at + 1]):
		_at += 1
		_buttons()


func _go(to: String) -> void:
	if await _open(to):
		_history.resize(_at + 1)
		_history.append(to)
		_at = _history.size() - 1
		_buttons()


func _buttons() -> void:
	%Back.disabled = _at <= 0
	%Forward.disabled = _at >= _history.size() - 1


# Shows the page at [param to] and returns true, or alerts why it can't and keeps the page on show.
# A page asked for after it wins: this one then returns false.
func _open(to: String) -> bool:
	_load += 1
	var load := _load
	_address.text = to
	if not to.begins_with("file:///"):
		var host := to.get_slice("://", 1).get_slice("/", 0) if "://" in to else to.get_slice(":", 1).get_slice("@", 1)
		_status.text = "Connect: Contacting host: %s..." % host
		if contact_seconds > 0.0:
			_loading = 0.0
			set_process(true)
			await get_tree().create_timer(contact_seconds).timeout
			if load != _load:
				return false
			_loading = -1.0
			set_process(false)
			%Meteors.queue_redraw()
		_fail("Netscape is unable to locate the server: %s\nThe server does not have a DNS entry.\n\nCheck the server name in the Location (URL) and try again." % host)
		return false
	var path := to.trim_prefix("file:///").get_slice("#", 0).uri_decode().replace("/", "\\")
	var desktop_path := "C:\\WINDOWS\\Desktop\\"
	if path.to_upper().begins_with(desktop_path.to_upper()):
		path = "Desktop\\" + path.substr(desktop_path.length())
	var file: Win95File = _state.setup.file_at(path) if _state != null else null
	if file == null or file.is_folder:
		_fail("File Not Found\n\nThe file %s cannot be found. Please check the location and try again." % path)
		return false
	url = to
	var page := render(file.contents, to)
	page_title = page.title
	%TitleBar.title = "%s - [%s]" % [_app_title, page.title if page.title != "" else to.get_file()]
	var style := StyleBoxFlat.new()
	style.bg_color = page.background
	style.set_content_margin_all(8)
	_page.add_theme_stylebox_override(&"normal", style)
	_page.add_theme_color_override(&"default_color", page.text_color)
	_page.text = page.bbcode
	_page.scroll_to_line(0)
	_status.text = "Document: Done"
	return true


# Netscape's alert; the Location box goes back to the page on show.
func _fail(message: String) -> void:
	_address.text = url
	_status.text = ""
	var desktop := get_parent() as Win95Desktop
	if desktop == null:
		return  # outside a desktop, as in a test: the Location box and status say enough
	var box: Node = desktop.open(_MESSAGE, false)
	box.closed.connect(box.queue_free)
	box.show_message(_app_title, message)


# Meteors streak from the top right to the bottom left of the N while Netscape contacts a host.
func _draw_meteors() -> void:
	if _loading < 0.0:
		return
	var box: Vector2 = %Meteors.size
	for i in meteors:
		var along := fmod(_loading * meteor_speed + float(i) / meteors, 1.0)
		var lane := box.y * (float(i) + 0.5) / meteors - box.y * 0.5
		var head := Vector2(lerpf(box.x + 6.0, -6.0, along), lerpf(lane - 6.0, lane + box.y, along)).floor()
		for k in 6:
			%Meteors.draw_rect(Rect2(head + Vector2(k, -k), Vector2.ONE), Color(1.0, 1.0, 0.8, 1.0 - k / 6.0))


## [param link] as an absolute URL, read relative to the page at [param base].
static func resolve(base: String, link: String) -> String:
	return _Renderer.resolve(base, link)


## A page as the RichTextLabel shows it.
class Page:
	## The text of its TITLE; empty when it has none.
	var title := ""
	## The page as BBCode, links as [code][url=absolute URL][/code].
	var bbcode := ""
	## BODY's BGCOLOR, TEXT and LINK, with Win95's defaults.
	var background := Color(0.753, 0.753, 0.753)
	var text_color := Color.BLACK
	var link_color := Color(0, 0, 1)


## [param html] as a [Page], its links and pictures read relative to [param base]. Tags outside
## HTML 3.2, and FORM, are left out; unclosed tags are fine, as browsers allowed.
static func render(html: String, base: String) -> Page:
	return _Renderer.new(base).run(html)


class _Renderer:
	const HTML_COLORS := {
		"black": "000000", "silver": "c0c0c0", "gray": "808080", "white": "ffffff", "maroon": "800000",
		"red": "ff0000", "purple": "800080", "fuchsia": "ff00ff", "green": "008000", "lime": "00ff00",
		"olive": "808000", "yellow": "ffff00", "navy": "000080", "blue": "0000ff", "teal": "008080", "aqua": "00ffff"}
	const ENTITIES := {
		"amp": "&", "lt": "<", "gt": ">", "quot": "\"", "nbsp": "\u00a0", "copy": "\u00a9", "reg": "\u00ae",
		"middot": "\u00b7", "eacute": "\u00e9", "auml": "\u00e4", "ouml": "\u00f6", "aring": "\u00e5", "uuml": "\u00fc"}
	const HEADING_SIZES := {"h1": 24, "h2": 18}
	const FONT_SIZES := [12, 12, 12, 12, 18, 24, 24, 36]  # by FONT SIZE, 1 to 7
	const SKIPPED := ["script", "style", "form", "select", "textarea", "applet", "object"]
	const LISTS := ["ul", "ol", "menu", "dir"]

	var page := Page.new()
	var _base := ""
	var _out := PackedStringArray()
	var _breaks := 0  # the line breaks that the next text starts with
	var _pre_opened := false  # PRE just opened: a newline right after it doesn't count
	var _line_start := true
	var _pre := 0
	var _skip := 0
	var _in_title := false
	var _closers := {}  # tag -> Array of the BBCode that closes each open one
	var _items: Array[int] = []  # LI count of each open list, innermost last
	var _cells := 0  # TD and TH so far in this TR
	var _tag := RegEx.create_from_string("<!--[\\s\\S]*?-->|<(/?)([a-zA-Z][a-zA-Z0-9]*)([^>]*)>")
	var _attribute := RegEx.create_from_string("([a-zA-Z-]+)(?:\\s*=\\s*(?:\"([^\"]*)\"|'([^']*)'|([^\\s>]+)))?")
	var _space := RegEx.create_from_string("\\s+")
	var _entity := RegEx.create_from_string("&(#?[a-zA-Z0-9]+);?")

	## [param link] as an absolute URL, read relative to the page at [param base].
	static func resolve(base: String, link: String) -> String:
		if "://" in link or link.begins_with("mailto:"):
			return link
		var scheme_end := base.find("://") + 3
		var host_end := base.find("/", scheme_end)
		if base.begins_with("file:///"):
			host_end = scheme_end  # file:/// has an empty host
		if host_end < 0:
			base += "/"
			host_end = base.length() - 1
		if link.begins_with("#") or link == "":
			return base.get_slice("#", 0) + link
		if link.begins_with("/"):
			return base.substr(0, host_end) + link
		var folder := base.substr(host_end).get_slice("#", 0).get_slice("?", 0)
		folder = folder.substr(0, folder.rfind("/") + 1)
		var parts: Array[String] = []
		for part in (folder + link).split("/"):
			if part == "..":
				if parts.size() > 1:
					parts.pop_back()
			elif part != ".":
				parts.append(part)
		return base.substr(0, host_end) + "/".join(parts)

	func _init(base: String) -> void:
		_base = base

	func run(html: String) -> Page:
		var from := 0
		for m in _tag.search_all(html):
			_text(html.substr(from, m.get_start() - from))
			from = m.get_end()
			if m.get_string(2) != "":
				var tag := m.get_string(2).to_lower()
				if m.get_string(1) == "/":
					_close(tag)
				else:
					_open(tag, _attributes(m.get_string(3)))
		_text(html.substr(from))
		page.title = _decode(_space.sub(page.title, " ", true)).strip_edges()
		page.bbcode = "".join(_out)
		return page

	func _open(tag: String, attrs: Dictionary) -> void:
		if tag in SKIPPED:
			_skip += 1
		if _skip > 0:
			return
		match tag:
			"title":
				_in_title = true
			"body":
				page.background = _color(attrs.get("bgcolor", ""), page.background)
				page.text_color = _color(attrs.get("text", ""), page.text_color)
				page.link_color = _color(attrs.get("link", ""), page.link_color)
			"p":
				_block(2)
				_push_align(tag, attrs)
			"div":
				_block(1)
				_push_align(tag, attrs)
			"center":
				_block(1)
				_push(tag, "[center]", "[/center]")
			"br":
				_flush()
				_emit("\n")
				_line_start = true
			"hr":
				_block(1)
				_flush()
				_emit("[hr]")
				_block(1)
			"h1", "h2", "h3", "h4", "h5", "h6":
				_block(2)
				_push_align(tag, attrs)
				_push(tag, "[font_size=%d][b]" % HEADING_SIZES.get(tag, 12), "[/b][/font_size]")
			"b", "strong":
				_push(tag, "[b]", "[/b]")
			"i", "em", "cite", "var", "dfn", "address":
				_push(tag, "[i]", "[/i]")
			"u":
				_push(tag, "[u]", "[/u]")
			"s", "strike":
				_push(tag, "[s]", "[/s]")
			"tt", "code", "kbd", "samp":
				_push(tag, "[code]", "[/code]")
			"pre", "xmp", "listing":
				_block(2)
				_pre += 1
				_push(tag, "[code]", "[/code]")
				_pre_opened = true
			"blockquote":
				_block(2)
				_push(tag, "[indent]", "[/indent]")
			"font":
				var open := ""
				var close := ""
				if attrs.has("size"):
					var size: String = attrs["size"]
					var n := (3 + size.to_int()) if size.begins_with("+") or size.begins_with("-") else size.to_int()
					open += "[font_size=%d]" % FONT_SIZES[clampi(n, 1, 7)]
					close = "[/font_size]" + close
				if attrs.has("color"):
					open += "[color=#%s]" % _color(attrs["color"], page.text_color).to_html(false)
					close = "[/color]" + close
				_push(tag, open, close)
			"a":
				if attrs.has("href"):
					var link := resolve(_base, attrs["href"]).replace("]", "%5D")
					_push(tag, "[url=%s][color=#%s]" % [link, page.link_color.to_html(false)], "[/color][/url]")
				else:
					_push(tag, "", "")
			"img":
				_flush()
				_emit(_picture(attrs))
			"ul", "ol", "menu", "dir":
				_block(1 if _items.is_empty() else 0)
				_flush(true)
				_items.append(0)
				_push(tag, "[ol type=1]" if tag == "ol" else "[ul]", "[/ol]" if tag == "ol" else "[/ul]")
				_line_start = true
			"li":
				if not _items.is_empty():
					if _items[-1] > 0:
						_emit("\n")
					_items[-1] += 1
					_breaks = 0
					_line_start = true
			"dl":
				_block(1)
			"dt":
				_block(1)
			"dd":
				_block(1)
				_flush()
				_emit("\u00a0\u00a0\u00a0\u00a0")
			"table", "tr", "caption":
				_block(1)
				_cells = 0
			"td", "th":
				if _cells > 0:
					_flush()
					_emit("\u00a0\u00a0\u00a0")
				_cells += 1
				if tag == "th":
					_push(tag, "[b]", "[/b]")

	func _close(tag: String) -> void:
		if tag in SKIPPED:
			_skip = maxi(_skip - 1, 0)
			return
		if _skip > 0:
			return
		match tag:
			"title":
				_in_title = false
			"p", "h1", "h2", "h3", "h4", "h5", "h6", "pre", "xmp", "listing", "blockquote":
				_pop(tag)
				_pop(tag + "/align")
				_block(2)
				if tag in ["pre", "xmp", "listing"]:
					_pre = maxi(_pre - 1, 0)
			"div", "center":
				_pop(tag)
				_pop(tag + "/align")
				_block(1)
			"ul", "ol", "menu", "dir":
				_breaks = 0
				_pop(tag)
				if not _items.is_empty():
					_items.pop_back()
				_block(1)
			"table", "tr", "dl":
				_block(1)
			_:
				_pop(tag)

	func _text(raw: String) -> void:
		if _skip > 0 or raw == "":
			return
		if _in_title:
			page.title += raw
			return
		var text := raw if _pre > 0 else _space.sub(raw, " ", true)
		if _pre_opened:
			text = text.trim_prefix("\n")
			_pre_opened = false
		if (_line_start or _breaks > 0) and _pre == 0:
			text = text.lstrip(" ")
		if text == "":
			return
		_flush()
		text = _decode(text)
		_emit(text.replace("[", "\u0001").replace("]", "[rb]").replace("\u0001", "[lb]"))
		_line_start = text.ends_with("\n") or text.ends_with(" ")

	# Asks for [param count] line breaks before the next text; none at the top of the page.
	func _block(count: int) -> void:
		if not _out.is_empty():
			_breaks = maxi(_breaks, count)

	# [param starts_line]: the next BBCode starts its own line, as a list does.
	func _flush(starts_line := false) -> void:
		var count := _breaks - int(starts_line)
		if count > 0:
			_emit("\n".repeat(count))
		if _breaks > 0:
			_line_start = true
		_breaks = 0

	func _emit(bbcode: String) -> void:
		_out.append(bbcode)
		_line_start = false


	# Opens a tag whose ALIGN is center or right; P and the headings close it at the next block.
	func _push_align(tag: String, attrs: Dictionary) -> void:
		_pop(tag + "/align")
		var align: String = attrs.get("align", "").to_lower()
		if align in ["center", "right"]:
			_flush()
			_push(tag + "/align", "[%s]" % align, "[/%s]" % align)

	func _push(tag: String, open: String, close: String) -> void:
		if open != "":
			_flush()
			_out.append(open)
		if not _closers.has(tag):
			_closers[tag] = []
		_closers[tag].append(close)

	func _pop(tag: String) -> void:
		var open: Array = _closers.get(tag, [])
		if not open.is_empty():
			_out.append(open.pop_back())

	# The pictures were on the web, out of reach, so their ALT text stands in, as with images off.
	func _picture(attrs: Dictionary) -> String:
		var alt: String = _decode(attrs.get("alt", ""))
		return "[lb]%s[rb]" % alt.replace("[", "(").replace("]", ")") if alt != "" else ""

	func _attributes(source: String) -> Dictionary:
		var found := {}
		for m in _attribute.search_all(source):
			found[m.get_string(1).to_lower()] = m.get_string(2) + m.get_string(3) + m.get_string(4)
		return found

	func _color(value: String, fallback: Color) -> Color:
		var key := value.strip_edges().to_lower()
		var hex: String = HTML_COLORS.get(key, key.trim_prefix("#"))
		return Color.from_string("#" + hex, fallback) if hex.is_valid_hex_number() and hex.length() == 6 else fallback

	func _decode(text: String) -> String:
		var decoded := ""
		var from := 0
		for m in _entity.search_all(text):
			var name := m.get_string(1)
			var value := ""
			if name.begins_with("#x") or name.begins_with("#X"):
				value = char(name.substr(2).hex_to_int())
			elif name.begins_with("#"):
				value = char(name.substr(1).to_int())
			else:
				value = ENTITIES.get(name.to_lower(), m.get_string())
			decoded += text.substr(from, m.get_start() - from) + value
			from = m.get_end()
		return decoded + text.substr(from)
