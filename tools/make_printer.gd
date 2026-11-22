extends SceneTree
## Builds the beige 80-column dot-matrix printer under the work desk: its atlas
## (materials/textures/printer.png); its mesh, props/printer.tres, with two surfaces: 0 the beige
## body (materials/beige_plastic.tres), 1 the atlas details (materials/printer.tres): the front
## panel, the smoked lid, the platen knob and the fanfold stack; and the page that it prints,
## props/printer_sheet.tres, in the atlas too.
## The printer's front faces +Z, X runs across it, the floor is at Y 0, and the stack stands at +X.
## The page's front faces +Z and it hangs from its top edge at Y 0.
## Usage, from Godot/: godot --headless --path . -s ../tools/make_printer.gd, then --import.

const ATLAS_PATH := "res://materials/textures/printer.png"
const MESH_PATH := "res://props/printer.tres"
const SHEET_PATH := "res://props/printer_sheet.tres"
const ATLAS_SIZE := Vector2(128.0, 64.0)

const BEIGE := Color8(204, 196, 170)
const DARK := Color8(40, 38, 36)
const SMOKE := Color8(92, 78, 66)
const PAPER := Color8(244, 243, 236)
const GREEN_BAR := Color8(198, 226, 196)
const HOLE := Color8(150, 150, 150)

const FRONT := Rect2i(0, 0, 64, 14)
const TOP := Rect2i(0, 14, 64, 44)
const KNOB := Rect2i(64, 40, 8, 8)
const BLANK := Rect2i(96, 8, 32, 40)
const STACK_SIDE := Rect2i(96, 0, 32, 8)

const BODY := Vector3(0.4, 0.09, 0.28)
const STACK := Vector3(0.25, 0.07, 0.28)
const STACK_X := 0.36
## A page of continuous paper: 9.5 by 12 inches.
const PAGE := Vector2(0.24, 0.3)

var _img := Image.create(int(ATLAS_SIZE.x), int(ATLAS_SIZE.y), false, Image.FORMAT_RGBA8)
var _rng := RandomNumberGenerator.new()
var _beige := SurfaceTool.new()
var _detail := SurfaceTool.new()


func _initialize() -> void:
	_rng.seed = 110
	_draw_atlas()
	var failed := false
	var err := _img.save_png(ProjectSettings.globalize_path(ATLAS_PATH))
	if err != OK:
		push_error("make_printer: couldn't save %s: %s" % [ATLAS_PATH, error_string(err)])
		failed = true
	else:
		print("make_printer: wrote ", ATLAS_PATH)
	_begin()
	_build()
	failed = not _save([_beige, _detail], MESH_PATH) or failed
	_begin()
	_box(Vector3(0.0, -PAGE.y * 0.5, 0.0), Vector3(PAGE.x, PAGE.y, 0.003), Basis(), BLANK, BLANK, BLANK)
	failed = not _save([_detail], SHEET_PATH) or failed
	quit(1 if failed else 0)


func _begin() -> void:
	for st: SurfaceTool in [_beige, _detail]:
		st.clear()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)


func _save(surfaces: Array[SurfaceTool], path: String) -> bool:
	var mesh := ArrayMesh.new()
	for st: SurfaceTool in surfaces:
		st.index()
		st.commit(mesh)
	var err := ResourceSaver.save(mesh, path)
	if err != OK:
		push_error("make_printer: couldn't save %s: %s" % [path, error_string(err)])
		return false
	print("make_printer: wrote ", path)
	return true


# --- The atlas -------------------------------------------------------------------------------

func _draw_atlas() -> void:
	_img.fill(BEIGE)
	_front()
	_top()
	_fill(KNOB, DARK)
	_paper(BLANK)
	_stack_side()


func _fill(r: Rect2i, c: Color) -> void:
	_img.fill_rect(r, c)


func _noise(r: Rect2i, amount: float) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			_img.set_pixel(x, y, _img.get_pixelv(Vector2i(x, y)).darkened(_rng.randf_range(0.0, amount)))


## The front: the lid's seam, a dark badge and the control panel with its lamps and buttons.
func _front() -> void:
	var o := FRONT.position
	_noise(FRONT, 0.06)
	_fill(Rect2i(o.x, o.y, FRONT.size.x, 1), BEIGE.darkened(0.25))
	_fill(Rect2i(o.x, o.y + FRONT.size.y - 1, FRONT.size.x, 1), BEIGE.darkened(0.3))
	_fill(Rect2i(o.x + 4, o.y + 5, 10, 3), DARK)
	_fill(Rect2i(o.x + 40, o.y + 3, 20, 8), BEIGE.darkened(0.15))
	_img.set_pixel(o.x + 42, o.y + 5, Color8(60, 230, 70))
	_img.set_pixel(o.x + 45, o.y + 5, Color8(250, 160, 30))
	for i in 3:
		_fill(Rect2i(o.x + 48 + i * 4, o.y + 6, 3, 3), Color8(150, 145, 130))


