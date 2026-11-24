class_name SetupPatch
extends Resource
## What a customer did on their computer: changes to its running Win95 setup (Win95Setup), read from
## and written to a .setup story file (docs/dialogue.md). A patch says what must be so, not a step,
## so it never fails on what the player did: a file to delete that is gone stays gone, and a file
## to put in a folder that is gone brings the folder back.

const DIR: String = "res://story/computers/"
const EXTENSION: String = ".setup"
## The tops of a path, as in "C:\My Documents\letter.txt", "Desktop\todo.txt", "Recycled\old.txt".
const TOPS: PackedStringArray = ["Desktop", "C:", "Recycled"]
# The Win95Setup fields that a patch changes file by file and mail by mail.
const _TREES: Array[StringName] = [&"desktop", &"drive_c", &"recycle_bin", &"emails"]
const _FILE_SKIP: Array[StringName] = [&"name", &"children", &"is_folder"]
const _MAIL_KEY: Array[StringName] = [&"sent", &"subject"]

## Throws away the running copy first, for the setup of the Customer file and its start patch.
@export var reset: bool = false
## The Win95Setup settings to set, by property.
@export var settings: Dictionary[StringName, Variant] = {}
## The paths of the files and folders to delete; a folder goes with what is in it.
@export var deleted: PackedStringArray = []
## The files and folders to put, by path, parents first, each as it must be (its children aside).
## A file of that name that is there takes the fields; one that isn't is added at the end.
@export var files: Dictionary[String, Win95File] = {}
## The mails to delete: only their sent and subject count.
@export var unmailed: Array[Email] = []
## The mails to put, in order; each takes the place of the mail with its sent and subject, or comes
## last.
@export var mails: Array[Email] = []


## The name of the patch file of [param errand]: its file name, such as "0403_skater_bro".
static func errand_name(errand: Errand) -> String:
	return errand.file_name()


## The name of the start patch of [param customer]: its file name, such as "skater_bro".
static func customer_name(customer: Customer) -> String:
	return customer.resource_path.get_file().get_basename()


## A new running copy of [param customer]'s setup, with its start patch from [param patches] (by
## file name) on it; null for a customer whose computer has no Win95 setup.
static func start(customer: Customer, patches: Dictionary[String, SetupPatch]) -> Win95Setup:
	if customer.computer == null or customer.computer.win95_setup == null:
		return null
	var setup := customer.computer.win95_setup.copy()
	var patch: SetupPatch = patches.get(customer_name(customer))
	if patch != null:
		patch.apply(setup)
	return setup


## Puts on [param setup], once each and by errand code, the patches of [param customer]'s errands in
## [param errands] up to [param upto]: before it, or also its own with [param including]. A patch
## that resets starts again from [method start].
static func catch_up(setup: Win95Setup, customer: Customer, upto: Errand, including: bool, errands: Array[Errand], patches: Dictionary[String, SetupPatch]) -> void:
	if upto == null or upto.code == "":
		return
	var theirs := errands.filter(func(e: Errand) -> bool:
		return e.customer == customer and e.code != "" and (e.code < upto.code or including and e.code == upto.code))
	theirs.sort_custom(func(a: Errand, b: Errand) -> bool: return a.code < b.code)
	var done := PackedStringArray()
	for errand: Errand in theirs:
		var patch_name := errand_name(errand)
		done.append(patch_name)
		if patch_name in setup.patched:
			continue
		var patch: SetupPatch = patches.get(patch_name)
		if patch != null:
			if patch.reset:
				setup.take(start(customer, patches))
				setup.patched = done.slice(0, -1)
			patch.apply(setup)
		setup.patched.append(patch_name)


