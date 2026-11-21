extends SceneTree
## Builds the tree meshes of the Outside: Godot/props/tree_<kind>_<variant>.tres. Each mesh has three
## flat-shaded surfaces (bark, light leaves, dark leaves), so a tree costs three draw calls. The seeds
## fix the shapes, so a re-run writes the same meshes.
## Usage, from Godot/: godot --headless --path . -s ../tools/make_trees.gd

const BARK := "res://materials/bark.tres"
const LEAVES := "res://materials/leaves.tres"
const LEAVES_LIGHT := "res://materials/leaves_light.tres"
const LEAVES_DARK := "res://materials/leaves_dark.tres"
const LEAVES_PINE := "res://materials/leaves_pine.tres"

const ROUND := [
	{"name": "round_a", "seed": 11, "light": LEAVES_LIGHT, "dark": LEAVES, "trunk": 2.1, "crown": Vector3(0.0, 2.75, 0.0), "size": Vector3(0.9, 0.95, 0.85), "lumps": 9},
	{"name": "round_b", "seed": 23, "light": LEAVES, "dark": LEAVES_DARK, "trunk": 2.3, "crown": Vector3(0.1, 2.95, 0.0), "size": Vector3(0.8, 0.95, 0.8), "lumps": 8},
]
const PINE := [
	{"name": "pine_a", "seed": 5, "light": LEAVES_DARK, "dark": LEAVES_PINE, "height": 3.6, "base": 1.0, "radius": 0.95, "tiers": 4},
	{"name": "pine_b", "seed": 17, "light": LEAVES_PINE, "dark": LEAVES_DARK, "height": 4.0, "base": 0.9, "radius": 0.8, "tiers": 5},
]

var _rng := RandomNumberGenerator.new()


func _initialize() -> void:
	var failed := false
	for spec: Dictionary in ROUND:
		failed = not _save(_round_tree(spec), spec.name) or failed
	for spec: Dictionary in PINE:
		failed = not _save(_pine_tree(spec), spec.name) or failed
	quit(1 if failed else 0)


func _save(mesh: ArrayMesh, tree_name: String) -> bool:
	var path := "res://props/tree_%s.tres" % tree_name
	var err := ResourceSaver.save(mesh, path)
	if err != OK:
		push_error("make_trees: couldn't save %s: %s" % [path, error_string(err)])
		return false
	print("make_trees: wrote ", path)
	return true


func _round_tree(spec: Dictionary) -> ArrayMesh:
	_rng.seed = spec.seed
	var bark := _surface(BARK)
	var light := _surface(spec.light)
	var dark := _surface(spec.dark)
	var crown: Vector3 = spec.crown
	var size: Vector3 = spec.size
	var top := Vector3(_rng.randf_range(-0.08, 0.08), spec.trunk, _rng.randf_range(-0.08, 0.08))
	_limb(bark, Vector3.ZERO, top, 0.14, 0.07, 5)
	for i in 3:
		var angle := TAU * (i + _rng.randf_range(0.0, 0.5)) / 3.0
		var from := top.lerp(Vector3.ZERO, _rng.randf_range(0.15, 0.35))
		var to := crown + Vector3(cos(angle) * size.x * 0.6, _rng.randf_range(-0.2, 0.1), sin(angle) * size.z * 0.6)
		_limb(bark, from, to, 0.05, 0.02, 4)
	var lumps: int = spec.lumps
	for i in lumps:
		var angle := TAU * i / lumps + _rng.randf_range(-0.3, 0.3)
		var rise := _rng.randf_range(-0.6, 0.9)
		var at := crown + Vector3(cos(angle) * size.x * 0.55, rise * size.y * 0.6, sin(angle) * size.z * 0.55)
		var tone := light if rise > 0.2 or _rng.randf() < 0.25 else dark
		_lump(tone, at, _rng.randf_range(0.42, 0.6))
	_lump(light, crown + Vector3(0.0, size.y * 0.55, 0.0), 0.55)
	_lump(dark, crown, 0.7)
	return _commit([bark, light, dark])


func _pine_tree(spec: Dictionary) -> ArrayMesh:
	_rng.seed = spec.seed
	var bark := _surface(BARK)
	var light := _surface(spec.light)
	var dark := _surface(spec.dark)
	var height: float = spec.height
	var base: float = spec.base
	_limb(bark, Vector3.ZERO, Vector3(0.0, height * 0.85, 0.0), 0.12, 0.04, 5)
	var tiers: int = spec.tiers
	var step := (height - base) / (tiers + 0.6)
	for i in tiers:
		var share := 1.0 - float(i) / tiers
		var rim_y := base + step * i + _rng.randf_range(-0.05, 0.05)
		var apex_y := rim_y + step * 1.9
		var radius: float = spec.radius * (0.35 + 0.65 * share) * _rng.randf_range(0.9, 1.08)
		_tier(light if i % 2 == 0 else dark, rim_y, apex_y, radius)
	return _commit([bark, light, dark])


