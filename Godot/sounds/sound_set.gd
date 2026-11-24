class_name SoundSet
extends Resource
## One sound effect with a few takes: each play picks one at random, a little higher or lower, so a
## repeated sound doesn't sound copied. Make one .tres per effect in sounds/ and export it where
## the effect happens.

## The physics layer of the sound zones (rooms/shop/sound_zones.tscn). A 3D player hears the zones
## only with this layer in its area_mask; Godot's default mask is 0.
const SOUND_ZONES: int = 1

## The takes; one is picked at random each time.
@export var sounds: Array[AudioStream] = []
@export_range(-40.0, 12.0, 0.5) var volume_db: float = 0.0
## Each play's pitch is picked between x and y; 1 is as recorded.
@export var pitch_range: Vector2 = Vector2(0.95, 1.05)


## Plays a random take on [param player], an AudioStreamPlayer or AudioStreamPlayer3D, from
## [param from_seconds] into the take. A take already playing on [param player] stops.
func play_on(player: Node, from_seconds: float = 0.0) -> void:
	if sounds.is_empty():
		push_error("SoundSet %s has no sounds" % resource_path)
		return
	player.set(&"stream", sounds.pick_random())
	player.set(&"pitch_scale", randf_range(pitch_range.x, pitch_range.y))
	player.set(&"volume_db", volume_db)
	player.call(&"play", from_seconds)


## Plays a random take from where [param at] is: in 3D when it is a Node3D, else flat. The player
## is a new child of [param at] that frees itself when the take is over. A 3D take sounds like the
## room it is in (rooms/shop/sound_zones.tscn).
func play_at(at: Node) -> void:
	@warning_ignore("incompatible_ternary")
	var player: Node = AudioStreamPlayer3D.new() if at is Node3D else AudioStreamPlayer.new()
	if player is AudioStreamPlayer3D:
		(player as AudioStreamPlayer3D).area_mask = SOUND_ZONES
	at.add_child(player)
	play_on(player)
	var stream: AudioStream = player.get(&"stream")
	var seconds := stream.get_length() / maxf(0.1, player.get(&"pitch_scale")) if stream != null else 0.0
	# The length, not the player's finished signal: with no audio device that never fires.
	player.get_tree().create_timer(seconds + 0.1).timeout.connect(player.queue_free)