## [param customer]'s computer as it comes on the visit of [param errand], with that visit's patch,
## or before it, as the patch's editor starts from: for null, at the start of the game with or
## without the start patch. A patch that resets starts from [method start]. Null without a setup.
static func arriving(customer: Customer, errand: Errand, with_patch: bool, errands: Array[Errand], patches: Dictionary[String, SetupPatch]) -> Win95Setup:
	if customer.computer == null or customer.computer.win95_setup == null:
		return null
	if errand == null:
		return start(customer, patches) if with_patch else customer.computer.win95_setup.copy()
	var own: SetupPatch = patches.get(errand_name(errand))
	if not with_patch and own != null and own.reset:
		return start(customer, patches)
	var setup := start(customer, patches)
	catch_up(setup, customer, errand, with_patch, errands, patches)
	return setup


## True when the patch changes nothing.
func is_empty() -> bool:
	return not reset and settings.is_empty() and deleted.is_empty() and files.is_empty() and unmailed.is_empty() and mails.is_empty()


## Changes [param setup] as the patch says. [member reset] is [method catch_up]'s to do.
func apply(setup: Win95Setup) -> void:
	for property: StringName in settings:
		setup.set(property, settings[property])
	for path: String in deleted:
		var container: Variant = _container(setup, path, false)
		if container != null:
			var file := _named(container, path.get_file())
			if file != null:
				container.erase(file)
	for path: String in files:
		var container: Array = _container(setup, path, true)
		var file := _named(container, _leaf(path))
		if file == null:
			file = Win95File.new()
			file.name = _leaf(path)
			container.append(file)
		_take_fields(file, files[path])
		file.is_folder = files[path].is_folder
	var gone := unmailed.map(_mail_key)
	setup.emails.assign(setup.emails.filter(func(e: Email) -> bool: return _mail_key(e) not in gone))
	var keys := setup.emails.map(_mail_key)
	for mail: Email in mails:
		var at := keys.find(_mail_key(mail))
		if at >= 0:
			setup.emails[at] = mail.duplicate()
		else:
			setup.emails.append(mail.duplicate())


## The patch that makes [param before] into [param after], or a String that says why there is
## none, naming the file, mail or setting: a picture that no res:// file holds, two files of one name.
static func between(before: Win95Setup, after: Win95Setup) -> Variant:
	var patch := SetupPatch.new()
	for property: Dictionary in _fields(after, _TREES):
		var name: StringName = property.name
		if before.get(name) == after.get(name):
			continue
		var text: Variant = _encode(after.get(name), property)
		if text == null:
			return "the setting %s is %s, which no res:// file holds" % [name, after.get(name)]
		if text != _encode(before.get(name), property):
			patch.settings[name] = after.get(name)
	var old: Variant = _flatten(before)
	var new: Variant = _flatten(after)
	for flat: Variant in [old, new]:
		if flat is String:
			return flat
	for key: String in old:
		if not new.has(key) and not (old.has(_parent_key(key)) and not new.has(_parent_key(key))):
			patch.deleted.append(old[key][0])
	for key: String in new:
		var file: Win95File = new[key][1]
		var text: Variant = _fields_text(file, _FILE_SKIP)
		if text is Array:
			return "%s: %s" % [new[key][0], text[0]]
		if not old.has(key) or old[key][1].is_folder != file.is_folder or _fields_text(old[key][1], _FILE_SKIP) != text:
			patch.files[new[key][0]] = file
	var old_mails: Variant = _mails_by_key(before)
	var new_mails: Variant = _mails_by_key(after)
	for by_key: Variant in [old_mails, new_mails]:
		if by_key is String:
			return by_key
	for key: String in old_mails:
		if not new_mails.has(key):
			patch.unmailed.append(old_mails[key])
	for key: String in new_mails:
		var text: Variant = _fields_text(new_mails[key], [])
		if text is Array:
			return "the mail '%s': %s" % [key, text[0]]
		if not old_mails.has(key) or _fields_text(old_mails[key], []) != text:
			patch.mails.append(new_mails[key])
	return patch


