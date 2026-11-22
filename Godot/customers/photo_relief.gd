class_name PhotoRelief
extends RefCounted
## A person's upper body as a low-poly relief of their neutral portrait (wiki: Architecture, People
## and customers). The front carries the photo and bulges towards the middle of its outline; the
## back carries the person seen from behind (Person.back), or the photo mirrored when there is none.
## The mesh's origin is the bottom centre of the outline, and its front faces +Z.

## The surfaces of [method build]'s mesh.
enum Surface { FRONT, BACK, HEAD_BACK }

## The share of the outline's height, from the top, that is the head: the head's back is one colour
## when the person has no back picture, so no face shows from behind.
const HEAD_SHARE: float = 0.36
## The two triangles of a grid cell, corners 0 to 3 running clockwise as seen from the front, which
## Godot draws as front faces; the back runs them the other way.
const FRONT_ORDER: Array[int] = [0, 1, 2, 0, 2, 3]
const BACK_ORDER: Array[int] = [0, 2, 1, 0, 3, 2]


## The relief of the opaque part of [param portrait]: [param metres_per_pixel] scales it, the middle
## bulges by up to [param depth] metres each way, and one grid cell spans [param step] pixels. The
## edge rounds off over [param round_off] pixels. Returns an empty mesh, with an error, for a portrait
## with no opaque pixels.
static func build(portrait: Image, metres_per_pixel: float, depth: float, step: int = 2, round_off: float = 20.0) -> ArrayMesh:
	var image := _rgba(portrait)
	var w := image.get_width()
	var h := image.get_height()
	var cols := w / step + 1
	var rows := h / step + 1
	var inside := PackedByteArray()
	inside.resize(cols * rows)
	var dist := PackedFloat32Array()
	dist.resize(cols * rows)
	var left := w
	var right := -1
	for r: int in rows:
		for c: int in cols:
			var px := mini(c * step, w - 1)
			var opaque := image.get_pixel(px, mini(r * step, h - 1)).a > 0.5
			inside[r * cols + c] = 1 if opaque else 0
			dist[r * cols + c] = 1e6 if opaque else 0.0
			if opaque:
				left = mini(left, px)
				right = maxi(right, px)
	var mesh := ArrayMesh.new()
	if right < 0:
		push_error("PhotoRelief: the portrait %s has no opaque pixels" % portrait.resource_path)
		return mesh
	_chamfer(dist, cols, rows)
	var centre := (left + right) * 0.5
	var cells := round_off / step
	var hat := _average(image, Rect2i(left, 0, right - left + 1, int(h * 0.15)))
	for surface: int in Surface.size():
		var side := 1.0 if surface == Surface.FRONT else -1.0
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for r: int in rows - 1:
			var head := float(r * step) / h < HEAD_SHARE
			if (surface == Surface.BACK and head) or (surface == Surface.HEAD_BACK and not head):
				continue
			for c: int in cols - 1:
				var corners: Array[int] = [r * cols + c, r * cols + c + 1, (r + 1) * cols + c + 1, (r + 1) * cols + c]
				if corners.any(func(i: int) -> bool: return inside[i] == 0):
					continue
				for k: int in FRONT_ORDER if side > 0.0 else BACK_ORDER:
					var i := corners[k]
					var px := float(mini((i % cols) * step, w - 1))
					var py := float(mini((i / cols) * step, h - 1))
					var d := dist[i] - 1.0
					var bulge := 0.0 if d <= 0.0 else depth * sqrt(1.0 - pow(1.0 - minf(d / cells, 1.0), 2.0))
					# Seen from behind, the person's left is on the right: the back samples the mirror image.
					var u := px if side > 0.0 else 2.0 * centre - px
					tool.set_uv(Vector2(u / w, py / h))
					tool.set_color(hat)
					tool.add_vertex(Vector3((px - centre) * metres_per_pixel, (h - py) * metres_per_pixel, bulge * side * (1.0 if side > 0.0 else 0.8)))
		tool.generate_normals()
		tool.commit(mesh)
	return mesh


## The width in pixels of the head in [param portrait]: the opaque span 12 % of the image's height
## below the top of the outline. 24 when there is no outline.
static func head_width(portrait: Image) -> float:
	var image := _rgba(portrait)
	var top := -1
	for y: int in image.get_height():
		for x: int in image.get_width():
			if image.get_pixel(x, y).a > 0.5:
				top = y
				break
		if top >= 0:
			break
	if top < 0:
		return 24.0
	var row := mini(top + int(image.get_height() * 0.12), image.get_height() - 1)
	var first := -1
	var last := -1
	for x: int in image.get_width():
		if image.get_pixel(x, row).a > 0.5:
			if first < 0:
				first = x
			last = x
	return float(last - first + 1) if first >= 0 else 24.0


static func _rgba(portrait: Image) -> Image:
	var image := portrait.duplicate() as Image
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	return image


# The distance in cells from each inside cell to the nearest outside cell, in two passes.
static func _chamfer(dist: PackedFloat32Array, cols: int, rows: int) -> void:
	for r: int in rows:
		for c: int in cols:
			var i := r * cols + c
			if c > 0: dist[i] = minf(dist[i], dist[i - 1] + 1.0)
			if r > 0: dist[i] = minf(dist[i], dist[i - cols] + 1.0)
			if r > 0 and c > 0: dist[i] = minf(dist[i], dist[i - cols - 1] + 1.4)
			if r > 0 and c < cols - 1: dist[i] = minf(dist[i], dist[i - cols + 1] + 1.4)
	for r: int in range(rows - 1, -1, -1):
		for c: int in range(cols - 1, -1, -1):
			var i := r * cols + c
			if c < cols - 1: dist[i] = minf(dist[i], dist[i + 1] + 1.0)
			if r < rows - 1: dist[i] = minf(dist[i], dist[i + cols] + 1.0)
			if r < rows - 1 and c < cols - 1: dist[i] = minf(dist[i], dist[i + cols + 1] + 1.4)
			if r < rows - 1 and c > 0: dist[i] = minf(dist[i], dist[i + cols - 1] + 1.4)


static func _average(image: Image, area: Rect2i) -> Color:
	var sum := Color(0, 0, 0, 0)
	var count := 0
	for y: int in range(area.position.y, mini(area.end.y, image.get_height())):
		for x: int in range(area.position.x, mini(area.end.x, image.get_width())):
			var colour := image.get_pixel(x, y)
			if colour.a > 0.5:
				sum += colour
				count += 1
	return sum / count * 0.8 if count > 0 else Color(0.3, 0.3, 0.3)
