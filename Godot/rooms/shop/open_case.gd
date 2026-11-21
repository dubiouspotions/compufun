class_name OpenCase
extends Node3D
## A job's computer lying open in the Workview: its pieces in their places, the pieces on its mat,
## and the hotspots that take and put them (wiki: Hardware Repair). It draws the job from Game on
## every change and acts through Game.

## The job whose computer this is. Set once, before the case enters the tree.
var job: Job
## True while the player works in this case: it is open, in focus, in the Workview. JobComputer
## sets it. Only an active case takes clicks.
var active: bool = false:
	set(value):
		active = value
		if is_node_ready():
			_sync()

var _shown: Dictionary[StringName, Node3D] = {}
var _mat_shown: Array[Node3D] = []

@onready var _places: Node3D = %Places
@onready var _spots: Node3D = %Spots
@onready var _mat_surface: Hotspot = %MatSurface
@onready var _eye: Marker3D = %Eye


func _ready() -> void:
	for part: Part in Part.every():
		var place := _place(part)
		if place != null:
			(place.get_node("Hotspot") as Hotspot).clicked.connect(_on_place_clicked.bind(part).unbind(1))
	for i: int in _spots.get_child_count():
		(_spots.get_child(i).get_node("Hotspot") as Hotspot).clicked.connect(_on_spot_clicked.bind(i).unbind(1))
	_mat_surface.clicked.connect(func(_h: Hotspot) -> void: Game.put_on_mat(job))
	Game.changed.connect(_sync)
	_sync()


## Where the Workview camera looks from while the case is open: higher, so the case and the mat
## both show. In world space.
func eye_transform() -> Transform3D:
	return _eye.global_transform


func _place(part: Part) -> Node3D:
	var place := _places.get_node_or_null(String(part.id())) as Node3D
	if place == null:
		push_error("OpenCase: no place named %s under %s" % [part.id(), _places.get_path()])
	return place


# Converges the models and the hotspots on the job's pieces, its mat and the hand.
func _sync() -> void:
	if job == null:
		return
	for part: Part in Part.every():
		var place := _place(part)
		if place == null:
			continue
		var piece := job.piece(part)
		var shown: Node3D = _shown.get(part.id())
		if (piece != null) != (shown != null):
			if shown != null:
				shown.queue_free()
				_shown.erase(part.id())
			else:
				_shown[part.id()] = _show_model(part, place)
		(place.get_node("Hotspot") as Hotspot).set_enabled(active and (Game.can_take(job, part) or Game.can_put(job, part)))
	for shown: Node3D in _mat_shown:
		shown.queue_free()
	_mat_shown.clear()
	for i: int in job.mat.size():
		var spot := _spots.get_child(mini(i, _spots.get_child_count() - 1)) as Node3D
		_mat_shown.append(_show_model(job.mat[i].part, spot))
	for i: int in _spots.get_child_count():
		(_spots.get_child(i).get_node("Hotspot") as Hotspot).set_enabled(active and Game.hand == null and i < job.mat.size())
	_mat_surface.set_enabled(active and Game.hand != null)


func _show_model(part: Part, where: Node3D) -> Node3D:
	if part.model == null:
		push_error("OpenCase: %s has no model" % part.resource_path)
		return null
	var model := part.model.instantiate() as Node3D
	where.add_child(model)
	return model


func _on_place_clicked(part: Part) -> void:
	if Game.can_take(job, part):
		Game.take_part(job, part)
	else:
		Game.put_part(job)


func _on_spot_clicked(index: int) -> void:
	Game.take_from_mat(job, index)
