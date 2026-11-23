extends "res://tests/test.gd"
## Netscape: HTML 3.2 turns into BBCode, links resolve, the window browses the .htm files on drive C,
## and with no modem every web address fails after the meteors, leaving the page on show.

const COMPUTER_STATE_PATH := "res://win95/computer_state.gd"  # loaded at run time: it names the Game autoload
const BROWSER_PATH := "res://win95/web_browser.tscn"


func run() -> void:
	for path in DirAccess.get_files_at("res://customers"):
		var customer := load("res://customers/" + path) as Customer if path.ends_with(".tres") else null
		if customer != null and customer.computer != null and customer.computer.win95_setup != null:
			var setup := customer.computer.win95_setup
			var shortcut := setup.file_at("Desktop\\Netscape Navigator")
			var program := setup.file_at(shortcut.target) if shortcut != null else null
			check("only the activist has Netscape: %s" % path, program != null and program.program == load(BROWSER_PATH), path == "activist_guy.tres")

	var browser: GDScript = load("res://win95/web_browser.gd")
	check("a relative link", browser.resolve("http://a.com/x/y.htm", "z.htm"), "http://a.com/x/z.htm")
	check("up a folder", browser.resolve("http://a.com/x/y.htm", "../z.htm"), "http://a.com/z.htm")
	check("from the root", browser.resolve("http://a.com/x/y.htm", "/"), "http://a.com/")
	check("from a bare host", browser.resolve("http://a.com", "z.htm"), "http://a.com/z.htm")
	check("an absolute link", browser.resolve("http://a.com/", "http://b.com/"), "http://b.com/")
	check("on drive C", browser.resolve("file:///C:/DOCS/a.htm", "b.htm"), "file:///C:/DOCS/b.htm")

	var page: RefCounted = browser.render("<title> Hi  there </title><body bgcolor=navy text=\"#FFFF00\"><h1>Big</h1><p>a  <b>b</b>\n<i>c</i> [d] &amp; &lt;e&gt;<p align=center>f<p>g", "http://a.com/")
	check("the title", page.title, "Hi there")
	check("BGCOLOR by name", page.background, Color("#000080"))
	check("TEXT by hex", page.text_color, Color("#ffff00"))
	check("the BBCode", page.bbcode, "[font_size=24][b]Big[/b][/font_size]\n\na [b]b[/b] [i]c[/i] [lb]d[rb] & <e>\n\n[center]f[/center]\n\ng")
	page = browser.render("<ul><li>one<li>two</ul>after<a href=\"b.htm\">link</a><script>x()</script><pre>\na\n  b</pre>", "http://a.com/")
	check("lists, links, PRE and no SCRIPT", page.bbcode, "[ul]one\ntwo[/ul]\nafter[url=http://a.com/b.htm][color=#0000ff]link[/color][/url]\n\n[code]a\n  b[/code]")

	var b := Win95File.new()
	b.name = "B.HTM"
	b.contents = "<title>Bee</title>"
	var a := Win95File.new()
	a.name = "A.HTM"
	a.contents = "<a href=\"B.HTM\">b</a><img src=\"pic.gif\" alt=\"Pic\">"
	var docs := Win95File.new()
	docs.name = "DOCS"
	docs.is_folder = true
	docs.children = [a, b]
	var setup := Win95Setup.new()
	setup.drive_c = [docs]
	var state: Node = load(COMPUTER_STATE_PATH).new()
	state.setup = setup

	var desk := Control.new()
	desk.size = Vector2(640, 480)
	root.add_child(desk)
	var window: Node = load(BROWSER_PATH).instantiate()
	desk.add_child(window)
	await process_frame
	var splash: Node = desk.get_node_or_null(^"Splash")
	check("the splash shows first, centred, and the window waits", [splash != null and splash.visible, splash.position if splash != null else Vector2.ZERO, window.visible], [true, Vector2(215, 82), false])
	await create_timer(window.splash_seconds + 0.1).timeout
	check("then the window shows, and the splash is gone", [window.visible, is_instance_valid(splash)], [true, false])
	check("the meteors fly while it contacts home", [window.is_processing(), window.get_node("%Address").text, window.get_node("%Stop").disabled], [true, "http://home.netscape.com/", false])
	await create_timer(window.contact_seconds + 0.1).timeout
	check("no modem: they stop, and the window stays blank", [window.is_processing(), window.url, window.get_node("%Address").text], [false, "", ""])
	window.navigate("www.yahoo.com")
	window.stop()
	check("Stop stops it at once", [window.is_processing(), window.get_node("%Status").text, window.get_node("%Address").text], [false, "Transfer interrupted!", ""])
	window.contact_seconds = 0.0
	check("the Directory menu lists the directory buttons", window.get_node("%Directory").item_count, 7)
	window.navigate("about:")
	check("about: is Netscape's own page, with its logo", [window.page_title, window.get_node("%Page").text.contains("[img]res://win95/netscape/logo_96.png[/img]")], ["Version 2.0", true])
	window.back()

	window.open_file(a, state)
	check("opens a file on drive C", window.url, "file:///C:/DOCS/A.HTM")
	check("its picture is out of reach: the broken picture", window.get_node("%Page").text.contains("[img tooltip=\"Pic\"]res://win95/netscape/broken.png[/img]"), true)
	window.get_node("%Page").meta_clicked.emit(browser.resolve(window.url, "B.HTM"))
	check("and follows its link to another", window.page_title, "Bee")
	window.back()
	check("Back goes back", window.url, "file:///C:/DOCS/A.HTM")
	window.forward()
	check("Forward goes forward", window.url, "file:///C:/DOCS/B.HTM")
	window.back()
	window.navigate("www.yahoo.com")
	check("a web address fails and keeps the page", [window.url, window.get_node("%Address").text, window.get_node("%Forward").disabled], ["file:///C:/DOCS/A.HTM", "file:///C:/DOCS/A.HTM", false])
	window.navigate("C:\\DOCS\\GONE.HTM")
	check("so does a missing file", window.url, "file:///C:/DOCS/A.HTM")
	state.free()
	desk.queue_free()
	await process_frame
