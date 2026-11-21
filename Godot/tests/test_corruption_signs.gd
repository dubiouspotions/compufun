extends "res://tests/test.gd"
## Every corruption sign file (wiki: Architecture, "Corruption signs") is a scene whose root script
## extends CorruptionSign and sets a title. It reads the files as text: a sign script names the Game
## autoload, so it does not compile under -s.

const FOLDER: String = "res://corruption/"


func run() -> void:
	var files := Array(ResourceLoader.list_directory(FOLDER)).filter(func(f: String) -> bool: return f.get_extension() == "tscn")
	check("the sign folder lists", files is Array, true)
	for file: String in files:
		var text := FileAccess.get_file_as_string(FOLDER + file)
		check("%s reads" % file, text.is_empty(), false)
		var root := _root_block(text)
		var script_id := _match(root, "script = ExtResource\\(\"([^\"]+)\"\\)")
		var script_path := _match(text, "\\[ext_resource type=\"Script\"[^\\]]*path=\"([^\"]+)\"[^\\]]*id=\"%s\"\\]" % script_id)
		check("%s has a root script" % file, script_path.is_empty(), false)
		var source := FileAccess.get_file_as_string(script_path) if not script_path.is_empty() else ""
		check("%s: its script extends CorruptionSign" % file, RegEx.create_from_string("(?m)^extends CorruptionSign$").search(source) != null, true)
		check("%s has a title" % file, _match(root, "(?m)^title = \"(.+)\"$").is_empty(), false)


# The lines of the root node: from the first [node] to the next one.
func _root_block(text: String) -> String:
	var start := text.find("[node ")
	if start < 0:
		return ""
	var next := text.find("\n[node ", start + 1)
	return text.substr(start, next - start if next > 0 else -1)


func _match(text: String, pattern: String) -> String:
	var found := RegEx.create_from_string(pattern).search(text)
	return found.get_string(1) if found != null else ""
