class_name DbSearch
extends RefCounted
## The search in CompuFunDB: the symptom that the player picked, the checks that CompuFunDB offered
## (those that go with it among a few that don't, in the order shown), the checks that the player
## marked as failing and the repair steps they ticked, as the Problems spell them. Game holds it; change
## it through Game, which emits Game.changed.

var query: String = ""
var offered: Array[String] = []
var marked_checks: Array[String] = []
var ticked_repairs: Array[String] = []


## The search as plain data, for Game.snapshot().
func snapshot() -> Dictionary:
	return {"query": query, "offered": offered.duplicate(), "marked_checks": marked_checks.duplicate(), "ticked_repairs": ticked_repairs.duplicate()}


## The search that [param data] describes, in the format of [method snapshot], or an error message.
static func from(data: Variant) -> Variant:
	if not data is Dictionary:
		return "the CompuFunDB search is not a dictionary: %s" % data
	var search := DbSearch.new()
	search.query = str(data.get("query", ""))
	if search.query.is_empty():
		return "the CompuFunDB search has no query: %s" % data
	for key: String in ["offered", "marked_checks", "ticked_repairs"]:
		if not data.get(key, []) is Array:
			return "%s of the CompuFunDB search '%s' is not a list: %s" % [key, search.query, data[key]]
	search.offered.assign(data.get("offered", []).map(str))
	search.marked_checks.assign(data.get("marked_checks", []).map(str))
	search.ticked_repairs.assign(data.get("ticked_repairs", []).map(str))
	return search
