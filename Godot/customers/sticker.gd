class_name Sticker
extends Resource
## A sticker on a customer's computer case: a picture on one face of the case (Computer.stickers).

## A face of the case. LEFT and RIGHT are as seen from the front; RIGHT is the side panel.
enum Face { FRONT, LEFT, RIGHT }

const _POSTER := preload("res://props/poster.tscn")

## The picture, stretched to [member size].
@export var texture: Texture2D
## The face of the case that the sticker is on.
@export var face: Face = Face.FRONT
## The centre of the sticker, in metres from the centre of its face: x to the right and y up, as seen
## when looking at that face.
@export var position: Vector2
## Width and height, in metres.
@export var size := Vector2(0.06, 0.04)
## How far the sticker is turned, in degrees counterclockwise as seen when looking at its face.
@export_range(-180.0, 180.0) var tilt_degrees: float


## Puts [param stickers] on a case, replacing the stickers that a previous call put there.
## [param faces] holds a node per face, at the centre of that face: its +Z points out of the case and
## its +Y up the face. A sticker on a face that [param faces] lacks is not shown (the face is hidden
## in that pose).
static func stick(stickers: Array[Sticker], faces: Dictionary[Face, Node3D]) -> void:
	for node: Node3D in faces.values():
		for old: Node in node.get_children():
			node.remove_child(old)
			old.queue_free()
	for sticker: Sticker in stickers:
		var node: Node3D = faces.get(sticker.face)
		if node == null:
			continue
		var poster := _POSTER.instantiate() as Poster
		poster.texture = sticker.texture
		poster.size = sticker.size
		poster.position = Vector3(sticker.position.x, sticker.position.y, 0.0)
		poster.rotation.z = deg_to_rad(sticker.tilt_degrees)
		node.add_child(poster)
