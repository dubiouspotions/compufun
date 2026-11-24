extends "res://tests/test.gd"
## A screen that isn't 16:9 shows the whole design frame and more (docs/ios.md, "Filling the
## screen"): the world buffer grows with the canvas at whole world pixels, the camera keeps the
## design frame's width on a taller screen and its height on a wider one, and a touch panel keeps
## its place at the window's edge.

const DUO := 1920.0 / 1320.0
const WIDE := 2345.0 / 1080.0


func run() -> void:
	var main_script: GDScript = load("res://main.gd")  # by path: it names Game
	var sizes: Array = [[Vector2(1920, 1080), Vector2i(480, 270)], [Vector2(1920, 1320), Vector2i(480, 330)],
			[Vector2(2345, 1080), Vector2i(587, 270)], [Vector2(1920, 1334), Vector2i(480, 334)],
			[Vector2(1920, 1320.0001), Vector2i(480, 330)]]
	for each: Array in sizes:
		check("the world buffer for a canvas of %s" % each[0], main_script.call(&"world_buffer_size", each[0], 4), each[1])

	check("16:9 keeps the height", ViewCamera.keep_for(16.0 / 9.0), Camera3D.KEEP_HEIGHT)
	check("a taller screen keeps the width", ViewCamera.keep_for(DUO), Camera3D.KEEP_WIDTH)
	check("a wider screen keeps the height", ViewCamera.keep_for(WIDE), Camera3D.KEEP_HEIGHT)
	check("16:9 takes the marker's fov", ViewCamera.fov_for(50.0, 16.0 / 9.0), 50.0)
	check("a wider screen takes the marker's fov", ViewCamera.fov_for(50.0, WIDE), 50.0)
	var across := ViewCamera.picture_tangents(50.0, 16.0 / 9.0).x
	check("a taller screen spans the design frame's width", is_equal_approx(tan(deg_to_rad(ViewCamera.fov_for(50.0, DUO)) * 0.5), across), true)
	var design := ViewCamera.design_tangents(50.0)
	for aspect: float in [DUO, WIDE, 1.0, 3.0]:
		var picture := ViewCamera.picture_tangents(50.0, aspect)
		check("at %.3f the picture holds the design frame" % aspect, picture.x >= design.x - 1e-5 and picture.y >= design.y - 1e-5, true)
		check("at %.3f the picture has the screen's shape" % aspect, is_equal_approx(picture.x / picture.y, aspect), true)

	var buffer := SubViewport.new()
	buffer.size = Vector2i(480, 270)
	var camera := ViewCamera.new()
	buffer.add_child(camera)
	root.add_child(buffer)
	camera.view_fov = 50.0
	check("in 480 x 270 the camera keeps the height", [camera.keep_aspect, camera.fov], [Camera3D.KEEP_HEIGHT, 50.0])
	buffer.size = Vector2i(480, 330)
	check("in 480 x 330 it keeps the width", [camera.keep_aspect, is_equal_approx(camera.fov, ViewCamera.fov_for(50.0, 480.0 / 330.0))], [Camera3D.KEEP_WIDTH, true])
	buffer.queue_free()

	MovablePanel.config_path = user_dir() + "touch_controls.cfg"
	var frame := Control.new()
	frame.size = Vector2(1920, 1320)
	root.add_child(frame)
	var pad: Control = load("res://ui/touch/trackpad.tscn").instantiate()
	frame.add_child(pad)
	await process_frame
	var panel: MovablePanel = pad.get_node(^"Panel")
	check("the trackpad keeps to the left edge", panel.position.x, panel.default_position.x)
	var share_1080 := panel.default_position.y / (1080.0 - panel.size.y)
	check("and keeps its share of the room below in a taller window", is_equal_approx(roundf(share_1080 * (1320.0 - panel.size.y)), panel.position.y), true)
	frame.queue_free()
