extends SceneTree
## Builds the Windows 95 Modems icon (win95/theme/icons_extracted/modem_phone_yellow_32.png) as a
## low-poly 3D model for the corruption sign win_phone: a yellow push-button phone on a grey modem
## with its lights. Writes the atlas, corruption/win_phone/modem_phone.png, in the icon's own colours
## and with its row of lights, and the mesh, corruption/win_phone/modem_phone.tres, one surface.
## The model stands where props/phone.tscn's push-button phone stands: the front faces +Z, X runs
## across, the floor is at Y 0. The icon shows it from the front left; seen from the front, its row
## of lights reads the other way round. The normals are smooth, so that the shop's outline, a hull
## grown along them, stays closed; the material shades it flat (psx_world's flat_normals).
## Usage, from Godot/: godot --headless --path . -s ../tools/make_win_phone.gd, then --import.

const ICON_PATH := "res://win95/theme/icons_extracted/modem_phone_yellow_32.png"
const ATLAS_PATH := "res://corruption/win_phone/modem_phone.png"
const MESH_PATH := "res://corruption/win_phone/modem_phone.tres"
const ATLAS_SIZE := Vector2i(64, 32)

## The icon's colours, as the icon has them.
const YELLOW := Color8(255, 255, 0)
const OLIVE := Color8(128, 128, 0)
const LIGHT_GREY := Color8(192, 192, 192)
const DARK_GREY := Color8(128, 128, 128)
const WHITE := Color8(255, 255, 255)
const BLACK := Color8(0, 0, 0)

## The atlas: the keypad on the phone's sloped front, the modem's front with its lights, and one
## solid cell per colour.
const KEYPAD := Rect2i(0, 0, 28, 16)
const LIGHTS := Rect2i(32, 0, 28, 6)
const CELL := 4
const CELLS: Array[Color] = [YELLOW, OLIVE, LIGHT_GREY, DARK_GREY, WHITE, BLACK]
const CELLS_AT := Vector2i(32, 16)

## The modem: half its width and depth, and its height.
const MODEM := Vector3(0.105, 0.032, 0.1)
## The phone's body on the modem: half its width and depth at the bottom, and at the top, whose front
## edge is set back so that the keypad's face slopes; its height over the modem.
const BODY_BOTTOM := Vector2(0.078, 0.07)
const BODY_TOP := Vector2(0.06, 0.03)
const BODY_TOP_Z := -0.02
const BODY_HEIGHT := 0.045
## The handset across the top: half its length, the grip's height and depth, and the cups'.
const HANDSET_HALF := 0.1
const GRIP := Vector2(0.014, 0.022)
const CUP := Vector2(0.03, 0.04)
const HANDSET_Z := -0.03

var _img := Image.create_empty(ATLAS_SIZE.x, ATLAS_SIZE.y, false, Image.FORMAT_RGBA8)
var _st := SurfaceTool.new()


func _initialize() -> void:
	var icon := Image.load_from_file(ProjectSettings.globalize_path(ICON_PATH))
	if icon == null or icon.is_empty():
		push_error("make_win_phone: couldn't read the icon %s" % ICON_PATH)
		quit(1)
		return
	_draw_atlas(_lights_of(icon))
	var err := _img.save_png(ProjectSettings.globalize_path(ATLAS_PATH))
	if err != OK:
		push_error("make_win_phone: couldn't save %s: %s" % [ATLAS_PATH, error_string(err)])
		quit(1)
		return
	print("make_win_phone: wrote ", ATLAS_PATH)
	_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_modem()
	_body()
	_handset()
	var mesh := _smoothed(_st.commit_to_arrays())
	err = ResourceSaver.save(mesh, MESH_PATH)
	if err != OK:
		push_error("make_win_phone: couldn't save %s: %s" % [MESH_PATH, error_string(err)])
		quit(1)
		return
	print("make_win_phone: wrote ", MESH_PATH)
	quit(0)


# --- The atlas -------------------------------------------------------------------------------

# The colours of the icon's lights, left to right as the icon shows them: in each column, its first
# pure green or red pixel along the modem's front.
func _lights_of(icon: Image) -> Array[Color]:
	var lights: Array[Color] = []
	for x: int in icon.get_width():
		for y: int in icon.get_height():
			var c := icon.get_pixel(x, y)
			if c.a > 0.5 and (c.is_equal_approx(Color(0, 1, 0)) or c.is_equal_approx(Color(1, 0, 0))):
				lights.append(c)
				break
	if lights.is_empty():
		push_error("make_win_phone: the icon %s has no green or red light" % ICON_PATH)
	return lights


func _draw_atlas(lights: Array[Color]) -> void:
	_img.fill(YELLOW)
	for i: int in CELLS.size():
		_img.fill_rect(Rect2i(CELLS_AT + Vector2i(i * CELL, 0), Vector2i(CELL, CELL)), CELLS[i])
	_draw_keypad()
	_img.fill_rect(LIGHTS, LIGHT_GREY)
	_img.fill_rect(Rect2i(LIGHTS.position.x, LIGHTS.end.y - 1, LIGHTS.size.x, 1), DARK_GREY)
	var reversed := lights.duplicate()
	reversed.reverse()  # seen from the front, not the icon's front left
	var start := LIGHTS.position.x + 3
	for i: int in reversed.size():
		_img.fill_rect(Rect2i(start + i * 3, LIGHTS.position.y + 2, 2, 2), reversed[i])


# The icon's keypad on the yellow face: 3 x 4 white keys, each with an olive side and a black shadow.
func _draw_keypad() -> void:
	_img.fill_rect(KEYPAD, YELLOW)
	for row: int in 4:
		for column: int in 3:
			var key := KEYPAD.position + Vector2i(3 + column * 8, 2 + row * 3)
			_img.fill_rect(Rect2i(key, Vector2i(5, 2)), WHITE)
			_img.fill_rect(Rect2i(key + Vector2i(5, 0), Vector2i(1, 2)), OLIVE)
			_img.fill_rect(Rect2i(key + Vector2i(1, 2), Vector2i(5, 1)), BLACK)


