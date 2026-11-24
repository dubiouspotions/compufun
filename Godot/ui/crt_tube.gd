class_name CrtTube
extends Node
## The tube of one monitor: its power, its lock on the signal, the degauss and the magnetised
## mask. It animates the crt_* uniforms of its looks (the close-up's and the 3D screen's, see
## [method add_look]), so each monitor has a tube of its own, and plays the monitor's sounds.
## [method reconcile] moves it toward the state that the game wants. See docs/crt.md.

## The seconds that the picture takes to collapse to a line, a dot, and fade.
@export var power_off_seconds: float = 1.8
## The seconds that the tube takes to warm up to full brightness.
@export var warmup_seconds: float = 3.0
## The seconds from a degauss until the mangled picture blanks to black.
@export var degauss_blank_at: float = 0.5
## The seconds that the degauss keeps the picture black.
@export var degauss_black_seconds: float = 0.2
## The seconds that the picture takes to fade back in after the degauss's black.
@export var degauss_fade_in_seconds: float = 0.3
## The seconds after the fade-in that the degauss's mangling takes to die down.
@export var degauss_settle_seconds: float = 0.4
## The seconds that the picture takes to tear and roll away when the signal goes.
@export var sync_lost_seconds: float = 0.35
## The seconds of black while the monitor finds a new signal.
@export var sync_search_seconds: float = 0.5
## The seconds that the picture rolls before it locks onto a new signal.
@export var sync_lock_seconds: float = 0.9
## How much the mask magnetises per second while the screen shows a computer, at warp 1; the
## day's warp scales it, so it doesn't happen at warp 0. It stops at the warp, so only warp 1
## magnetises it fully.
@export_range(0.0, 0.1, 0.001) var magnetize_per_second: float = 0.007
@export var power_on_sound: AudioStream = preload("res://sounds/crt_power_on.wav")
@export var power_off_sound: AudioStream = preload("res://sounds/crt_power_off.wav")
@export var degauss_sound: AudioStream = preload("res://sounds/crt_degauss.wav")
@export var relay_sound: AudioStream = preload("res://sounds/crt_relay.wav")

# Monitors stand switched on: the game starts with a warm picture and no power-on sound.
var _on: bool = true
var _signal: bool = false
var _warp: float = 0.0
var _values: Dictionary[StringName, float] = {}
# Every uniform that the looks get, the cursor's too: a look added later catches up.
var _params: Dictionary[StringName, Variant] = {}
var _looks: Array[ShaderMaterial] = []
var _tweens: Dictionary[StringName, Tween] = {}
var _players: Dictionary[AudioStream, AudioStreamPlayer] = {}


func _ready() -> void:
	for sound: AudioStream in [power_on_sound, power_off_sound, degauss_sound, relay_sound]:
		var player := AudioStreamPlayer.new()
		player.stream = sound
		add_child(player)
		_players[sound] = player
	_set_value(1.0, &"crt_power")
	_set_value(1.0, &"crt_warmup")
	_set_value(0.0, &"crt_degauss")
	_set_value(0.0, &"crt_blank")
	_set_value(1.0, &"crt_sync")  # the monitor's own NO SIGNAL box is a steady picture
	_set_value(0.0, &"crt_magnetization")
	_set_value(0.0, &"crt_picture")


func _process(delta: float) -> void:
	if _on and _signal and _warp > 0.0 and not _tweens.has(&"crt_magnetization"):
		_set_value(minf(_warp, _values[&"crt_magnetization"] + magnetize_per_second * _warp * delta), &"crt_magnetization")


## Lets this tube drive [param look]'s crt_* uniforms, from their current values on.
func add_look(look: ShaderMaterial) -> void:
	_looks.append(look)
	for uniform: StringName in _params:
		look.set_shader_parameter(uniform, _params[uniform])


## Sets [param uniform] on every look, for example the cursor's crt_cursor.
func set_param(uniform: StringName, value: Variant) -> void:
	_params[uniform] = value
	for look: ShaderMaterial in _looks:
		look.set_shader_parameter(uniform, value)


