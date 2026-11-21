extends SceneTree
## Builds the shop's wall shelving of IT goods for sale: the goods atlas
## (materials/textures/shop_goods.png), the pegboard tile (materials/textures/pegboard.png) and one
## mesh, props/wall_shelf.tres, with three surfaces: 0 the metal frame, 1 the pegboard, 2 the goods.
## props/wall_shelf.tscn gives each surface its material, so the whole wall costs three draw calls.
## The mesh's front faces +Z, X runs along the wall and the floor is at Y 0.
## Usage, from Godot/: godot --headless --path . -s ../tools/make_wall_shelf.gd, then --import.

const ATLAS_PATH := "res://materials/textures/shop_goods.png"
const PEGBOARD_PATH := "res://materials/textures/pegboard.png"
const MESH_PATH := "res://props/wall_shelf.tres"
const ATLAS_SIZE := 128.0

const CARD_W := 16
const SOFTWARE_W := 24
const CARDS := [
	{"label": "VGA", "band": Color8(40, 70, 170), "cable": Color8(25, 25, 28), "plug": Color8(40, 60, 150)},
	{"label": "COM", "band": Color8(30, 130, 70), "cable": Color8(130, 130, 135), "plug": Color8(205, 195, 165)},
	{"label": "LPT", "band": Color8(180, 30, 35), "cable": Color8(205, 195, 165), "plug": Color8(130, 130, 135)},
	{"label": "PWR", "band": Color8(235, 190, 30), "cable": Color8(25, 25, 28), "plug": Color8(25, 25, 28)},
	{"label": "TEL", "band": Color8(230, 120, 30), "cable": Color8(205, 195, 165), "plug": Color8(240, 240, 235)},
	{"label": "PS2", "band": Color8(110, 50, 150), "cable": Color8(130, 130, 135), "plug": Color8(110, 50, 150)},
	{"label": "SCSI", "band": Color8(20, 130, 140), "cable": Color8(25, 25, 28), "plug": Color8(130, 130, 135)},
	{"label": "IDE", "band": Color8(70, 70, 75), "cable": Color8(170, 170, 170), "plug": Color8(25, 25, 28)},
]
const SOFTWARE := [
	{"title": "ATLAS", "back": Color8(20, 40, 110), "ink": Color8(250, 220, 60)},
	{"title": "PAINT", "back": Color8(20, 150, 150), "ink": Color8(255, 255, 255)},
	{"title": "GOLF", "back": Color8(40, 120, 40), "ink": Color8(255, 255, 255)},
	{"title": "C:\\>", "back": Color8(30, 30, 35), "ink": Color8(170, 170, 170)},
	{"title": "RACE", "back": Color8(15, 15, 15), "ink": Color8(230, 40, 30)},
]
const PATCH_COLORS := {
	"black": Color8(25, 25, 28), "grey": Color8(130, 130, 135), "beige": Color8(205, 195, 165),
	"vga": Color8(40, 60, 150), "white": Color8(240, 240, 235), "card_edge": Color8(215, 210, 200),
}

# 3 x 5 glyphs, one string per row.
const FONT := {
	"A": ["###", "#.#", "###", "#.#", "#.#"], "C": ["###", "#..", "#..", "#..", "###"],
	"D": ["##.", "#.#", "#.#", "#.#", "##."], "E": ["###", "#..", "##.", "#..", "###"],
	"F": ["###", "#..", "##.", "#..", "#.."], "G": ["###", "#..", "#.#", "#.#", "###"],
	"H": ["#.#", "#.#", "###", "#.#", "#.#"], "I": ["###", ".#.", ".#.", ".#.", "###"],
	"L": ["#..", "#..", "#..", "#..", "###"], "M": ["#.#", "###", "###", "#.#", "#.#"],
	"N": ["##.", "#.#", "#.#", "#.#", "#.#"], "O": ["###", "#.#", "#.#", "#.#", "###"],
	"P": ["###", "#.#", "###", "#..", "#.."], "R": ["##.", "#.#", "##.", "#.#", "#.#"],
	"S": ["###", "#..", "###", "..#", "###"], "T": ["###", ".#.", ".#.", ".#.", ".#."],
	"U": ["#.#", "#.#", "#.#", "#.#", "###"], "V": ["#.#", "#.#", "#.#", "#.#", ".#."], "W": ["#.#", "#.#", "###", "###", "#.#"],
	"X": ["#.#", "#.#", ".#.", "#.#", "#.#"], "0": ["###", "#.#", "#.#", "#.#", "###"],
	"1": [".#.", "##.", ".#.", ".#.", "###"], "2": ["###", "..#", "###", "#..", "###"],
	"3": ["###", "..#", ".##", "..#", "###"], "4": ["#.#", "#.#", "###", "..#", "..#"],
	"5": ["###", "#..", "###", "..#", "###"], "6": ["###", "#..", "###", "#.#", "###"],
	"8": ["###", "#.#", "###", "#.#", "###"], "9": ["###", "#.#", "###", "..#", "###"],
	"$": [".##", "##.", ".#.", ".##", "##."], ".": ["...", "...", "...", "...", ".#."],
	":": ["...", ".#.", "...", ".#.", "..."], "\\": ["#..", "#..", ".#.", "..#", "..#"],
	">": ["#..", ".#.", "..#", ".#.", "#.."],
}

