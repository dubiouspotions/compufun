class_name CambionLabel
extends Label3D
## A label in the shop that names CompuFun's things, such as the taped note's "Start CompuFunDB". The
## corruption sign logo_cambion swaps its text for [member cambion_text] at the moment that the logo
## signs turn CambIon, and swaps it back when it ends.

## The group of the CambionLabels in the shop.
const GROUP: StringName = &"cambion_labels"

## The text while [member cambion] is on. The scene's [member Label3D.text] is the text while it is off.
@export_multiline var cambion_text: String = ""

## On: the label shows [member cambion_text].
var cambion: bool = false:
	set(value):
		cambion = value
		_show()

var _plain_text: String = ""


## Every CambionLabel in the group [constant GROUP] of [param tree]. Reports an empty group, and a
## node in the group that is not a CambionLabel.
static func every(tree: SceneTree) -> Array[CambionLabel]:
	var labels: Array[CambionLabel] = []
	for node: Node in tree.get_nodes_in_group(GROUP):
		var label := node as CambionLabel
		if label == null:
			push_error("CambionLabel: %s in the group %s is not a CambionLabel" % [node.get_path(), GROUP])
		else:
			labels.append(label)
	if labels.is_empty():
		push_error("CambionLabel: no label in the group %s" % GROUP)
	return labels


func _ready() -> void:
	_plain_text = text
	if cambion_text.is_empty():
		push_error("CambionLabel %s: cambion_text is empty" % get_path())
	_show()


func _show() -> void:
	if is_node_ready():
		text = cambion_text if cambion else _plain_text
