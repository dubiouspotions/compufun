extends "res://tests/test.gd"
## The Details texts, a deleted file's Original Location, and the View menu of a folder window.

const COMPUTER_STATE_PATH := "res://win95/computer_state.gd"  # loaded at run time: it names the Game autoload
const FILE_DETAILS_PATH := "res://win95/file_details.gd"  # names ComputerState
const ICON_VIEW_PATH := "res://win95/icon_view.gd"  # names Win95Desktop, which names ComputerState


func run() -> void:
	var details: GDScript = load(FILE_DETAILS_PATH)
	var note := _file("NETLOG.TXT")
	note.contents = "x".repeat(1500)
	note.modified = "Thursday, May 30, 1996 11:12:44 PM"
	check("a file's Details", details.cells(&"folder", note, null), PackedStringArray(["2KB", "Text Document", "5/30/96 11:12 PM"]))
	var windows := _file("WINDOWS")
	windows.is_folder = true
	check("a folder's Details", details.cells(&"folder", windows, null), PackedStringArray(["", "File Folder", ""]))
	var drive := _file("(C:)")
	drive.is_folder = true
	check("a drive's Details in My Computer", details.cells(&"my_computer", drive, null), PackedStringArray(["Local Disk", "", ""]))

	var state: Node = load(COMPUTER_STATE_PATH).new()
	state.setup = Win95Setup.new()
	state.setup.drive_c.append(windows)
	windows.children.append(note)
	state.setup.recycle_bin.append(note)
	state.setup.deleted_from[note] = windows.children
	check("the Original Location of a file deleted from a folder", state.original_location(note), "C:\\WINDOWS")
	state.setup.deleted_from.erase(note)
	check("the Original Location of a file that the setup put in the bin", state.original_location(note), "C:\\WINDOWS\\Desktop")
	state.free()

	var window: Node = (load("res://win95/folder_window.tscn") as PackedScene).instantiate()
	root.add_child(window)
	await process_frame
	var views: Dictionary = (load(ICON_VIEW_PATH) as GDScript).get_script_constant_map().FolderView
	var items: FlowContainer = window.items
	var view_menu: PopupMenu = window.get_node("%View")
	view_menu.id_pressed.emit(views.LIST)
	check("View > List switches the view", items.folder_view, views.LIST)
	check("List fills columns", items.vertical, true)
	check("the View menu's radio follows the view", range(view_menu.item_count).map(func(i: int) -> bool: return view_menu.is_item_checked(i)), [false, false, true, false])
	items.folder_view = views.DETAILS
	check("the radio follows a switch from elsewhere", view_menu.is_item_checked(view_menu.get_item_index(views.DETAILS)), true)
	check("the Details header shows", window.get_node("%Header").visible, true)
	var icon: Node = items.get_child(0)
	check("Details rows are compact", icon.compact, true)
	items.folder_view = views.LARGE_ICONS
	check("Large Icons hides the header", window.get_node("%Header").visible, false)
	check("Large Icons fills rows", items.vertical, false)
	window.queue_free()


func _file(file_name: String) -> Win95File:
	var file := Win95File.new()
	file.name = file_name
	return file
