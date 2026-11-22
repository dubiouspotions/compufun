extends "res://tests/test.gd"
## A person has the moods that it has portraits for, in Person.MOODS order, and a mood has its own
## voice when voices/moods/ has a file for it.


func run() -> void:
	var person := Person.new()
	for mood: StringName in [&"angry", &"neutral", &"happy"]:
		person.portraits[mood] = PlaceholderTexture2D.new()
	check("the moods with portraits, in MOODS order", person.moods(), [&"neutral", &"happy", &"angry"] as Array[StringName])
	check("no portraits, no moods", Person.new().moods(), [] as Array[StringName])
	check("a mood with a voice file", Voices.has_mood(&"happy"), true)
	check("a mood that speaks as neutral", Voices.has_mood(&"trust"), false)
