extends "res://tests/test.gd"
## The records that the player makes in CompuFunDB, with their marked symptoms and ticked repairs,
## survive a snapshot and a restore, and a malformed record is refused.


func run() -> void:
	check("start day 1", game.restore({}), "")
	var record: DbRecord = game.add_record("Pierre: turns off")
	check("the record is added", game.records.size(), 1)
	game.mark_symptom(record, "The fan is full of dust", true)
	game.mark_symptom(record, "The fan is full of dust", true)
	check("a symptom is marked once", record.marked_symptoms, ["The fan is full of dust"])
	game.tick_repair(record, "Install the fan", true)
	game.tick_repair(record, "Install the fan", false)
	check("a repair unticks", record.ticked_repairs, [])
	game.tick_repair(record, "Install the fan", true)

	check("restore the snapshot", game.restore(game.snapshot()), "")
	var restored: DbRecord = game.records[0]
	check("the text survives", restored.text, "Pierre: turns off")
	check("the marks survive", restored.marked_symptoms, ["The fan is full of dust"])
	check("the ticks survive", restored.ticked_repairs, ["Install the fan"])

	var refused: String = game.restore({"records": [{"text": "x", "marked_symptoms": "oops"}]})
	check("a list that is not a list is refused", refused.contains("marked_symptoms of the record 'x' is not a list"), true)
	check("the refusal keeps the records", game.records[0], restored)
	check("a restore without records starts empty", game.restore({}), "")
	check("no records", game.records.size(), 0)