## The patch as its .setup file says it.
func write() -> String:
	var out := PackedStringArray()
	if reset:
		out.append("reset")
	for property: StringName in settings:
		var info := _property(Win95Setup.new(), property)
		out.append("set %s: %s" % [property, _encode(settings[property], info)])
	for path: String in deleted:
		out.append("delete " + path)
	for path: String in files:
		out.append("")
		out.append(("folder " if files[path].is_folder else "file ") + path)
		out.append_array(_fields_text(files[path], _FILE_SKIP))
	for mail: Email in unmailed:
		out.append("")
		out.append("unmail")
		out.append_array(_fields_text(mail, [], _MAIL_KEY))
	for mail: Email in mails:
		out.append("")
		out.append("mail")
		out.append_array(_fields_text(mail, []))
	return "\n".join(out).strip_edges(true, false) + "\n"


## The patch in [param text], read from [param path], with one "path:line: what" per error.
static func parse(text: String, path: String) -> StoryFormat.Parsed:
	var parsed := StoryFormat.Parsed.new()
	var patch := SetupPatch.new()
	parsed.value = patch
	var lines := text.split("\n")
	var i := 0
	while i < lines.size():
		var line := lines[i].strip_edges(false, true)
		var at := "%s:%d: " % [path, i + 1]
		i += 1
		if line == "" or line.begins_with("#"):
			continue
		if line.begins_with("\t"):
			parsed.errors.append(at + "an indented line with no 'file', 'folder', 'mail' or 'unmail' above it")
			continue
		var word := line.get_slice(" ", 0)
		var rest := line.substr(word.length() + 1)
		match word:
			"reset":
				if not patch.is_empty():
					parsed.errors.append(at + "'reset' comes first, before every change")
				patch.reset = true
			"set":
				var setting := StringName(rest.get_slice(":", 0))
				var info := _property(Win95Setup.new(), setting)
				if info.is_empty() or setting in _TREES:
					parsed.errors.append(at + "Win95Setup has no setting '%s'" % setting)
					continue
				var value: Variant = _decode(rest.substr(String(setting).length() + 1).trim_prefix(" "), info, Win95Setup.new())
				if value is _Bad:
					parsed.errors.append(at + value.why)
				else:
					patch.settings[setting] = value
			"delete":
				var bad := _bad_path(rest)
				if bad != "":
					parsed.errors.append(at + bad)
				patch.deleted.append(rest)
			"file", "folder":
				var bad := _bad_path(rest)
				if bad != "":
					parsed.errors.append(at + bad)
				var file := Win95File.new()
				file.is_folder = word == "folder"
				file.name = _leaf(rest)
				i = _read_fields(lines, i, file, _FILE_SKIP, path, parsed.errors)
				patch.files[rest] = file
			"mail", "unmail":
				var mail := Email.new()
				i = _read_fields(lines, i, mail, [] if word == "mail" else _fields(mail, _MAIL_KEY).map(func(p: Dictionary) -> StringName: return p.name), path, parsed.errors)
				(patch.mails if word == "mail" else patch.unmailed).append(mail)
			_:
				parsed.errors.append(at + "'%s' is not reset, set, delete, file, folder, mail or unmail" % word)
	return parsed


# Says why a field value can't be read.
class _Bad:
	extends RefCounted
	var why: String
	func _init(reason: String) -> void:
		why = reason


