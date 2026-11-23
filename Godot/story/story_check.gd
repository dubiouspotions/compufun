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
## A conversation's trigger in the words of [method sign_starts].
const TRIGGER_WORDS: Dictionary[String, String] = {"drop-off": "drop-off", "pick-up": "pick-up", "phone": "phone call"}


## Who sets and who checks each flag of [param week]: flag name to
## {"set_by": PackedStringArray, "checked_by": PackedStringArray}. Each entry starts with the file
## path, such as "res://story/errands/0102_skater_bro.errand (0102/drop-off/1 > "Did you...")". A
## corruption sign checks its flag sign_<id>, Game checks every <customer>_runs_cambion, the [x]
## sets and Game checks every gone_<customer>, and an errand's problem sets its replaced_flag and
## the flags of its drop_off_signs.
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
			var problem := errand.problem
			if problem != null and problem.replaced_flag != &"":
				_note(index, problem.replaced_flag, "set_by", "%s (replaced_flag)" % problem.resource_path)
			for id: StringName in problem.drop_off_signs if problem != null else ([] as Array[StringName]):
				_note(index, StringName("sign_" + id), "set_by", "%s (drop_off_signs)" % problem.resource_path)
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


## The places in [param week] that set the flag of the sign [param id], from [param index] (from
## [method flag_index]), in the Story Lab's words: each {"text" (plain words, such as "Day 3, at closing"), "day", "errand",
## "problem"}, of which the one that names where it is is set (day 0, "" or &"" for the others);
## "detail", the day's key ("on start", "on close" or "close signs"), the errand's conversation id
## (such as "0303/drop-off/1", with ' > "choice"' when a choice sets it) or "drop_off_signs"; and
## "value", the number that it sets the flag to (0 stops the sign).
static func sign_starts(week: StoryFiles.Week, index: Dictionary, id: StringName) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var entry: Dictionary = index.get(StringName("sign_" + id), {})
	for where: String in entry.get("set_by", PackedStringArray()):
		found.append(_sign_start(week, where))
	return found


# One "set_by" entry of the flag index, "<path> (<detail>)" with an optional " =<value>", in words.
static func _sign_start(week: StoryFiles.Week, where: String) -> Dictionary:
	var start := {"text": where, "day": 0, "errand": "", "problem": &"", "detail": "", "value": 1}
	var path := where.get_slice(" (", 0)
	var detail := where.substr(path.length() + 2)
	var value := -1
	var set_to := RegEx.create_from_string("\\) =(-?\\d+)$").search(detail)
	if set_to != null:
		value = set_to.get_string(1).to_int()
		detail = detail.substr(0, set_to.get_start())
	detail = detail.trim_suffix(")")
	start["detail"] = detail
	if value >= 0:
		start["value"] = value
	var text := ""
	if path.begins_with(StoryFiles.DAYS_DIR):
		start["day"] = path.get_file().get_basename().trim_prefix("day_").to_int()
		var when: String = {"on start": "as the day starts", "on close": "at closing", "close signs": "at closing, until the next morning"}.get(detail, detail)
		text = "Day %d, %s" % [start["day"], when]
	elif path.begins_with(StoryFiles.ERRANDS_DIR):
		start["errand"] = path
		var stem := path.get_file().get_basename()
		var who := stem.substr(5).capitalize()
		for day: Day in week.days:
			for errand: Errand in day.errands:
				if errand.file == path and errand.customer != null:
					who = errand.customer.spoken_name()
		var trigger := detail.get_slice("/", 1)
		text = "%s %s, %s" % [stem.substr(0, 4), who, TRIGGER_WORDS.get(trigger, trigger)]
		if detail.contains(" > "):
			text += ", when the player picks %s" % detail.substr(detail.find(" > ") + 3)
	elif detail == "drop_off_signs":
		start["problem"] = StringName(path.get_file().get_basename())
		text = "the problem %s, at drop-off" % path.get_file().get_basename().replace("_", " ")
	else:
		return start
	if value == 0:
		text += " (stops it)"
	elif value > 1:
		text += " (stage %d)" % value
	start["text"] = text
	return start


