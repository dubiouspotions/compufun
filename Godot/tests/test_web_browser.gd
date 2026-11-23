extends "res://tests/test.gd"
## Netscape: HTML 3.2 turns into BBCode, links resolve, and the window browses the
## CompuFun site, a missing page, a missing host and the .htm files on drive C.

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

	var window: Node = load(BROWSER_PATH).instantiate()
	root.add_child(window)
	await process_frame
	check("opens at home", window.url, "http://www.compufun.com/")
	check("titled after the page", window.get_node("%TitleBar").title, "Netscape - [CompuFun - Your Friendly Computer Store]")
	check("shows the logo", window.get_node("%Page").text.contains("[img width=82 height=82]res://win95/web/www.compufun.com/logo.png[/img]"), true)
	window.get_node("%Page").meta_clicked.emit("http://www.compufun.com/support.htm")
	check("a link goes to its page", window.page_title, "CompuFun Support")
	window.back()
	check("Back goes back", window.url, "http://www.compufun.com/")
	window.forward()
	check("Forward goes forward", window.url, "http://www.compufun.com/support.htm")
	window.navigate("www.compufun.com/nothing.htm")
	check("a missing page is a 404", window.page_title, "404 Not Found")
	check("and cuts Forward", window.get_node("%Forward").disabled, true)
	window.navigate("www.nowhere.com")
	check("a missing host", [window.url, window.page_title], ["http://www.nowhere.com", "Unable to locate server"])

	var b := Win95File.new()
	b.name = "B.HTM"
	b.contents = "<title>Bee</title>"
	var a := Win95File.new()
	a.name = "A.HTM"
	a.contents = "<a href=\"B.HTM\">b</a>"
	var docs := Win95File.new()
	docs.name = "DOCS"
	docs.is_folder = true
	docs.children = [a, b]
	var setup := Win95Setup.new()
	setup.drive_c = [docs]
	var state: Node = load(COMPUTER_STATE_PATH).new()
	state.setup = setup
	window.open_file(a, state)
	check("opens a file on drive C", window.url, "file:///C:/DOCS/A.HTM")
	window.get_node("%Page").meta_clicked.emit(browser.resolve(window.url, "B.HTM"))
	check("and follows its link to another", window.page_title, "Bee")
	window.navigate("C:\\DOCS\\GONE.HTM")
	check("a missing file", window.page_title, "Cannot open file")
	state.free()
	window.queue_free()
	await process_frame
