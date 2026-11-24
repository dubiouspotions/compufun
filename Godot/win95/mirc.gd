extends "res://win95/window.gd"
## mIRC 4.1, the IRC client of spring 1996 (docs/mirc.md): the MDI frame with its Status window,
## the menus, the toolbar, and the Setup and Options dialogs. No computer in the shop has its modem,
## so Connect goes through Dial-Up Networking and fails in the Status window. Its folder on drive C
## holds MIRC.INI, whose name, nicknames and servers Setup shows, and the logs, which Options >
## Logging lists and opens as Windows opens a .log file: in Notepad.

## The menu items that do something; the rest are greyed out, as offline mIRC needs none.
enum Item { CONNECT = 1, SETUP, OPTIONS, EXIT, ABOUT }

## Where mIRC keeps MIRC.INI and its logs on drive C: its own folder, as 4.x did.
@export var folder := "C:\\MIRC"
## Seconds that Winsock tries to reach the server on a computer without a dial-up connection.
@export var contact_seconds := 2.0

const _SETUP := preload("res://win95/mirc_setup.tscn")
const _OPTIONS := preload("res://win95/mirc_options.tscn")
const _MESSAGE := preload("res://win95/message_box.tscn")
const _CONNECT_TO := preload("res://win95/connect_to.gd")
const _ABOUT := "mIRC32 v4.1\n\nCopyright (c) Khaled Mardam-Bey 1995,1996.\nAll rights reserved.\n\nAs a home user, you are under no obligation whatsoever to pay for this program."
const _NOT_CONNECTED := "*** Not connected to server"

## True while it tries to reach a server.
var connecting := false
## The lines in the Status window, oldest first.
var status_lines: PackedStringArray = []

var _state: ComputerState

@onready var _buffer: RichTextLabel = %Buffer
@onready var _editbox: LineEdit = %Editbox


func _ready() -> void:
	super()
	var desktop := get_parent() as Win95Desktop
	if desktop != null:
		_state = desktop.computer
	for menu in $VBox/MenuBar.get_children():
		(menu as PopupMenu).id_pressed.connect(_on_menu)
	%ConnectButton.pressed.connect(connect_to_server)
	%SetupButton.pressed.connect(open_setup)
	%OptionsButton.pressed.connect(open_options)
	%TitleBar.appearance_changed.connect(func() -> void: %StatusTitle.active = %TitleBar.active)
	%StatusTitle.close_pressed.connect(request_close)
	_editbox.text_submitted.connect(_on_command)


func _focus_default() -> void:
	_editbox.grab_focus()


## Adds [param line] at the bottom of the Status window.
func echo(line: String) -> void:
	status_lines.append(line)
	_buffer.text = "\n".join(status_lines)


## Connects to [param host] on [param port], or without a host to the server that MIRC.INI names, as
## File > Connect does: Winsock dials through AutoDial, gets nowhere, and the Status window says so.
## Without a server in MIRC.INI, it opens Setup instead.
func connect_to_server(host := "", port := 6667) -> void:
	if connecting:
		return
	if host == "":
		var server := _chosen_server()
		if server.is_empty():
			open_setup()
			return
		host = server[1]
		port = int(server[2])
	connecting = true
	echo("*** Connecting to %s (%d)" % [host, port])
	await _CONNECT_TO.autodial(self, _state.setup if _state != null else null, contact_seconds)
	connecting = false
	echo("*** Unable to resolve IRC server name")


## Opens File > Setup, modal to mIRC, filled from MIRC.INI. Its Connect! button connects to the
## server chosen in its list.
func open_setup() -> void:
	var sheet := _open_dialog(_SETUP)
	if sheet == null:
		return
	var ini := _ini()
	var user: Dictionary = ini.get("mirc", {})
	sheet.get_node("%RealName").text = user.get("user", "")
	sheet.get_node("%Email").text = user.get("email", "")
	sheet.get_node("%Nickname").text = user.get("nick", "")
	sheet.get_node("%Alternate").text = user.get("anick", "")
	var list: OptionButton = sheet.get_node("%Servers")
	var servers := _servers(ini)
	var chosen := _chosen_server()
	if not chosen.is_empty() and not servers.any(func(server: PackedStringArray) -> bool: return server.slice(1) == chosen.slice(1)):
		servers.push_front(chosen)
	for server in servers:
		list.add_item(server[0])
		if not chosen.is_empty() and server.slice(1) == chosen.slice(1):
			list.select(list.item_count - 1)
	sheet.get_node("%ConnectNow").pressed.connect(func() -> void:
		sheet.close()
		if list.selected < 0:
			connect_to_server()
		else:
			connect_to_server(servers[list.selected][1], int(servers[list.selected][2])))
	sheet.belong_to(self)


