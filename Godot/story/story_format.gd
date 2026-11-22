class_name StoryFormat
extends RefCounted
## Reads and writes the story files: a day (.day) and an errand (.errand). The format is in
## docs/dialogue.md. Writing a parsed file gives the same text when the file is in the written
## layout, so the Story Lab can edit the text and the graph of one file.

## The result of a parse: the resource, and one "path:line: what" per problem. The resource holds
## what parsed; a file with errors must not play.
class Parsed:
	extends RefCounted
	var value: Resource
	var errors: PackedStringArray = []

const TRIGGERS: Dictionary[String, Conversation.Trigger] = {
	"drop-off": Conversation.Trigger.ARRIVE,
	"pick-up": Conversation.Trigger.PICKUP,
	"phone": Conversation.Trigger.PHONE,
}
const BRINGS: Dictionary[String, Errand.Brings] = {
	"leaves": Errand.Brings.LEAVES,
	"none": Errand.Brings.NOTHING,
	"shows": Errand.Brings.SHOWS,
}
const CUSTOMERS_DIR: String = "res://customers/"
const PROBLEMS_DIR: String = "res://problems/"
const EFFECTS_DIR: String = "res://voices/effects/"
const _DEFAULT_FIRST_WAIT: Vector2 = Vector2(5.0, 8.0)
const _DEFAULT_GAP: Vector2 = Vector2(20.0, 40.0)


## The errand in [param text], read from [param path], whose file name gives its errand code.
static func parse_errand(text: String, path: String) -> Parsed:
	return _Reader.new(text, path).errand()


## The day in [param text], read from [param path] (story/days/day_<n>.day).
static func parse_day(text: String, path: String) -> Parsed:
	return _Reader.new(text, path).day()


## The story file of [param errand].
static func write_errand(errand: Errand) -> String:
	var out := PackedStringArray()
	out.append("customer: " + _stem(errand.customer))
	if errand.problem != null:
		out.append("problem: " + _stem(errand.problem))
	if errand.brings != Errand.Brings.LEAVES:
		out.append("computer: " + BRINGS.find_key(errand.brings))
	if errand.when != null:
		out.append("when: " + write_condition(errand.when))
	_write_text_block(out, "brief", errand.brief)
	for c: Conversation in errand.conversations:
		out.append("")
		var head: String = "== " + TRIGGERS.find_key(c.trigger)
		if c.when != null:
			head += " [if %s]" % write_condition(c.when)
		if c.once:
			head += " [once]"
		if c.effect != null:
			head += " [effect %s]" % _stem(c.effect)
		if c.leave_text != Conversation.new().leave_text:
			head += " [leave %s]" % c.leave_text
		if c.back_text != Conversation.new().back_text:
			head += " [back %s]" % c.back_text
		out.append(head)
		if c.brief != "":
			out.append("brief: " + c.brief)
		_write_block(out, c, 0)
	return "\n".join(out) + "\n"


## The story file of [param day].
static func write_day(day: Day) -> String:
	var out := PackedStringArray()
	out.append("weather: " + ("rain" if day.rain else "clear"))
	out.append("warp: " + _number(day.warp))
	if not day.set_flags.is_empty():
		out.append("on start: " + write_flags(day.set_flags))
	if not day.close_flags.is_empty():
		out.append("on close: " + write_flags(day.close_flags))
	if not day.close_signs.is_empty():
		out.append("close signs: " + ", ".join(PackedStringArray(day.close_signs)))
	if day.first_wait_seconds != _DEFAULT_FIRST_WAIT:
		out.append("first customer: " + _range(day.first_wait_seconds))
	if day.gap_seconds != _DEFAULT_GAP:
		out.append("between customers: " + _range(day.gap_seconds))
	_write_text_block(out, "notes", day.notes)
	return "\n".join(out) + "\n"


## [param when] as a story file writes it: needed flags, then "not" flags, then the days.
static func write_condition(when: Condition) -> String:
	var terms := PackedStringArray()
	for flag: StringName in when.need_flags:
		terms.append(flag)
	for flag: StringName in when.not_flags:
		terms.append("not " + flag)
	if when.from_day == when.to_day:
		terms.append("day %d" % when.from_day)
	elif when.from_day != 1 or when.to_day != 7:
		terms.append("days %d-%d" % [when.from_day, when.to_day])
	return ", ".join(terms)


