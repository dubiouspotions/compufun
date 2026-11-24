extends "res://win95/window.gd"
## PowerPoint's Apply Design (Format > Apply Design): the design templates in the Presentation
## Designs folder by name, a preview of the one picked, and Apply.

## The player applied [param design_name]; empty is the Default Design.
signal chosen(design_name: String)

var _designs: Array[PptDesign] = []
var _sample := PptDeck.Slide.new("Title Slide")


func _ready() -> void:
	super()
	_sample.title = "Title of Slide"
	_sample.body = PackedStringArray(["Subtitle"])
	%Designs.item_selected.connect(_preview)
	%Designs.item_activated.connect(func(_index: int) -> void: _apply())
	%Apply.pressed.connect(_apply)
	%Cancel.pressed.connect(close)
	closed.connect(queue_free)


## Lists [param designs], the Default Design first, with [param current] picked.
func list(designs: Array[PptDesign], current: String) -> void:
	_designs = designs
	%Designs.clear()
	for design in designs:
		%Designs.add_item(design.name)
	var at := 0
	for i in range(1, designs.size()):
		if designs[i].name == current:
			at = i
	if not designs.is_empty():
		%Designs.select(at)
		_preview(at)


func _preview(index: int) -> void:
	%Preview.show_slide(_sample, _designs[index])


func _apply() -> void:
	var picked: PackedInt32Array = %Designs.get_selected_items()
	if picked.is_empty():
		return
	chosen.emit("" if picked[0] == 0 else _designs[picked[0]].name)  # the first is the Default Design
	close()