## Opens File > Options, modal to mIRC. Its Logging page lists the logs in mIRC's folder; View, or a
## double-click, opens the chosen one.
func open_options() -> void:
	var sheet := _open_dialog(_OPTIONS)
	if sheet == null:
		return
	var list: ItemList = sheet.get_node("%Logs")
	var logs := log_files()
	for file in logs:
		list.add_item(file.name)
	var view := func(index: int) -> void:
		if index >= 0 and index < logs.size():
			view_log(logs[index])
	list.item_activated.connect(view)
	sheet.get_node("%View").pressed.connect(func() -> void:
		var selected := list.get_selected_items()
		view.call(selected[0] if not selected.is_empty() else -1))
	sheet.belong_to(self)


## The log files in mIRC's folder, by name: one per channel or query window that it logged.
func log_files() -> Array[Win95File]:
	var found: Array[Win95File] = []
	var home := _state.setup.file_at(folder) if _state != null and _state.setup != null else null
	if home == null:
		return found
	for file: Win95File in home.children:
		if not file.is_folder and file.name.get_extension().to_lower() == "log":
			found.append(file)
	found.sort_custom(func(a: Win95File, b: Win95File) -> bool: return a.name.naturalnocasecmp_to(b.name) < 0)
	return found


## Opens [param file] as Windows opens a .log file: in the program that opens .log files, Notepad.
func view_log(file: Win95File) -> void:
	var desktop := get_parent() as Win95Desktop
	var screen: Node = desktop.owner if desktop != null else null  # win95.gd, which opens files as Windows does
	if screen == null or not screen.has_method(&"open_file"):
		push_error("mIRC: no Win95 screen owns its desktop, so it can't open %s" % file.name)
		return
	screen.open_file(file)


func _on_menu(id: int) -> void:
	match id:
		Item.CONNECT:
			connect_to_server()
		Item.SETUP:
			open_setup()
		Item.OPTIONS:
			open_options()
		Item.EXIT:
			request_close()
		Item.ABOUT:
			var box := _open_dialog(_MESSAGE)
			if box != null:
				box.closed.connect(box.queue_free)
				box.inform("About mIRC", _ABOUT, preload("res://win95/mirc/logo_32.png"))
				box.belong_to(self)


# The editbox takes commands; offline, only these do anything.
func _on_command(text: String) -> void:
	_editbox.clear()
	var words := text.strip_edges().split(" ", false)
	if words.is_empty():
		return
	match words[0].to_lower():
		"/server":
			if words.size() > 1:
				connect_to_server(words[1], int(words[2]) if words.size() > 2 else 6667)
			else:
				connect_to_server()
		"/clear":
			status_lines.clear()
			_buffer.text = ""
		_:
			echo(_NOT_CONNECTED)


# A new window made from [param scene] on mIRC's desktop; null, with an error, when it has none. The
# caller fills it, then makes it modal with belong_to, which centres it at its size.
func _open_dialog(scene: PackedScene) -> Control:
	var desktop := get_parent() as Win95Desktop
	if desktop == null:
		push_error("mIRC: not on a Win95Desktop, so it can't open %s" % scene.resource_path)
		return null
	return desktop.open(scene, false)


# MIRC.INI in mIRC's folder: each section by its lower-case name, holding its keys (lower case) and
# values. Empty when the file is missing.
func _ini() -> Dictionary:
	var file := _state.setup.file_at(folder + "\\MIRC.INI") if _state != null and _state.setup != null else null
	return parse_ini(file.contents) if file != null else {}


## The sections of an INI file's [param text], by lower-case name, each a Dictionary of its keys
## (lower case) to their values.
static func parse_ini(text: String) -> Dictionary:
	var sections := {}
	var section := {}
	for raw in text.split("\n"):
		var line := raw.strip_edges()
		if line.begins_with("[") and line.ends_with("]"):
			section = {}
			sections[line.substr(1, line.length() - 2).to_lower()] = section
		elif "=" in line:
			section[line.get_slice("=", 0).strip_edges().to_lower()] = line.substr(line.find("=") + 1)
	return sections


## A server line of MIRC.INI, such as "DALnet: Random serverSERVER:irc.dal.net:7000GROUP:01", as
## [description, host, port]; empty when it names no server.
static func parse_server(line: String) -> PackedStringArray:
	var at := line.find("SERVER:")
	if at < 0:
		return PackedStringArray()
	var address := line.substr(at + 7).get_slice("GROUP:", 0)
	return PackedStringArray([line.substr(0, at), address.get_slice(":", 0), address.get_slice(":", 1) if ":" in address else "6667"])


# The servers of MIRC.INI's [Servers] list, in its order.
func _servers(ini: Dictionary) -> Array[PackedStringArray]:
	var found: Array[PackedStringArray] = []
	var section: Dictionary = ini.get("servers", {})
	for key: String in section:
		var server := parse_server(section[key])
		if not server.is_empty():
			found.append(server)
	return found


# The server that Setup chose last, MIRC.INI's [mirc] host; empty when there is none.
func _chosen_server() -> PackedStringArray:
	var user: Dictionary = _ini().get("mirc", {})
	return parse_server(user.get("host", ""))