var _img := Image.create(int(ATLAS_SIZE), int(ATLAS_SIZE), false, Image.FORMAT_RGBA8)
var _rng := RandomNumberGenerator.new()
## Atlas rects of the goods, in pixels, by name.
var _rects := {}
var _frame := SurfaceTool.new()
var _pegboard := SurfaceTool.new()
var _goods := SurfaceTool.new()
var _failed := false


func _initialize() -> void:
	_rng.seed = 102
	_draw_atlas()
	var failed := _failed or not _save_png(_img, ATLAS_PATH)
	failed = not _save_png(_pegboard_tile(), PEGBOARD_PATH) or failed
	for st: SurfaceTool in [_frame, _pegboard, _goods]:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_build()
	var mesh := ArrayMesh.new()
	for st: SurfaceTool in [_frame, _pegboard, _goods]:
		st.index()
		st.commit(mesh)
	var err := ResourceSaver.save(mesh, MESH_PATH)
	if err != OK:
		push_error("make_wall_shelf: couldn't save %s: %s" % [MESH_PATH, error_string(err)])
		failed = true
	else:
		print("make_wall_shelf: wrote ", MESH_PATH)
	quit(1 if failed else 0)


func _save_png(image: Image, path: String) -> bool:
	var err := image.save_png(ProjectSettings.globalize_path(path))
	if err != OK:
		push_error("make_wall_shelf: couldn't save %s: %s" % [path, error_string(err)])
		return false
	print("make_wall_shelf: wrote ", path)
	return true


# --- The atlas -------------------------------------------------------------------------------

func _draw_atlas() -> void:
	_img.fill(Color8(128, 128, 128))
	for i in CARDS.size():
		_card(i * CARD_W, CARDS[i])
	for i in SOFTWARE.size():
		_software(i * SOFTWARE_W, i, SOFTWARE[i])
	var names: Array = PATCH_COLORS.keys()
	for i in names.size():
		_rects[names[i]] = _fill(Rect2i(120, 32 + i * 4, 8, 4), PATCH_COLORS[names[i]])
	_modem(Rect2i(0, 64, 32, 24))
	_cdrom(Rect2i(32, 64, 32, 24))
	_mouse(Rect2i(64, 64, 16, 24))
	_floppies(Rect2i(80, 64, 16, 16))
	_speakers(Rect2i(96, 64, 32, 24))
	_keyboard(Rect2i(0, 88, 64, 16))
	_price_strip(Rect2i(64, 88, 64, 8))
	_ribbon(Rect2i(0, 104, 8, 24))


func _fill(r: Rect2i, c: Color) -> Rect2i:
	_img.fill_rect(r, c)
	return r


func _noise(r: Rect2i, amount: float) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var c := _img.get_pixel(x, y)
			_img.set_pixel(x, y, c.darkened(_rng.randf_range(0.0, amount)))