## [param flags] as a story file writes them: "a, b=2, c=0".
static func write_flags(flags: Dictionary[StringName, int]) -> String:
	var terms := PackedStringArray()
	for flag: StringName in flags:
		terms.append(flag if flags[flag] == 1 else "%s=%d" % [flag, flags[flag]])
	return ", ".join(terms)


static func _write_block(out: PackedStringArray, reply: Reply, depth: int) -> void:
	var tabs := "\t".repeat(depth)
	if not reply.set_flags.is_empty():
		out.append(tabs + "set " + write_flags(reply.set_flags))
	for line: DialogueLine in reply.lines:
		var said: String = "%s(%s) %s" % [tabs, line.pose, line.text]
		if line.effect != null:
			said += " [effect %s]" % _stem(line.effect)
		out.append(said)
	for choice: Choice in reply.choices:
		var said: String = "%s%s %s" % [tabs, "+" if choice.returns else "-", choice.text]
		if choice.when != null:
			said += " [if %s]" % write_condition(choice.when)
		if choice.ends:
			said += " [end]"
		out.append(said)
		if choice.replies.size() == 1 and choice.replies[0].when == null:
			_write_block(out, choice.replies[0], depth + 1)
			continue
		for answer: Reply in choice.replies:
			out.append(tabs + "\t" + ("if " + write_condition(answer.when) if answer.when != null else "else"))
			_write_block(out, answer, depth + 2)
	if reply.then != null:
		var starts_with_choice := reply.then.set_flags.is_empty() and reply.then.lines.is_empty()
		if starts_with_choice and not reply.choices.is_empty():
			out.append("")
		_write_block(out, reply.then, depth)


static func _write_text_block(out: PackedStringArray, key: String, text: String) -> void:
	if text == "":
		return
	out.append(key + ":")
	for line: String in text.split("\n"):
		out.append("\t" + line)


static func _stem(resource: Resource) -> String:
	return resource.resource_path.get_file().get_basename() if resource != null else ""


