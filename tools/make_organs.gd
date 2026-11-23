extends SceneTree
## Builds the organs that Skater Bro's computer holds instead of its parts (problem organ_failure):
## a wet texture and material per tissue (materials/textures/<tissue>.png, materials/<tissue>.tres,
## with the highlights baked in, since psx_world has no specular) and one model per organ,
## props/parts/<organ>.tscn. Each model
## is lumpy low-poly ellipsoids, flat side down, origin at the bottom centre of its place, sized to
## fit that place in rooms/shop/open_case.tscn.
## Usage, from Godot/: godot --headless --path . -s ../tools/make_organs.gd, then --import.

const TEXTURE_SIZE := 32
const SHADER := preload("res://shaders/psx_world.gdshader")

## Each tissue: base colour, dark (veins, folds), light (wet highlights).
const TISSUES := {
	"flesh": [Color8(122, 18, 22), Color8(62, 6, 10), Color8(236, 150, 150)],
	"liver": [Color8(92, 26, 18), Color8(46, 10, 8), Color8(210, 140, 120)],
	"lung": [Color8(196, 112, 112), Color8(120, 52, 60), Color8(250, 210, 205)],
	"brain": [Color8(206, 150, 150), Color8(136, 80, 86), Color8(252, 226, 222)],
	"blood": [Color8(84, 4, 8), Color8(46, 0, 4), Color8(190, 70, 70)],
}

const MATERIAL_TEXT := """[gd_resource type="ShaderMaterial" format=3]

[ext_resource type="Shader" path="%s" id="1_shader"]
[ext_resource type="Texture2D" path="%s" id="2_texture"]

[resource]
render_priority = 0
shader = ExtResource("1_shader")
shader_parameter/albedo_texture = ExtResource("2_texture")
"""

var _rng := RandomNumberGenerator.new()
var _materials: Dictionary[String, ShaderMaterial] = {}


func _initialize() -> void:
	_rng.seed = 6696
	var failed := false
	for tissue: String in TISSUES:
		var material := _tissue(tissue)
		if material == null:
			failed = true
			break
		_materials[tissue] = material
	if not failed:
		var organs := {"heart": _heart(), "kidney": _kidney(), "spleen": _spleen(), "lungs": _lungs(), "liver": _liver(), "brain": _brain()}
		for organ: String in organs:
			failed = not _save_model(organ, organs[organ]) or failed
	quit(1 if failed else 0)


# Draws and saves the texture of [param tissue] and returns its material, saved next to it.
func _tissue(tissue: String) -> ShaderMaterial:
	var colors: Array = TISSUES[tissue]
	var base: Color = colors[0]
	var dark: Color = colors[1]
	var light: Color = colors[2]
	var img := Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = _rng.randi()
	noise.frequency = 0.12
	var veins := FastNoiseLite.new()
	veins.seed = _rng.randi()
	veins.frequency = 0.07
	veins.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	for y: int in TEXTURE_SIZE:
		for x: int in TEXTURE_SIZE:
			var mottle := noise.get_noise_2d(x, y) * 0.5 + 0.5
			var color := base.lerp(dark, clampf(0.55 - mottle, 0.0, 1.0)).lerp(base.lightened(0.12), clampf(mottle - 0.6, 0.0, 1.0))
			if veins.get_noise_2d(x, y) > (0.35 if tissue == "brain" else 0.72):
				color = color.lerp(dark, 0.75)
			img.set_pixel(x, y, color)
	for i: int in 9:
		var at := Vector2i(_rng.randi_range(0, TEXTURE_SIZE - 2), _rng.randi_range(0, TEXTURE_SIZE - 1))
		img.set_pixelv(at, light)
		if _rng.randf() < 0.6:
			img.set_pixelv(at + Vector2i(1, 0), light.lerp(base, 0.4))
	var png := "res://materials/textures/%s.png" % tissue
	var err := img.save_png(ProjectSettings.globalize_path(png))
	if err != OK:
		push_error("make_organs: couldn't save %s: %s" % [png, error_string(err)])
		return null
	print("make_organs: wrote ", png)
	# Written as text so that it can name the PNG before --import has made a texture of it.
	var path := "res://materials/%s.tres" % tissue
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("make_organs: couldn't write %s: %s" % [path, error_string(FileAccess.get_open_error())])
		return null
	file.store_string(MATERIAL_TEXT % [SHADER.resource_path, png])
	file.close()
	print("make_organs: wrote ", path)
	var material := ShaderMaterial.new()
	material.take_over_path(path)
	return material