func _text(x: int, y: int, text: String, c: Color) -> void:
	for ch in text:
		if not FONT.has(ch):
			push_error("make_wall_shelf: no glyph for '%s' in '%s'" % [ch, text])
			_failed = true
			continue
		var glyph: Array = FONT[ch]
		for row in 5:
			for col in 3:
				if (glyph[row] as String)[col] == "#":
					_img.set_pixel(x + col, y + row, c)
		x += 4


func _text_width(text: String) -> int:
	return text.length() * 4 - 1


func _ring(center: Vector2, radius: Vector2, c: Color) -> void:
	for i in 48:
		var a := TAU * i / 48.0
		_img.set_pixelv(Vector2i((center + Vector2(cos(a), sin(a)) * radius).round()), c)


func _disc(center: Vector2, radius: float, c: Color) -> void:
	for y in range(floori(center.y - radius), ceili(center.y + radius) + 1):
		for x in range(floori(center.x - radius), ceili(center.x + radius) + 1):
			if Vector2(x, y).distance_to(center) <= radius:
				_img.set_pixel(x, y, c)


func _sticker(x: int, y: int) -> void:
	_fill(Rect2i(x, y, 5, 3), Color8(255, 150, 30))
	_img.set_pixel(x + 1, y + 1, Color8(200, 20, 20))
	_img.set_pixel(x + 3, y + 1, Color8(200, 20, 20))


func _card(x: int, spec: Dictionary) -> void:
	var r := _fill(Rect2i(x, 0, CARD_W, 32), Color8(232, 228, 216))
	_rects["card_" + spec.label] = r
	_fill(Rect2i(x, 0, CARD_W, 10), spec.band)
	_fill(Rect2i(x + 7, 1, 2, 2), Color8(40, 36, 32))
	var label: String = spec.label
	_text(x + (CARD_W - _text_width(label)) / 2, 4, label, Color.WHITE)
	_fill(Rect2i(x + 1, 11, CARD_W - 2, 17), Color8(196, 206, 214))
	_fill(Rect2i(x + 2, 12, 1, 15), Color8(235, 240, 245))
	_ring(Vector2(x + 7.5, 18.5), Vector2(5, 5), spec.cable)
	_ring(Vector2(x + 7.5, 18.5), Vector2(3.5, 3.5), spec.cable)
	_fill(Rect2i(x + 4, 24, 3, 2), spec.plug)
	_fill(Rect2i(x + 9, 24, 3, 2), spec.plug)
	_sticker(x + 10, 28)


func _software(x: int, index: int, spec: Dictionary) -> void:
	var r := _fill(Rect2i(x, 32, SOFTWARE_W, 32), spec.back)
	_rects["software_%d" % index] = r
	_noise(r, 0.08)
	var ink: Color = spec.ink
	var title: String = spec.title
	_text(x + (SOFTWARE_W - _text_width(title)) / 2, 34, title, ink)
	var mid := Vector2(x + 11.5, 49.5)
	match index:
		0:
			_disc(mid, 7.0, Color8(40, 110, 200))
			_disc(mid + Vector2(-2, -2), 2.5, Color8(60, 160, 60))
			_disc(mid + Vector2(3, 2), 2.0, Color8(60, 160, 60))
		1:
			_disc(mid + Vector2(-3, -1), 4.0, Color8(230, 50, 60))
			_disc(mid + Vector2(3, 2), 3.5, Color8(250, 210, 40))
			_disc(mid + Vector2(-1, 4), 2.5, Color8(60, 80, 220))
		2:
			_fill(Rect2i(x + 2, 52, 20, 6), Color8(90, 180, 70))
			_fill(Rect2i(x + 15, 42, 1, 11), Color.WHITE)
			_fill(Rect2i(x + 16, 42, 4, 3), Color8(230, 40, 30))
			_disc(Vector2(x + 7, 50), 1.5, Color.WHITE)
		3:
			_fill(Rect2i(x + 3, 42, 18, 13), Color8(0, 0, 170))
			_text(x + 4, 44, "C:\\", Color8(255, 255, 85))
			_fill(Rect2i(x + 4, 50, 3, 1), Color8(170, 170, 170))
		4:
			for i in 5:
				_fill(Rect2i(x + 2 + i * 4, 52 - i * 2, 3, 4 + i * 2), Color8(250, 140 + i * 20, 30))
	_fill(Rect2i(x, 60, SOFTWARE_W, 4), ink.darkened(0.3))
	_sticker(x + 17, 56)


