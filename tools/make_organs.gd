extends SceneTree
## Builds the organs that stand in for the parts of Skater Bro's computer (problem organ_failure), at
## about SIZE of an adult's, laid out in the open case where they fit rather than on the parts'
## places. Each organ is props/parts/<organ>.tscn: OrganMotion on the root, the organ in its Body
## child (origin at its bottom, so it swells off the floor), and blood dripping off it. The blood on
## the case's floor is props/parts/case_blood.tscn. Each tissue has a wet texture and material,
## materials/textures/<tissue>.png and materials/<tissue>.tres, with the highlights painted in, since
## psx_world has no specular.
## Usage, from Godot/: godot --headless --path . -s ../tools/make_organs.gd, then --import.

## The organs' size as a share of an adult's.
const SIZE := 0.85
## The case's floor, in the open case's space.
const FLOOR := 0.01
const CASE := "res://rooms/shop/open_case.tscn"
const MOTION := "res://props/parts/organ_motion.gd"
const SQUELCH := "res://sounds/squelch.tres"
## The heartbeat's length (sounds/heartbeat.wav), so every organ keeps in step with it.
const BEAT := 1.25
const TEXTURE_SIZE := 32
const SHADER := preload("res://shaders/psx_world.gdshader")

## Each tissue: base colour, dark (veins, folds, speckles), light (wet highlights), and how much of
## it is dark lines (0 none, 1 all). Only pinks, reds and purples, so it all reads as one meat.
const TISSUES := {
	"flesh": [Color8(156, 40, 44), Color8(80, 12, 18), Color8(240, 160, 160), 0.15],
	"fat": [Color8(228, 160, 164), Color8(170, 96, 110), Color8(255, 232, 232), 0.1],
	"artery": [Color8(170, 30, 34), Color8(100, 10, 16), Color8(255, 180, 170), 0.05],
	"vein": [Color8(70, 40, 92), Color8(36, 16, 52), Color8(190, 160, 220), 0.1],
	"lung": [Color8(200, 128, 128), Color8(54, 40, 46), Color8(255, 220, 215), 0.3],
	"liver": [Color8(96, 28, 20), Color8(48, 10, 8), Color8(220, 150, 130), 0.1],
	"gall": [Color8(104, 44, 96), Color8(56, 18, 52), Color8(220, 170, 215), 0.05],
	"brain": [Color8(206, 156, 150), Color8(120, 70, 76), Color8(255, 230, 225), 0.55],
	"kidney": [Color8(104, 34, 30), Color8(52, 12, 12), Color8(230, 150, 140), 0.1],
	"spleen": [Color8(92, 34, 62), Color8(46, 12, 32), Color8(210, 150, 190), 0.1],
	"cartilage": [Color8(222, 150, 160), Color8(150, 80, 96), Color8(255, 225, 230), 0.1],
	"blood": [Color8(84, 4, 8), Color8(40, 0, 4), Color8(200, 70, 70), 0.05],
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
# The organ being built: tissue to its surface.
var _surfaces: Dictionary[String, SurfaceTool] = {}
# Each place's transform in the open case.
var _places: Dictionary[String, Transform3D] = {}


func _initialize() -> void:
	_rng.seed = 6696
	if not _read_places():
		quit(1)
		return
	for tissue: String in TISSUES:
		var material := _tissue(tissue)
		if material == null:
			quit(1)
			return
		_materials[tissue] = material
	# name: [place, where in the case (x, z), turn about Y in degrees, lift off the floor, builder, motion kind, amount, period]
	var organs := {
		"heart": ["motherboard", Vector2(0.025, -0.005), -35.0, 0.0, _heart, OrganMotion.Kind.BEAT, 0.09, BEAT],
		"lungs": ["fan", Vector2(0.135, 0.08), 90.0, 0.0, _lung, OrganMotion.Kind.BREATHE, 0.07, BEAT * 3.6],
		"liver": ["gpu", Vector2(0.1, -0.122), 0.0, 0.0, _liver, OrganMotion.Kind.JIGGLE, 0.05, BEAT],
		"brain": ["hard_drive", Vector2(-0.035, 0.112), 90.0, 0.0, _brain, OrganMotion.Kind.THROB, 0.015, BEAT],
		"kidney_left": ["ram_1", Vector2(-0.112, -0.016), 0.0, 0.0, _kidney.bind(false), OrganMotion.Kind.THROB, 0.03, BEAT],
		"kidney_right": ["ram_2", Vector2(-0.024, -0.15), 90.0, 0.0, _kidney.bind(true), OrganMotion.Kind.THROB, 0.03, BEAT],
		"spleen": ["cpu", Vector2(-0.085, -0.03), 20.0, 0.02, _spleen, OrganMotion.Kind.THROB, 0.03, BEAT],
	}
	var failed := false
	for organ: String in organs:
		var spec: Array = organs[organ]
		_surfaces.clear()
		(spec[4] as Callable).call()
		failed = not _save_organ(organ, spec) or failed
	failed = not _save_case_blood(organs) or failed
	quit(1 if failed else 0)


func _read_places() -> bool:
	var scene := load(CASE) as PackedScene
	var case := scene.instantiate() if scene != null else null
	var places := case.get_node_or_null(^"Places") if case != null else null
	if places == null:
		push_error("make_organs: %s has no Places" % CASE)
		if case != null:
			case.free()
		return false
	for place: Node in places.get_children():
		_places[place.name] = (place as Node3D).transform
	case.free()
	return true


# Centimetres of an adult organ, in metres at SIZE.
static func cm(v: Variant) -> Variant:
	if v is Array:
		return (v as Array).map(func(each: Variant) -> Variant: return each * 0.01 * SIZE)
	return v * 0.01 * SIZE


func _st(tissue: String) -> SurfaceTool:
	if not _surfaces.has(tissue):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_smooth_group(0)
		_surfaces[tissue] = st
	return _surfaces[tissue]


# Draws and saves the texture of [param tissue] and returns its material, saved next to it.
func _tissue(tissue: String) -> ShaderMaterial:
	var spec: Array = TISSUES[tissue]
	var base: Color = spec[0]
	var dark: Color = spec[1]
	var light: Color = spec[2]
	var lines: float = spec[3]
	var img := Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = _rng.randi()
	noise.frequency = 0.12
	var veins := FastNoiseLite.new()
	veins.seed = _rng.randi()
	veins.frequency = 0.08
	veins.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	for y: int in TEXTURE_SIZE:
		for x: int in TEXTURE_SIZE:
			var mottle := noise.get_noise_2d(x, y) * 0.5 + 0.5
			var color := base.lerp(dark, clampf(0.55 - mottle, 0.0, 1.0)).lerp(base.lightened(0.12), clampf(mottle - 0.6, 0.0, 1.0))
			if veins.get_noise_2d(x, y) > 0.8 - lines * 0.6:
				color = color.lerp(dark, 0.8)
			img.set_pixel(x, y, color)
	for i: int in 10:
		var at := Vector2i(_rng.randi_range(0, TEXTURE_SIZE - 2), _rng.randi_range(0, TEXTURE_SIZE - 1))
		img.set_pixelv(at, light)
		if _rng.randf() < 0.6:
			img.set_pixelv(at + Vector2i(1, 0), light.lerp(base, 0.4))
	var png := "res://materials/textures/%s.png" % tissue
	var err := img.save_png(ProjectSettings.globalize_path(png))
	if err != OK:
		push_error("make_organs: couldn't save %s: %s" % [png, error_string(err)])
		return null
	# Written as text so that it can name the PNG before --import has made a texture of it.
	var path := "res://materials/%s.tres" % tissue
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("make_organs: couldn't write %s: %s" % [path, error_string(FileAccess.get_open_error())])
		return null
	file.store_string(MATERIAL_TEXT % [SHADER.resource_path, png])
	file.close()
	var material := ShaderMaterial.new()
	material.take_over_path(path)
	return material


# An ellipsoid blob of [param tissue]: [param radii] around [param center], its surface pushed in and
# out by noise ([param lumps], a share of the radius), cut flat at y 0. [param shape] moves each
# unit-sphere point first and returns it, or a Vector4 whose w scales its radius.
func _blob(tissue: String, center: Vector3, radii: Vector3, lumps: float, shape: Callable = Callable(), rings: int = 8, segments: int = 14) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = _rng.randi()
	noise.frequency = 1.4
	var grid: Array[PackedVector3Array] = []
	for r: int in rings + 1:
		var row := PackedVector3Array()
		var lat := PI * float(r) / rings - PI / 2.0
		for s: int in segments + 1:
			var lon := TAU * float(s % segments) / segments
			var unit := Vector3(cos(lat) * cos(lon), sin(lat), cos(lat) * sin(lon))
			var factor := 1.0
			if shape.is_valid():
				var shaped: Variant = shape.call(unit)
				if shaped is Vector4:
					var v4: Vector4 = shaped
					unit = Vector3(v4.x, v4.y, v4.z)
					factor = v4.w
				else:
					unit = shaped
			var p: Vector3 = center + unit * radii * factor * (1.0 + lumps * noise.get_noise_3dv(unit * 2.0))
			p.y = maxf(p.y, 0.0)
			row.append(p)
		grid.append(row)
	var st := _st(tissue)
	for r: int in rings:
		for s: int in segments:
			var uv := Vector2(float(s) / segments, float(r) / rings) * 2.0
			var du := Vector2(2.0 / segments, 0.0)
			var dv := Vector2(0.0, 2.0 / rings)
			_tri(st, grid[r][s], grid[r + 1][s + 1], grid[r][s + 1], uv, uv + du + dv, uv + du)
			_tri(st, grid[r][s], grid[r + 1][s], grid[r + 1][s + 1], uv, uv + dv, uv + du + dv)


# A tube of [param tissue] through [param points], from [param from_radius] to [param to_radius],
# open at the start and closed at the end.
func _tube(tissue: String, points: PackedVector3Array, from_radius: float, to_radius: float, segments: int = 7) -> void:
	var st := _st(tissue)
	var rings: Array[PackedVector3Array] = []
	for i: int in points.size():
		var ahead := points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)]
		var axis := ahead.normalized()
		var side := axis.cross(Vector3.UP if absf(axis.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT).normalized()
		var up := side.cross(axis)
		var radius := lerpf(from_radius, to_radius, float(i) / (points.size() - 1))
		var ring := PackedVector3Array()
		for s: int in segments + 1:
			var a := TAU * s / segments
			ring.append(points[i] + (side * cos(a) + up * sin(a)) * radius)
		rings.append(ring)
	for i: int in points.size() - 1:
		for s: int in segments:
			var uv := Vector2(float(s) / segments, float(i))
			var du := Vector2(1.0 / segments, 0.0)
			_tri(st, rings[i][s], rings[i + 1][s], rings[i + 1][s + 1], uv, uv + Vector2(0, 1), uv + du + Vector2(0, 1))
			_tri(st, rings[i][s], rings[i + 1][s + 1], rings[i][s + 1], uv, uv + du + Vector2(0, 1), uv + du)
	var end := points[points.size() - 1]
	var last := rings[rings.size() - 1]
	for s: int in segments:
		_tri(st, end, last[s + 1], last[s], Vector2(0.5, 0.5), Vector2(1, 1), Vector2(0, 1))


# Points along a smooth curve through [param through] (Catmull-Rom), [param per_span] per span.
static func _curve(through: Array, per_span: int = 4) -> PackedVector3Array:
	var points := PackedVector3Array()
	for i: int in through.size() - 1:
		var p0: Vector3 = through[maxi(i - 1, 0)]
		var p1: Vector3 = through[i]
		var p2: Vector3 = through[i + 1]
		var p3: Vector3 = through[mini(i + 2, through.size() - 1)]
		for k: int in per_span:
			var t := float(k) / per_span
			points.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t))
	points.append(through[through.size() - 1])
	return points


