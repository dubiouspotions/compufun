@tool
class_name CallOuts
extends Resource
## What one customer, or every customer, calls out while they wait at the counter and the player
## looks elsewhere: the sets of a call-outs file, story/callouts/<customer>.callouts or
## everyone.callouts (docs/dialogue.md, "Call-outs").

## The file name of the call-outs that every customer falls back to.
const EVERYONE: StringName = &"everyone"
## The dayparts that a set can be limited to: the ones in which a customer can wait.
const DAYPARTS: Array[StringName] = [&"morning", &"midday", &"afternoon"]


## One set of call-outs: its lines, [member Conversation.when], [member Conversation.effect] and
## [member Conversation.daypart].
class Set:
	extends Conversation
	## The set adds everyone's lines, of the set that everyone's file picks then, after its own
	## ([code][with everyone][/code]).
	var with_everyone: bool = false
	var _merged: Set
	var _merged_with: Set

	## True when the set has neither a condition nor a daypart: it plays when no other set matches.
	func is_plain() -> bool:
		return when == null and daypart == &""

	## This set with [param everyone]'s lines after its own, the same Set each time for the same
	## [param everyone], so the call-out box goes on rather than starting again. Itself without
	## [member with_everyone] or [param everyone].
	func adding(everyone: Set) -> Set:
		if not with_everyone or everyone == null:
			return self
		if _merged == null or _merged_with != everyone:
			_merged_with = everyone
			_merged = Set.new()
			_merged.id = id
			_merged.brief = brief
			_merged.when = when
			_merged.daypart = daypart
			_merged.effect = effect
			_merged.lines.assign(lines + everyone.lines)
		return _merged


## The customer's file name, or [constant EVERYONE].
var name: StringName = &""
## The res:// path of the file.
var file: String = ""
## In the order of the file. At most one is plain ([method Set.is_plain]).
var sets: Array[Set] = []


## The set that plays on [param day] with [param flags] in [param daypart] (one of
## [constant DAYPARTS], or empty): the first set with a condition or a daypart whose both match,
## else the plain set; null when neither.
func pick(day: int, flags: Dictionary[StringName, int], daypart: StringName) -> Set:
	var plain: Set = null
	for each: Set in sets:
		if each.is_plain():
			plain = each
		elif (each.when == null or each.when.is_met(day, flags)) and (each.daypart == &"" or each.daypart == daypart):
			return each
	return plain