# An ellipsoid blob: [param radii] around [param center], its surface pushed in and out by noise
# ([param lumps], a share of the radius), cut flat at y 0. [param shape] may move each unit-sphere
# point before scaling (taper, bend, grooves).
# [param xform] moves the finished blob; with it, nothing is cut at y 0.
func _blob(st: SurfaceTool, center: Vector3, radii: Vector3, lumps: float, shape: Callable = Callable(), rings: int = 5, segments: int = 9, xform: Variant = null) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = _rng.randi()
	noise.frequency = 1.6
	var grid: Array[PackedVector3Array] = []
	for r: int in rings + 1:
		var row := PackedVector3Array()
		var lat := PI * float(r) / rings - PI / 2.0
		for s: int in segments + 1:
			var lon := TAU * float(s % segments) / segments
			var unit := Vector3(cos(lat) * cos(lon), sin(lat), cos(lat) * sin(lon))
			if shape.is_valid():
				unit = shape.call(unit)
			var p := center + unit * radii * (1.0 + lumps * noise.get_noise_3dv(unit * 2.0))
			if xform is Transform3D:
				p = xform * p
			else:
				p.y = maxf(p.y, 0.0)
			row.append(p)
		grid.append(row)
	for r: int in rings:
		for s: int in segments:
			var a := grid[r][s]
			var b := grid[r][s + 1]
			var c := grid[r + 1][s + 1]
			var d := grid[r + 1][s]
			var uv := Vector2(float(s) / segments, float(r) / rings)
			var du := Vector2(1.0 / segments, 0.0)
			var dv := Vector2(0.0, 1.0 / rings)
			_tri(st, a, c, b, uv, uv + du + dv, uv + du)
			_tri(st, a, d, c, uv, uv + dv, uv + du + dv)


# A tube of [param radius] from [param from] to [param to], with a closed far end.
func _tube(st: SurfaceTool, from: Vector3, to: Vector3, radius: float, segments: int = 6) -> void:
	var axis := (to - from).normalized()
	var side := axis.cross(Vector3.FORWARD if absf(axis.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var up := side.cross(axis)
	for s: int in segments:
		var a0 := TAU * s / segments
		var a1 := TAU * (s + 1) / segments
		var o0 := (side * cos(a0) + up * sin(a0)) * radius
		var o1 := (side * cos(a1) + up * sin(a1)) * radius
		var u0 := float(s) / segments
		var u1 := float(s + 1) / segments
		_tri(st, from + o0, to + o0, to + o1, Vector2(u0, 0), Vector2(u0, 1), Vector2(u1, 1))
		_tri(st, from + o0, to + o1, from + o1, Vector2(u0, 0), Vector2(u1, 1), Vector2(u1, 0))
		_tri(st, to, to + o1, to + o0, Vector2(0.5, 0.5), Vector2(u1, 1), Vector2(u0, 1))


# A flat, ragged pool of about [param radius] around [param center], just above y 0.
func _smear(st: SurfaceTool, center: Vector3, radius: float, points: int = 11) -> void:
	var rim := PackedVector3Array()
	for i: int in points:
		var angle := TAU * i / points
		rim.append(center + Vector3(cos(angle), 0.0, sin(angle)) * radius * _rng.randf_range(0.55, 1.15) + Vector3(0, 0.0015, 0))
	var mid := center + Vector3(0, 0.0015, 0)
	for i: int in points:
		_tri(st, mid, rim[(i + 1) % points], rim[i], Vector2(0.5, 0.5), Vector2(0.8, 0.9), Vector2(0.2, 0.9))


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ua: Vector2, ub: Vector2, uc: Vector2) -> void:
	for v: Array in [[a, ua], [c, uc], [b, ub]]:
		st.set_uv(v[1])
		st.add_vertex(v[0])


func _begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	return st


# Adds what [param st] holds to [param into] (a new mesh when null) as a surface of [param tissue].
func _end(st: SurfaceTool, tissue: String, into: ArrayMesh = null) -> ArrayMesh:
	st.generate_normals()
	var mesh := st.commit(into)
	mesh.surface_set_material(mesh.get_surface_count() - 1, _materials[tissue])
	return mesh


# On the motherboard's free corner, clear of the CPU, the RAM and the GPU: lying on its side, apex
# to -X, the aorta and the pulmonary trunk sticking up at the base.
func _heart() -> ArrayMesh:
	var st := _begin()
	var at := Vector3(-0.045, 0.0, 0.045)
	var blood := _begin()
	_smear(blood, at + Vector3(0.01, 0.0, -0.01), 0.1)
	var taper := func(u: Vector3) -> Vector3:
		var t := clampf(0.5 - u.x * 0.5, 0.0, 1.0)
		return Vector3(u.x, u.y * lerpf(1.0, 0.45, t * t), u.z * lerpf(1.0, 0.4, t * t))
	_blob(st, at + Vector3(0.0, 0.03, 0.0), Vector3(0.065, 0.036, 0.052), 0.12, taper, 6, 11)
	_blob(st, at + Vector3(0.03, 0.04, 0.02), Vector3(0.03, 0.025, 0.028), 0.1)
	_tube(st, at + Vector3(0.042, 0.045, -0.006), at + Vector3(0.078, 0.075, -0.018), 0.012)
	_tube(st, at + Vector3(0.038, 0.048, 0.02), at + Vector3(0.072, 0.07, 0.04), 0.009)
	return _end(blood, "blood", _end(st, "flesh"))


# In a RAM slot, which stands the module on its edge (local Z is down in the case): a bean in the
# module's plane, leaning over until it lies almost flat, so the two kidneys overlap like shingles.
func _kidney() -> ArrayMesh:
	var st := _begin()
	var bean := func(u: Vector3) -> Vector3:
		return Vector3(u.x, u.y, u.z - 0.35 * (1.0 - u.x * u.x) + 0.2)
	var lean := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(65.0)), Vector3.ZERO)
	_blob(st, Vector3.ZERO, Vector3(0.05, 0.0075, 0.024), 0.08, bean, 5, 9, lean)
	_tube(st, lean * Vector3(0.0, 0.0, -0.004), lean * Vector3(0.003, 0.0, -0.034), 0.0035, 5)
	return _end(st, "flesh")