# A flat, ragged pool of [param tissue] of about [param radius] around [param center].
func _pool(tissue: String, center: Vector3, radius: float, points: int = 13) -> void:
	var rim := PackedVector3Array()
	for i: int in points:
		var angle := TAU * i / points
		rim.append(center + Vector3(cos(angle), 0.0, sin(angle)) * radius * _rng.randf_range(0.6, 1.2))
	var flat := func(p: Vector3) -> Vector2: return Vector2(p.x, p.z) * 12.0
	for i: int in points:
		var next := rim[(i + 1) % points]
		_tri(_st(tissue), center, next, rim[i], flat.call(center), flat.call(next), flat.call(rim[i]))


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ua: Vector2, ub: Vector2, uc: Vector2) -> void:
	for v: Array in [[a, ua], [c, uc], [b, ub]]:
		st.set_uv(v[1])
		st.add_vertex(v[0])


# Lying on its back, the apex to +X: the ventricles with fat in their grooves and coronary vessels on
# them, the atria at the base, and the great vessels: the aortic arch with its branches, the
# pulmonary trunk and the vena cava.
func _heart() -> void:
	var taper := func(u: Vector3) -> Vector3:
		var t := clampf(u.x * 0.5 + 0.5, 0.0, 1.0)
		var narrow := lerpf(1.0, 0.28, pow(t, 1.6))
		return Vector3(u.x, u.y * narrow, u.z * narrow + 0.12 * t * t)
	_blob("flesh", cm(Vector3(0.5, 3.0, 0.0)), cm(Vector3(6.2, 3.0, 4.3)), 0.07, taper, 10, 16)
	_blob("flesh", cm(Vector3(-4.3, 3.3, -2.4)), cm(Vector3(2.4, 2.1, 2.2)), 0.12)
	_blob("flesh", cm(Vector3(-4.8, 3.6, 2.1)), cm(Vector3(2.1, 1.7, 2.0)), 0.12)
	for at: Vector3 in [Vector3(-2.3, 5.4, -1.8), Vector3(-2.6, 5.5, 1.2), Vector3(-1.8, 4.6, 3.6), Vector3(1.5, 5.0, -0.4), Vector3(3.6, 4.0, 0.3)]:
		_blob("fat", cm(at), cm(Vector3(1.4, 0.55, 1.2)), 0.25, Callable(), 5, 8)
	_tube("artery", _curve(cm([Vector3(-3.0, 5.6, 0.4), Vector3(0.0, 5.7, 0.9), Vector3(3.5, 4.6, 0.9), Vector3(6.2, 2.6, 0.9)])), cm(0.32), cm(0.15), 5)
	_tube("vein", _curve(cm([Vector3(-2.5, 4.6, -3.6), Vector3(0.5, 4.2, -3.4), Vector3(4.0, 3.0, -2.2)])), cm(0.3), cm(0.15), 5)
	var arch := _curve(cm([Vector3(-3.4, 5.0, 0.6), Vector3(-4.6, 8.2, 0.8), Vector3(-6.8, 8.8, -0.4), Vector3(-8.6, 6.4, -1.4), Vector3(-9.2, 3.4, -1.6)]))
	_tube("artery", arch, cm(1.35), cm(1.15), 9)
	for at: Vector3 in [Vector3(-5.2, 9.1, 0.6), Vector3(-6.3, 9.5, 0.0), Vector3(-7.3, 9.3, -0.7)]:
		_tube("artery", PackedVector3Array([cm(at - Vector3(0, 0.8, 0)), cm(at + Vector3(-0.3, 1.6, 0.2))]), cm(0.5), cm(0.42), 6)
	_tube("vein", _curve(cm([Vector3(-2.4, 5.2, -1.6), Vector3(-3.8, 7.4, -2.6), Vector3(-5.2, 7.6, -4.4)])), cm(1.3), cm(1.1), 8)
	_tube("vein", _curve(cm([Vector3(-5.4, 3.4, -3.8), Vector3(-7.6, 3.8, -4.2), Vector3(-9.6, 4.4, -4.0)])), cm(1.15), cm(1.0), 8)


