class_name DbSearch
extends RefCounted
## The search in CompuFunDB: the symptom that the player picked, what CompuFunDB offered to look for
## (the symptoms that go with it among a few that don't, in the order shown), the symptoms that the
## player marked and the repair steps they ticked, as the Problems spell them. Game holds it; change
## it through Game, which emits Game.changed.

var query: String = ""
var offered: Array[String] = []
var marked_symptoms: Array[String] = []
var ticked_repairs: Array[String] = []


## The search as plain data, for Game.snapshot().
func snapshot() -> Dictionary:
	return {"query": query, "offered": offered.duplicate(), "marked_symptoms": marked_symptoms.duplicate(), "ticked_repairs": ticked_repairs.duplicate()}


## The search that [param data] describes, in the format of [method snapshot], or an error message.
static func from(data: Variant) -> Variant:
	if not data is Dictionary:
		return "the CompuFunDB search is not a dictionary: %s" % data
	var search := DbSearch.new()
	search.query = str(data.get("query", ""))
	if search.query.is_empty():
		return "the CompuFunDB search has no query: %s" % data
	for key: String in ["offered", "marked_symptoms", "ticked_repairs"]:
		if not data.get(key, []) is Array:
			return "%s of the CompuFunDB search '%s' is not a list: %s" % [key, search.query, data[key]]
	search.offered.assign(data.get("offered", []).map(str))
	search.marked_symptoms.assign(data.get("marked_symptoms", []).map(str))
	search.ticked_repairs.assign(data.get("ticked_repairs", []).map(str))
	return search