# --- The mesh --------------------------------------------------------------------------------

func _modem() -> void:
	var m := MODEM
	_block(_corners(Vector2(m.x, m.z), 0.0, Vector2(m.x, m.z), m.y, 0.0), [DARK_GREY, LIGHTS, null, LIGHT_GREY, DARK_GREY, DARK_GREY])


func _body() -> void:
	_block(_corners(BODY_BOTTOM, MODEM.y, BODY_TOP, MODEM.y + BODY_HEIGHT, BODY_TOP_Z), [OLIVE, KEYPAD, null, YELLOW, YELLOW, YELLOW])


func _handset() -> void:
	var top := MODEM.y + BODY_HEIGHT
	var grip_top := top + CUP.x
	_box(Vector3(0.0, grip_top - GRIP.x * 0.5, HANDSET_Z), Vector3(HANDSET_HALF * 2.0, GRIP.x, GRIP.y), [OLIVE, YELLOW, OLIVE, YELLOW, YELLOW, YELLOW])
	for side: float in [-1.0, 1.0]:
		var x := side * (HANDSET_HALF - CUP.y * 0.5)
		_box(Vector3(x, grip_top - CUP.x * 0.5, HANDSET_Z), Vector3(CUP.y, CUP.x, CUP.y), [OLIVE, YELLOW, OLIVE, YELLOW, YELLOW, YELLOW])


func _box(centre: Vector3, size: Vector3, paints: Array) -> void:
	var h := size * 0.5
	_block(_corners(Vector2(h.x, h.z), centre.y - h.y, Vector2(h.x, h.z), centre.y + h.y, 0.0, Vector2(centre.x, centre.z)), paints)


# Eight corners: a bottom rectangle of half size [param bottom] at height [param y0] and a top one
# of half size [param top] at [param y1], moved back by [param top_z]; bit 0 is X, bit 1 Y, bit 2 Z.
func _corners(bottom: Vector2, y0: float, top: Vector2, y1: float, top_z: float, at: Vector2 = Vector2.ZERO) -> Array[Vector3]:
	var corners: Array[Vector3] = []
	for i: int in 8:
		var half := top if i & 2 else bottom
		var y := y1 if i & 2 else y0
		var z := (top_z if i & 2 else 0.0) + half.y * (1 if i & 4 else -1)
		corners.append(Vector3(at.x + half.x * (1 if i & 1 else -1), y, at.y + z))
	return corners


# The six faces of [param corners] (from [method _corners]) painted with [param paints], in the
# order back, front, bottom, top, left, right: a colour, a Rect2i of the atlas, or null for none.
func _block(corners: Array[Vector3], paints: Array) -> void:
	var inside := Vector3.ZERO
	for c: Vector3 in corners:
		inside += c / 8.0
	var faces: Array = [[0, 1, 3, 2], [4, 5, 7, 6], [0, 1, 5, 4], [2, 3, 7, 6], [0, 2, 6, 4], [1, 3, 7, 5]]
	for f: int in faces.size():
		if paints[f] == null:
			continue
		var quad: Array[Vector3] = []
		for k: int in faces[f]:
			quad.append(corners[k])
		var uvs: Array[Vector2] = []
		if paints[f] is Rect2i:
			var r: Rect2i = paints[f]
			var size := Vector2(ATLAS_SIZE)
			uvs = [Vector2(r.position.x, r.end.y) / size, Vector2(r.end) / size, Vector2(r.end.x, r.position.y) / size, Vector2(r.position) / size]
		else:
			var cell := CELLS_AT + Vector2i(CELLS.find(paints[f]) * CELL, 0)
			var uv := (Vector2(cell) + Vector2(CELL, CELL) * 0.5) / Vector2(ATLAS_SIZE)
			uvs = [uv, uv, uv, uv]
		_polygon(quad, uvs, inside)


# The mesh of [param arrays] with each vertex's normal the average of the faces that meet at its
# position, one vote per face direction.
func _smoothed(arrays: Array) -> ArrayMesh:
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var faces: Dictionary[Vector3i, Array] = {}
	for i: int in points.size():
		var key := Vector3i((points[i] * 100000.0).round())
		var seen: Array = faces.get_or_add(key, [])
		if not seen.any(func(n: Vector3) -> bool: return n.is_equal_approx(normals[i])):
			seen.append(normals[i])
	for i: int in points.size():
		var sum := Vector3.ZERO
		for n: Vector3 in faces[Vector3i((points[i] * 100000.0).round())]:
			sum += n
		normals[i] = sum.normalized()
	arrays[Mesh.ARRAY_NORMAL] = normals
	var st := SurfaceTool.new()
	st.create_from_arrays(arrays)
	st.index()
	return st.commit()


# A convex flat polygon with one normal, facing away from [param inside].
func _polygon(points: Array[Vector3], uvs: Array[Vector2], inside: Vector3) -> void:
	var middle := Vector3.ZERO
	for p: Vector3 in points:
		middle += p
	middle /= points.size()
	var n := (points[1] - points[0]).cross(points[2] - points[0]).normalized()
	var reverse := n.dot(middle - inside) > 0.0  # Godot's front faces wind clockwise seen from outside
	if not reverse:
		n = -n
	for i: int in range(1, points.size() - 1):
		var tri := [0, i + 1, i] if reverse else [0, i, i + 1]
		for k: int in tri:
			_st.set_normal(n)
			_st.set_uv(uvs[k])
			_st.add_vertex(points[k])