## The missing links of [param week], one sentence each, starting with the file path: a flag that
## nothing sets or nothing checks, a + choice without lines, an errand without a drop-off (unless it
## brings no computer and has no lines at all), an errand code whose alternatives can all fail on
## its day, a line's mood that the customer's person has no portrait for, a voice mood that a line
## speaks in (DialogueLine.voice) that has no voices/moods/<mood>.tres, a [leaving] line that the conversation can go on after (it plays in the
## dialogue box), a look that is not in DialogueLine.LOOKS or that never turns the view (on a
## [leaving] line or the phone), a problem without repair mechanics (no res://problems/<id>.tres, or one
## that fails Problem.has_repair_mechanics), and a problem file
## that no errand names.
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
	var named := {}
	for d: Day in week.days:
		for errand: Errand in d.errands:
			if errand.problem != null:
				named[errand.problem.short_name] = true
	for id: StringName in week.problems:
		if not named.has(id):
			found.append("%s%s.problem: no errand names the problem %s." % [StoryFiles.PROBLEMS_DIR, id, id])
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
		_check_leaving(c, false, "%s (%s)" % [errand.file, c.id], found)
		var person := errand.customer.person if errand.customer != null else null
		for line: DialogueLine in c.all_lines():
			var mood := line.mood
			if person == null or not person.moods().has(mood):
				found.append("%s (%s): \"%s\" is in the mood %s, which %s has no portrait for." % [errand.file, c.id, line.text.left(40), mood, person.resource_path if person != null else "a customer without a person"])
			if line.voice_mood != &"" and not Voices.has_mood(line.voice_mood):
				found.append("%s (%s): \"%s\" speaks in the voice mood %s, which has no voice (%s%s.tres)." % [errand.file, c.id, line.text.left(40), line.voice_mood, MOODS_DIR, line.voice_mood])
			elif line.voice_mood == &"" and not Voices.has_mood(mood):
				found.append("%s (%s): \"%s\" is in the mood %s, which has no voice (%s%s.tres)." % [errand.file, c.id, line.text.left(40), mood, MOODS_DIR, mood])
			if line.look != &"" and not DialogueLine.LOOKS.has(line.look):
				found.append("%s (%s): \"%s\" has the look %s, which is not %s." % [errand.file, c.id, line.text.left(40), line.look, " or ".join(PackedStringArray(DialogueLine.LOOKS.keys()))])
			elif line.look != &"" and (line.leaving or c.trigger == Conversation.Trigger.PHONE):
				found.append("%s (%s): \"%s\" has the look %s, which turns the view only before a line in the dialogue box, not on a [leaving] line or the phone." % [errand.file, c.id, line.text.left(40), line.look])
	var arrives := errand.conversations.any(func(c: Conversation) -> bool: return c.trigger == Conversation.Trigger.ARRIVE)
	if not arrives and not (errand.brings == Errand.Brings.NOTHING and lines == 0):
		found.append("%s has no drop-off conversation." % errand.file)
	var problem := errand.problem
	if problem != null and not problem.resource_path.ends_with(".tres"):
		found.append("%s names the problem %s, which has no repair mechanics: no %s%s.tres." % [errand.file, problem.short_name, StoryFormat.PROBLEMS_DIR, problem.short_name])
	elif problem != null and not problem.has_repair_mechanics():
		found.append("%s names the problem %s, which has no repair mechanics: no broken_part, software_check, blocker, missing_part, misplaced, stand_ins or empty_case." % [errand.file, problem.resource_path])


static func _check_choices(reply: Reply, where: String, found: PackedStringArray) -> void:
	for choice: Choice in reply.choices:
		var asked := "%s > \"%s\"" % [where.trim_suffix(")"), choice.text.left(30)] + ")"
		for answer: Reply in choice.replies:
			if answer.lines.is_empty() and answer.choices.is_empty() and choice.returns:
				found.append("%s: the + choice has no lines, so its list shows again at once." % asked)
			_check_choices(answer, asked, found)
	if reply.then != null:
		_check_choices(reply.then, where, found)


# Lists each leaving line in the block of [param reply] that a line or a list of choices can follow;
# [param more] is true when one can follow the block.
static func _check_leaving(reply: Reply, more: bool, where: String, found: PackedStringArray) -> void:
	var below := _shows(reply.then, more) if reply.then != null else more
	var after_lines := not reply.choices.is_empty() or below
	for i: int in reply.lines.size():
		var line := reply.lines[i]
		if not line.leaving:
			continue
		var line_follows := reply.lines.slice(i + 1).any(func(l: DialogueLine) -> bool: return not l.leaving)
		if line_follows or after_lines:
			found.append("%s: \"%s\" is [leaving], but the conversation can go on after it, so it plays in the dialogue box." % [where, line.text.left(40)])
	for choice: Choice in reply.choices:
		var asked := "%s > \"%s\"" % [where.trim_suffix(")"), choice.text.left(30)] + ")"
		var after := false if choice.ends else (true if choice.returns else below)
		for answer: Reply in choice.replies:
			_check_leaving(answer, after, asked, found)
	if reply.then != null:
		_check_leaving(reply.then, more, where, found)


# True when the block of [param reply] shows a line in the box or a list of choices; [param more]
# says whether one can follow it.
static func _shows(reply: Reply, more: bool) -> bool:
	if not reply.choices.is_empty() or reply.lines.any(func(l: DialogueLine) -> bool: return not l.leaving):
		return true
	return _shows(reply.then, more) if reply.then != null else more


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
