class_name StoryCheck
extends RefCounted
## The story check: the missing links of a week from the story files, and who sets and who checks
## each flag. The Story Lab shows them on the errands' cards and in its flag picker; dev/story.gd
## prints them (docs/building-and-testing.md).

const SIGNS_DIR: String = "res://corruption/"
const MOODS_DIR: String = "res://voices/moods/"
## Flags with this suffix after a customer's file name install Cambion (Game.runs_cambion).
const CAMBION_SUFFIX: String = "_runs_cambion"
## Flags with this prefix before a customer's file name record the [x] (Game.dismiss_visitor).
const GONE_PREFIX: String = "gone_"
## The most flags in one errand code's conditions that [method missing_links] tries every value of.
const MAX_FLAGS_TRIED: int = 10


## Who sets and who checks each flag of [param week]: flag name to
## {"set_by": PackedStringArray, "checked_by": PackedStringArray}. Each entry starts with the file
## path, such as "res://story/errands/0102_skater_bro.errand (0102/drop-off/1 > "Did you...")". A
## corruption sign checks its flag sign_<id>, Game checks every <customer>_runs_cambion, and the [x]
## sets and Game checks every gone_<customer>.
static func flag_index(week: StoryFiles.Week) -> Dictionary:
	var index := {}
	for d: Day in week.days:
		var day_path := "%sday_%d.day" % [StoryFiles.DAYS_DIR, d.number]
		_note_sets(index, d.set_flags, day_path + " (on start)")
		_note_sets(index, d.close_flags, day_path + " (on close)")
		for id: StringName in d.close_signs:
			_note(index, StringName("sign_" + id), "set_by", day_path + " (close signs)")
		for errand: Errand in d.errands:
			_note_when(index, errand.when, errand.file)
			for c: Conversation in errand.conversations:
				_scan(index, c, "%s (%s)" % [errand.file, c.id])
	var signs := sign_titles()
	for flag: StringName in signs:
		_note(index, flag, "checked_by", "%s%s.tscn (%s)" % [SIGNS_DIR, String(flag).trim_prefix("sign_"), signs[flag]])
	for flag: StringName in index.keys():
		if String(flag).ends_with(CAMBION_SUFFIX):
			_note(index, flag, "checked_by", "res://game.gd (Game.runs_cambion)")
		if String(flag).begins_with(GONE_PREFIX):
			_note(index, flag, "set_by", "res://corruption/customer_x.tscn (the [x])")
			_note(index, flag, "checked_by", "res://game.gd (Game.is_gone)")
	return index


## The missing links of [param week], one sentence each, starting with the file path: a flag that
## nothing sets or nothing checks, a + choice without lines, an errand without a drop-off (unless it
## brings no computer and has no lines at all), an errand code whose alternatives can all fail on
## its day, a line's mood that the customer's person has no portrait for or that has no
## voices/moods/<mood>.tres, and a problem without repair mechanics (no broken_part and no
## software_check).
static func missing_links(week: StoryFiles.Week) -> PackedStringArray:
	var found := PackedStringArray()
	var index := flag_index(week)
	var flags: Array = index.keys()
	flags.sort()
	for flag: StringName in flags:
		var set_by: PackedStringArray = index[flag]["set_by"]
		var checked_by: PackedStringArray = index[flag]["checked_by"]
		if set_by.is_empty() and not String(flag).begins_with("sign_"):
			found.append("%s checks the flag %s, which nothing sets." % [_and_more(checked_by), flag])
		if checked_by.is_empty():
			found.append("%s sets the flag %s, which nothing checks." % [_and_more(set_by), flag])
	for d: Day in week.days:
		for code: String in d.codes():
			var alternatives := d.alternatives(code)
			var failing := _all_can_fail(alternatives, d.number)
			if failing != "":
				found.append("%s: errand code %s can come with nobody on day %d: %s." % [alternatives[0].file, code, d.number, failing])
		for errand: Errand in d.errands:
			_check_errand(errand, found)
	return found


## The flag of every corruption sign scene, sign_<id>, to its title, read without instancing it.
static func sign_titles() -> Dictionary[StringName, String]:
	var titles: Dictionary[StringName, String] = {}
	for file: String in DirAccess.get_files_at(SIGNS_DIR):
		if not file.ends_with(".tscn"):
			continue
		var scene := load(SIGNS_DIR + file) as PackedScene
		if scene == null:
			push_error("StoryCheck: %s%s doesn't load as a scene" % [SIGNS_DIR, file])
			continue
		var state := scene.get_state()
		var title := file.get_basename()
		for i: int in state.get_node_property_count(0):
			if state.get_node_property_name(0, i) == &"title":
				title = state.get_node_property_value(0, i)
		titles[StringName("sign_" + file.get_basename())] = title
	return titles