static func _number(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else str(snappedf(value, 0.001))


static func _range(seconds: Vector2) -> String:
	return "%s-%s" % [_number(seconds.x), _number(seconds.y)]


# One parse of one file: its lines, where it is, and the errors so far.
class _Reader:
	extends RefCounted

	enum Kind { LINE, CHOICE, SET, IF, ELSE }

	var _path: String
	var _lines: PackedStringArray
	var _errors: PackedStringArray = []
	# The tokens of the conversation being read: {depth, kind, text, line, gap}; gap is an empty
	# line before it.
	var _tokens: Array[Dictionary] = []
	var _at: int = 0

	func _init(text: String, path: String) -> void:
		_path = path
		_lines = text.replace("\r\n", "\n").split("\n")

	func errand() -> Parsed:
		var result := Parsed.new()
		var errand := Errand.new()
		result.value = errand
		var stem := _path.get_file().get_basename()
		if RegEx.create_from_string("^[0-7][0-9][0-9][0-9]_[a-z0-9_]+$").search(stem) == null:
			_error(0, "the file name must be <errand code>_<name>, such as 0101_skater_bro, not '%s'" % stem)
		else:
			errand.code = stem.substr(0, 4)
			if errand.day_number() < 1 or errand.day_number() > 7 or errand.place() < 1:
				_error(0, "errand code %s: the day must be 01 to 07 and the place 01 or more" % errand.code)
		var sections := _section_starts()
		var header_end: int = sections[0] if not sections.is_empty() else _lines.size()
		var fields := _read_fields(0, header_end, ["customer", "problem", "computer", "when", "brief"])
		if not fields.has("customer"):
			_error(0, "no 'customer:'")
		else:
			errand.customer = _load(CUSTOMERS_DIR, fields.customer, fields.customer_line, "customer") as Customer
		if fields.has("problem"):
			errand.problem = _load(PROBLEMS_DIR, fields.problem, fields.problem_line, "problem") as Problem
		if fields.has("computer"):
			if BRINGS.has(fields.computer):
				errand.brings = BRINGS[fields.computer]
			else:
				_error(fields.computer_line, "computer: '%s' is not leaves, none or shows" % fields.computer)
		if fields.has("when"):
			errand.when = _condition(fields.when, fields.when_line)
		errand.brief = fields.get("brief", "")
		var counts: Dictionary[String, int] = {}
		for i: int in sections.size():
			var end: int = sections[i + 1] if i + 1 < sections.size() else _lines.size()
			var c := _conversation(sections[i], end)
			if c == null:
				continue
			var name: String = TRIGGERS.find_key(c.trigger)
			counts[name] = counts.get(name, 0) + 1
			c.id = StringName("%s/%s/%d" % [errand.code, name, counts[name]])
			errand.conversations.append(c)
		result.errors = _sorted_errors()
		return result

	func day() -> Parsed:
		var result := Parsed.new()
		var d := Day.new()
		result.value = d
		var stem := _path.get_file().get_basename()
		if not stem.begins_with("day_") or not stem.substr(4).is_valid_int() or stem.substr(4).to_int() < 1 or stem.substr(4).to_int() > 7:
			_error(0, "the file name must be day_1 to day_7, not '%s'" % stem)
		else:
			d.number = stem.substr(4).to_int()
		var keys := ["weather", "warp", "on start", "on close", "close signs", "first customer", "between customers", "notes"]
		var fields := _read_fields(0, _lines.size(), keys)
		if fields.has("weather"):
			if fields.weather in ["clear", "rain"]:
				d.rain = fields.weather == "rain"
			else:
				_error(fields.weather_line, "weather: '%s' is not clear or rain" % fields.weather)
		if fields.has("warp"):
			if fields.warp.is_valid_float() and fields.warp.to_float() >= 0.0 and fields.warp.to_float() <= 1.0:
				d.warp = fields.warp.to_float()
			else:
				_error(fields.warp_line, "warp: '%s' is not a number from 0 to 1" % fields.warp)
		if fields.has("on start"):
			d.set_flags = _flags(fields["on start"], fields["on start_line"])
		if fields.has("on close"):
			d.close_flags = _flags(fields["on close"], fields["on close_line"])
		if fields.has("close signs"):
			for id: String in _terms(fields["close signs"]):
				if _is_name(id):
					d.close_signs.append(StringName(id))
				else:
					_error(fields["close signs_line"], "close signs: '%s' is not a sign id" % id)
		if fields.has("first customer"):
			d.first_wait_seconds = _seconds(fields["first customer"], fields["first customer_line"])
		if fields.has("between customers"):
			d.gap_seconds = _seconds(fields["between customers"], fields["between customers_line"])
		d.notes = fields.get("notes", "")
		result.errors = _sorted_errors()
		return result

	# The line indices of the "==" lines.
	func _section_starts() -> Array[int]:
		var found: Array[int] = []
		for i: int in _lines.size():
			if _lines[i].begins_with("=="):
				found.append(i)
		return found

	# Reads "key: value" lines from [param from] to [param to]: key to value, and key_line to its
	# line index. A key with an empty value takes the tab-indented lines under it as its text.
	func _read_fields(from: int, to: int, keys: Array) -> Dictionary:
		var fields := {}
		var i := from
		while i < to:
			var raw := _lines[i]
			if raw.strip_edges() == "":
				i += 1
				continue
			if raw.begins_with("\t") or raw.begins_with(" "):
				_error(i, "an indented line without a key above it")
				i += 1
				continue
			var colon := raw.find(":")
			var key := raw.substr(0, colon).strip_edges() if colon > 0 else ""
			if key not in keys:
				_error(i, "'%s' is not a key here; the keys are %s" % [raw.strip_edges(), ", ".join(PackedStringArray(keys))])
				i += 1
				continue
			if fields.has(key):
				_error(i, "'%s:' a second time" % key)
			var value := raw.substr(colon + 1).strip_edges()
			fields[key + "_line"] = i
			i += 1
			if value == "":
				var text := PackedStringArray()
				while i < to and (_lines[i].begins_with("\t") or _lines[i].strip_edges() == ""):
					text.append(_lines[i].substr(1) if _lines[i].begins_with("\t") else "")
					i += 1
				while not text.is_empty() and text[text.size() - 1] == "":
					text.remove_at(text.size() - 1)
				value = "\n".join(text)
			fields[key] = value
		return fields

	func _conversation(from: int, to: int) -> Conversation:
		var head := _lines[from].substr(2).strip_edges()
		var tags := _split_tags(head)
		var name: String = tags.text
		if not TRIGGERS.has(name):
			_error(from, "'== %s': the trigger must be drop-off, pick-up or phone" % name)
			return null
		var c := Conversation.new()
		c.trigger = TRIGGERS[name]
		for tag: String in tags.tags:
			if tag.begins_with("if "):
				c.when = _condition(tag.substr(3), from)
			elif tag == "once":
				c.once = true
			elif tag.begins_with("effect "):
				c.effect = _load(EFFECTS_DIR, tag.substr(7).strip_edges(), from, "voice effect") as VoiceEffect
			elif tag.begins_with("leave "):
				c.leave_text = tag.substr(6).strip_edges()
			elif tag.begins_with("back "):
				c.back_text = tag.substr(5).strip_edges()
			else:
				_error(from, "[%s] is not a tag of a conversation: if, once, effect, leave or back" % tag)
		var body := from + 1
		while body < to and _lines[body].strip_edges() == "":
			body += 1
		if body < to and _lines[body].begins_with("brief:"):
			c.brief = _lines[body].substr(6).strip_edges()
			body += 1
		_tokenize(body, to)
		_block(0, c)
		return c

	func _tokenize(from: int, to: int) -> void:
		_tokens.clear()
		_at = 0
		var gap := false
		for i: int in range(from, to):
			var raw := _lines[i]
			if raw.strip_edges() == "":
				gap = true
				continue
			var depth := 0
			while depth < raw.length() and raw[depth] == "\t":
				depth += 1
			var text := raw.substr(depth).strip_edges(false, true)
			if text.begins_with(" "):
				_error(i, "indented with spaces; indent with tabs")
				text = text.strip_edges()
			var kind := Kind.LINE
			if text.begins_with("- ") or text.begins_with("+ "):
				kind = Kind.CHOICE
			elif text.begins_with("set "):
				kind = Kind.SET
			elif text.begins_with("if "):
				kind = Kind.IF
			elif text == "else":
				kind = Kind.ELSE
			_tokens.append({depth = depth, kind = kind, text = text, line = i, gap = gap})
			gap = false

	func _peek() -> Dictionary:
		return _tokens[_at] if _at < _tokens.size() else {}

	# Reads the block at [param depth] into [param into]: its flags and lines, its list of choices,
	# and what follows the list as [member Reply.then].
	func _block(depth: int, into: Reply) -> void:
		while _at < _tokens.size():
			var token := _peek()
			if token.depth < depth:
				return
			if token.depth > depth:
				_error(token.line, "indented deeper than the line above it")
				_at += 1
				continue
			match token.kind:
				Kind.SET:
					into.set_flags.merge(_flags(token.text.substr(4), token.line), true)
					_at += 1
				Kind.LINE:
					into.lines.append(_said(token))
					_at += 1
				Kind.IF, Kind.ELSE:
					_error(token.line, "'%s' must start the lines under a choice" % token.text)
					_at += 1
				Kind.CHOICE:
					into.choices.append(_choice(depth))
					while not _peek().is_empty() and _peek().depth == depth and _peek().kind == Kind.CHOICE and not _peek().gap:
						into.choices.append(_choice(depth))
					if not _peek().is_empty() and _peek().depth == depth:
						into.then = Reply.new()
						_block(depth, into.then)
					return

	func _choice(depth: int) -> Choice:
		var token := _peek()
		_at += 1
		var choice := Choice.new()
		choice.returns = token.text.begins_with("+")
		var tags := _split_tags(token.text.substr(2).strip_edges())
		choice.text = tags.text
		for tag: String in tags.tags:
			if tag.begins_with("if "):
				choice.when = _condition(tag.substr(3), token.line)
			elif tag == "end":
				choice.ends = true
			else:
				_error(token.line, "[%s] is not a tag of a choice: if or end" % tag)
		var next := _peek()
		if next.is_empty() or next.depth <= depth:
			choice.replies.append(Reply.new())
			return choice
		if next.depth == depth + 1 and next.kind in [Kind.IF, Kind.ELSE]:
			var after_else := false
			while not _peek().is_empty() and _peek().depth == depth + 1 and _peek().kind in [Kind.IF, Kind.ELSE]:
				var branch := _peek()
				_at += 1
				if after_else:
					_error(branch.line, "'%s' after 'else' never plays" % branch.text)
				var answer := Reply.new()
				if branch.kind == Kind.IF:
					answer.when = _condition(branch.text.substr(3), branch.line)
				else:
					after_else = true
				_block(depth + 2, answer)
				choice.replies.append(answer)
			if not _peek().is_empty() and _peek().depth == depth + 1:
				_error(_peek().line, "after 'if' and 'else', a line belongs under one of them")
				_block(depth + 1, Reply.new())
			return choice
		var answer := Reply.new()
		_block(depth + 1, answer)
		choice.replies.append(answer)
		return choice

	func _said(token: Dictionary) -> DialogueLine:
		var line := DialogueLine.new()
		var text: String = token.text
		var mood := RegEx.create_from_string("^\\(([a-z0-9_]+)\\)\\s*").search(text)
		if mood != null:
			line.pose = StringName(mood.get_string(1))
			text = text.substr(mood.get_end())
		var effect := RegEx.create_from_string("\\s*\\[effect ([a-z0-9_]+)\\]$").search(text)
		if effect != null:
			line.effect = _load(EFFECTS_DIR, effect.get_string(1), token.line, "voice effect") as VoiceEffect
			text = text.substr(0, effect.get_start())
		line.text = text
		if text == "":
			_error(token.line, "a line without text")
		return line

	# Splits trailing "[...]" tags off [param text]: {text, tags} with the tags in written order.
	func _split_tags(text: String) -> Dictionary:
		var tags := PackedStringArray()
		var tag := RegEx.create_from_string("\\s*\\[([^\\[\\]]*)\\]$")
		var found := tag.search(text)
		while found != null:
			tags.insert(0, found.get_string(1).strip_edges())
			text = text.substr(0, found.get_start())
			found = tag.search(text)
		return {text = text.strip_edges(), tags = tags}

	func _condition(text: String, line: int) -> Condition:
		var when := Condition.new()
		for term: String in _terms(text):
			var days := RegEx.create_from_string("^days? ([1-7])(?:-([1-7]))?$").search(term)
			if days != null:
				when.from_day = days.get_string(1).to_int()
				when.to_day = days.get_string(2).to_int() if days.get_string(2) != "" else when.from_day
				if when.to_day < when.from_day:
					_error(line, "'%s': the days run backwards" % term)
			elif term.begins_with("not ") and _is_name(term.substr(4)):
				when.not_flags.append(StringName(term.substr(4)))
			elif _is_name(term):
				when.need_flags.append(StringName(term))
			else:
				_error(line, "'%s' is not a condition: a flag, not flag, day 3 or days 2-4" % term)
		return when

	func _flags(text: String, line: int) -> Dictionary[StringName, int]:
		var flags: Dictionary[StringName, int] = {}
		for term: String in _terms(text):
			var parts := term.split("=")
			var value := 1
			if parts.size() == 2 and parts[1].strip_edges().is_valid_int():
				value = parts[1].strip_edges().to_int()
			elif parts.size() != 1:
				_error(line, "'%s' is not a flag: name, or name=number" % term)
				continue
			var name := parts[0].strip_edges()
			if not _is_name(name):
				_error(line, "'%s' is not a flag name: lower case, digits and _" % name)
				continue
			flags[StringName(name)] = value
		return flags

	func _seconds(text: String, line: int) -> Vector2:
		var parts := text.split("-")
		if parts.size() == 2 and parts[0].strip_edges().is_valid_float() and parts[1].strip_edges().is_valid_float():
			return Vector2(parts[0].to_float(), parts[1].to_float())
		_error(line, "'%s' is not seconds from-to, such as 20-40" % text)
		return Vector2.ZERO

	func _terms(text: String) -> PackedStringArray:
		var terms := PackedStringArray()
		for term: String in text.split(","):
			if term.strip_edges() != "":
				terms.append(term.strip_edges())
		return terms

	func _is_name(text: String) -> bool:
		return RegEx.create_from_string("^[a-z0-9_]+$").search(text) != null

	func _load(dir: String, name: String, line: int, what: String) -> Resource:
		var path := dir + name + ".tres"
		if not _is_name(name) or not ResourceLoader.exists(path):
			_error(line, "no %s '%s' (%s)" % [what, name, path])
			return null
		var resource := load(path)
		if resource == null:
			_error(line, "the %s %s doesn't load" % [what, path])
		return resource

	func _error(line: int, what: String) -> void:
		_errors.append("%s:%d: %s" % [_path, line + 1, what])

	# The errors from the top of the file down; a sort that keeps the order of one line's errors.
	func _sorted_errors() -> PackedStringArray:
		var keyed: Array = []
		for i: int in _errors.size():
			keyed.append([_errors[i].trim_prefix(_path + ":").get_slice(":", 0).to_int(), i, _errors[i]])
		keyed.sort()
		var sorted := PackedStringArray()
		for each: Array in keyed:
			sorted.append(each[2])
		return sorted