func _modem(r: Rect2i) -> void:
	_rects["modem"] = _fill(r, Color8(20, 20, 24))
	_fill(Rect2i(r.position.x, r.position.y + 15, r.size.x, 3), Color8(200, 30, 30))
	_text(r.position.x + 2, r.position.y + 2, "28.8", Color.WHITE)
	_fill(Rect2i(r.position.x + 12, r.position.y + 9, 16, 5), Color8(205, 195, 165))
	for i in 4:
		_img.set_pixel(r.position.x + 15 + i * 3, r.position.y + 11, Color8(60, 230, 60))
	_sticker(r.position.x + 25, r.position.y + 20)


func _cdrom(r: Rect2i) -> void:
	_rects["cdrom"] = _fill(r, Color8(185, 185, 195))
	_noise(r, 0.06)
	_fill(Rect2i(r.position.x, r.position.y + 18, r.size.x, 6), Color8(100, 40, 150))
	var c := Vector2(r.position.x + 20.5, r.position.y + 9.5)
	_disc(c, 7.0, Color8(225, 225, 235))
	_ring(c, Vector2(5, 5), Color8(150, 110, 210))
	_disc(c, 1.5, Color8(185, 185, 195))
	_text(r.position.x + 2, r.position.y + 3, "4X", Color8(100, 40, 150))
	_sticker(r.position.x + 2, r.position.y + 12)


func _mouse(r: Rect2i) -> void:
	_rects["mouse"] = _fill(r, Color8(240, 240, 235))
	_fill(Rect2i(r.position.x, r.position.y, r.size.x, 5), Color8(30, 80, 170))
	_fill(Rect2i(r.position.x + 7, r.position.y + 5, 1, 4), Color8(60, 60, 60))
	_disc(Vector2(r.position.x + 7.5, r.position.y + 14), 4.0, Color8(200, 195, 180))
	_fill(Rect2i(r.position.x + 7, r.position.y + 10, 1, 4), Color8(120, 115, 105))
	_sticker(r.position.x + 10, r.position.y + 20)


func _floppies(r: Rect2i) -> void:
	_rects["floppy"] = _fill(r, Color8(25, 45, 120))
	_text(r.position.x + 1, r.position.y + 1, "HD", Color.WHITE)
	var colors := [Color8(220, 40, 40), Color8(240, 200, 30), Color8(40, 170, 60)]
	for i in 3:
		_fill(Rect2i(r.position.x + 2 + i * 4, r.position.y + 8 - i, 5, 6), colors[i])
		_fill(Rect2i(r.position.x + 3 + i * 4, r.position.y + 8 - i, 3, 2), Color8(190, 190, 200))


func _speakers(r: Rect2i) -> void:
	_rects["speakers"] = _fill(r, Color8(30, 30, 30))
	for i in 2:
		var c := Vector2(r.position.x + 8.5 + i * 15, r.position.y + 13.5)
		_disc(c, 5.0, Color8(90, 90, 95))
		_disc(c, 2.0, Color8(50, 50, 55))
	_text(r.position.x + 7, r.position.y + 1, "AUDIO", Color8(250, 200, 40))
	_sticker(r.position.x + 26, r.position.y + 20)


func _keyboard(r: Rect2i) -> void:
	_rects["keyboard"] = _fill(r, Color8(240, 240, 235))
	_fill(Rect2i(r.position.x, r.position.y, 8, r.size.y), Color8(30, 80, 170))
	_fill(Rect2i(r.position.x + 12, r.position.y + 4, 44, 9), Color8(205, 195, 165))
	for y in 3:
		for x in 14:
			_img.set_pixel(r.position.x + 13 + x * 3, r.position.y + 5 + y * 3, Color8(120, 115, 105))
	_sticker(r.position.x + 57, r.position.y + 12)