# Reads the "\tkey: value" lines (and "\tkey:" blocks of "\t\t" lines) from line [param from] into
# [param object]; returns the index of the first line after them.
static func _read_fields(lines: PackedStringArray, from: int, object: Object, skip: Array, path: String, errors: PackedStringArray) -> int:
	var i := from
	while i < lines.size() and lines[i].begins_with("\t") and not lines[i].begins_with("\t\t"):
		var at := "%s:%d: " % [path, i + 1]
		var line := lines[i].substr(1).strip_edges(false, true)
		i += 1
		var key := StringName(line.get_slice(":", 0))
		var info := _property(object, key)
		if not line.contains(":") or info.is_empty() or key in skip:
			var names := _fields(object, skip).map(func(p: Dictionary) -> String: return p.name)
			errors.append(at + "'%s' is not one of %s" % [line.get_slice(":", 0), ", ".join(names)])
			continue
		var value_text := line.substr(String(key).length() + 1).trim_prefix(" ")
		if value_text == "":
			var block := PackedStringArray()
			while i < lines.size() and (lines[i].begins_with("\t\t") or lines[i].strip_edges() == "" and _block_goes_on(lines, i)):
				block.append(lines[i].substr(2))
				i += 1
			value_text = "\n".join(block)
		var value: Variant = _decode(value_text, info, object)
		if value is _Bad:
			errors.append(at + value.why)
		else:
			object.set(key, value)
	return i


# True when a "\t\t" line follows the blank lines at [param i], so they belong to the block.
static func _block_goes_on(lines: PackedStringArray, i: int) -> bool:
	while i < lines.size() and lines[i].strip_edges() == "":
		i += 1
	return i < lines.size() and lines[i].begins_with("\t\t")


# The fields of [param object] that differ from a new one, as "\tkey: value" lines; a String
# value with a line break as a block. [code][why][/code] when a value can't be written.
static func _fields_text(object: Object, skip: Array, only: Array = []) -> Variant:
	var plain: Object = object.get_script().new()
	var out := PackedStringArray()
	for property: Dictionary in _fields(object, skip):
		var value: Variant = object.get(property.name)
		if not only.has(property.name) and (not only.is_empty() or value == plain.get(property.name)):
			continue
		var text: Variant = _encode(value, property)
		if text == null:
			return ["%s is %s, which no res:// file holds" % [property.name, value]]
		if (value is String or value is StringName) and String(value).contains("\n"):
			out.append("\t%s:" % property.name)
			for line: String in String(value).split("\n"):
				out.append("\t\t" + line)
		else:
			out.append("\t%s: %s" % [property.name, text])
	return out


# The stored script fields of [param object], without those in [param skip].
static func _fields(object: Object, skip: Array) -> Array[Dictionary]:
	var wanted := PROPERTY_USAGE_SCRIPT_VARIABLE | PROPERTY_USAGE_STORAGE
	return object.get_property_list().filter(func(p: Dictionary) -> bool:
		return p.usage & wanted == wanted and StringName(p.name) not in skip)


static func _property(object: Object, name: StringName) -> Dictionary:
	for property: Dictionary in _fields(object, []):
		if property.name == name:
			return property
	return {}


# [param value] as text, or null for a resource that no res:// file holds.
static func _encode(value: Variant, property: Dictionary) -> Variant:
	if property.hint == PROPERTY_HINT_ENUM and value is int:
		return property.hint_string.split(",")[value].get_slice(":", 0).to_lower()
	if value is String or value is StringName:
		return String(value)
	if value == null or value is Object:
		return _resource_path(value)
	if value is Array and (value as Array).get_typed_builtin() == TYPE_OBJECT:
		var paths := PackedStringArray()
		for item: Variant in value:
			var item_path: Variant = _resource_path(item)
			if item_path == null:
				return null
			paths.append(item_path)
		return ", ".join(paths)
	return var_to_str(value)


static func _resource_path(resource: Variant) -> Variant:
	if resource == null:
		return "none"
	var path: String = (resource as Resource).resource_path if resource is Resource else ""
	return path if path.begins_with("res://") and not path.contains("::") else null