# The right lung, lying flat, the apex to +X and the hilum on -Z: three lobes split by the fissures,
# the bronchus and the pulmonary vessels stubbed off at the hilum.
func _lung() -> void:
	var lobes := func(u: Vector3) -> Vector4:
		var t := clampf(u.x * 0.5 + 0.5, 0.0, 1.0)
		var narrow := lerpf(1.0, 0.4, pow(t, 2.0))
		var v := Vector3(u.x, u.y * narrow, u.z * narrow * (0.65 if u.z < 0.0 else 1.0))
		var groove := 1.0
		if absf(u.x - 0.22) < 0.07 and u.z > -0.2:
			groove = 0.86
		if absf(u.x - (-0.15 + 0.55 * u.z)) < 0.07:
			groove = 0.86
		if u.x < -0.75:
			v.x = -0.75 - (u.x + 0.75) * 0.3
		return Vector4(v.x, v.y, v.z, groove)
	_blob("lung", cm(Vector3(0.0, 4.6, 0.0)), cm(Vector3(11.5, 4.6, 7.0)), 0.07, lobes, 12, 18)
	_tube("cartilage", _curve(cm([Vector3(-1.0, 4.4, -3.0), Vector3(-1.6, 5.2, -6.0), Vector3(-1.2, 6.0, -8.4)])), cm(0.9), cm(0.8), 8)
	_tube("vein", _curve(cm([Vector3(0.6, 3.8, -3.2), Vector3(0.8, 4.6, -6.4), Vector3(1.4, 5.4, -8.0)])), cm(0.95), cm(0.8), 7)
	_tube("artery", _curve(cm([Vector3(-2.8, 3.4, -2.8), Vector3(-3.6, 3.8, -5.8), Vector3(-4.4, 4.4, -7.2)])), cm(0.7), cm(0.6), 7)


