extends CorruptionSign
## Things in the shop make Windows noises. While the sign shows, an action in the shop sometimes
## plays a Win95 sound on top of its own sound: a click on a hotspot (the phone is one), a part that
## comes into or leaves the hand, the cable that goes in or comes out. The sign changes nothing that
## stage 0 must undo; it only listens.

## The Win95 sounds; each noise picks one.
@export var noises: SoundSet
## The chance, from 0 to 1, that one action makes a noise.
@export_range(0.0, 1.0, 0.05) var chance: float = 0.3

var _shop: Node
var _heard_hand: Piece
var _heard_cable: Job
## The frame of the last roll: a click that also changes the hand is one action, with one roll.
var _rolled_frame: int = -1


func _ready() -> void:
	if noises == null:
		push_error("WindowsNoises: %s has no noises" % scene_file_path)
	_shop = get_parent().get_parent()
	for node: Node in _shop.find_children("*", "Area3D", true, false):
		_listen(node)
	# Jobs, open cases and their screws add hotspots while the game runs.
	get_tree().node_added.connect(_listen)
	_heard_hand = Game.hand
	_heard_cable = Game.connected
	Game.changed.connect(_hear_changes)
	super()


func _listen(node: Node) -> void:
	var hotspot := node as Hotspot
	if hotspot != null and _shop.is_ancestor_of(hotspot) and not hotspot.clicked.is_connected(_on_clicked):
		hotspot.clicked.connect(_on_clicked)


func _on_clicked(hotspot: Hotspot) -> void:
	_roll(hotspot)


func _hear_changes() -> void:
	if Game.hand == _heard_hand and Game.connected == _heard_cable:
		return
	_heard_hand = Game.hand
	_heard_cable = Game.connected
	_roll(self)


## Plays a noise from [param at] (in 3D when it is a Node3D) with the chance [member chance].
func _roll(at: Node) -> void:
	if stage() == 0 or noises == null or Engine.get_process_frames() == _rolled_frame:
		return
	_rolled_frame = Engine.get_process_frames()
	if randf() < chance:
		noises.play_at(at)