# On the CPU's socket: long, thin and bent, low enough for the lungs on top.
func _spleen() -> ArrayMesh:
	var st := _begin()
	var bend := func(u: Vector3) -> Vector3:
		return Vector3(u.x, u.y, u.z + 0.3 * u.x * u.x - 0.15)
	_blob(st, Vector3(0.0, 0.0, 0.0), Vector3(0.036, 0.01, 0.018), 0.1, bend)
	return _end(st, "flesh")


# On the fan's place: two lobes and the windpipe between them.
func _lungs() -> ArrayMesh:
	var st := _begin()
	var lobe := func(u: Vector3) -> Vector3:
		var t := clampf(u.z * 0.5 + 0.5, 0.0, 1.0)
		return Vector3(u.x * lerpf(1.0, 0.6, t), u.y * lerpf(1.0, 0.75, t), u.z)
	_blob(st, Vector3(-0.03, 0.0, 0.0), Vector3(0.027, 0.03, 0.048), 0.1, lobe)
	_blob(st, Vector3(0.03, 0.0, 0.003), Vector3(0.025, 0.028, 0.045), 0.1, lobe)
	_tube(st, Vector3(0.0, 0.022, 0.01), Vector3(0.0, 0.025, 0.058), 0.007)
	return _end(st, "lung")


# Where the graphics card goes: a wedge, thick on one side and thin on the other.
func _liver() -> ArrayMesh:
	var st := _begin()
	var wedge := func(u: Vector3) -> Vector3:
		var t := u.x * 0.5 + 0.5
		return Vector3(u.x, u.y * lerpf(0.35, 1.1, t), u.z * lerpf(0.7, 1.0, t) - 0.1 * u.x)
	_blob(st, Vector3(0.0, 0.0, 0.0), Vector3(0.09, 0.034, 0.052), 0.09, wedge, 6, 11)
	return _end(st, "liver")


# In the drive bay: two halves, folded, the long way front to back.
func _brain() -> ArrayMesh:
	var st := _begin()
	var folds := func(u: Vector3) -> Vector3:
		var ripple := 1.0 + 0.07 * sin(u.z * 17.0 + u.y * 9.0) * sin(u.x * 13.0)
		return u * ripple
	_blob(st, Vector3(-0.026, 0.0, 0.0), Vector3(0.027, 0.048, 0.072), 0.06, folds, 6, 10)
	_blob(st, Vector3(0.026, 0.0, 0.0), Vector3(0.027, 0.048, 0.072), 0.06, folds, 6, 10)
	return _end(st, "brain")


func _save_model(organ: String, mesh: ArrayMesh) -> bool:
	var root := Node3D.new()
	root.name = organ.to_pascal_case()
	var instance := MeshInstance3D.new()
	instance.name = "Mesh"
	instance.mesh = mesh
	root.add_child(instance)
	instance.owner = root
	var scene := PackedScene.new()
	var err := scene.pack(root)
	root.free()
	var path := "res://props/parts/%s.tscn" % organ
	if err == OK:
		err = ResourceSaver.save(scene, path)
	if err != OK:
		push_error("make_organs: couldn't save %s: %s" % [path, error_string(err)])
		return false
	print("make_organs: wrote ", path)
	return true