## Shelf-edge price labels: white tags with a red dollar and a black price, on a dark channel.
func _price_strip(r: Rect2i) -> void:
	_rects["price_strip"] = _fill(r, Color8(50, 50, 55))
	var prices := ["9", "19", "29", "49", "5"]
	for i in prices.size():
		var tag := Rect2i(r.position.x + i * 13, r.position.y + 1, 12, 7)
		_fill(tag, Color8(245, 245, 240))
		_text(tag.position.x + 1, tag.position.y + 1, "$", Color8(200, 20, 20))
		_text(tag.position.x + 5, tag.position.y + 1, prices[i], Color.BLACK)
		if i == 0:
			_rects["price_tag"] = tag


func _ribbon(r: Rect2i) -> void:
	_rects["ribbon"] = _fill(r, Color8(175, 175, 175))
	for x in range(1, r.size.x, 2):
		_fill(Rect2i(r.position.x + x, r.position.y, 1, r.size.y), Color8(150, 150, 150))
	_fill(Rect2i(r.position.x, r.position.y, 1, r.size.y), Color8(200, 30, 30))


func _pegboard_tile() -> Image:
	var tile := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	for y in 8:
		for x in 8:
			tile.set_pixel(x, y, Color8(165, 125, 82).darkened(_rng.randf_range(0.0, 0.08)))
	tile.fill_rect(Rect2i(3, 3, 2, 2), Color8(55, 40, 28))
	return tile


# --- The mesh --------------------------------------------------------------------------------

const LENGTH := 3.0
const LOW_DEPTH := 0.4
const HIGH_DEPTH := 0.3
const PEGBOARD_BOTTOM := 1.0
const PEGBOARD_TOP := 2.17
## The tops of the boards that goods stand on: the plinth, two low boards and two high boards.
const BOARD_TOPS := [0.1, 0.55, 0.98, 2.22, 2.62]
const HOOK_ROWS := [2.06, 1.6]
const HOOK_XS := [-1.32, -1.1, -0.88, -0.66, -0.44, -0.22, 0.22, 0.44, 0.66, 0.88, 1.1, 1.32]
## What hangs on each hook, row by row: a card's label, or coil_<colour>, or ribbon.
const HOOKS := [
	["VGA", "VGA", "coil_black", "COM", "LPT", "ribbon", "PWR", "coil_grey", "TEL", "PS2", "SCSI", "IDE"],
	["coil_vga", "PWR", "IDE", "ribbon", "COM", "coil_beige", "LPT", "VGA", "coil_black", "TEL", "ribbon", "PS2"],
]
## The goods on each board, left bay then right bay, repeated until the bay is full.
const SHELVES := [
	["speakers", "cdrom"],
	["keyboard"],
	["mouse", "floppy", "mouse", "floppy", "floppy"],
	["modem", "cdrom", "speakers", "modem", "cdrom"],
	["software_0", "software_1", "software_2", "software_3", "software_4", "software_2", "software_0"],
]
## Width and height of each kind of goods' front, in metres.
const GOODS_SIZES := {
	"software": Vector2(0.19, 0.25), "modem": Vector2(0.27, 0.2), "cdrom": Vector2(0.26, 0.19),
	"mouse": Vector2(0.12, 0.18), "floppy": Vector2(0.1, 0.1), "speakers": Vector2(0.27, 0.2),
	"keyboard": Vector2(0.5, 0.125),
}


func _build() -> void:
	var half := LENGTH * 0.5
	var high_board_bottom: float = BOARD_TOPS[3] - 0.03
	for x: float in [-half + 0.02, 0.0, half - 0.02]:
		_box(_frame, Vector3(x, high_board_bottom * 0.5 + 0.22, 0.015), Vector3(0.04, high_board_bottom + 0.44, 0.03), Vector3i(1, 5, 1))
	for x: float in [-half + 0.015, half - 0.015]:
		_box(_frame, Vector3(x, 0.5, LOW_DEPTH * 0.5), Vector3(0.03, 1.0, LOW_DEPTH), Vector3i(1, 2, 1))
	_box(_pegboard, Vector3(0.0, (PEGBOARD_BOTTOM + PEGBOARD_TOP) * 0.5, 0.01), Vector3(LENGTH - 0.06, PEGBOARD_TOP - PEGBOARD_BOTTOM, 0.02), Vector3i(6, 3, 1))
	for i in BOARD_TOPS.size():
		var top: float = BOARD_TOPS[i]
		var depth := LOW_DEPTH if top < PEGBOARD_BOTTOM else HIGH_DEPTH
		var thickness := 0.1 if i == 0 else 0.03
		_box(_frame, Vector3(0.0, top - thickness * 0.5, depth * 0.5), Vector3(LENGTH - 0.06, thickness, depth), Vector3i(6, 1, 1))
		for side: float in [-1.0, 1.0]:
			_box(_goods, Vector3(side * half * 0.5, top - 0.018, depth + 0.004), Vector3(half - 0.08, 0.034, 0.008), Vector3i.ONE, _rects.price_strip)
		_shelf_goods(top, depth, SHELVES[i])
	for row in HOOK_ROWS.size():
		for i in HOOK_XS.size():
			_hook(Vector3(HOOK_XS[i], HOOK_ROWS[row], 0.0), HOOKS[row][i])