# [param text] as the value of [param property] of [param object], or a _Bad.
static func _decode(text: String, property: Dictionary, object: Object) -> Variant:
	if property.hint == PROPERTY_HINT_ENUM and property.type == TYPE_INT:
		var names := Array(property.hint_string.split(",")).map(func(n: String) -> String: return n.get_slice(":", 0).to_lower())
		if text.to_lower() not in names:
			return _Bad.new("%s is one of %s, not '%s'" % [property.name, ", ".join(names), text])
		return names.find(text.to_lower())
	match property.type:
		TYPE_STRING:
			return text
		TYPE_STRING_NAME:
			return StringName(text)
		TYPE_OBJECT:
			return _load(text)
	var current: Variant = object.get(property.name)
	if current is Array and (current as Array).get_typed_builtin() == TYPE_OBJECT:
		var items: Array = (current as Array).duplicate()
		items.clear()
		for item_path: String in text.split(",", false):
			var item: Variant = _load(item_path.strip_edges())
			if item is _Bad or item == null:
				return item if item is _Bad else _Bad.new("%s lists none" % property.name)
			items.append(item)
		return items
	var value: Variant = str_to_var(text)
	if property.type == TYPE_FLOAT and value is int:
		return float(value)
	if typeof(value) != property.type:
		return _Bad.new("%s is a %s, not '%s'" % [property.name, type_string(property.type), text])
	return value


static func _load(path: String) -> Variant:
	if path == "none":
		return null
	if not path.begins_with("res://") or not ResourceLoader.exists(path):
		return _Bad.new("no file at '%s'" % path)
	var loaded := load(path)
	return loaded if loaded != null else _Bad.new("'%s' doesn't load" % path)


static func _bad_path(path: String) -> String:
	var top := path.get_slice("\\", 0)
	if not TOPS.has(top) or path.get_slice_count("\\") < 2 or path.ends_with("\\"):
		return "'%s' starts with none of %s, then a backslash and a name" % [path, ", ".join(TOPS)]
	return ""


static func _leaf(path: String) -> String:
	return path.get_slice("\\", path.get_slice_count("\\") - 1)


static func _parent_key(key: String) -> String:
	return key.left(key.rfind("\\"))


# The list that holds the file at [param path]: its folder's children, made with [param make] when
# missing; null when missing and not made.
static func _container(setup: Win95Setup, path: String, make: bool) -> Variant:
	var parts := path.split("\\")
	var container: Array = [setup.desktop, setup.drive_c, setup.recycle_bin][TOPS.find(parts[0])]
	for i in range(1, parts.size() - 1):
		var folder := _named(container, parts[i])
		if folder == null:
			if not make:
				return null
			folder = Win95File.new()
			folder.name = parts[i]
			folder.is_folder = true
			container.append(folder)
		container = folder.children
	return container


static func _named(container: Array, file_name: String) -> Win95File:
	for file: Win95File in container:
		if file.name.nocasecmp_to(file_name) == 0:
			return file
	return null


static func _take_fields(target: Win95File, source: Win95File) -> void:
	for property: Dictionary in _fields(source, _FILE_SKIP):
		target.set(property.name, source.get(property.name))


# Every file and folder of [param setup] by its path in lower case, parents first: [path, file]; or
# a String naming two files of one name.
static func _flatten(setup: Win95Setup) -> Variant:
	var flat := {}
	for i in TOPS.size():
		var bad: String = _flatten_into(flat, [setup.desktop, setup.drive_c, setup.recycle_bin][i], TOPS[i])
		if bad != "":
			return bad
	return flat


static func _flatten_into(flat: Dictionary, container: Array, path: String) -> String:
	for file: Win95File in container:
		var file_path := path + "\\" + file.name
		if flat.has(file_path.to_lower()):
			return "two files are named %s" % file_path
		flat[file_path.to_lower()] = [file_path, file]
		var bad := _flatten_into(flat, file.children, file_path)
		if bad != "":
			return bad
	return ""


static func _mail_key(mail: Email) -> String:
	return "%s %s" % [mail.sent, mail.subject]


static func _mails_by_key(setup: Win95Setup) -> Variant:
	var by_key := {}
	for mail: Email in setup.emails:
		if by_key.has(_mail_key(mail)):
			return "two mails are sent %s with the subject '%s'" % [mail.sent, mail.subject]
		by_key[_mail_key(mail)] = mail
	return by_key
