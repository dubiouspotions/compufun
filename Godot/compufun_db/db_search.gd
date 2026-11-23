class_name DbSearch
extends RefCounted
## The search in CompuFunDB: the symptom that the player picked, the checks that CompuFunDB offered
## (those of its possible causes, in the order shown) and the checks that the
## player ticked as true on the computer, as the Problems spell them. Game holds it; change it
## through Game, which emits Game.changed.

var query: String = ""
var offered: Array[String] = []
var ticked_checks: Array[String] = []


## The search as plain data, for Game.snapshot().
func snapshot() -> Dictionary:
	return {"query": query, "offered": offered.duplicate(), "ticked_checks": ticked_checks.duplicate()}


## The search that [param data] describes, in the format of [method snapshot], or an error message.
static func from(data: Variant) -> Variant:
	if not data is Dictionary:
		return "the CompuFunDB search is not a dictionary: %s" % data
	var search := DbSearch.new()
	search.query = str(data.get("query", ""))
	if search.query.is_empty():
		return "the CompuFunDB search has no query: %s" % data
	for key: String in ["offered", "ticked_checks"]:
		if not data.get(key, []) is Array:
			return "%s of the CompuFunDB search '%s' is not a list: %s" % [key, search.query, data[key]]
	search.offered.assign(data.get("offered", []).map(str))
	search.ticked_checks.assign(data.get("ticked_checks", []).map(str))
	return search