## Lines up [param kinds] on the board whose top is at [param top], in each bay from its left end.
func _shelf_goods(top: float, depth: float, kinds: Array) -> void:
	for bay_left: float in [-LENGTH * 0.5 + 0.06, 0.04]:
		var x := bay_left
		var i := 0
		while true:
			var kind: String = kinds[i % kinds.size()]
			var size: Vector2 = GOODS_SIZES[kind.get_slice("_", 0)]
			if x + size.x > bay_left + LENGTH * 0.5 - 0.1:
				break
			var rect: Rect2i = _rects[kind]
			var stack := 2 if kind == "floppy" or kind == "keyboard" else 1
			for level in stack:
				var center := Vector3(x + size.x * 0.5, top + size.y * (level + 0.5) + 0.002 * level, depth * 0.5 + 0.005)
				_box(_goods, center, Vector3(size.x, size.y, depth - 0.04), Vector3i.ONE, rect, _column(rect), _row(rect))
			x += size.x + 0.025
			i += 1


func _hook(at: Vector3, what: String) -> void:
	_box(_goods, at + Vector3(0.0, 0.0, 0.09), Vector3(0.012, 0.012, 0.15), Vector3i.ONE, _rects.grey)
	_box(_goods, at + Vector3(0.0, 0.012, 0.168), Vector3(0.055, 0.032, 0.006), Vector3i.ONE, _rects.price_tag, _rects.white, _rects.white)
	if what == "ribbon":
		_box(_goods, at + Vector3(0.0, -0.16, 0.04), Vector3(0.055, 0.32, 0.012), Vector3i(1, 2, 1), _rects.ribbon, _rects.grey, _rects.grey)
		_box(_goods, at + Vector3(0.0, -0.33, 0.04), Vector3(0.07, 0.03, 0.025), Vector3i.ONE, _rects.black)
	elif what.begins_with("coil_"):
		var tone := what.get_slice("_", 1)
		var cable: Rect2i = _rects.black if tone == "vga" else _rects[tone]
		var plug: Rect2i = _rects.vga if tone == "vga" else _rects.black if tone != "black" else _rects.grey
		_coil(at + Vector3(0.0, -0.09, 0.05), 0.0, cable)
		_coil(at + Vector3(0.012, -0.085, 0.072), 0.25, cable)
		for side: float in [-1.0, 1.0]:
			_box(_goods, at + Vector3(side * 0.03, -0.205, 0.06), Vector3(0.04, 0.03, 0.025), Vector3i.ONE, plug)
	else:
		var card: Rect2i = _rects["card_" + what]
		_box(_goods, at + Vector3(0.0, -0.1, 0.05), Vector3(0.13, 0.23, 0.06), Vector3i(1, 2, 1), card, _rects.card_edge, _rects.card_edge)