# Lying on its belly side: the thick right lobe to -X, thinning to the left lobe at +X, split on top
# by the falciform ligament, the gallbladder bulging out at the front and the vena cava at the back.
func _liver() -> void:
	var wedge := func(u: Vector3) -> Vector4:
		var t := u.x * 0.5 + 0.5
		var v := Vector3(u.x, u.y * lerpf(1.15, 0.28, pow(t, 1.3)), u.z * lerpf(1.0, 0.62, t) - 0.12 * u.x)
		var groove := 0.9 if absf(u.x - 0.18) < 0.06 and u.y > 0.0 else 1.0
		return Vector4(v.x, v.y, v.z, groove)
	_blob("liver", cm(Vector3(0.0, 0.0, 0.0)), cm(Vector3(11.0, 7.0, 7.6)), 0.06, wedge, 10, 18)
	_blob("gall", cm(Vector3(-2.4, 1.2, 6.6)), cm(Vector3(2.8, 1.5, 1.7)), 0.12)
	_tube("vein", _curve(cm([Vector3(-4.0, 4.6, -6.2), Vector3(-4.2, 6.0, -8.6), Vector3(-4.0, 6.6, -10.0)])), cm(1.2), cm(1.05), 8)
	_tube("vein", _curve(cm([Vector3(-1.0, 1.4, -4.0), Vector3(0.6, 2.0, -7.6)])), cm(0.8), cm(0.7), 7)