## The top: a beige rim around the smoked lid over the platen, the paper slot behind it.
func _top() -> void:
	var o := TOP.position
	_noise(TOP, 0.06)
	_fill(Rect2i(o.x + 3, o.y + 14, 58, 27), SMOKE)
	_noise(Rect2i(o.x + 3, o.y + 14, 58, 27), 0.1)
	_fill(Rect2i(o.x + 6, o.y + 16, 52, 2), SMOKE.lightened(0.25))
	_fill(Rect2i(o.x + 10, o.y + 7, 44, 4), DARK)


## Continuous green-bar paper with its tractor-hole margins.
func _paper(r: Rect2i) -> void:
	_fill(r, PAPER)
	for y in range(r.position.y, r.end.y, 8):
		_fill(Rect2i(r.position.x + 3, y, r.size.x - 6, 4), GREEN_BAR)
	for y in range(r.position.y + 1, r.end.y, 3):
		_img.set_pixel(r.position.x + 1, y, HOLE)
		_img.set_pixel(r.end.x - 2, y, HOLE)


## The edge of the fanfold stack: sheets folded on top of each other.
func _stack_side() -> void:
	_fill(STACK_SIDE, PAPER)
	for y in range(STACK_SIDE.position.y + 1, STACK_SIDE.end.y, 2):
		_fill(Rect2i(STACK_SIDE.position.x, y, STACK_SIDE.size.x, 1), Color8(200, 200, 192))


# --- The mesh --------------------------------------------------------------------------------

func _build() -> void:
	_box(Vector3(0.0, BODY.y * 0.5, 0.0), BODY, Basis(), FRONT, Rect2i(), TOP)
	_box(Vector3(0.0, BODY.y + 0.015, -0.1), Vector3(0.34, 0.03, 0.08), Basis(), Rect2i(), Rect2i(), Rect2i())
	_box(Vector3(BODY.x * 0.5 + 0.01, 0.07, -0.02), Vector3(0.02, 0.036, 0.036), Basis(), KNOB, KNOB, KNOB)
	_box(Vector3(STACK_X, STACK.y * 0.5, 0.0), STACK, Basis(), STACK_SIDE, STACK_SIDE, BLANK)


## A box turned by [param basis]. [param front] maps onto the +Z face, [param side] onto the other
## four sides and the back, [param top] onto the top and the bottom. Rects are atlas pixels; an
## empty rect puts that face on the beige surface.
func _box(center: Vector3, size: Vector3, basis: Basis, front: Rect2i, side: Rect2i, top: Rect2i) -> void:
	var h := size * 0.5
	_face(center, basis, Vector3.BACK, Vector3.RIGHT, Vector3.UP, Vector2(h.x, h.y), h.z, front)
	_face(center, basis, Vector3.FORWARD, Vector3.LEFT, Vector3.UP, Vector2(h.x, h.y), h.z, side)
	_face(center, basis, Vector3.RIGHT, Vector3.FORWARD, Vector3.UP, Vector2(h.z, h.y), h.x, side)
	_face(center, basis, Vector3.LEFT, Vector3.BACK, Vector3.UP, Vector2(h.z, h.y), h.x, side)
	_face(center, basis, Vector3.UP, Vector3.RIGHT, Vector3.FORWARD, Vector2(h.x, h.z), h.y, top)
	_face(center, basis, Vector3.DOWN, Vector3.RIGHT, Vector3.BACK, Vector2(h.x, h.z), h.y, top)


func _face(center: Vector3, basis: Basis, normal: Vector3, right: Vector3, up: Vector3, half: Vector2, offset: float, rect: Rect2i) -> void:
	var st := _beige if rect == Rect2i() else _detail
	var uv_rect := Rect2(Vector2(rect.position) / ATLAS_SIZE, Vector2(rect.size) / ATLAS_SIZE)
	var corners: Array[Vector3] = []
	var uvs: Array[Vector2] = []
	for f: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
		corners.append(center + basis * (normal * offset + right * half.x * (f.x * 2.0 - 1.0) + up * half.y * (1.0 - f.y * 2.0)))
		uvs.append(uv_rect.position + uv_rect.size * f)
	var n := basis * normal
	var order := [0, 1, 2, 0, 2, 3]
	if (corners[1] - corners[0]).cross(corners[2] - corners[0]).dot(n) > 0.0:
		order = [0, 2, 1, 0, 3, 2]
	for k: int in order:
		st.set_normal(n)
		st.set_uv(uvs[k])
		st.add_vertex(corners[k])
