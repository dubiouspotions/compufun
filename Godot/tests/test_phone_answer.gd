extends "res://tests/test.gd"
## The customer answers right after the far end picks up: the call waits for the click near the end
## of sounds/phone_receiver.wav (tools/make_shop_sounds.py).

## How long phone_receiver.wav goes on after the far end's click, in seconds.
const AFTER_CLICK: float = 0.395


func run() -> void:
	var phone_call: Node = load("res://ui/phone_call.tscn").instantiate()
	var length := (load("res://sounds/phone_receiver.wav") as AudioStream).get_length()
	print("phone_receiver.wav lasts %.3f s, the click at %.3f s; the customer answers at %.3f s" % [length, length - AFTER_CLICK, phone_call.ring_seconds])
	check("the customer answers after the far end's click", phone_call.ring_seconds >= length - AFTER_CLICK, true)
	check("the customer answers before the call sound ends", phone_call.ring_seconds <= length, true)
	phone_call.free()