# Lying upright, the front to +X: two hemispheres, folded into gyri, the long fissure between them,
# the cerebellum under the back, and the brainstem cut off.
func _brain() -> void:
	var gyri := FastNoiseLite.new()
	gyri.seed = _rng.randi()
	gyri.frequency = 2.6
	gyri.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	gyri.fractal_octaves = 2
	for side: float in [-1.0, 1.0]:
		var hemisphere := func(u: Vector3) -> Vector4:
			var v := u
			if u.z * side < 0.0:
				v.z *= 0.2
			v.y *= lerpf(0.7, 1.0, clampf(u.y * 0.5 + 0.5, 0.0, 1.0))
			v.x *= lerpf(0.92, 1.0, clampf(u.y * 0.5 + 0.5, 0.0, 1.0))
			var folds := 0.93 + 0.11 * gyri.get_noise_3dv(u + Vector3(side * 3.0, 0, 0))
			return Vector4(v.x, v.y, v.z, folds)
		_blob("brain", cm(Vector3(0.4, 1.2, side * 1.35)), cm(Vector3(8.4, 6.4, 5.9)), 0.0, hemisphere, 16, 26)
	var folia := func(u: Vector3) -> Vector4:
		return Vector4(u.x, u.y, u.z, 1.0 + 0.07 * sin(u.y * 26.0))
	for side: float in [-1.0, 1.0]:
		_blob("brain", cm(Vector3(-6.2, 1.2, side * 2.5)), cm(Vector3(2.8, 2.0, 3.0)), 0.04, folia, 8, 12)
	_tube("cartilage", _curve(cm([Vector3(-4.0, 2.4, 0.0), Vector3(-6.0, 1.4, 0.0), Vector3(-8.4, 0.9, 0.0)])), cm(1.3), cm(1.1), 8)


