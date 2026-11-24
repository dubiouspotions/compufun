extends CorruptionSign
## Clippy is gone from every computer: the Office Assistant's window in Word and Excel comes, talks
## and answers as before, but shows no paper clip, and every WordPad shows his empty frame, as a
## computer with the NoClippy problem does (wiki: In-world - Corruption Signs).

const _WORDPAD := preload("res://win95/wordpad.gd")
const _ASSISTANT := preload("res://win95/office/assistant/assistant.gd")


func _apply(shown_stage: int) -> void:
	_set_taken(shown_stage > 0)


func _exit_tree() -> void:
	_set_taken(false)  # the root outlives the shop


func _set_taken(taken: bool) -> void:
	var root := get_tree().root
	if taken == root.get_meta(_WORDPAD.ASSISTANT_TAKEN_META, false):
		return
	root.set_meta(_WORDPAD.ASSISTANT_TAKEN_META, taken)
	get_tree().call_group(_WORDPAD.GROUP, &"_sync_assistant")
	get_tree().call_group(_ASSISTANT.GROUP, &"_sync_assistant")
