extends "res://win95/window.gd"
## Netscape Navigator 2.0, after screenshots of the real one: the splash, the toolbar, the Location
## and directory buttons, the throbber and the menus. It shows HTML 3.2 pages from drive C and its
## own about: page. No computer in the shop has a modem, so a web address shows the copy in
## Netscape's disk cache, if there is one, or fails as Netscape failed
## offline: meteors fly across the N while it contacts the host, then an alert, and the page on
## show stays. No forms, frames, scripts or style sheets: they came later.

## The menu items that do something; the rest are greyed out, as offline Netscape needs none.
enum Item { OPEN_LOCATION = 1, CLOSE, COPY, SELECT_ALL, RELOAD, BACK, FORWARD, HOME, STOP,
		SHOW_TOOLBAR, SHOW_LOCATION, SHOW_DIRECTORY, ABOUT, HANDBOOK, DIRECTORY = 100 }

## The file extensions that this app opens, lower case, without the dot.
@export var opens: Array[String] = ["htm", "html"]
## The page that the window opens with and that Home goes to.
@export var home := "http://home.netscape.com/"
## Seconds that the splash shows before the window; 0 skips it.
@export var splash_seconds := 3.0
## Seconds that Netscape tries to reach a host on a computer without a dial-up connection before it
## gives up; 0 gives up at once.
@export var contact_seconds := 2.5
## How many meteors fly across the N at a time.
@export var meteors := 3
## Meteors that cross the N per second, each.
@export var meteor_speed := 1.5
## Netscape's disk cache on drive C. Offline, a web page shows from it if it holds a copy.
@export var cache_folder := "C:\\Program Files\\Netscape\\Navigator\\Cache"

const _MESSAGE := preload("res://win95/message_box.tscn")
const _CONNECT_TO := preload("res://win95/connect_to.tscn")
const _ABOUT := """<TITLE>Version 2.0</TITLE><BODY BGCOLOR="#C0C0C0">
<CENTER><IMG SRC="about:logo"><BR><B>N E T S C A P E</B>
<H2>Netscape Navigator (TM)</H2><B>Version 2.0</B><BR>
Copyright &copy; 1994-1995 Netscape Communications Corporation, All rights reserved.</CENTER>
<P>This software is subject to the license agreement set forth in the <A HREF="about:license">license</A>.
Please read and agree to all terms before using this software.
<P>Report any problems through the <A HREF="http://home.netscape.com/assist/feedback.html">feedback page</A>.
<P>Netscape Communications, Netscape, Netscape Navigator and the Netscape Communications logo are
trademarks of Netscape Communications Corporation.
<HR>Contains Java (TM) software developed by Sun Microsystems, Inc.<BR>
Copyright &copy; 1992-1995 Sun Microsystems, Inc. All Rights Reserved.
<HR>Contains security software from RSA Data Security, Inc.<BR>
Copyright &copy; 1994 RSA Data Security, Inc. All rights reserved.<BR>
<B>This version supports International security with RSA Public Key Cryptography, MD2, MD5, RC4.</B>"""

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
	var desktop := get_parent() as Win95Desktop
	if desktop != null:
		_state = desktop.computer
	_app_title = %TitleBar.title
	for menu in $VBox/MenuBar.get_children():
		(menu as PopupMenu).id_pressed.connect(_on_menu.bind(menu))
	for button: Button in %DirectoryButtons.get_children():
		var link: String = button.get_meta(&"url")
		button.pressed.connect(navigate.bind(link))
		%Directory.add_item(button.text.strip_edges(), Item.DIRECTORY + button.get_index())
	%Back.pressed.connect(back)
	%Forward.pressed.connect(forward)
	%Home.pressed.connect(func() -> void: navigate(home))
	%Reload.pressed.connect(reload)
	%Open.pressed.connect(_open_location)
	%Stop.pressed.connect(stop)
	%History.about_to_popup.connect(_list_history)
	%History.get_popup().index_pressed.connect(func(index: int) -> void: navigate(%History.get_popup().get_item_text(index)))
	_address.text_submitted.connect(navigate)
	_page.meta_clicked.connect(func(link: Variant) -> void: navigate(str(link)))
	_page.meta_hover_started.connect(func(link: Variant) -> void: _status.text = link)
	_page.meta_hover_ended.connect(func(_link: Variant) -> void: _status.text = "")
	%Meteors.draw.connect(_draw_meteors)
	set_process(false)
	_buttons()
	_paint(Page.new())
	if splash_seconds > 0.0 and get_parent() is Control:
		await _show_splash()
	if _load == 0:
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
	if not _Renderer.has_scheme(address):
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


