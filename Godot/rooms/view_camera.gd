class_name ViewCamera
extends Camera3D
## The room's camera. Its field of view is given for the 16:9 design frame, and a viewport of
## another shape shows that frame whole and more: a taller one adds room above and below, a wider
## one adds room at the sides (docs/ios.md, "Filling the screen").

## The aspect ratio of the design frame (1920 x 1080).
const DESIGN_ASPECT: float = 16.0 / 9.0

## The vertical field of view of the 16:9 design frame, in degrees (ViewMarker.fov). Setting it, or
## a change of the viewport's size, sets keep_aspect and fov for the viewport's shape.
@export_range(1.0, 179.0) var view_fov: float = 50.0:
	set(value):
		view_fov = value
		_fit()


func _ready() -> void:
	get_viewport().size_changed.connect(_fit)
	_fit()


## The tangents of half the design frame's field of view: x across, y up. A point at (x, y) in camera
## space, divided by its distance ahead, is on the frame's edge where it equals these.
static func design_tangents(fov_degrees: float) -> Vector2:
	var up := tan(deg_to_rad(fov_degrees) * 0.5)
	return Vector2(up * DESIGN_ASPECT, up)


## The keep_aspect that shows the whole design frame in a viewport of [param aspect] (width / height):
## KEEP_WIDTH for a viewport narrower than 16:9, KEEP_HEIGHT otherwise.
static func keep_for(aspect: float) -> KeepAspect:
	return KEEP_WIDTH if aspect < DESIGN_ASPECT else KEEP_HEIGHT


## The fov, in degrees, that goes with [method keep_for] for [param aspect]: the design frame's
## horizontal field of view under KEEP_WIDTH, [param fov_degrees] itself under KEEP_HEIGHT.
static func fov_for(fov_degrees: float, aspect: float) -> float:
	if keep_for(aspect) == KEEP_HEIGHT:
		return fov_degrees
	return rad_to_deg(2.0 * atan(design_tangents(fov_degrees).x))


## The tangents of half the field of view of the whole picture in a viewport of [param aspect]: the
## design frame's, grown across or up to fill it.
static func picture_tangents(fov_degrees: float, aspect: float) -> Vector2:
	var design := design_tangents(fov_degrees)
	if keep_for(aspect) == KEEP_WIDTH:
		return Vector2(design.x, design.x / aspect)
	return Vector2(design.y * aspect, design.y)


## [method picture_tangents] for this camera's viewport and [member view_fov] now.
func tangents() -> Vector2:
	return picture_tangents(view_fov, _aspect())


func _aspect() -> float:
	var shown := get_viewport().get_visible_rect().size if is_inside_tree() else Vector2.ZERO
	return shown.aspect() if shown.y > 0.0 else DESIGN_ASPECT


func _fit() -> void:
	var aspect := _aspect()
	keep_aspect = keep_for(aspect)
	fov = fov_for(view_fov, aspect)
