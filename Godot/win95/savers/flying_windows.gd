extends Saver
## The Flying Windows screensaver: Windows logos, each in one colour, fly out of the middle of a black
## screen towards the viewer, growing as they come; a new one starts far away when one leaves the
## screen or passes the viewer. Any key, click or mouse move ends it.

## How many logos fly at once (Win95's default; its setting allows 5 to 75).
var density: int = 25
## How far a logo comes towards the viewer each second, in distances of the screen from the viewer.
var speed: float = 2.6
## A logo's width, trail included, as a share of the screen's height, at the screen's distance.
var logo_width: float = 0.5
## How far from the middle a logo flies, at most, in screen half-widths and half-heights at the screen's
## distance. A logo leaves the screen at a width between logo_width / spread and the largest.
var spread: float = 4.0

const _FAR := 12.0  # a new logo is about 10 px wide
const _NEAR := 1.4  # a logo closer than this is gone: as in Win95, none grows past about 90 px
# The VGA colours but black; Win95 gives each logo one.
const _COLOURS: Array[Color] = [Color("800000"), Color("008000"), Color("808000"), Color("000080"),
		Color("800080"), Color("008080"), Color("c0c0c0"), Color("808080"), Color("ff0000"),
		Color("00ff00"), Color("ffff00"), Color("0000ff"), Color("ff00ff"), Color("00ffff"), Color("ffffff")]
const _BITMAP := Vector2i(96, 75)  # the logo's one-bit picture at its largest

## Each logo: x and y across the view at the screen's distance (-1 to 1 spans the screen), z its
## distance in those units.
var _logos: Array[Vector3] = []
var _colours: Array[Color] = []
var _bitmap: Image
## The logo in one bit at each width in pixels, made when a logo first needs it.
var _bitmaps: Dictionary[int, ImageTexture] = {}


func _ready() -> void:
	super()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bitmap = _logo_image()
	for i: int in density:
		_logos.append(_new_logo(randf_range(_NEAR, _FAR)))
		_colours.append(_COLOURS.pick_random())


func _process(delta: float) -> void:
	for i: int in _logos.size():
		var logo := _logos[i]
		logo.z -= speed * delta
		if logo.z <= _NEAR or not _on_screen(logo):
			logo = _new_logo(_FAR)
			_colours[i] = _COLOURS.pick_random()
		_logos[i] = logo
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
	var order: Array = range(_logos.size())
	order.sort_custom(func(a: int, b: int) -> bool: return _logos[a].z > _logos[b].z)
	for i: int in order:
		var bitmap := _bitmap_at(roundi(_logo_size(_logos[i]).x))
		draw_texture(bitmap, (_project(_logos[i]) - bitmap.get_size() * 0.5).round(), _colours[i])


func _new_logo(z: float) -> Vector3:
	return Vector3(randf_range(-spread, spread), randf_range(-spread, spread), z)


func _project(logo: Vector3) -> Vector2:
	return size * 0.5 * (Vector2.ONE + Vector2(logo.x, logo.y) / logo.z)


func _logo_size(logo: Vector3) -> Vector2:
	var width := maxf(1.0, logo_width / logo.z * size.y * 0.5)
	return Vector2(width, width * _BITMAP.y / _BITMAP.x)


func _on_screen(logo: Vector3) -> bool:
	return Rect2(Vector2.ZERO, size).grow(_logo_size(logo).x).has_point(_project(logo))


# The logo shrunk to [param width] pixels and back to one bit: a thin line stays where it covers a
# third of a pixel, so a small logo stays a solid shape, as Win95's small ones are.
func _bitmap_at(width: int) -> ImageTexture:
	width = clampi(width, 1, _BITMAP.x)
	if not _bitmaps.has(width):
		var image := _bitmap.duplicate() as Image
		image.resize(width, maxi(1, roundi(width * float(_BITMAP.y) / _BITMAP.x)), Image.INTERPOLATE_BILINEAR)
		for y: int in image.get_height():
			for x: int in image.get_width():
				image.set_pixel(x, y, Color.WHITE if image.get_pixel(x, y).a > 0.33 else Color.TRANSPARENT)
		_bitmaps[width] = ImageTexture.create_from_image(image)
	return _bitmaps[width]


# The Windows 95 logo in white: a waving window frame, taller on its right, with a cross and four
# open panes, and on its left a trail of squares that grow towards the frame.
func _logo_image() -> Image:
	var image := Image.create(_BITMAP.x, _BITMAP.y, false, Image.FORMAT_LA8)
	for py: int in _BITMAP.y:
		for px: int in _BITMAP.x:
			var at := (Vector2(px, py) + Vector2.ONE * 0.5) / Vector2(_BITMAP)
			if _in_frame(at) or _in_trail(at):
				image.set_pixel(px, py, Color.WHITE)
	return image


func _top(u: float) -> float:
	return 0.13 - 0.07 * sin(PI * 0.9 * clampf(u, 0.0, 1.0))


func _height(u: float) -> float:
	return lerpf(0.73, 0.8, clampf(u, 0.0, 1.0))


func _in_frame(at: Vector2) -> bool:
	var u := (at.x - 0.52) / 0.4
	var v := (at.y - _top(u)) / _height(u)
	if u < 0.0 or u > 1.0 or v < 0.0 or v > 1.0:
		return false
	var pane_u := (u > 0.08 and u < 0.4) or (u > 0.52 and u < 0.86)
	var pane_v := (v > 0.07 and v < 0.47) or (v > 0.55 and v < 0.93)
	return not (pane_u and pane_v)


func _in_trail(at: Vector2) -> bool:
	var v := (at.y - _top(0.0)) / _height(0.0)
	for column: int in 6:
		var grown := column / 5.0
		var half := Vector2(lerpf(0.008, 0.03, grown), lerpf(0.012, 0.045, grown))
		if absf(at.x - (0.06 + column * 0.08)) > half.x:
			continue
		var rows := v * 7.0 - (0.5 if column % 2 == 1 and column < 3 else 0.0)
		var centre := (floorf(rows) + 0.5) / 7.0
		if rows >= 0.0 and rows < 7.0 and absf(v - centre) * _height(0.0) < half.y:
			return true
	return false