## Turns the monitor on or off and locks onto or loses the signal, with their animations and
## sounds, when [param on] or [param has_signal] differ from the last call. [param warp] is the
## day's warp (0 to 1), which magnetises the mask. [param instant] shows the new state at once,
## silently, and ends the animations of earlier changes: for a [member Game.jump].
func reconcile(on: bool, signal_in: bool, warp: float, instant: bool = false) -> void:
	_warp = warp
	if instant:
		_on = on
		_signal = signal_in
		for uniform: StringName in [&"crt_power", &"crt_warmup", &"crt_sync", &"crt_picture"]:
			if _tweens.has(uniform):
				_tweens[uniform].kill()
				_tweens.erase(uniform)
		_set_value(1.0 if on else 0.0, &"crt_power")
		_set_value(1.0, &"crt_warmup")
		_set_value(1.0 if on or signal_in else 0.0, &"crt_sync")
		_set_value(1.0 if signal_in else 0.0, &"crt_picture")
		return
	if on != _on:
		_on = on
		if on:
			_power_on()
		else:
			_play(power_off_sound)
			_animate(&"crt_power", 0.0, power_off_seconds, Tween.EASE_OUT, Tween.TRANS_CUBIC)
	if signal_in != _signal:
		_signal = signal_in
		_animate(&"crt_picture", 1.0 if signal_in else 0.0, sync_lock_seconds, Tween.EASE_IN_OUT, Tween.TRANS_SINE)
		if not _on:
			_set_value(1.0 if signal_in else 0.0, &"crt_sync")
		elif signal_in:
			_lock_sync()
		else:
			_lose_sync()


## Mangles the picture and its colours, blanks it to black at [member degauss_blank_at] while the
## magnetised mask clears, fades it back in, and lets the mangling die down over
## [member degauss_settle_seconds]. Does nothing while the monitor is off.
func degauss() -> void:
	if not _on:
		return
	_play(degauss_sound)
	var back_at := degauss_blank_at + degauss_black_seconds + degauss_fade_in_seconds
	var mangle := _new_tween(&"crt_degauss")
	mangle.tween_method(_set_value.bind(&"crt_degauss"), _values[&"crt_degauss"], 1.0, 0.05)
	mangle.tween_interval(back_at - 0.05)
	mangle.tween_method(_set_value.bind(&"crt_degauss"), 1.0, 0.0, degauss_settle_seconds).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	var blank := _new_tween(&"crt_blank")
	blank.tween_interval(degauss_blank_at)
	blank.tween_method(_set_value.bind(&"crt_blank"), _values[&"crt_blank"], 1.0, 0.04)
	blank.tween_interval(degauss_black_seconds)
	blank.tween_method(_set_value.bind(&"crt_blank"), 1.0, 0.0, degauss_fade_in_seconds).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	var clear := _new_tween(&"crt_magnetization")
	clear.tween_interval(degauss_blank_at)
	clear.tween_method(_set_value.bind(&"crt_magnetization"), _values[&"crt_magnetization"], 0.0, degauss_black_seconds)


func _power_on() -> void:
	_play(power_on_sound)
	_set_value(1.0, &"crt_power")
	_set_value(0.0, &"crt_warmup")
	_animate(&"crt_warmup", 1.0, warmup_seconds, Tween.EASE_IN_OUT, Tween.TRANS_SINE)
	degauss()


func _lock_sync() -> void:
	_play(relay_sound)
	_set_value(1.0, &"crt_sync")  # the monitor's own NO SIGNAL box is a steady picture
	var tween := _new_tween(&"crt_sync")
	tween.tween_interval(sync_search_seconds)
	tween.tween_method(_set_value.bind(&"crt_sync"), 0.0, 1.0, sync_lock_seconds).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


# The picture tears and rolls away, then the monitor's own NO SIGNAL box shows.
func _lose_sync() -> void:
	_play(relay_sound)
	var tween := _new_tween(&"crt_sync")
	tween.tween_method(_set_value.bind(&"crt_sync"), _values[&"crt_sync"], 0.0, sync_lost_seconds).set_ease(Tween.EASE_IN)
	tween.tween_interval(sync_search_seconds)
	tween.tween_callback(_play.bind(relay_sound))
	tween.tween_method(_set_value.bind(&"crt_sync"), 0.0, 1.0, 0.1)


func _play(sound: AudioStream) -> void:
	if sound != null:
		_players[sound].play()


func _animate(uniform: StringName, to: float, seconds: float, easing: Tween.EaseType, transition: Tween.TransitionType) -> void:
	_new_tween(uniform).tween_method(_set_value.bind(uniform), _values[uniform], to, seconds).set_ease(easing).set_trans(transition)


func _new_tween(uniform: StringName) -> Tween:
	if _tweens.has(uniform):
		_tweens[uniform].kill()
	var tween := create_tween()
	_tweens[uniform] = tween
	tween.finished.connect(func() -> void:
		if _tweens.get(uniform) == tween:
			_tweens.erase(uniform))
	return tween


func _set_value(value: float, uniform: StringName) -> void:
	_values[uniform] = value
	set_param(uniform, value)
