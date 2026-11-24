class_name PropertyPage
extends Control
## One tab of a PropertySheet; the tab shows the node's name. Lay the page out at Win95's pixel
## positions and set custom_minimum_size to its size: the sheet sizes itself to its largest page.

## The player changed something on the page; the sheet enables Apply.
@warning_ignore("unused_signal")  # the pages emit it
signal edited


## Fills the page from [param computer]'s running copy, once, when the sheet opens.
func load_from(_computer: ComputerState) -> void:
	pass


## The Win95Setup properties that the page changes, by name, with their new values.
func pending() -> Dictionary[StringName, Variant]:
	return {}


## Commits the page, on Apply and OK: sets [method pending] in one change. A page whose change
## isn't a setting, such as an uninstall, overrides this.
func apply(computer: ComputerState) -> void:
	var values := pending()
	if not values.is_empty():
		computer.apply_settings(values)