## Shows the page on show again, as it is now on the disk.
func reload() -> void:
	if url != "":
		_open(url)


## Stops contacting a host; the page on show stays.
func stop() -> void:
	if _loading >= 0.0:
		_load += 1
		_stop_meteors()
		_address.text = url
		_status.text = "Transfer interrupted!"


func _go(to: String) -> void:
	if await _open(to):
		_history.resize(_at + 1)
		_history.append(to)
		_at = _history.size() - 1
		_buttons()


func _buttons() -> void:
	%Back.disabled = _at <= 0
	%Forward.disabled = _at >= _history.size() - 1


func _on_menu(id: int, menu: PopupMenu) -> void:
	match id:
		Item.OPEN_LOCATION:
			_open_location()
		Item.CLOSE:
			request_close()
		Item.COPY:
			DisplayServer.clipboard_set(_page.get_selected_text())
		Item.SELECT_ALL:
			_page.select_all()
		Item.RELOAD:
			reload()
		Item.BACK:
			back()
		Item.FORWARD:
			forward()
		Item.HOME:
			navigate(home)
		Item.STOP:
			stop()
		Item.SHOW_TOOLBAR, Item.SHOW_LOCATION, Item.SHOW_DIRECTORY:
			var index := menu.get_item_index(id)
			menu.toggle_item_checked(index)
			var bars := {Item.SHOW_TOOLBAR: %Toolbar, Item.SHOW_LOCATION: %LocationRow, Item.SHOW_DIRECTORY: %DirectoryButtons}
			(bars[id] as Control).visible = menu.is_item_checked(index)
		Item.ABOUT:
			navigate("about:")
		Item.HANDBOOK:
			navigate(%Handbook.get_meta(&"url"))
		_ when id >= Item.DIRECTORY:
			navigate(%DirectoryButtons.get_child(id - Item.DIRECTORY).get_meta(&"url"))


func _open_location() -> void:
	_address.grab_focus()
	_address.select_all()


func _list_history() -> void:
	var popup: PopupMenu = %History.get_popup()
	popup.clear()
	for visited in _history:
		popup.add_item(visited)


# The splash shows on the desktop, centred, while the window waits hidden.
func _show_splash() -> void:
	var splash: Control = %Splash
	remove_child(splash)
	var desktop := get_parent() as Control
	desktop.add_child(splash)
	splash.theme = theme  # outside the window, it would lose the Win95 fonts
	splash.top_level = false
	splash.size = splash.custom_minimum_size
	splash.position = ((desktop.size - splash.size) / 2).floor()
	splash.show()
	visible = false
	await get_tree().create_timer(splash_seconds).timeout
	splash.queue_free()
	if is_queued_for_deletion():
		return
	visible = true
	if desktop is Win95Desktop:
		(desktop as Win95Desktop).activate(self)


# Shows the page at [param to] and returns true, or alerts why it can't and keeps the page on show.
# A page asked for after it wins: this one then returns false.
func _open(to: String) -> bool:
	_load += 1
	var load := _load
	_address.text = to
	var html := ""
	if to.begins_with("about:"):
		html = _ABOUT if to == "about:" else ""
	elif to.begins_with("file:///"):
		var path := to.trim_prefix("file:///").get_slice("#", 0).uri_decode().replace("/", "\\")
		var desktop_path := "C:\\WINDOWS\\Desktop\\"
		if path.to_upper().begins_with(desktop_path.to_upper()):
			path = "Desktop\\" + path.substr(desktop_path.length())
		var file: Win95File = _state.setup.file_at(path) if _state != null else null
		if file == null or file.is_folder:
			_fail("File Not Found\n\nThe file %s cannot be found. Please check the location and try again." % path)
			return false
		html = file.contents
	else:
		var host := to.get_slice("://", 1).get_slice("/", 0) if "://" in to else to.get_slice(":", 1).get_slice("@", 1)
		_status.text = "Connect: Contacting host: %s..." % host
		_loading = 0.0
		set_process(true)
		%Stop.disabled = false
		await _go_online()
		if load != _load:
			return false
		_stop_meteors()
		var cached := _cached(to)
		if cached == null:
			_fail("Netscape is unable to locate the server: %s\nThe server does not have a DNS entry.\n\nCheck the server name in the Location (URL) and try again." % host)
			return false
		html = cached.contents
	url = to
	var page := render(html, to, _cached_picture)
	page_title = page.title
	%TitleBar.title = "%s - [%s]" % [_app_title, page.title if page.title != "" else to.get_file()]
	_paint(page)
	_status.text = "Document: Done"
	return true


