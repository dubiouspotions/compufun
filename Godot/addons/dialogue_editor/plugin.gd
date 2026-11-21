@tool
extends EditorPlugin
## Adds the Dialogue tab next to 2D, 3D and Script.

const DialogueEditor := preload("res://addons/dialogue_editor/dialogue_editor.gd")

var _panel: DialogueEditor


func _enter_tree() -> void:
	_panel = DialogueEditor.new()
	EditorInterface.get_editor_main_screen().add_child(_panel)
	_make_visible(false)


func _exit_tree() -> void:
	if _panel != null:
		_panel.queue_free()


func _has_main_screen() -> bool:
	return true


func _make_visible(visible: bool) -> void:
	if _panel == null:
		return
	_panel.visible = visible
	if visible:
		_panel.refresh()


func _get_plugin_name() -> String:
	return "Dialogue"


func _get_plugin_icon() -> Texture2D:
	return EditorInterface.get_editor_theme().get_icon(&"TextEdit", &"EditorIcons")


func _save_external_data() -> void:
	_panel.save_all()


func _get_unsaved_status(for_scene: String) -> String:
	return _panel.unsaved_status() if for_scene == "" else ""