# Lying flat, a bean in the XZ plane, its hilum to -Z (to +Z when [param mirrored]): the renal
# artery and vein and the ureter hanging out of it, wrapped in fat.
func _kidney(mirrored: bool) -> void:
	var flip := -1.0 if mirrored else 1.0
	var bean := func(u: Vector3) -> Vector3:
		return Vector3(u.x, u.y, u.z + flip * (0.4 * (1.0 - u.x * u.x) - 0.18))
	_blob("kidney", cm(Vector3(0.0, 1.6, 0.0)), cm(Vector3(5.6, 1.6, 3.1)), 0.05, bean, 8, 14)
	var hilum: Vector3 = cm(Vector3(0.0, 1.8, -1.2 * flip))
	_blob("fat", hilum + cm(Vector3(0.0, 0.3, -0.8 * flip)), cm(Vector3(2.2, 1.0, 1.4)), 0.3, Callable(), 5, 8)
	_tube("artery", _curve([hilum + cm(Vector3(-0.6, 0.6, 0)), hilum + cm(Vector3(-1.2, 1.2, -3.0 * flip)), hilum + cm(Vector3(-0.8, 1.0, -5.0 * flip))]), cm(0.45), cm(0.4), 6)
	_tube("vein", _curve([hilum + cm(Vector3(0.6, 0.4, 0)), hilum + cm(Vector3(1.4, 1.0, -3.2 * flip)), hilum + cm(Vector3(1.6, 0.8, -5.4 * flip))]), cm(0.55), cm(0.5), 6)
	_tube("cartilage", _curve([hilum + cm(Vector3(0.2, -0.4, 0)), hilum + cm(Vector3(0.6, -1.0, -2.6 * flip)), hilum + cm(Vector3(2.8, -1.4, -4.0 * flip)), hilum + cm(Vector3(5.6, -1.6, -4.4 * flip))]), cm(0.3), cm(0.25), 5)


# A flat crescent with notches on its front edge, and its vessels stubbed off at the hilum.
func _spleen() -> void:
	var crescent := func(u: Vector3) -> Vector4:
		var notch := 1.0
		for at: float in [-0.35, 0.1, 0.45]:
			if u.z > 0.3 and absf(u.x - at) < 0.06:
				notch = 0.82
		return Vector4(u.x, u.y, u.z + 0.35 * u.x * u.x - 0.15, notch)
	_blob("spleen", cm(Vector3(0.0, 1.5, 0.0)), cm(Vector3(6.0, 1.5, 3.6)), 0.06, crescent, 8, 16)
	_tube("vein", _curve(cm([Vector3(0.0, 1.8, -1.8), Vector3(0.4, 2.6, -4.0)])), cm(0.5), cm(0.45), 6)
	_tube("artery", _curve(cm([Vector3(-0.8, 1.9, -1.6), Vector3(-1.0, 2.8, -3.8)])), cm(0.35), cm(0.3), 6)