func _surface(material_path: String) -> SurfaceTool:
	var material := load(material_path) as Material
	if material == null:
		push_error("make_trees: %s is not a Material" % material_path)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(material)
	return st


func _commit(surfaces: Array[SurfaceTool]) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for st in surfaces:
		st.commit(mesh)
	return mesh


## A flat-shaded triangle whose front faces away from [param inside].
func _triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, inside: Vector3) -> void:
	var normal := (b - a).cross(c - a).normalized()
	if normal.dot((a + b + c) / 3.0 - inside) > 0.0:
		var swap := b
		b = c
		c = swap
		normal = -normal
	normal = -normal # Godot's front faces wind clockwise, so the cross product points inward
	st.set_normal(normal)
	for v: Vector3 in [a, b, c]:
		st.add_vertex(v)


## A tapered prism with [param sides] sides from [param from] to [param to].
func _limb(st: SurfaceTool, from: Vector3, to: Vector3, from_radius: float, to_radius: float, sides: int) -> void:
	var axis := (to - from).normalized()
	var side := axis.cross(Vector3.FORWARD if absf(axis.y) > 0.9 else Vector3.UP).normalized()
	var other := axis.cross(side)
	var turn := _rng.randf_range(0.0, TAU)
	for i in sides:
		var a0 := turn + TAU * i / sides
		var a1 := turn + TAU * (i + 1) / sides
		var d0 := side * cos(a0) + other * sin(a0)
		var d1 := side * cos(a1) + other * sin(a1)
		var mid := (from + to) * 0.5
		_triangle(st, from + d0 * from_radius, from + d1 * from_radius, to + d0 * to_radius, mid)
		_triangle(st, to + d0 * to_radius, from + d1 * from_radius, to + d1 * to_radius, mid)


## A lumpy low-poly ball: two rings of six jittered points between two poles.
func _lump(st: SurfaceTool, at: Vector3, radius: float) -> void:
	var rings: Array[PackedVector3Array] = []
	for latitude: float in [0.6, -0.35]:
		var ring := PackedVector3Array()
		var turn := _rng.randf_range(0.0, TAU)
		for i in 6:
			var angle := turn + TAU * i / 6.0
			var r := radius * _rng.randf_range(0.8, 1.15)
			ring.append(at + Vector3(cos(angle) * cos(latitude), sin(latitude), sin(angle) * cos(latitude)) * r)
		rings.append(ring)
	var north := at + Vector3(_rng.randf_range(-0.1, 0.1), radius * _rng.randf_range(0.9, 1.1), _rng.randf_range(-0.1, 0.1))
	var south := at - Vector3(0.0, radius * 0.75, 0.0)
	for i in 6:
		var j := (i + 1) % 6
		_triangle(st, north, rings[0][i], rings[0][j], at)
		_triangle(st, rings[0][i], rings[1][i], rings[0][j], at)
		_triangle(st, rings[0][j], rings[1][i], rings[1][j], at)
		_triangle(st, south, rings[1][j], rings[1][i], at)


## A pine tier: a jittered cone from [param apex_y] down to a drooping rim at [param rim_y], with a
## hollow underside that the shade turns into a dark band.
func _tier(st: SurfaceTool, rim_y: float, apex_y: float, radius: float) -> void:
	var sides := 8
	var apex := Vector3(_rng.randf_range(-0.04, 0.04), apex_y, _rng.randf_range(-0.04, 0.04))
	var hollow := Vector3(0.0, rim_y + (apex_y - rim_y) * 0.3, 0.0)
	var rim := PackedVector3Array()
	var turn := _rng.randf_range(0.0, TAU)
	for i in sides:
		var angle := turn + TAU * i / sides
		var r := radius * (_rng.randf_range(0.75, 1.05) if i % 2 == 0 else _rng.randf_range(0.95, 1.2))
		rim.append(Vector3(cos(angle) * r, rim_y + _rng.randf_range(-0.08, 0.04), sin(angle) * r))
	var core := Vector3(0.0, (rim_y + apex_y) * 0.5, 0.0)
	for i in sides:
		var j := (i + 1) % sides
		_triangle(st, apex, rim[i], rim[j], core)
		_triangle(st, hollow, rim[j], rim[i], hollow + Vector3.UP * 10.0)
