class_name Stub
## Marks what isn't built yet with a 2 x 2 red dot, so the team sees what is missing. Debug builds
## only: the published game shows no dots.

const COLOR := Color(1, 0, 0)
const SIZE := 2.0

static var _marked: Dictionary[Texture2D, Texture2D] = {}
static var _dot: Texture2D


## True when the dots show.
static func shown() -> bool:
	return OS.is_debug_build()


## Draws the dot on [param canvas] with its top left corner at [param at].
static func draw(canvas: CanvasItem, at: Vector2) -> void:
	if shown():
		canvas.draw_rect(Rect2(at, Vector2(SIZE, SIZE)), COLOR)


## [param texture] with the dot in its top right corner, for an icon; [param texture] itself in a
## published game.
static func mark(texture: Texture2D) -> Texture2D:
	if texture == null or not shown():
		return texture
	if not _marked.has(texture):
		var image := texture.get_image()
		if image.is_compressed():
			image.decompress()
		image.convert(Image.FORMAT_RGBA8)
		image.fill_rect(Rect2i(image.get_width() - int(SIZE), 0, int(SIZE), int(SIZE)), COLOR)
		_marked[texture] = ImageTexture.create_from_image(image)
	return _marked[texture]


## The dot alone, as the icon of a menu item that has none; null in a published game.
static func dot() -> Texture2D:
	if not shown():
		return null
	if _dot == null:
		var image := Image.create_empty(int(SIZE), int(SIZE), false, Image.FORMAT_RGBA8)
		image.fill(COLOR)
		_dot = ImageTexture.create_from_image(image)
	return _dot