# Where [param spec] lays the organ, in the space of its place.
func _laid(spec: Array) -> Transform3D:
	var at: Vector2 = spec[1]
	var in_case := Transform3D(Basis(Vector3.UP, deg_to_rad(spec[2])), Vector3(at.x, FLOOR + spec[3], at.y))
	return _places[spec[0]].affine_inverse() * in_case


func _commit() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for tissue: String in _surfaces:
		var st := _surfaces[tissue]
		st.generate_normals()
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _materials[tissue])
	return mesh


func _save_organ(organ: String, spec: Array) -> bool:
	if not _places.has(spec[0]):
		push_error("make_organs: %s has no place %s" % [CASE, spec[0]])
		return false
	var root := Node3D.new()
	root.name = organ.to_pascal_case()
	root.set_script(load(MOTION))
	root.set(&"kind", spec[5])
	root.set(&"amount", spec[6])
	root.set(&"period", spec[7])
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = _commit()
	body.transform = _laid(spec)
	root.add_child(body)
	body.owner = root
	var box := body.mesh.get_aabb()
	var drips := CPUParticles3D.new()
	drips.name = "Drips"
	drips.transform = body.transform * Transform3D(Basis(), box.get_center())
	drips.amount = 4
	drips.lifetime = 0.9
	drips.local_coords = false
	drips.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	drips.emission_box_extents = box.size * 0.35
	drips.direction = Vector3.DOWN
	drips.spread = 8.0
	drips.gravity = Vector3(0, -0.35, 0)
	drips.initial_velocity_max = 0.01
	drips.scale_amount_min = 0.6
	drips.scale_amount_max = 1.3
	var drop := SphereMesh.new()
	drop.radius = 0.0028
	drop.height = 0.0075
	drop.radial_segments = 5
	drop.rings = 3
	drop.material = _materials["blood"]
	drips.mesh = drop
	root.add_child(drips)
	drips.owner = root
	return _save(root, "res://props/parts/%s.tscn" % organ)


# A pool of blood on the case's floor under every organ, and between them, that oozes and squelches.
func _save_case_blood(organs: Dictionary) -> bool:
	_surfaces.clear()
	var lift := 0.0012
	for organ: String in organs:
		var spec: Array = organs[organ]
		var at: Vector2 = spec[1]
		_pool("blood", Vector3(at.x, FLOOR + lift, at.y), 0.06)
		lift += 0.0002
	for i: int in 6:
		_pool("blood", Vector3(_rng.randf_range(-0.05, 0.17), FLOOR + lift, _rng.randf_range(-0.17, 0.16)), _rng.randf_range(0.025, 0.05))
		lift += 0.0002
	var root := Node3D.new()
	root.name = "CaseBlood"
	root.set_script(load(MOTION))
	root.set(&"kind", OrganMotion.Kind.BREATHE)
	root.set(&"amount", 0.04)
	root.set(&"period", BEAT * 5.0)
	root.set(&"squelch", load(SQUELCH))
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = _commit()
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(body)
	body.owner = root
	return _save(root, "res://props/parts/case_blood.tscn")


func _save(root: Node, path: String) -> bool:
	var scene := PackedScene.new()
	var err := scene.pack(root)
	root.free()
	if err == OK:
		err = ResourceSaver.save(scene, path)
	if err != OK:
		push_error("make_organs: couldn't save %s: %s" % [path, error_string(err)])
		return false
	print("make_organs: wrote ", path)
	return true