func _paint(page: Page) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = page.background
	style.set_content_margin_all(8)
	_page.add_theme_stylebox_override(&"normal", style)
	_page.add_theme_color_override(&"default_color", page.text_color)
	_page.text = page.bbcode
	_page.scroll_to_line(0)


# Tries to go online, as Winsock did: on a computer with a dial-up connection, AutoDial's Connect
# To dialog, modal to Netscape, until the player cancels it; else contact_seconds of trying. It
# never gets online: no computer on the bench has its modem.
func _go_online() -> void:
	var desktop := get_parent() as Win95Desktop
	if desktop == null or _state == null or _state.setup.dial_up_name == "":
		if contact_seconds > 0.0:
			await get_tree().create_timer(contact_seconds).timeout
		return
	var dialog: Node = desktop.open(_CONNECT_TO, false)
	dialog.show_connection(_state.setup)
	dialog.belong_to(self)
	await dialog.finished
	dialog.queue_free()


# The copy of [param link] in Netscape's disk cache, from the last time the computer was online, or
# null. The cache index, FAT.DB, has a line per copy: the URL, a tab and the file name.
func _cached(link: String) -> Win95File:
	if _state == null:
		return null
	var index := _state.setup.file_at(cache_folder + "\\FAT.DB")
	if index == null:
		return null
	for line in index.contents.split("\n", false):
		if line.get_slice("\t", 0).strip_edges() == link:
			var copy := _state.setup.file_at(cache_folder + "\\" + line.get_slice("\t", 1).strip_edges())
			return copy if copy != null and not copy.is_folder else null
	return null


# The resource path of the cached picture at [param link], or "" when the cache has none.
func _cached_picture(link: String) -> String:
	var copy := _cached(link)
	return copy.picture.resource_path if copy != null and copy.picture != null else ""


func _stop_meteors() -> void:
	_loading = -1.0
	set_process(false)
	%Stop.disabled = true
	%Meteors.queue_redraw()


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
	box.belong_to(self)


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
## HTML 3.2, and FORM, are left out; unclosed tags are fine, as browsers allowed. [param pictures]
## takes a picture's absolute URL and gives the resource path of its texture, or "" for Netscape's
## broken picture; without it, every picture is broken.
static func render(html: String, base: String, pictures := Callable()) -> Page:
	return _Renderer.new(base, pictures).run(html)


class _Renderer:
	const ABOUT_LOGO := "res://win95/netscape/logo_96.png"
	const BROKEN_PICTURE := "res://win95/netscape/broken.png"
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
	var _pictures := Callable()
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
	## True when [param link] starts with a scheme, such as http: or about:; a drive letter is none.
	static func has_scheme(link: String) -> bool:
		var colon := link.find(":")
		return colon > 1 and link.substr(0, colon).is_valid_ascii_identifier()

	static func resolve(base: String, link: String) -> String:
		if has_scheme(link):
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

	func _init(base: String, pictures: Callable) -> void:
		_base = base
		_pictures = pictures

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

	# Netscape's own pictures show; the rest were on the web, out of reach, so each shows Netscape's
	# broken picture, its ALT text as the tooltip.
	func _picture(attrs: Dictionary) -> String:
		if attrs.get("src", "") == "about:logo":
			return "[img]%s[/img]" % ABOUT_LOGO
		var path: String = _pictures.call(resolve(_base, attrs.get("src", ""))) if _pictures.is_valid() else ""
		if path != "":
			var size := ""
			if attrs.has("width") and attrs.has("height"):
				size = " width=%d height=%d" % [str(attrs["width"]).to_int(), str(attrs["height"]).to_int()]
			return "[img%s]%s[/img]" % [size, path]
		var alt: String = _decode(attrs.get("alt", "")).replace("\"", "'").replace("]", ")")
		return "[img tooltip=\"%s\"]%s[/img]" % [alt, BROKEN_PICTURE] if alt != "" else "[img]%s[/img]" % BROKEN_PICTURE

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
