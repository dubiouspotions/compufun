class_name StorySignStarts
## Edits of the story files that start a corruption sign (its flag sign_<id>) in a day or in an
## errand's conversation, for the week board's sign chips. Each takes a file's text and returns
## it changed; the rest of the text stays as it was.


## The day file [param text] (at [param path]) with the sign [param id] started at [param key]
## ("on start" or "on close": sign_<id> set to [param value]; "close signs": the id listed), or
## with [param add] false without that start. Returns {"text"}, or {"error"} when the day doesn't
## parse or the key is unknown.
static func day_edit(text: String, path: String, key: String, id: StringName, value: int, add: bool) -> Dictionary:
	var parsed := StoryFormat.parse_day(text, path)
	if not parsed.errors.is_empty():
		return {"error": "%s doesn't parse: %s" % [path, parsed.errors[0]]}
	var day := parsed.value as Day
	var flag := StringName("sign_" + id)
	match key:
		"on start", "on close":
			var flags := day.set_flags if key == "on start" else day.close_flags
			if add:
				flags[flag] = value
			elif flags.get(flag, -1) == value:
				flags.erase(flag)
		"close signs":
			if add and id not in day.close_signs:
				day.close_signs.append(id)
			elif not add:
				day.close_signs.erase(id)
		_:
			return {"error": "%s: a sign starts at on start, on close or close signs, not '%s'" % [path, key]}
	return {"text": StoryFormat.write_day(day)}


## The errand file [param text] with its first drop-off setting sign_<id> to [param value] as it
## starts: on the conversation's first set line, or a new one under its header (and brief). An
## errand without a drop-off gets one.
static func with_drop_off_set(text: String, id: StringName, value: int) -> String:
	var term := _term(id, value)
	var lines := text.split("\n")
	for i: int in lines.size():
		if not _trigger_of(lines[i]) == "drop-off":
			continue
		var at := i + 1
		if at < lines.size() and lines[at].begins_with("brief:"):
			at += 1
		if at < lines.size() and lines[at].begins_with("set "):
			var terms := _terms(lines[at])
			terms[StringName("sign_" + id)] = value
			lines[at] = "set " + StoryFormat.write_flags(terms)
		else:
			lines.insert(at, "set " + term)
		return "\n".join(lines)
	return text.strip_edges(false, true) + "\n\n== drop-off\nset %s\n" % term


## The errand file [param text] without the sets of sign_<id> to [param value] in the conversation
## [param conversation] (an id such as "0303/drop-off/1": the first drop-off; text after " > " is
## left out). A set line that sets nothing else goes, and so does a conversation left with nothing
## but its "==" line.
static func without_set(text: String, conversation: String, id: StringName, value: int) -> String:
	var head := conversation.get_slice(" > ", 0)
	var trigger := head.get_slice("/", 1)
	var number := head.get_slice("/", 2).to_int()
	var flag := StringName("sign_" + id)
	var lines := Array(text.split("\n"))
	var seen := 0
	var inside := false
	var header := -1
	var i := 0
	while i < lines.size():
		var line: String = lines[i]
		var section := _trigger_of(line)
		if section != "":
			if section == trigger:
				seen += 1
			inside = section == trigger and seen == number
			if inside:
				header = i
		elif inside and line.strip_edges().begins_with("set "):
			var terms := _terms(line)
			if terms.get(flag, -1) == value:
				terms.erase(flag)
				if terms.is_empty():
					lines.remove_at(i)
					continue
				lines[i] = line.substr(0, line.find("set ")) + "set " + StoryFormat.write_flags(terms)
		i += 1
	if header >= 0 and lines[header] == "== " + trigger:
		var end := header + 1
		while end < lines.size() and String(lines[end]).strip_edges() == "":
			end += 1
		if end == lines.size() or _trigger_of(lines[end]) != "":
			while header > 0 and String(lines[header - 1]).strip_edges() == "":
				header -= 1
			for gone: int in end - header:
				lines.remove_at(header)
			lines.insert(header, "")
	return "\n".join(PackedStringArray(lines))


# The trigger of a conversation's "==" line, such as "drop-off"; "" for any other line.
static func _trigger_of(line: String) -> String:
	return line.trim_prefix("==").strip_edges().get_slice(" ", 0) if line.begins_with("==") else ""


# The flags of a "set" line: name to number.
static func _terms(line: String) -> Dictionary[StringName, int]:
	var terms: Dictionary[StringName, int] = {}
	for term: String in line.strip_edges().trim_prefix("set ").split(","):
		var name := term.get_slice("=", 0).strip_edges()
		if name != "":
			terms[StringName(name)] = term.get_slice("=", 1).strip_edges().to_int() if term.contains("=") else 1
	return terms


static func _term(id: StringName, value: int) -> String:
	return "sign_%s" % id if value == 1 else "sign_%s=%d" % [id, value]
