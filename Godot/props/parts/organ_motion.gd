class_name OrganMotion
extends Node3D
## Keeps an organ model alive wherever it is (in a computer, in the hand, in the trash): its Body
## child beats, breathes, jiggles or throbs, scaled about its own bottom, and it squelches now and
## then. It moves by the clock (the seconds since the game started), as a Hum with from_clock plays,
## so a heart stays in step with its heartbeat.

enum Kind {
	BEAT, ## Contracts with each lub and, less, each dub, as a heart.
	BREATHE, ## Swells and sinks slowly, as a lung.
	JIGGLE, ## Wobbles after each lub and settles, as a liver shaken by the heart.
	THROB, ## Swells a little with each lub, as an organ full of arteries.
}

@export var kind: Kind = Kind.THROB
## The seconds of one cycle: a heartbeat (match the heartbeat sound's length), or a breath.
@export var period: float = 1.0
## How far the body swells or shrinks, as a share of its size.
@export_range(0.0, 0.5) var amount: float = 0.05
## Where the dub falls in a heartbeat, as a share of [member period].
@export_range(0.0, 1.0) var dub_at: float = 0.3
## Plays from the organ now and then; null for silence.
@export var squelch: SoundSet
## The seconds between two squelches, picked at random between x and y.
@export var squelch_every: Vector2 = Vector2(5.0, 14.0)

var _next_squelch: float = 0.0

@onready var _body: Node3D = $Body


func _ready() -> void:
	_next_squelch = randf_range(squelch_every.x, squelch_every.y)


func _process(delta: float) -> void:
	var phase := fmod(Time.get_ticks_msec() / 1000.0, period) / period
	_body.scale = _scale_at(phase)
	if squelch == null or not is_visible_in_tree():
		return
	_next_squelch -= delta
	if _next_squelch <= 0.0:
		_next_squelch = randf_range(squelch_every.x, squelch_every.y)
		squelch.play_at(_body)


func _scale_at(phase: float) -> Vector3:
	var beat := _pulse(phase, 0.0, 0.07) + 0.6 * _pulse(phase, dub_at, 0.06)
	match kind:
		Kind.BEAT:
			return Vector3(1.0 - amount * beat, 1.0 - amount * 0.6 * beat, 1.0 - amount * beat)
		Kind.BREATHE:
			var breath := (1.0 - cos(TAU * phase)) / 2.0
			return Vector3(1.0 + amount * breath, 1.0 + amount * 0.7 * breath, 1.0 + amount * 1.3 * breath)
		Kind.JIGGLE:
			var since := phase * period
			var wobble := exp(-since * 5.0) * sin(since * TAU * 4.0)
			return Vector3(1.0 + amount * wobble, 1.0 - amount * wobble, 1.0 + amount * 0.5 * wobble)
		_:
			return Vector3.ONE * (1.0 + amount * beat)


# A bump of height 1 at [param at] in a looping phase, [param width] wide, rising fast.
static func _pulse(phase: float, at: float, width: float) -> float:
	var d := fposmod(phase - at + 0.5, 1.0) - 0.5
	return exp(-pow(d / (width if d >= 0.0 else width * 0.4), 2.0))
