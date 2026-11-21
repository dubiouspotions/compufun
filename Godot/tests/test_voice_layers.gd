extends "res://tests/test.gd"
## A voice is three layers: the person, the mood over it, the effect on top. Each character has
## their own person (voice), and a missing layer leaves the ones below.


func run() -> void:
	var person := VoicePerson.new()
	person.settings = {"scale": 0.8, "tension": 0.3}
	var mood := VoiceMood.new()
	mood.settings = {"tension": 0.7}
	var effect := VoiceEffect.new()
	effect.base = {"tension": 0.2}
	effect.alternate = {"bits": 4.0}
	check("person alone", Voices.layer(person, null, null), "base:scale=0.8,tension=0.3")
	check("mood over person", Voices.layer(person, mood, null), "base:scale=0.8,tension=0.7")
	check("effect on top; its alternate keeps the layers below", Voices.layer(person, mood, effect),
		"base:scale=0.8,tension=0.2|alt:scale=0.8,tension=0.7,bits=4.0")
	check("no layers is plain", Voices.layer(null, null, null), "")
	for name in ["skater_bro", "young_entrepreneur", "retired_accountant"]:
		var customer: Customer = load("res://customers/%s.tres" % name)
		check("%s speaks with its person's voice" % name, customer.voice != null and customer.voice == customer.person.voice, true)
	for dir in DirAccess.get_directories_at("res://people"):
		var who: Person = load("res://people/%s/person.tres" % dir)
		if not who.portraits.is_empty():
			check("%s has its own voice" % dir, who.voice != null and who.voice.resource_path == "res://voices/persons/%s.tres" % dir, true)
	check("effects/cambion_glitch.tres loads", load("res://voices/effects/cambion_glitch.tres") is VoiceEffect, true)
