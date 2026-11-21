class_name DbRecord
extends RefCounted
## One record in CompuFunDB: the customer and what they reported, as the character typed it up, the
## symptoms that the player marked and the repair steps they ticked, as the Problems spell them.
## Game holds the records; change them through Game, which emits Game.changed.

var text: String = ""
## The Job.order of the computer that the record was typed up for.
var job_order: int = -1
var marked_symptoms: Array[String] = []
var ticked_repairs: Array[String] = []


## The record as plain data, for Game.snapshot().
func snapshot() -> Dictionary:
	return {"text": text, "job_order": job_order, "marked_symptoms": marked_symptoms.duplicate(), "ticked_repairs": ticked_repairs.duplicate()}


## The record that [param data] describes, in the format of [method snapshot], or an error message.
static func from(data: Variant) -> Variant:
	if not data is Dictionary:
		return "a record is not a dictionary: %s" % data
	var record := DbRecord.new()
	record.text = str(data.get("text", ""))
	record.job_order = int(data.get("job_order", -1))
	for key: String in ["marked_symptoms", "ticked_repairs"]:
		if not data.get(key, []) is Array:
			return "%s of the record '%s' is not a list: %s" % [key, record.text, data[key]]
	record.marked_symptoms.assign(data.get("marked_symptoms", []).map(str))
	record.ticked_repairs.assign(data.get("ticked_repairs", []).map(str))
	return record