static func _check_errand(errand: Errand, found: PackedStringArray) -> void:
	var lines := 0
	for c: Conversation in errand.conversations:
		lines += c.all_lines().size()
		_check_choices(c, "%s (%s)" % [errand.file, c.id], found)
		var person := errand.customer.person if errand.customer != null else null
		for line: DialogueLine in c.all_lines():
			var mood := line.mood
			if person == null or not person.moods().has(mood):
				found.append("%s (%s): \"%s\" is in the mood %s, which %s has no portrait for." % [errand.file, c.id, line.text.left(40), mood, person.resource_path if person != null else "a customer without a person"])
			if not Voices.has_mood(mood):
				found.append("%s (%s): \"%s\" is in the mood %s, which has no voice (%s%s.tres)." % [errand.file, c.id, line.text.left(40), mood, MOODS_DIR, mood])
	var arrives := errand.conversations.any(func(c: Conversation) -> bool: return c.trigger == Conversation.Trigger.ARRIVE)
	if not arrives and not (errand.brings == Errand.Brings.NOTHING and lines == 0):
		found.append("%s has no drop-off conversation." % errand.file)
	var problem := errand.problem
	if problem != null and problem.broken_part == null and problem.software_check == null:
		found.append("%s names the problem %s, which has no repair mechanics: no broken_part and no software_check." % [errand.file, problem.resource_path])


static func _check_choices(reply: Reply, where: String, found: PackedStringArray) -> void:
	for choice: Choice in reply.choices:
		var asked := "%s > \"%s\"" % [where.trim_suffix(")"), choice.text.left(30)] + ")"
		for answer: Reply in choice.replies:
			if answer.lines.is_empty() and answer.choices.is_empty() and choice.returns:
				found.append("%s: the + choice has no lines, so its list shows again at once." % asked)
			_check_choices(answer, asked, found)
	if reply.then != null:
		_check_choices(reply.then, where, found)


# Every line of [param reply], its choices' replies and what follows its list.
# Why [param alternatives] can all fail on [param day], or "" when one always comes: it tries every
# value of the flags that their conditions name.
static func _all_can_fail(alternatives: Array[Errand], day: int) -> String:
	var names: Array[StringName] = []
	for each: Errand in alternatives:
		if each.when == null:
			return ""
		for flag: StringName in each.when.need_flags + each.when.not_flags:
			if flag not in names:
				names.append(flag)
	if names.size() > MAX_FLAGS_TRIED:
		return ""
	for bits: int in 1 << names.size():
		var flags: Dictionary[StringName, int] = {}
		for i: int in names.size():
			if bits & (1 << i):
				flags[names[i]] = 1
		if not alternatives.any(func(each: Errand) -> bool: return each.when.is_met(day, flags)):
			var on := PackedStringArray(flags.keys())
			return "with %s, no alternative's 'when' holds" % (("only " + ", ".join(on) + " set") if not on.is_empty() else "no flags set")
	return ""


static func _scan(index: Dictionary, reply: Reply, where: String) -> void:
	_note_sets(index, reply.set_flags, where)
	_note_when(index, reply.when, where)
	for choice: Choice in reply.choices:
		var asked := "%s > \"%s\")" % [where.trim_suffix(")"), choice.text.left(30)]
		_note_when(index, choice.when, asked)
		for answer: Reply in choice.replies:
			_scan(index, answer, asked)
	if reply.then != null:
		_scan(index, reply.then, where)


static func _note_when(index: Dictionary, when: Condition, where: String) -> void:
	if when == null:
		return
	for flag: StringName in when.need_flags:
		_note(index, flag, "checked_by", where)
	for flag: StringName in when.not_flags:
		_note(index, flag, "checked_by", where + " (not)")


static func _note_sets(index: Dictionary, sets: Dictionary[StringName, int], where: String) -> void:
	for flag: StringName in sets:
		_note(index, flag, "set_by", where if sets[flag] == 1 else "%s =%d" % [where, sets[flag]])


static func _note(index: Dictionary, flag: StringName, role: String, where: String) -> void:
	if not index.has(flag):
		index[flag] = {"set_by": PackedStringArray(), "checked_by": PackedStringArray()}
	var notes: PackedStringArray = index[flag][role]  # a copy: packed arrays are values
	notes.append(where)
	index[flag][role] = notes


static func _and_more(where: PackedStringArray) -> String:
	return where[0] + (" (and %d more)" % (where.size() - 1) if where.size() > 1 else "")
