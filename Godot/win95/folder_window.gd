extends "res://win95/window.gd"
## A Win95 folder window, as explorer.exe opens it: icons in the view that the View menu picks,
## a menu bar, and a status bar that counts the icons.

enum FileMenu { CLOSE }

const _HEADER_HEIGHT := 17.0
static var _palette: Win95Palette = preload("res://win95/theme/palette.tres")

## The icons. Fill it with items.add_item(); its item_opened signal reports double-clicks. Its
## folder_view is the window's view, and its columns are the Details header's.
@onready var items: IconView = %Items
@onready var _object_count: Label = %ObjectCount
@onready var _scroll: ScrollContainer = %Scroll
@onready var _header: Control = %Header
## The square where the two scroll bars meet, which Win95 fills with the face colour.
@onready var _corner: Control = %Corner


func _ready() -> void:
	super()
	%File.id_pressed.connect(func(id: int) -> void:
		if id == FileMenu.CLOSE:
			close())
	%Edit.id_pressed.connect(func(_id: int) -> void: items.select_all())
	%View.id_pressed.connect(func(id: int) -> void: items.folder_view = id as IconView.FolderView)
	for i in %Help.item_count:
		%Help.set_item_icon(i, Stub.dot())
	_header.draw.connect(_draw_header)
	_corner.draw.connect(func() -> void: _corner.draw_rect(Rect2(Vector2.ZERO, _corner.size), _palette.face_color))
	_scroll.sort_children.connect(_fit_to_bars)
	_scroll.get_h_scroll_bar().value_changed.connect(func(_value: float) -> void: _header.queue_redraw())
	items.items_changed.connect(_sync_status)
	items.folder_view_changed.connect(_sync_view)
	_sync_status()
	_sync_view()


func _sync_status() -> void:
	_object_count.text = "%d object(s)" % items.item_count()


func _sync_view() -> void:
	var folder_view := items.folder_view
	for i in %View.item_count:
		%View.set_item_checked(i, %View.get_item_id(i) == folder_view)
	var details := folder_view == IconView.FolderView.DETAILS
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if folder_view in [IconView.FolderView.LIST, IconView.FolderView.DETAILS] else ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED if folder_view == IconView.FolderView.LIST else ScrollContainer.SCROLL_MODE_AUTO
	%ItemsMargin.add_theme_constant_override("margin_top", int(_HEADER_HEIGHT) if details else 0)
	_header.visible = details
	_fit_to_bars()


# The header lies over the top of the scroll area, so the vertical scroll bar runs beside it, as in Win95.
func _fit_to_bars() -> void:
	var down := _scroll.get_v_scroll_bar()
	var across := _scroll.get_h_scroll_bar()
	_header.offset_right = -down.size.x if down.visible else 0.0
	_header.queue_redraw()
	_corner.visible = down.visible and across.visible
	_corner.offset_left = -down.size.x
	_corner.offset_top = -across.size.y


func _draw_header() -> void:
	var button := _header.get_theme_stylebox("normal", &"Button")
	var font := _header.get_theme_font("font", &"Label")
	var font_size := _header.get_theme_font_size("font_size", &"Label")
	var ink := _header.get_theme_color("font_color", &"Label")
	var x := -float(_scroll.scroll_horizontal)
	for column in items.columns:
		var cell := Rect2(x, 0, column.width, _HEADER_HEIGHT)
		_header.draw_style_box(button, cell)
		ReportList.draw_text(_header, cell, column.title, font, font_size, ink, FileIcon.CELL_PAD, column.right_aligned)
		x += column.width
	# Win95 fills the rest of the header with a blank button whose right edge is out of sight.
	_header.draw_style_box(button, Rect2(x, 0, maxf(_header.size.x - x, 0.0) + 4.0, _HEADER_HEIGHT))
