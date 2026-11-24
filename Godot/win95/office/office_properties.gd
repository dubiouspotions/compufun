extends PropertySheet
## An Office document's File > Properties, as Office 97 shows it (docs/win95-reference.md, "Office
## 97"): "Letter Properties" with the tabs General and Summary, open on Summary. General tells the
## file's type, place, size and dates; Summary edits the file's Win95File.summary, which OK keeps.

## The types that Office 97 named, by extension.
const _TYPES := {"DOC": "Microsoft Word Document", "RTF": "Rich Text Format", "XLS": "Microsoft Excel Worksheet"}

var _file: Win95File


## Shows [param file], a document in [param location] such as "C:\My Documents"; an untitled one has
## an empty location and is called [param display_name]. [param template] fills Summary's Template
## row ("Normal" in Word); empty hides the row, as in Excel.
func show_document(file: Win95File, display_name: String, location: String, template: String) -> void:
	_file = file
	%TitleBar.title = "%s Properties" % display_name
	%Tabs.current_tab = %Summary.get_index()
	for field in _summary_fields():
		var value: String = file.summary.get(field.get_meta(&"summary_key"), "")
		if field is TextEdit:
			(field as TextEdit).text = value
		else:
			(field as LineEdit).text = value
	%Template.text = template
	%Template.visible = template != ""
	%TemplateLabel.visible = template != ""
	var saved := location != ""
	%Icon.texture = file.icon if saved else null
	%FileName.text = display_name if saved else ""
	var extension := file.name.get_extension().to_upper()
	%Type.text = _TYPES.get(extension, "%s File" % extension) if saved else ""
	%Location.text = location
	%Size.text = (load("res://win95/properties_window.gd") as GDScript).call(&"size_text", file.size_in_bytes()) if saved else ""
	%DosName.text = dos_name(file.name) if saved else ""
	for date: Label in [%Created, %Accessed]:
		date.text = file.modified if saved and file.modified != "" else "(unknown)"
	%Modified.text = file.modified if saved and file.modified != "" else "(unknown)"


## Commits Summary into the file, as OK does.
func apply() -> void:
	super()
	if _file == null:
		return
	for field in _summary_fields():
		var key: StringName = field.get_meta(&"summary_key")
		var value: String = (field as TextEdit).text if field is TextEdit else (field as LineEdit).text
		if value == "":
			_file.summary.erase(key)
		else:
			_file.summary[key] = value
	if computer != null:
		computer.changed.emit()


## [param file_name] as MS-DOS shows a long name: eight capitals and ~1, then the extension.
static func dos_name(file_name: String) -> String:
	var base := file_name.get_basename().to_upper().replace(" ", "")
	var extension := file_name.get_extension().to_upper().left(3)
	if base.length() > 8 or file_name.get_basename().contains(" "):
		base = base.left(6) + "~1"
	return base + ("." + extension if extension != "" else "")


func _summary_fields() -> Array[Control]:
	var fields: Array[Control] = []
	for child in %Summary.get_children():
		if child.has_meta(&"summary_key"):
			fields.append(child)
	return fields
