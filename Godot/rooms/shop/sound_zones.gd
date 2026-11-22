extends Node3D
## Where a 3D sound plays: the shop's zone sends it to the Shop bus and into the Room reverb, the
## storage room's to Master and into the Storage reverb, the street's to the Street bus. A 3D player
## finds a zone only with SoundSet.SOUND_ZONES in its area_mask (docs/gotchas.md). While the player
## is in the storage room, the Shop bus pans right, toward the door to the shop; the Voice, Win95,
## Street and Room buses send to Shop, so the whole shop pans with it.

## The view in the storage room.
@export var storage_view: StringName = &"Storage"
## The bus of everything heard from the shop; its first effect is the panner.
@export var shop_bus: StringName = &"Shop"
## How far right the shop sounds in the storage room: 0 in the middle, 1 all from the right.
@export_range(0.0, 1.0) var storage_pan: float = 0.8
## The seconds that the pan takes to follow a turn into or out of the storage room.
@export var pan_seconds: float = 0.35

var _panner: AudioEffectPanner
var _target: float = 0.0
var _tween: Tween


func _ready() -> void:
	var bus := AudioServer.get_bus_index(shop_bus)
	if bus < 0:
		push_error("SoundZones: no audio bus '%s' in default_bus_layout.tres" % shop_bus)
		return
	_panner = AudioServer.get_bus_effect(bus, 0) as AudioEffectPanner if AudioServer.get_bus_effect_count(bus) > 0 else null
	if _panner == null:
		push_error("SoundZones: the first effect of the bus '%s' is not a panner" % shop_bus)
		return
	_panner.pan = 0.0
	Game.changed.connect(_sync)
	_sync()


func _sync() -> void:
	var target := storage_pan if Game.view == storage_view else 0.0
	if target == _target:
		return
	_target = target
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_panner, "pan", target, pan_seconds)