## Two-thirds of a ring of cable: a loop hanging off a hook, taller than wide.
func _coil(center: Vector3, tilt: float, rect: Rect2i) -> void:
	const SEGMENTS := 10
	const SIDES := 4
	const RADIUS := 0.07
	const TUBE := 0.012
	var basis := Basis(Vector3.UP, tilt).scaled(Vector3(1.0, 1.25, 1.0))
	var uv := _uv(rect).get_center()
	for i in SEGMENTS:
		for j in SIDES:
			var corners: Array[Vector3] = []
			for k: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
				var a := TAU * (i + k.x) / SEGMENTS
				var b := TAU * (j + k.y) / SIDES
				var ring := Vector3(cos(a), sin(a), 0.0)
				corners.append(center + basis * (ring * (RADIUS + TUBE * cos(b)) + Vector3(0.0, 0.0, TUBE * sin(b))))
			var a_mid := TAU * (i + 0.5) / SEGMENTS
			var tube_center := center + basis * Vector3(cos(a_mid), sin(a_mid), 0.0) * RADIUS
			var quad_center := (corners[0] + corners[1] + corners[2] + corners[3]) * 0.25
			_quad(_goods, (quad_center - tube_center).normalized(), corners, [uv, uv, uv, uv])


## A box with subdivided faces. [param front] maps onto the +Z face; [param side] onto the other
## four sides and the back; [param top] onto the top and the bottom. Rects are atlas pixels; an
## empty rect gives UV 0, for the world-mapped materials.
func _box(st: SurfaceTool, center: Vector3, size: Vector3, divisions: Vector3i, front := Rect2i(), side := Rect2i(), top := Rect2i()) -> void:
	if side == Rect2i():
		side = front
	if top == Rect2i():
		top = side
	var h := size * 0.5
	_face(st, center, Vector3.BACK, Vector3.RIGHT, Vector3.UP, Vector2(h.x, h.y), h.z, front, Vector2i(divisions.x, divisions.y))
	_face(st, center, Vector3.FORWARD, Vector3.LEFT, Vector3.UP, Vector2(h.x, h.y), h.z, side, Vector2i(divisions.x, divisions.y))
	_face(st, center, Vector3.RIGHT, Vector3.FORWARD, Vector3.UP, Vector2(h.z, h.y), h.x, side, Vector2i(divisions.z, divisions.y))
	_face(st, center, Vector3.LEFT, Vector3.BACK, Vector3.UP, Vector2(h.z, h.y), h.x, side, Vector2i(divisions.z, divisions.y))
	_face(st, center, Vector3.UP, Vector3.RIGHT, Vector3.FORWARD, Vector2(h.x, h.z), h.y, top, Vector2i(divisions.x, divisions.z))
	_face(st, center, Vector3.DOWN, Vector3.RIGHT, Vector3.BACK, Vector2(h.x, h.z), h.y, top, Vector2i(divisions.x, divisions.z))


func _face(st: SurfaceTool, center: Vector3, normal: Vector3, right: Vector3, up: Vector3, half: Vector2, offset: float, rect: Rect2i, divisions: Vector2i) -> void:
	var uv_rect := _uv(rect)
	for i in divisions.x:
		for j in divisions.y:
			var corners: Array[Vector3] = []
			var uvs: Array[Vector2] = []
			for k: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
				var f := Vector2(float(i + k.x) / divisions.x, float(j + k.y) / divisions.y)
				corners.append(center + normal * offset + right * half.x * (f.x * 2.0 - 1.0) + up * half.y * (1.0 - f.y * 2.0))
				uvs.append(uv_rect.position + uv_rect.size * f)
			_quad(st, normal, corners, uvs)


## Two flat-shaded triangles; corners run clockwise as seen from the side that [param normal] faces.
func _quad(st: SurfaceTool, normal: Vector3, corners: Array[Vector3], uvs: Array[Vector2]) -> void:
	var order := [0, 1, 2, 0, 2, 3]
	if (corners[1] - corners[0]).cross(corners[2] - corners[0]).dot(normal) > 0.0:
		order = [0, 2, 1, 0, 3, 2]
	for k: int in order:
		st.set_normal(normal)
		st.set_uv(uvs[k])
		st.add_vertex(corners[k])


func _uv(rect: Rect2i) -> Rect2:
	return Rect2(Vector2(rect.position) / ATLAS_SIZE, Vector2(rect.size) / ATLAS_SIZE)


## The leftmost two pixel columns of [param rect]: the colour of a box's sides.
func _column(rect: Rect2i) -> Rect2i:
	return Rect2i(rect.position, Vector2i(2, rect.size.y))


## The top two pixel rows of [param rect]: the colour of a box's top.
func _row(rect: Rect2i) -> Rect2i:
	return Rect2i(rect.position, Vector2i(rect.size.x, 2))
