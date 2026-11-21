class_name PropertySheet
extends "res://win95/window.gd"
## A Win95 property sheet, such as Display Properties: tabs of PropertyPages, and OK, Cancel and
## Apply. A tab that is not a PropertyPage only shows. An applet's sheet is a scene that inherits
## property_sheet.tscn and adds its pages under %Tabs. It reads the computer from its
## Win95Desktop, and closing frees it, so the next open reads the running copy again.

## False hides Apply, as on System Properties.
@export var has_apply := true

## The computer whose running copy the pages show and change; null when not on a Win95Desktop.
var computer: ComputerState


func _ready() -> void:
	super()
	var desktop := get_parent() as Win95Desktop
	computer = desktop.computer if desktop != null else null
	if computer == null or computer.setup == null:
		push_error("%s: not on a Win95Desktop with a running computer, so its pages stay empty" % %TitleBar.title)
	%Ok.pressed.connect(func() -> void:
		apply()
		close())
	%Cancel.pressed.connect(close)
	%Apply.pressed.connect(apply)
	%Apply.visible = has_apply
	%Apply.disabled = true
	closed.connect(queue_free)
	for page in pages():
		page.edited.connect(func() -> void: %Apply.disabled = false)
		if computer != null and computer.setup != null:
			page.load_from(computer)


## The pages, in tab order.
func pages() -> Array[PropertyPage]:
	var found: Array[PropertyPage] = []
	for child in %Tabs.get_children():
		if child is PropertyPage:
			found.append(child)
	return found


## Commits every page to the computer, as Apply does, and greys Apply until the next edit.
func apply() -> void:
	if computer == null:
		return
	for page in pages():
		page.apply(computer)
	%Apply.disabled = true
